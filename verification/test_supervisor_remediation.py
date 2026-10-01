"""No-launch failures must be recoverable without weakening writer ownership."""
import argparse
import importlib.util
import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

HELPER = Path(__file__).resolve().parents[1] / 'assets/native/process-supervisor.py'


@unittest.skipUnless(sys.platform == 'linux', 'Actual supervisor requires Linux')
class SupervisorNoLaunch(unittest.TestCase):
    def setUp(self):
        self.fixture = tempfile.TemporaryDirectory(prefix='supervisor-no-launch-')
        self.addCleanup(self.fixture.cleanup)
        self.status = Path(self.fixture.name) / 'status.json'
        spec = importlib.util.spec_from_file_location('supervisor', HELPER)
        self.helper = importlib.util.module_from_spec(spec); spec.loader.exec_module(self.helper)
        self.parent_birth = Path('/proc', str(os.getpid()), 'stat').read_text().rsplit(')', 1)[1].split()[19]
        self.args = argparse.Namespace(status_file=str(self.status), nonce='no-launch', command=['missing-worker'],
                                       parent_pid=os.getpid(), parent_birth=self.parent_birth)

    def assert_no_launch(self):
        status = json.loads(self.status.read_text())
        self.assertEqual(status['nonce'], 'no-launch')
        self.assertIs(status['quiescent'], True)
        self.assertIn('no worker was launched', status['error'])

    def test_missing_executable_certifies_no_worker(self):
        result = subprocess.run([sys.executable, str(HELPER), '--status-file', str(self.status),
                                 '--nonce', 'no-launch', '--parent-pid', str(os.getpid()),
                                 '--parent-birth', self.parent_birth, '--', str(Path(self.fixture.name) / 'missing-worker')],
                                capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_launch()

    def test_dead_or_reused_launcher_identity_never_launches(self):
        self.args.parent_birth = str(int(self.parent_birth) + 1)
        with patch.object(self.helper.subprocess, 'Popen') as launch:
            self.assertNotEqual(self.helper.supervise(self.args), 0)
            launch.assert_not_called()
        self.assert_no_launch()

    def test_caller_death_during_startup_never_adopts_new_parent(self):
        root = Path(self.fixture.name)
        ready, release, marker = (root / name for name in ('ready', 'release', 'writer'))
        driver_template = '''import argparse,importlib.util,pathlib,sys,time
spec=importlib.util.spec_from_file_location('startup_supervisor',HELPER)
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
pathlib.Path(READY).touch()
while not pathlib.Path(RELEASE).exists():time.sleep(.005)
sys.exit(helper.supervise(argparse.Namespace(status_file=STATUS,nonce='no-launch',
    parent_pid=PARENT_PID,parent_birth=PARENT_BIRTH,
    command=[sys.executable,'-c',WORKER])))
'''
        launcher = f'''import os,pathlib,subprocess,sys
values={{'HELPER':{str(HELPER)!r},'READY':{str(ready)!r},'RELEASE':{str(release)!r},
        'STATUS':{str(self.status)!r},'PARENT_PID':os.getpid(),
        'PARENT_BIRTH':pathlib.Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],
        'WORKER':{f'import pathlib;pathlib.Path({str(marker)!r}).write_text("orphan writer launched")'!r}}}
driver={driver_template!r}
for name,value in values.items():driver=driver.replace(name,repr(value))
child=subprocess.Popen([sys.executable,'-c',driver],start_new_session=True,
    stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
birth=pathlib.Path('/proc',str(child.pid),'stat').read_text().rsplit(')',1)[1].split()[19]
print(child.pid,birth,flush=True)
'''
        result = subprocess.run([sys.executable, '-c', launcher], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        pid, identity = result.stdout.strip().split()
        descriptor = os.pidfd_open(int(pid), 0)
        try:
            deadline = time.monotonic() + 5
            while not ready.exists() and time.monotonic() < deadline:
                time.sleep(.005)
            self.assertTrue(ready.exists(), 'Supervisor must reach the simulated startup boundary')
            release.touch()  # Original launcher has already exited and been reaped.
            while not self.status.exists() and time.monotonic() < deadline:
                time.sleep(.005)
            self.assertTrue(self.status.exists(), 'No-launch result must be durable')
            self.assert_no_launch()
            self.assertIn('original launcher already stopped', self.status.read_text())
            self.assertFalse(marker.exists(), 'Reparenting must not authorize an orphan launch')
        finally:
            try:
                fields = Path('/proc', pid, 'stat').read_text().rsplit(')', 1)[1].split()
                if fields[19] == identity and fields[0] not in ('Z', 'X'):
                    signal.pidfd_send_signal(descriptor, signal.SIGTERM)
            except (FileNotFoundError, ProcessLookupError):
                pass
            os.close(descriptor)

    def test_subreaper_setup_failure_never_launches(self):
        library = Mock(); library.prctl.return_value = 1
        with patch.object(self.helper.ctypes, 'CDLL', return_value=library), \
                patch.object(self.helper.subprocess, 'Popen') as launch:
            self.assertNotEqual(self.helper.supervise(self.args), 0)
            launch.assert_not_called()
        self.assert_no_launch()

    def test_initial_inspection_failure_never_launches(self):
        library = Mock(); library.prctl.return_value = 0
        with patch.object(self.helper.ctypes, 'CDLL', return_value=library), \
                patch.object(self.helper, 'process_table', side_effect=OSError('fixture inspection unavailable')), \
                patch.object(self.helper.subprocess, 'Popen') as launch:
            self.assertNotEqual(self.helper.supervise(self.args), 0)
            launch.assert_not_called()
        self.assert_no_launch()
