"""F03 real subprocess descendants: shutdown must precede rollback and retry."""
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.request
import urllib.error

KIT = Path(__file__).resolve().parents[1]
SCRIPTS = KIT / 'assets/packs/web-design/scaffold/.agents/skills/impeccable/scripts'


@unittest.skipUnless(os.name == 'posix' and shutil.which('node'), 'POSIX and Node required')
class WebShutdownRemediationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='codex-web-shutdown-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.source = self.root / 'copy.html'
        self.source.write_text('original copy')
        self.env = {**os.environ, 'PATH': str(self.bin) + os.pathsep + os.environ['PATH']}
        self.batch = {'entries': [{'id': 'entry1', 'pageUrl': '/', 'ops': [{
            'entryId': 'entry1', 'ref': 'copy', 'originalText': 'original copy',
            'newText': 'retry copy', 'sourceHint': {'file': 'copy.html', 'line': 1},
        }]}], 'candidates': []}
        self.worker = self.bin / 'codex'
        # Real descendant ignores SIGTERM and writes after the original timeout.
        self.worker.write_text('''#!/usr/bin/env python3
import json, os, pathlib, signal, subprocess, sys, time
if '--version' in sys.argv: print('test codex'); sys.exit(0)
root=pathlib.Path.cwd()
mode=os.environ.get('FIXTURE_MODE','hang')
if mode=='retry':
    (root/'copy.html').write_text('retry copy')
    result=sys.argv[sys.argv.index('--output-last-message')+1]
    pathlib.Path(result).write_text(json.dumps({'status':'done','appliedEntryIds':['entry1'],'files':['copy.html'],'notes':[]}))
    sys.exit(0)
(root/'copy.html').write_text('worker partial copy')
grandchild="import os,pathlib,signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); v=pathlib.Path('/proc/self/stat').read_text(); pathlib.Path('descendant.birth').write_text(v[v.rfind(')')+2:].split()[19]); pathlib.Path('descendant.pid').write_text(str(os.getpid())); time.sleep(1.4); pathlib.Path('copy.html').write_text('late descendant write'); time.sleep(5)"
child=subprocess.Popen([sys.executable,'-c',grandchild],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
v=pathlib.Path('/proc/self/stat').read_text()
(root/'worker.birth').write_text(v[v.rfind(')')+2:].split()[19])
(root/'worker.pid').write_text(str(os.getpid()))
while not (root/'descendant.pid').exists(): time.sleep(.01)
if mode=='exit-error': sys.exit(7)
if mode=='exit-success':
    result=sys.argv[sys.argv.index('--output-last-message')+1]
    pathlib.Path(result).write_text(json.dumps({'status':'error','message':'fixture failed','files':['copy.html']}))
    sys.exit(0)
if mode=='resistant': signal.signal(signal.SIGTERM,signal.SIG_IGN)
while True: time.sleep(1)
''')
        self.worker.chmod(0o755)
        self.addCleanup(self.kill_fixture_workers)

    def kill_fixture_workers(self):
        # Exact owned fixture PIDs only, never a process-name/global kill.
        for name in ('worker.pid', 'descendant.pid'):
            path = self.root / name
            identity = self.root / name.replace('.pid', '.birth')
            if path.exists() and identity.exists():
                descriptor = None
                try:
                    pid = int(path.read_text())
                    descriptor = os.pidfd_open(pid, 0)
                    value = Path(f'/proc/{pid}/stat').read_text()
                    if value[value.rfind(')')+2:].split()[19] == identity.read_text():
                        signal.pidfd_send_signal(descriptor, signal.SIGKILL)
                except (FileNotFoundError, ProcessLookupError):
                    pass
                finally:
                    if descriptor is not None: os.close(descriptor)

    def script(self, extra=''):
        return f'''
import fs from 'node:fs';
import {{commitManualEdits}} from {json.dumps((SCRIPTS/'live-commit-manual-edits.mjs').as_uri())};
const batch={json.dumps(self.batch)};
const before={{term:process.listenerCount('SIGTERM'),int:process.listenerCount('SIGINT'),exit:process.listenerCount('exit')}};
const first=await commitManualEdits({{cwd:process.cwd(),batch,provider:'codex',timeoutMs:300}});
const atRollback=fs.readFileSync('copy.html','utf8');
{extra}
await new Promise(resolve=>setTimeout(resolve,1600));
console.log(JSON.stringify({{first,atRollback,after:fs.readFileSync('copy.html','utf8'),before,afterListeners:{{term:process.listenerCount('SIGTERM'),int:process.listenerCount('SIGINT'),exit:process.listenerCount('exit')}}}}));
'''

    def run_fixture(self, mode='hang', extra=''):
        result = subprocess.run(['node', '--input-type=module', '-e', self.script(extra)],
                                cwd=self.root, env={**self.env, 'FIXTURE_MODE': mode},
                                capture_output=True, text=True, timeout=12)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def assert_rolled_back(self, data):
        self.assertTrue(data['first']['failed'])
        self.assertEqual(data['atRollback'], 'original copy')
        self.assertEqual(data['after'], 'original copy')
        self.assertEqual(data['before'], data['afterListeners'])

    def test_timeout_stops_resistant_descendant_before_rollback(self):
        self.assert_rolled_back(self.run_fixture())

    def detach_fixture_descendant(self):
        self.worker.write_text(self.worker.read_text().replace(
            'stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)',
            'stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)'))

    def test_timeout_stops_setsid_descendant_before_rollback_and_retry(self):
        self.detach_fixture_descendant()
        self.assert_rolled_back(self.run_fixture())
        extra = '''
const second=await commitManualEdits({cwd:process.cwd(),batch,provider:'codex',timeoutMs:1000,env:{...process.env,FIXTURE_MODE:'retry'}});
if(second.applied.length!==1) throw new Error(JSON.stringify(second));
'''
        data = self.run_fixture(extra=extra)
        self.assertEqual(data['atRollback'], 'original copy')
        self.assertEqual(data['after'], 'retry copy')

    def test_leader_exit_stops_setsid_descendant_before_rollback(self):
        self.detach_fixture_descendant()
        for mode in ('exit-error', 'exit-success'):
            with self.subTest(mode=mode):
                self.source.write_text('original copy')
                for name in ('worker.pid', 'descendant.pid'):
                    (self.root / name).unlink(missing_ok=True)
                self.assert_rolled_back(self.run_fixture(mode))

    def test_direct_parent_exit_stops_setsid_descendant(self):
        self.detach_fixture_descendant()
        self.test_direct_parent_exit_force_kills_only_owned_group()

    def test_parent_sigkill_stops_setsid_descendant_without_exit_handler(self):
        self.detach_fixture_descendant()
        code = f'''
import {{runCopyEditBatchAgent}} from {json.dumps((SCRIPTS/'live-copy-edit-agent.mjs').as_uri())};
await runCopyEditBatchAgent({json.dumps(self.batch)},{{cwd:process.cwd(),provider:'codex',timeoutMs:5000}});
'''
        parent = subprocess.Popen(['node', '--input-type=module', '-e', code], cwd=self.root,
                                  env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: parent.kill() if parent.poll() is None else None)
        deadline = time.monotonic() + 5
        while not (self.root/'descendant.pid').exists() and time.monotonic() < deadline:
            time.sleep(.02)
        self.assertTrue((self.root/'descendant.pid').exists())
        parent.kill()
        parent.communicate(timeout=5)
        time.sleep(1.6)
        self.assertEqual(self.source.read_text(), 'worker partial copy')

    def test_validation_timeout_stops_setsid_descendant_before_rollback(self):
        self.detach_fixture_descendant()
        self.test_validation_timeout_stops_shell_descendants_before_rollback()

    def test_supervisor_inspection_failure_retains_and_stops_owned_descendants(self):
        self.detach_fixture_descendant()
        supervisor = SCRIPTS / 'process-supervisor.py'
        status = self.root / 'supervisor.json'
        code = f'''
import argparse,importlib.util,pathlib,sys
spec=importlib.util.spec_from_file_location('fixture_supervisor',{str(supervisor)!r})
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
real_table=module.process_table
failed=[]
def inspect():
    if pathlib.Path('descendant.pid').exists() and not failed:
        failed.append(True)
        raise PermissionError('fixture inspection interrupted')
    return real_table()
module.process_table=inspect
args=argparse.Namespace(status_file={str(status)!r},nonce='inspection-failure-fixture',parent_pid={os.getpid()},parent_birth=real_table()[{os.getpid()}]['birth'],command=[sys.executable,{str(self.worker)!r},'exec'])
sys.exit(module.supervise(args))
'''
        result = subprocess.run(['python3', '-c', code], cwd=self.root, env=self.env,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 143, result.stderr)
        ownership = json.loads(status.read_text())
        self.assertTrue(ownership['quiescent'])
        self.assertIn('fixture inspection interrupted', ownership['error'])
        time.sleep(1.6)
        self.assertEqual(self.source.read_text(), 'worker partial copy')

    def test_timeout_escalates_for_resistant_leader_and_descendant(self):
        self.assert_rolled_back(self.run_fixture('resistant'))

    def test_timeout_does_not_signal_unrelated_process(self):
        unrelated = subprocess.Popen(['python3', '-c',
            "import pathlib,signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(.7); pathlib.Path('unrelated.html').write_text('unrelated writer survived'); time.sleep(4)"],
            cwd=self.root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        try:
            self.assert_rolled_back(self.run_fixture())
            self.assertIsNone(unrelated.poll())
            self.assertEqual((self.root/'unrelated.html').read_text(), 'unrelated writer survived')
        finally:
            unrelated.kill()
            unrelated.wait(timeout=3)

    def test_validation_timeout_stops_shell_descendants_before_rollback(self):
        (self.root/'package.json').write_text(json.dumps({'scripts': {
            'impeccable:manual-edit-validate': 'FIXTURE_MODE=hang ' + str(self.worker) + ' validate',
        }}))
        code = f'''
import fs from 'node:fs';
import {{runCopyEditPostApplyChecks}} from {json.dumps((SCRIPTS/'live-copy-edit-agent.mjs').as_uri())};
const result=await runCopyEditPostApplyChecks({{cwd:process.cwd(),files:['copy.html'],env:{{...process.env,IMPECCABLE_LIVE_MANUAL_EDIT_VALIDATE_TIMEOUT_MS:'300'}}}});
fs.writeFileSync('copy.html','original copy');
await new Promise(resolve=>setTimeout(resolve,1600));
console.log(JSON.stringify({{result,after:fs.readFileSync('copy.html','utf8')}}));
'''
        result = subprocess.run(['node', '--input-type=module', '-e', code], cwd=self.root,
                                env=self.env, capture_output=True, text=True, timeout=7)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertFalse(data['result']['ok'])
        self.assertIn('timed out', data['result']['failures'][0]['message'])
        self.assertEqual(data['after'], 'original copy')

    def test_unverifiable_shutdown_preserves_transaction_and_blocks_retry(self):
        code = f'''
import fs from 'node:fs';
import {{commitManualEdits}} from {json.dumps((SCRIPTS/'live-commit-manual-edits.mjs').as_uri())};
const realKill=process.kill.bind(process);
process.kill=(pid,signal)=>{{if(pid<0&&signal===0){{const error=new Error('fixture cannot inspect group');error.code='EPERM';throw error;}}return realKill(pid,signal);}};
const batch={json.dumps(self.batch)};
const first=await commitManualEdits({{cwd:process.cwd(),batch,provider:'codex',timeoutMs:300}});
const firstPid=fs.readFileSync('worker.pid','utf8');
let second;
try {{ await commitManualEdits({{cwd:process.cwd(),batch,provider:'codex',timeoutMs:1000,env:{{...process.env,FIXTURE_MODE:'retry'}}}}); second={{started:true}}; }}
catch(error) {{ second={{blocked:true,code:error.code}}; }}
console.log(JSON.stringify({{first,second,firstPid,afterPid:fs.readFileSync('worker.pid','utf8'),after:fs.readFileSync('copy.html','utf8')}}));
'''
        result = subprocess.run(['node', '--input-type=module', '-e', code], cwd=self.root,
                                env=self.env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertTrue(data['first']['needsManualDecision'])
        self.assertTrue(data['first']['rollbackDeferred'])
        self.assertTrue(data['second']['blocked'])
        self.assertEqual(data['second']['code'], 'MANUAL_EDIT_OPERATION_OWNED')
        self.assertEqual(data['after'], 'worker partial copy')
        self.assertEqual(data['firstPid'], data['afterPid'])

    def test_nonzero_leader_exit_stops_descendant_before_rollback(self):
        self.assert_rolled_back(self.run_fixture('exit-error'))

    def test_zero_leader_exit_also_stops_descendant_before_validation_rollback(self):
        self.assert_rolled_back(self.run_fixture('exit-success'))

    def test_retry_cannot_receive_writes_from_previous_attempt(self):
        extra = '''
const second=await commitManualEdits({cwd:process.cwd(),batch,provider:'codex',timeoutMs:1000,env:{...process.env,FIXTURE_MODE:'retry'}});
if(second.applied.length!==1) throw new Error(JSON.stringify(second));
'''
        data = self.run_fixture(extra=extra)
        self.assertTrue(data['first']['failed'])
        self.assertEqual(data['atRollback'], 'original copy')
        self.assertEqual(data['after'], 'retry copy')
        self.assertEqual(data['before'], data['afterListeners'])

    def test_parent_interrupt_waits_for_shutdown_and_rollback(self):
        for sig in (signal.SIGTERM, signal.SIGINT):
            with self.subTest(signal=sig):
                self.source.write_text('original copy')
                for name in ('worker.pid', 'descendant.pid'):
                    (self.root / name).unlink(missing_ok=True)
                proc = subprocess.Popen(['node', '--input-type=module', '-e', self.script()],
                                        cwd=self.root, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                self.addCleanup(lambda p=proc: p.kill() if p.poll() is None else None)
                deadline = time.monotonic() + 4
                while not (self.root / 'descendant.pid').exists() and time.monotonic() < deadline:
                    time.sleep(.02)
                self.assertTrue((self.root / 'descendant.pid').exists())
                proc.send_signal(sig)
                stdout, stderr = proc.communicate(timeout=10)
                self.assertEqual(proc.returncode, 0, stdout + stderr)
                self.assert_rolled_back(json.loads(stdout))

    def test_direct_parent_exit_force_kills_only_owned_group(self):
        code = f'''
import fs from 'node:fs';
import {{runCopyEditBatchAgent}} from {json.dumps((SCRIPTS/'live-copy-edit-agent.mjs').as_uri())};
void runCopyEditBatchAgent({json.dumps(self.batch)},{{cwd:process.cwd(),provider:'codex',timeoutMs:5000}});
const timer=setInterval(()=>{{if(fs.existsSync('descendant.pid')) process.exit(23);}},20);
'''
        result = subprocess.run(['node', '--input-type=module', '-e', code], cwd=self.root,
                                env=self.env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 23, result.stderr)
        time.sleep(1.6)
        self.assertEqual(self.source.read_text(), 'worker partial copy')

    def test_shutdown_barrier_awaits_caller_rollback(self):
        code = f'''
import fs from 'node:fs';
import {{commitManualEdits,shutdownManualEditCommits}} from {json.dumps((SCRIPTS/'live-commit-manual-edits.mjs').as_uri())};
const task=commitManualEdits({{cwd:process.cwd(),batch:{json.dumps(self.batch)},provider:'codex',timeoutMs:5000}});
while(!fs.existsSync('descendant.pid')) await new Promise(resolve=>setTimeout(resolve,20));
await shutdownManualEditCommits('fixture server exit');
console.log(JSON.stringify({{afterBarrier:fs.readFileSync('copy.html','utf8'),result:await task}}));
'''
        result = subprocess.run(['node', '--input-type=module', '-e', code], cwd=self.root,
                                env=self.env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data['afterBarrier'], 'original copy')
        self.assertTrue(data['result']['failed'])
        time.sleep(1.6)
        self.assertEqual(self.source.read_text(), 'original copy')

    def test_live_server_shutdown_waits_for_worker_and_rollback(self):
        with socket.socket() as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
        pending = self.root / '.impeccable/live/pending-manual-edits.json'
        pending.parent.mkdir(parents=True)
        pending.write_text(json.dumps({'version': 1, 'entries': self.batch['entries']}))
        server = subprocess.Popen(['node', str(SCRIPTS/'live-server.mjs'), f'--port={port}'],
                                  cwd=self.root, env={**self.env, 'IMPECCABLE_LIVE_COPY_AGENT': 'codex'},
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: server.kill() if server.poll() is None else None)
        info = self.root / '.impeccable/live/server.json'
        deadline = time.monotonic() + 5
        while not info.exists() and server.poll() is None and time.monotonic() < deadline:
            time.sleep(.02)
        self.assertTrue(info.exists(), f'server exited: {server.poll()}')
        token = json.loads(info.read_text())['token']
        request = urllib.request.Request(f'http://127.0.0.1:{port}/manual-edit-commit?token={token}&async=1&pageUrl=/',
                                         data=b'', method='POST')
        with urllib.request.urlopen(request, timeout=3) as response:
            self.assertEqual(response.status, 202)
        deadline = time.monotonic() + 5
        while not (self.root/'descendant.pid').exists() and time.monotonic() < deadline:
            time.sleep(.02)
        self.assertTrue((self.root/'descendant.pid').exists())
        server.send_signal(signal.SIGTERM)
        stdout, stderr = server.communicate(timeout=5)
        self.assertEqual(server.returncode, 0, stdout + stderr)
        self.assertEqual(self.source.read_text(), 'original copy')

        time.sleep(1.6)
        self.assertEqual(self.source.read_text(), 'original copy')

    def start_http_server(self, *, timeout_ms=4500, mode='hang', port=None):
        if port is None:
            with socket.socket() as probe:
                probe.bind(('127.0.0.1', 0))
                port = probe.getsockname()[1]
        pending = self.root / '.impeccable/live/pending-manual-edits.json'
        pending.parent.mkdir(parents=True, exist_ok=True)
        if not pending.exists():
            pending.write_text(json.dumps({'version': 1, 'entries': self.batch['entries']}))
        server = subprocess.Popen(['node', str(SCRIPTS/'live-server.mjs'), f'--port={port}'],
                                  cwd=self.root, env={**self.env, 'FIXTURE_MODE': mode,
                                  'IMPECCABLE_LIVE_COPY_AGENT': 'codex',
                                  'IMPECCABLE_LIVE_COPY_AGENT_TIMEOUT_MS': str(timeout_ms)},
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        def cleanup():
            if server.poll() is None:
                server.terminate()
                try: server.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill(); server.communicate(timeout=3)
        self.addCleanup(cleanup)
        return server, port

    def wait_http_server(self, server):
        file = self.root / '.impeccable/live/server.json'
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if server.poll() is not None:
                stdout, stderr = server.communicate(timeout=2)
                self.fail(f'HTTP server exited {server.returncode}: {stdout} {stderr}')
            if file.exists():
                data = json.loads(file.read_text())
                if data['pid'] == server.pid:
                    return data
            time.sleep(.01)
        self.fail('HTTP server did not become ready')

    def http_post(self, info, endpoint, payload=None):
        request = urllib.request.Request(
            f'http://127.0.0.1:{info["port"]}{endpoint}' + ('&' if '?' in endpoint else '?') + f'token={info["token"]}',
            data=json.dumps(payload).encode() if payload is not None else b'', method='POST')
        try:
            with urllib.request.urlopen(request, timeout=3) as response:
                return response.status, json.loads(response.read())
        except urllib.error.HTTPError as error:
            try: return error.code, json.loads(error.read())
            finally: error.close()

    def wait_http_descendant(self):
        deadline = time.monotonic() + 5
        while not (self.root/'descendant.pid').exists() and time.monotonic() < deadline:
            time.sleep(.01)
        self.assertTrue((self.root/'descendant.pid').exists())

    def test_http_apply_rollback_discard_are_fenced_before_any_restore(self):
        server, port = self.start_http_server()
        info = self.wait_http_server(server)
        code, _ = self.http_post(info, '/manual-edit-commit?async=1&pageUrl=/')
        self.assertEqual(code, 202)
        self.wait_http_descendant()
        self.assertEqual(self.source.read_text(), 'worker partial copy')
        transaction = self.root/'.impeccable/live/manual-edit-apply-transaction.json'
        original = transaction.read_bytes()
        pending = self.root/'.impeccable/live/pending-manual-edits.json'
        staged = pending.read_bytes()
        for endpoint, payload in [('/manual-edit-commit?async=1&pageUrl=/', None),
                                  ('/manual-edit-repair-decision?pageUrl=/', {'action': 'rollback'}),
                                  ('/manual-edit-discard?pageUrl=/', None)]:
            with self.subTest(endpoint=endpoint):
                code, result = self.http_post(info, endpoint, payload)
                self.assertEqual(code, 409, result)
                self.assertEqual(transaction.read_bytes(), original)
                self.assertEqual(pending.read_bytes(), staged)
                self.assertEqual(self.source.read_text(), 'worker partial copy')
        server.terminate()
        stdout, stderr = server.communicate(timeout=5)
        self.assertEqual(server.returncode, 0, stdout + stderr)
        self.assertEqual(self.source.read_text(), 'original copy')
        time.sleep(1.6)
        self.assertEqual(self.source.read_text(), 'original copy')

    def test_http_restart_does_not_restore_until_owned_descendants_are_quiescent(self):
        continuous = "import os,pathlib,signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); v=pathlib.Path('/proc/self/stat').read_text(); pathlib.Path('descendant.birth').write_text(v[v.rfind(')')+2:].split()[19]); pathlib.Path('descendant.pid').write_text(str(os.getpid()))\nfor _ in range(600):\n pathlib.Path('copy.html').write_text('late descendant write'); time.sleep(.01)"
        lines = self.worker.read_text().splitlines()
        self.worker.write_text('\n'.join('grandchild=' + repr(continuous) if line.startswith('grandchild=') else line for line in lines) + '\n')
        server, port = self.start_http_server()
        info = self.wait_http_server(server)
        self.assertEqual(self.http_post(info, '/manual-edit-commit?async=1&pageUrl=/')[0], 202)
        self.wait_http_descendant()
        descendant = int((self.root/'descendant.pid').read_text())
        server.kill(); server.communicate(timeout=3)
        restarted, _ = self.start_http_server(port=port)
        deadline = time.monotonic() + 1
        restored_while_writing = []
        while time.monotonic() < deadline:
            content = self.source.read_text()
            try:
                value = Path(f'/proc/{descendant}/stat').read_text()
                live = value[value.rfind(')')+2:].split()[0] not in ('Z', 'X')
            except FileNotFoundError:
                live = False
            if content == 'original copy' and live:
                restored_while_writing.append(True)
            time.sleep(.002)
        self.assertEqual(restored_while_writing, [])
        if restarted.poll() is None:
            new_info = self.wait_http_server(restarted)
            self.assertEqual(self.source.read_text(), 'original copy')
            restarted.terminate(); restarted.communicate(timeout=5)
        else:
            stdout, stderr = restarted.communicate(timeout=3)
            self.assertEqual(restarted.returncode, 1, stdout + stderr)
            self.assertIn('Recovery blocked before restoring files', stderr)
        retry, _ = self.start_http_server(port=port, mode='retry')
        retry_info = self.wait_http_server(retry)
        self.assertEqual(self.source.read_text(), 'original copy')
        self.assertEqual(self.http_post(retry_info, '/manual-edit-commit?async=1&pageUrl=/')[0], 202)
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            entries = json.loads((self.root/'.impeccable/live/pending-manual-edits.json').read_text())['entries']
            if not entries: break
            time.sleep(.02)
        self.assertEqual(entries, [])
        self.assertEqual(self.source.read_text(), 'retry copy')
        time.sleep(1.4)
        self.assertEqual(self.source.read_text(), 'retry copy')

    def test_concurrent_dead_owner_recovery_cannot_replace_a_new_live_lease(self):
        owner_file = self.root/'.impeccable/live/manual-edit-operation-owner.json'
        owner_file.parent.mkdir(parents=True)
        owner_file.write_text(json.dumps({'version': 1, 'id': 'dead-owner-fixture', 'cwd': str(self.root),
                                         'pid': 99999999, 'birth': '1', 'workers': [], 'externalWriterActive': False}))
        code = f'''
import {{withManualEditOwnership}} from {json.dumps((SCRIPTS/'live/manual-edit-ownership.mjs').as_uri())};
try {{
  await withManualEditOwnership(process.cwd(),async()=>{{
    console.log('exclusive-owner');
    await new Promise(resolve=>setTimeout(resolve,600));
  }});
}} catch(error) {{ console.error(error.code);process.exitCode=3; }}
'''
        children = [subprocess.Popen(['node', '--input-type=module', '-e', code], cwd=self.root,
                                     env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                    for _ in range(2)]
        try:
            outputs = [child.communicate(timeout=5) for child in children]
            self.assertEqual(sorted(child.returncode for child in children), [0, 3], outputs)
            self.assertEqual(sum('exclusive-owner' in output[0] for output in outputs), 1)
            self.assertTrue(any('MANUAL_EDIT_OPERATION_OWNED' in output[1] for output in outputs))
            self.assertTrue(json.loads(owner_file.read_text())['released'])
        finally:
            for child in children:
                if child.poll() is None:
                    child.kill(); child.communicate(timeout=3)

    def test_legacy_unowned_transaction_is_preserved_without_automatic_restore(self):
        transaction = self.root/'.impeccable/live/manual-edit-apply-transaction.json'
        transaction.parent.mkdir(parents=True)
        transaction.write_text(json.dumps({'version': 1, 'id': 'legacy-fixture', 'pageUrl': '/',
                                          'entryIds': ['entry1'], 'files': [{'file': 'copy.html',
                                          'exists': True, 'content': 'original copy'}]}))
        before = transaction.read_bytes()
        code = f'''
import {{clearManualApplyTransaction}} from {json.dumps((SCRIPTS/'live/manual-apply.mjs').as_uri())};
try {{ clearManualApplyTransaction(process.cwd()); console.log('unexpected-clear'); }}
catch(error) {{ console.log(error.code); }}
'''
        clear = subprocess.run(['node', '--input-type=module', '-e', code], cwd=self.root,
                               env=self.env, capture_output=True, text=True, timeout=3)
        self.assertEqual(clear.returncode, 0, clear.stderr)
        self.assertEqual(clear.stdout.strip(), 'MANUAL_EDIT_OPERATION_OWNED')
        self.assertEqual(transaction.read_bytes(), before)
        self.source.write_text('legacy writer state preserved')
        server, _ = self.start_http_server()
        stdout, stderr = server.communicate(timeout=5)
        self.assertEqual(server.returncode, 1, stdout + stderr)
        self.assertIn('Legacy transaction has no worker ownership evidence', stderr)
        self.assertEqual(transaction.read_bytes(), before)
        self.assertEqual(self.source.read_text(), 'legacy writer state preserved')

    def test_missing_python_launcher_is_proven_no_launch_and_immediately_retryable(self):
        code = f'''
import fs from 'node:fs';
import {{commitManualEdits}} from {json.dumps((SCRIPTS/'live-commit-manual-edits.mjs').as_uri())};
const batch={json.dumps(self.batch)};
const first=await commitManualEdits({{cwd:process.cwd(),batch,provider:'codex',timeoutMs:300,env:{{...process.env,PATH:{str(self.bin)!r}}}}});
const ownerAfterFirst=JSON.parse(fs.readFileSync('.impeccable/live/manual-edit-operation-owner.json','utf8')).released;
const second=await commitManualEdits({{cwd:process.cwd(),batch,provider:'codex',timeoutMs:1000,env:{{...process.env,FIXTURE_MODE:'retry'}}}});
console.log(JSON.stringify({{first,second,ownerAfterFirst,source:fs.readFileSync('copy.html','utf8')}}));
'''
        result = subprocess.run(['node', '--input-type=module', '-e', code], cwd=self.root,
                                env=self.env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertTrue(data['first']['failed'])
        self.assertIn('ENOENT', data['first']['failed'][0]['reason'])
        self.assertTrue(data['ownerAfterFirst'])
        self.assertEqual(len(data['second']['applied']), 1)
        self.assertEqual(data['source'], 'retry copy')
        evidence = list((self.root/'.impeccable/live/manual-edit-worker-evidence').glob('*/*.json'))
        self.assertTrue(any(json.loads(file.read_text()).get('noLauncherStarted') for file in evidence))

    def test_unproven_v2_owner_and_malformed_transaction_preserve_source(self):
        directory = self.root/'.impeccable/live'
        directory.mkdir(parents=True)
        transaction = directory/'manual-edit-apply-transaction.json'
        (directory/'pending-manual-edits.json').write_text(json.dumps({'version':1,'entries':self.batch['entries']}))
        code = f'''
import {{rollbackManualApplyTransaction,clearManualApplyTransaction}} from {json.dumps((SCRIPTS/'live/manual-apply.mjs').as_uri())};
for(const fn of [()=>rollbackManualApplyTransaction({{cwd:process.cwd()}}),()=>clearManualApplyTransaction(process.cwd())]) {{
 try {{fn();console.log('unexpected-success');}}catch(error){{console.log(error.code);}}
}}
'''
        for value in [json.dumps({'version':2,'id':'old','ownershipId':'unproven-old-owner','entryIds':['entry1'],
                                 'files':[{'file':'copy.html','exists':True,'content':'stale snapshot'}]}), '{bad', 'null', '[]',
                      json.dumps({'version':2,'id':'corrupt','ownershipId':'unproven-old-owner','entryIds':['entry1'],'files':'corrupt snapshot shape'})]:
            transaction.write_text(value)
            result = subprocess.run(['node','--input-type=module','-e',code],cwd=self.root,env=self.env,
                                    capture_output=True,text=True,timeout=4)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(result.stdout.splitlines(),['MANUAL_EDIT_OPERATION_OWNED']*2)
            self.assertEqual(transaction.read_text(),value)
            self.assertEqual(self.source.read_text(),'original copy')

    def test_failed_restore_and_corrupt_buffer_keep_snapshot_and_recover_proven_owner(self):
        code = f'''
import fs from 'node:fs';
import {{withManualEditOwnership}} from {json.dumps((SCRIPTS/'live/manual-edit-ownership.mjs').as_uri())};
import {{writeManualApplyTransaction,rollbackManualApplyTransaction,clearManualApplyTransaction}} from {json.dumps((SCRIPTS/'live/manual-apply.mjs').as_uri())};
const tx='.impeccable/live/manual-edit-apply-transaction.json';
const pending='.impeccable/live/pending-manual-edits.json';
await withManualEditOwnership(process.cwd(),async()=>{{
 fs.mkdirSync('.impeccable/live',{{recursive:true}});
 fs.writeFileSync(pending,JSON.stringify({{version:1,entries:{json.dumps(self.batch['entries'])}}}));
 writeManualApplyTransaction({{cwd:process.cwd(),batch:{json.dumps(self.batch)}}});
 fs.writeFileSync('copy.html','partial writer result');
 for(const value of ['{{bad','null',JSON.stringify({{version:1,entries:[null]}}),JSON.stringify({{version:1,entries:[{{id:true}}]}})]){{
  fs.writeFileSync(pending,value);
  try{{rollbackManualApplyTransaction({{cwd:process.cwd()}});throw new Error('unexpected-corrupt-success');}}
  catch(error){{if(error.code!=='MANUAL_EDIT_OPERATION_OWNED')throw error;}}
 }}
 if(!fs.existsSync(tx)||fs.readFileSync('copy.html','utf8')!=='partial writer result')throw new Error('corrupt buffer lost state');
 fs.writeFileSync(pending,JSON.stringify({{version:1,entries:{json.dumps(self.batch['entries'])}}}));
 fs.unlinkSync('copy.html');fs.mkdirSync('copy.html');
 try{{rollbackManualApplyTransaction({{cwd:process.cwd()}});throw new Error('unexpected-restore-success');}}
 catch(error){{if(error.code!=='MANUAL_EDIT_OPERATION_OWNED')throw error;}}
 try{{clearManualApplyTransaction(process.cwd());throw new Error('unexpected-clear-success');}}
 catch(error){{if(error.code!=='MANUAL_EDIT_OPERATION_OWNED')throw error;}}
 if(!JSON.parse(fs.readFileSync(tx)).recoveryFailed)throw new Error('snapshot missing');
}});
fs.rmdirSync('copy.html');
const result=rollbackManualApplyTransaction({{cwd:process.cwd()}});
console.log(JSON.stringify({{result,source:fs.readFileSync('copy.html','utf8'),retained:fs.existsSync(tx)}}));
'''
        result = subprocess.run(['node','--input-type=module','-e',code],cwd=self.root,env=self.env,
                                capture_output=True,text=True,timeout=5)
        self.assertEqual(result.returncode,0,result.stderr)
        data=json.loads(result.stdout)
        self.assertEqual(data['source'],'original copy')
        self.assertFalse(data['retained'])

    def test_malformed_live_owner_identity_cannot_be_treated_as_dead(self):
        directory=self.root/'.impeccable/live'
        directory.mkdir(parents=True)
        code=f'''
import fs from 'node:fs';
import {{withManualEditOwnership}} from {json.dumps((SCRIPTS/'live/manual-edit-ownership.mjs').as_uri())};
const file='.impeccable/live/manual-edit-operation-owner.json';
const stat=fs.readFileSync('/proc/self/stat','utf8');
const birth=stat.slice(stat.lastIndexOf(')')+2).split(' ')[19];
for(const field of ['birth','birthString','pid','id','version','workers','released','externalWriterActive']){{
 const owner={{version:1,id:'live-fixture',cwd:process.cwd(),pid:process.pid,birth,workers:[],externalWriterActive:false}};
 if(field==='birthString')owner.birth='junk';
 else owner[field]=field==='workers'?null:(field==='released'||field==='externalWriterActive'?'invalid':true);
 const original=JSON.stringify(owner);fs.writeFileSync(file,original);
 try{{await withManualEditOwnership(process.cwd(),async()=>{{throw new Error('unexpected-acquire');}});}}
 catch(error){{if(error.code!=='MANUAL_EDIT_OPERATION_OWNED')throw error;}}
 if(fs.readFileSync(file,'utf8')!==original)throw new Error('malformed owner replaced');
}}
console.log('preserved');
'''
        result=subprocess.run(['node','--input-type=module','-e',code],cwd=self.root,env=self.env,
                              capture_output=True,text=True,timeout=4)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.strip(),'preserved')

    def test_empty_recovery_is_noop_on_unsupported_platform(self):
        code=f'''
import {{rollbackManualApplyTransaction}} from {json.dumps((SCRIPTS/'live/manual-apply.mjs').as_uri())};
Object.defineProperty(process,'platform',{{value:'darwin'}});
console.log(rollbackManualApplyTransaction({{cwd:process.cwd()}}));
'''
        result=subprocess.run(['node','--input-type=module','-e',code],cwd=self.root,env=self.env,
                              capture_output=True,text=True,timeout=3)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.strip(),'null')

    def test_synchronous_invalid_validation_argv_has_no_launch_and_retry_succeeds(self):
        (self.root/'package.json').write_text(json.dumps({'scripts':{'impeccable:manual-edit-validate':'echo bad\0'}}))
        code=f'''
import fs from 'node:fs';
import {{runCopyEditPostApplyChecks}} from {json.dumps((SCRIPTS/'live-copy-edit-agent.mjs').as_uri())};
const first=await runCopyEditPostApplyChecks({{cwd:process.cwd(),files:['copy.html']}});
fs.writeFileSync('package.json',JSON.stringify({{scripts:{{'impeccable:manual-edit-validate':'true'}}}}));
const symbolEnv=await runCopyEditPostApplyChecks({{cwd:process.cwd(),files:['copy.html'],env:{{...process.env,INVALID:Symbol('fixture')}}}});
const second=await runCopyEditPostApplyChecks({{cwd:process.cwd(),files:['copy.html']}});
console.log(JSON.stringify({{first,second,symbolEnv}}));
'''
        result=subprocess.run(['node','--input-type=module','-e',code],cwd=self.root,env=self.env,
                              capture_output=True,text=True,timeout=6)
        self.assertEqual(result.returncode,0,result.stderr)
        data=json.loads(result.stdout)
        self.assertFalse(data['first']['ok'])
        self.assertTrue(data['second']['ok'])
        self.assertTrue(data['symbolEnv']['ok'])

    def test_boolean_supervisor_identity_is_not_recovery_proof(self):
        directory=self.root/'.impeccable/live'
        directory.mkdir(parents=True)
        status=directory/'fixture-status.json'
        owner=directory/'manual-edit-operation-owner.json'
        code=f'''
import {{withManualEditOwnership}} from {json.dumps((SCRIPTS/'live/manual-edit-ownership.mjs').as_uri())};
try{{await withManualEditOwnership(process.cwd(),async()=>{{}});console.log('unexpected-acquire');}}
catch(error){{console.log(error.code);}}
'''
        for supervisor_pid,worker_pid,no_launcher in [(True,None,False),(False,None,True),(1,True,False)]:
            status.write_text(json.dumps({'nonce':'fixture','supervisor_pid':supervisor_pid,'quiescent':True,'noLauncherStarted':no_launcher}))
            owner.write_text(json.dumps({'version':1,'id':'stale','cwd':str(self.root),'pid':99999999,'birth':'1',
                                        'workers':[{'pid':worker_pid,'nonce':'fixture','statusPath':str(status)}]}))
            original=owner.read_bytes()
            result=subprocess.run(['node','--input-type=module','-e',code],cwd=self.root,env=self.env,
                                  capture_output=True,text=True,timeout=3)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(result.stdout.strip(),'MANUAL_EDIT_OPERATION_OWNED')
            self.assertEqual(owner.read_bytes(),original)

    def test_caller_dies_before_supervisor_imports_no_worker_is_launched(self):
        launcher=self.bin/'python3'
        launcher.write_text(f'''#!{sys.executable}
import json,os,pathlib,sys,time
if pathlib.Path(sys.argv[1]).name=='process-supervisor.py':
 stat=pathlib.Path('/proc/self/stat').read_text()
 pathlib.Path('supervisor-argv.json').write_text(json.dumps({{'argv':sys.argv[1:],'pid':os.getpid(),'birth':stat[stat.rfind(')')+2:].split()[19]}}))
 time.sleep(.7)
os.execv({sys.executable!r},[{sys.executable!r},*sys.argv[1:]])
''')
        launcher.chmod(0o755)
        code=f'''
import {{commitManualEdits}} from {json.dumps((SCRIPTS/'live-commit-manual-edits.mjs').as_uri())};
await commitManualEdits({{cwd:process.cwd(),batch:{json.dumps(self.batch)},provider:'codex',timeoutMs:5000}});
'''
        caller=subprocess.Popen(['node','--input-type=module','-e',code],cwd=self.root,env=self.env,
                                stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        descriptor=None
        try:
            record=self.root/'supervisor-argv.json'
            deadline=time.monotonic()+4
            while not record.exists() and time.monotonic()<deadline:
                self.assertIsNone(caller.poll())
                time.sleep(.01)
            self.assertTrue(record.exists())
            metadata=json.loads(record.read_text())
            argv=metadata['argv']
            self.assertEqual(argv[argv.index('--parent-pid')+1],str(caller.pid))
            stat=Path(f'/proc/{caller.pid}/stat').read_text()
            self.assertEqual(argv[argv.index('--parent-birth')+1],stat[stat.rfind(')')+2:].split()[19])
            owner=json.loads((self.root/'.impeccable/live/manual-edit-operation-owner.json').read_text())
            self.assertEqual(owner['workers'][0]['pid'],metadata['pid'])
            pending_descriptor=os.pidfd_open(metadata['pid'],0)
            try:
                supervisor_stat=Path(f"/proc/{metadata['pid']}/stat").read_text()
                self.assertEqual(supervisor_stat[supervisor_stat.rfind(')')+2:].split()[19],metadata['birth'])
                descriptor=pending_descriptor
            finally:
                if descriptor is None:os.close(pending_descriptor)
            caller.kill();caller.communicate(timeout=3)
            certificate=Path(owner['workers'][0]['statusPath'])
            deadline=time.monotonic()+4
            status={}
            while time.monotonic()<deadline:
                try:status=json.loads(certificate.read_text())
                except (FileNotFoundError,json.JSONDecodeError):pass
                if status.get('quiescent'):break
                time.sleep(.01)
            self.assertTrue(status.get('quiescent'),status)
            self.assertIn('no worker was launched',status.get('error',''))
            self.assertFalse((self.root/'worker.pid').exists())
            self.assertFalse((self.root/'descendant.pid').exists())
            self.assertEqual(self.source.read_text(),'original copy')
        finally:
            if caller.poll() is None:caller.kill();caller.communicate(timeout=3)
            if descriptor is not None:
                try:signal.pidfd_send_signal(descriptor,signal.SIGTERM)
                except ProcessLookupError:pass
                os.close(descriptor)

    def test_pid_registration_error_stops_owned_worker_before_rollback(self):
        code = f'''
import fs from 'node:fs';
import {{commitManualEdits}} from {json.dumps((SCRIPTS/'live-commit-manual-edits.mjs').as_uri())};
const realRename=fs.renameSync;
let failed=false;
fs.renameSync=(from,to)=>{{
  if(String(to).endsWith('manual-edit-operation-owner.json')&&!failed) {{
    const value=JSON.parse(fs.readFileSync(from,'utf8'));
    if(value.workers.some(worker=>worker.pid!==null)) {{failed=true;throw new Error('fixture PID registration failed');}}
  }}
  return realRename(from,to);
}};
const result=await commitManualEdits({{cwd:process.cwd(),batch:{json.dumps(self.batch)},provider:'codex',timeoutMs:5000}});
const atRollback=fs.readFileSync('copy.html','utf8');
await new Promise(resolve=>setTimeout(resolve,1600));
console.log(JSON.stringify({{result,failed,atRollback,after:fs.readFileSync('copy.html','utf8')}}));
'''
        result = subprocess.run(['node', '--input-type=module', '-e', code], cwd=self.root,
                                env=self.env, capture_output=True, text=True, timeout=6)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertTrue(data['failed'])
        self.assertTrue(data['result']['failed'])
        self.assertEqual(data['atRollback'], 'original copy')
        self.assertEqual(data['after'], 'original copy')


if __name__ == '__main__':
    unittest.main()
