"""Kernel child exhaustion must defeat a real fork during /proc enumeration."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

HELPER = Path(__file__).resolve().parents[1] / 'assets/native/process-supervisor.py'


@unittest.skipUnless(sys.platform == 'linux', 'Owned descendants require Linux')
class SupervisorEnumerationRace(unittest.TestCase):
    def test_new_setsid_writer_missing_from_proc_snapshot_prevents_certificate(self):
        with tempfile.TemporaryDirectory(prefix='supervisor-enumeration-race-') as directory:
            root = Path(directory)
            status = root / 'status.json'
            worker = root / 'worker.py'
            # The CLI exits after spawning an adopted child. That last child
            # forks a new detached writer precisely after the /proc names have
            # been enumerated, then exits before its own stat is read.
            parent_code = '''import os,pathlib,time
birth=pathlib.Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19]
pathlib.Path('fork-parent.birth').write_text(birth)
pathlib.Path('fork-parent.pid').write_text(str(os.getpid()))
while not pathlib.Path('fork-now').exists(): time.sleep(.001)
pid=os.fork()
if pid: os._exit(0)
os.setsid()
birth=pathlib.Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19]
pathlib.Path('new-writer.birth').write_text(birth)
pathlib.Path('new-writer.pid').write_text(str(os.getpid()))
time.sleep(.4)
pathlib.Path('copy.txt').write_text('late new writer')
time.sleep(3)
'''
            worker.write_text(
                "import os,pathlib,subprocess,sys,time\n"
                "birth=pathlib.Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19]\n"
                "pathlib.Path('cli.birth').write_text(birth)\n"
                "pathlib.Path('cli.pid').write_text(str(os.getpid()))\n"
                f"subprocess.Popen([sys.executable,'-c',{parent_code!r}],start_new_session=True,"
                "stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n"
                "while not pathlib.Path('fork-parent.pid').exists(): time.sleep(.001)\n")
            harness = f'''import argparse,importlib.util,os,pathlib,sys,time
spec=importlib.util.spec_from_file_location('fixture_supervisor',{str(HELPER)!r})
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
real_listdir=module.os.listdir
injected=[]
def racing_listdir(directory):
    names=real_listdir(directory)
    marker=pathlib.Path('cli.pid')
    if directory=='/proc' and marker.exists() and pathlib.Path('fork-parent.pid').exists() and not injected and not pathlib.Path('/proc',marker.read_text(),'stat').exists():
        injected.append(True)
        pathlib.Path('fork-now').touch()
        deadline=time.monotonic()+1
        while not pathlib.Path('new-writer.pid').exists() and time.monotonic()<deadline:time.sleep(.001)
        # This pause models ordinary preemption between names and stat reads.
        # It is NOT a production shutdown heuristic or a fabricated process table.
        time.sleep(.03)
    return names
module.os.listdir=racing_listdir
parent_pid=os.getppid()
parent_birth=pathlib.Path('/proc',str(parent_pid),'stat').read_text().rsplit(')',1)[1].split()[19]
code=module.supervise(argparse.Namespace(status_file={str(status)!r},nonce='enumeration-race',command=[sys.executable,{str(worker)!r}],parent_pid=parent_pid,parent_birth=parent_birth))
pathlib.Path('race-injected.json').write_text(str(bool(injected)))
sys.exit(code)
'''
            try:
                result = subprocess.run([sys.executable, '-c', harness], cwd=root,
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((root / 'race-injected.json').read_text(), 'True')
                self.assertTrue((root / 'new-writer.pid').exists(), 'Race must actually create a new writer')
                certificate = json.loads(status.read_text())
                self.assertEqual(certificate['nonce'], 'enumeration-race')
                self.assertIs(certificate['quiescent'], True)
                time.sleep(.6)
                self.assertFalse((root / 'copy.txt').exists(),
                                 'A writer absent from the /proc name snapshot wrote after a quiescent certificate')
                pid = int((root / 'new-writer.pid').read_text())
                stat_file = Path('/proc', str(pid), 'stat')
                if stat_file.exists():
                    self.assertIn(stat_file.read_text().rsplit(')', 1)[1].split()[0], ('Z', 'X'))
            finally:
                # Bind cleanup to the original fixture process, not a recycled
                # numeric PID after the supervisor already reaped that child.
                for filename in ('cli.pid', 'fork-parent.pid', 'new-writer.pid'):
                    file = root / filename
                    birth_file = file.with_suffix('.birth')
                    if file.exists() and birth_file.exists():
                        descriptor = None
                        try:
                            pid = int(file.read_text())
                            descriptor = os.pidfd_open(pid, 0)
                            fields = Path('/proc', str(pid), 'stat').read_text().rsplit(')', 1)[1].split()
                            if fields[19] == birth_file.read_text() and fields[0] not in ('Z', 'X'):
                                signal.pidfd_send_signal(descriptor, signal.SIGKILL)
                        except (FileNotFoundError, ProcessLookupError):
                            pass
                        finally:
                            if descriptor is not None:
                                os.close(descriptor)


if __name__ == '__main__':
    unittest.main()
