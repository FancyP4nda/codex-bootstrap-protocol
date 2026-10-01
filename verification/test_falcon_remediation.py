#!/usr/bin/env python3
"""F02/F08/F09: independent disposable evidence, sandbox and steering handoff."""
import argparse
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import types
import unittest
from unittest.mock import patch

KIT = Path(__file__).resolve().parents[1]
FALCON = KIT / 'assets/packs/falcon/scaffold/.agents/skills/falcon/scripts/falcon.py'
BASELINE = '190f8daa13abeff033916b4b8556d464723d5d4e'
VALID = {'summary': 'reviewed scoped implementation', 'changed_files': ['src/file.txt'],
         'tests': ['disposable verification'], 'risks': []}


def module(path=FALCON, baseline=False):
    name = 'falcon_' + ('baseline' if baseline else 'remediation')
    if baseline:
        source = subprocess.check_output(['git', '-C', str(KIT), 'show',
                                          f'{BASELINE}:{FALCON.relative_to(KIT)}'], text=True)
        result = types.ModuleType(name)
        result.__file__ = str(FALCON)
        exec(compile(source, str(FALCON), 'exec'), result.__dict__)
        return result
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class FalconRemediationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='falcon-remediation-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.home = self.root / 'home'
        self.home.mkdir()
        self.codex_home = self.home / '.codex'
        self.codex_home.mkdir()
        self.env = {**os.environ, 'HOME': str(self.home), 'CODEX_HOME': str(self.codex_home)}
        self.git('init', '-q')
        self.git('config', 'user.name', 'Disposable Verification')
        self.git('config', 'user.email', 'verification@example.invalid')
        (self.repo / '.gitignore').write_text('.codex/state/tmp/\n')
        (self.repo / 'src').mkdir()
        (self.repo / 'src/file.txt').write_text('original\n')
        (self.repo / 'unrelated.txt').write_text('original unrelated\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'disposable initial')
        self.prompt = self.root / 'prompt.txt'
        self.prompt.write_text('Implement the assigned scoped source change and test.')
        self.m = module()
        self.app = self.m.Falcon(self.repo)

    def git(self, *args, root=None):
        return subprocess.check_output(['git', '-C', str(root or self.repo), *args],
                                       env=self.env, text=True).strip()

    def dispatch(self, app=None):
        app = app or self.app
        args = argparse.Namespace(scope=['src'], prompt_file=str(self.prompt), bead=[], paste=True)
        with patch('sys.stdout', io.StringIO()):
            app.dispatch(args)
        return app.records()[-1]

    def test_shutdown_certificate_requires_exact_positive_integer_identity(self):
        record = self.dispatch()
        self.app.new_attempt(record)
        attempt = self.app.attempt(record)
        attempt['supervisor_launch_intent'] = True
        self.m.save(self.app.path(record['id']), record)
        certificate = Path(attempt['supervisor_status'])
        for malformed in (True, False, 0, -1, 1.5, '123'):
            with self.subTest(supervisor_pid=malformed):
                certificate.write_text(json.dumps({'nonce': attempt['supervisor_nonce'],
                                                  'supervisor_pid': malformed, 'quiescent': True}))
                self.assertFalse(self.app.quiescent(record), 'Malformed certificate cannot release scope')

    @unittest.skipUnless(sys.platform == 'linux', 'Real /proc zombie lifecycle requires Linux')
    def test_zombie_process_is_not_active_and_legacy_live_identity_stays_owned(self):
        legacy = subprocess.check_output(['ps', '-o', 'lstart=', '-p', str(os.getpid())], text=True).strip()
        self.assertTrue(self.m.alive({'pid': os.getpid(), 'birth': legacy}))
        with self.assertRaisesRegex(ValueError, 'legacy process identity'):
            self.m.signal_owner({'pid': os.getpid(), 'birth': legacy}, signal.SIGTERM)
        pid = os.fork()
        if pid == 0:
            os._exit(0)
        try:
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                fields = Path('/proc', str(pid), 'stat').read_text().rsplit(')', 1)[1].split()
                if fields[0] == 'Z':
                    break
                time.sleep(.005)
            self.assertEqual(fields[0], 'Z', 'Fixture must be a real unreaped zombie')
            self.assertEqual(self.m.birth(pid), '')
            self.assertFalse(self.m.alive({'pid': pid, 'birth': fields[19]}))
        finally:
            os.waitpid(pid, 0)

    def worker(self, record, output=VALID, code=0, resume=False):
        record = self.app.load(record['id'])
        self.app.new_attempt(record)
        self.m.save(self.app.path(record['id']), record)
        report = Path(self.app.attempt(record)['report'])
        commands = []

        class Child:
            def __init__(self):
                self.pid = 99999999
                self.stdin = io.StringIO()
                self.stdout = iter([json.dumps({'type': 'thread.started', 'thread_id': 'fixture-thread'})])

            def wait(self):
                if output is not None:
                    report.write_text(output if isinstance(output, str) else json.dumps(output))
                Path(record['attempts'][-1]['supervisor_status']).write_text(json.dumps({
                    'nonce': record['attempts'][-1]['supervisor_nonce'],
                    'supervisor_pid': self.pid, 'quiescent': True,
                }))
                return code

        def launch(command, **kwargs):
            commands.append(command)
            return Child()

        with patch.object(self.m, 'birth', return_value=''), patch.object(self.m.subprocess, 'Popen', side_effect=launch):
            result = self.app.worker(record['id'], resume)
        return self.app.load(record['id']), result, commands

    def completed_change(self):
        record = self.dispatch()
        worktree = Path(record['worktree'])
        (worktree / 'src/file.txt').write_text('scoped implementation\n')
        record, code, _ = self.worker(record)
        self.assertEqual(code, 0)
        return record, worktree

    def test_baseline_reproduces_stale_report_and_leaf_symlink_failures(self):
        baseline = module(baseline=True)
        app = baseline.Falcon(self.repo)
        record = self.dispatch(app)
        record['session'] = 'fixture-thread'
        baseline.save(app.path(record['id']), record)
        old_report = app.state / f'{record["id"]}.report.json'
        old_report.write_text(json.dumps(VALID))

        class Child:
            stdin = io.StringIO()
            stdout = iter([])

            def wait(self):
                return 0

        with patch.object(baseline, 'birth', return_value=''), patch.object(baseline.subprocess, 'Popen', return_value=Child()):
            self.assertEqual(app.worker(record['id'], True), 0)
        self.assertEqual(app.load(record['id'])['status'], 'complete')
        self.assertEqual(app.load(record['id'])['report'], str(old_report))
        sentinel = self.root / 'outside.txt'
        sentinel.write_text('unrelated sentinel')
        app.path(record['id']).with_suffix('.tmp').symlink_to(sentinel)
        baseline.save(app.path(record['id']), app.load(record['id']))
        self.assertIn(record['id'], sentinel.read_text())
        self.assertIn('commit only your scoped files', app.prompt(record))

    def test_attempt_reports_require_fresh_full_schema_on_dispatch_and_resume(self):
        record = self.dispatch()
        record, code, _ = self.worker(record)
        self.assertEqual(code, 0)
        old_path = Path(record['report'])
        old_bytes = old_path.read_bytes()
        failures = [None, '{malformed', {'summary': 'partial'},
                    {**VALID, 'tests': 'not an array'}, {**VALID, 'risks': [4]},
                    {**VALID, 'unexpected': True}, ['summary', 'changed_files', 'tests', 'risks']]
        for output in failures:
            with self.subTest(output=output):
                record, code, commands = self.worker(record, output, resume=True)
                self.assertEqual(code, 1)
                self.assertEqual(record['status'], 'failed')
                self.assertIsNone(record['report'])
                self.assertIsNone(record['report_hash'])
                self.assertIn('--output-schema', commands[0])
                self.assertNotEqual(self.app.attempt(record)['report'], str(old_path))
                self.assertEqual(old_path.read_bytes(), old_bytes)
        record, code, _ = self.worker(record, VALID, code=7, resume=True)
        self.assertEqual(code, 7)
        self.assertEqual(record['status'], 'failed')
        self.assertIsNone(record['report'])
        record, code, _ = self.worker(record, {**VALID, 'summary': 'fresh amended evidence'}, resume=True)
        self.assertEqual(code, 0)
        self.assertEqual(record['status'], 'complete')
        self.assertNotEqual(record['report'], str(old_path))
        self.assertEqual(len({a['id'] for a in record['attempts']}), len(record['attempts']))

    def test_worker_never_commits_and_steering_handoff_preserves_unrelated_work(self):
        record, worktree = self.completed_change()
        self.assertIn('leave scoped source changes uncommitted', self.app.prompt(record))
        self.assertIn('Never update Beads, stage, commit', self.app.prompt(record))
        (self.repo / 'unrelated.txt').write_text('user unstaged work\n')
        (self.repo / 'staged.txt').write_text('user staged work\n')
        self.git('add', 'staged.txt')
        before = self.git('status', '--porcelain=v1')
        audit = self.app.audit(record)
        args = argparse.Namespace(message='steering-reviewed source change',
                                  report_hash=audit['report_hash'], diff_hash=audit['diff_hash'])
        result = self.app.steering_commit(record, args)
        self.assertEqual(result['status'], 'committed')
        self.assertEqual(self.git('show', '--format=', '--name-only', result['commit']), 'src/file.txt')
        self.assertEqual(self.git('status', '--porcelain=v1'), before)
        self.assertEqual(self.git('status', '--porcelain=v1', root=worktree), '')
        # Integration is separately steering-owned; unrelated staged/unstaged
        # work remains untouched by the explicit scoped cherry-pick.
        integration = self.root / 'integration'
        self.git('worktree', 'add', '-q', '-b', 'integration-test', str(integration), 'HEAD')
        subprocess.run(['git', '-C', str(integration), 'cherry-pick', result['commit']],
                       env=self.env, check=True, stdout=subprocess.DEVNULL)
        self.assertEqual((integration / 'src/file.txt').read_text(), 'scoped implementation\n')
        self.assertEqual((self.repo / 'src/file.txt').read_text(), 'original\n')
        self.assertEqual((self.repo / 'unrelated.txt').read_text(), 'user unstaged work\n')
        self.assertEqual((self.repo / 'staged.txt').read_text(), 'user staged work\n')
        self.assertEqual(self.git('diff', '--cached', '--name-only'), 'staged.txt')

    def test_handoff_rejects_out_of_scope_changes_and_stale_hashes(self):
        record, worktree = self.completed_change()
        audit = self.app.audit(record)
        (worktree / 'unrelated.txt').write_text('unexpected worker change\n')
        with self.assertRaisesRegex(ValueError, 'out-of-scope'):
            self.app.audit(record)
        (worktree / 'unrelated.txt').write_text('original unrelated\n')
        (worktree / 'src/file.txt').write_text('changed after review\n')
        args = argparse.Namespace(message='must fail', report_hash=audit['report_hash'], diff_hash=audit['diff_hash'])
        with self.assertRaisesRegex(ValueError, 'evidence changed'):
            self.app.steering_commit(record, args)
        Path(record['report']).write_text(json.dumps({**VALID, 'summary': 'tampered'}))
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            self.app.audit(record)

    def test_steering_commit_has_explicit_recovery_after_branch_publication(self):
        record, worktree = self.completed_change()
        audit = self.app.audit(record)
        args = argparse.Namespace(message='interrupted steering commit', report_hash=audit['report_hash'], diff_hash=audit['diff_hash'])
        actual_save = self.m.save

        def crash_after_publication(path, data):
            if data.get('status') == 'committed':
                raise OSError('simulated interruption after checked branch update')
            return actual_save(path, data)

        with patch.object(self.m, 'save', side_effect=crash_after_publication):
            with self.assertRaisesRegex(OSError, 'simulated interruption'):
                self.app.steering_commit(record, args)
        pending = self.app.load(record['id'])
        self.assertIn('pending_commit', pending)
        with self.assertRaisesRegex(ValueError, 'recover'):
            self.app.start_worker(pending, True)
        result = self.app.recover_commit(pending)
        self.assertEqual(result['status'], 'committed')
        self.assertNotIn('pending_commit', self.app.load(record['id']))
        self.assertEqual((worktree / 'src/file.txt').read_text(), 'scoped implementation\n')
        self.assertEqual(self.git('status', '--porcelain=v1', root=worktree), '')

    def test_leaf_and_ancestor_symlinks_fail_closed_without_sentinel_writes(self):
        record = self.dispatch()
        sentinel = self.root / 'outside.txt'
        sentinel.write_text('untouched outside sentinel')
        for name in ['registry.lock', 'monitor.json', f'{record["id"]}.tmp', f'{record["id"]}.json']:
            with self.subTest(name=name):
                target = self.app.state / name
                original = target.read_bytes() if target.exists() else None
                if target.exists():
                    target.unlink()
                target.symlink_to(sentinel)
                try:
                    if name == 'registry.lock':
                        with self.assertRaisesRegex(ValueError, 'symlink'):
                            with self.app.locked():
                                pass
                    elif name == 'monitor.json':
                        with self.assertRaisesRegex(ValueError, 'symlink'):
                            self.app.monitor(argparse.Namespace(action='status'))
                    elif name.endswith('.tmp'):
                        with self.assertRaisesRegex(ValueError, 'symlink'):
                            self.m.save(self.app.path(record['id']), record)
                    else:
                        with self.assertRaisesRegex(ValueError, 'symlink'):
                            self.app.load(record['id'])
                    self.assertEqual(sentinel.read_text(), 'untouched outside sentinel')
                finally:
                    target.unlink()
                    if original is not None:
                        target.write_bytes(original)
        attempt = self.app.new_attempt(record)
        self.m.save(self.app.path(record['id']), record)
        for key in ('report', 'log', 'supervisor_status'):
            target = Path(attempt[key])
            target.unlink()
            target.symlink_to(sentinel)
            with self.assertRaisesRegex(ValueError, 'symlink'):
                self.app.attempt(record)
            target.unlink()
            target.write_text('')
        outside = self.root / 'outside-directory'
        outside.mkdir()
        folder = self.app.state / 'attempts' / record['id']
        moved = folder.with_name(folder.name + '-preserved')
        folder.rename(moved)
        folder.symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.app.new_attempt(record)
        self.assertEqual(list(outside.iterdir()), [])

    def test_worktree_parent_symlink_rejected_before_git_creation(self):
        outside = self.root / 'outside-worktrees'
        outside.mkdir()
        (self.app.state / 'worktrees').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.dispatch()
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual(self.git('branch', '--list', 'falcon/*'), '')

    def launch_real_worker_fixture(self, *, detached=False, normal_exit=False):
        fixture_bin = self.root / 'bin'
        fixture_bin.mkdir(exist_ok=True)
        worker = fixture_bin / 'codex'
        descendant = "import os,pathlib,signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); pathlib.Path('descendant.pid').write_text(str(os.getpid())); time.sleep(1.2); pathlib.Path('src/file.txt').write_text('late cancelled worker write\\n'); time.sleep(5)"
        worker.write_text(f'''#!/usr/bin/env python3
import json,os,pathlib,signal,subprocess,sys,time
print(json.dumps({{'type':'thread.started','thread_id':'fixture-thread'}}),flush=True)
pathlib.Path('src/file.txt').write_text('worker partial change\\n')
subprocess.Popen([sys.executable,'-c',{descendant!r}],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session={detached!r})
while not pathlib.Path('descendant.pid').exists(): time.sleep(.01)
if {normal_exit!r}:
    pathlib.Path(sys.argv[sys.argv.index('--output-last-message')+1]).write_text({json.dumps(VALID)!r})
    sys.exit(0)
signal.signal(signal.SIGTERM,signal.SIG_IGN)
while True: time.sleep(1)
''')
        worker.chmod(0o755)
        env = {**self.env, 'PATH': str(fixture_bin) + os.pathsep + os.environ['PATH']}
        launched = subprocess.run([sys.executable, str(FALCON), '--root', str(self.repo),
                                   'dispatch', '--scope', 'src', '--prompt-file', str(self.prompt)],
                                  env=env, capture_output=True, text=True, timeout=5)
        self.assertEqual(launched.returncode, 0, launched.stderr)
        record = json.loads(launched.stdout)
        worktree = Path(record['worktree'])
        def cleanup():
            latest = self.app.load(record['id'])
            if self.m.alive(latest):
                try:
                    os.killpg(latest['pid'], signal.SIGTERM)
                except ProcessLookupError:
                    pass
            marker = worktree / 'descendant.pid'
            if marker.exists():
                try:
                    os.kill(int(marker.read_text()), signal.SIGKILL)
                except ProcessLookupError:
                    pass
        self.addCleanup(cleanup)
        deadline = time.monotonic() + 5
        while not (worktree / 'descendant.pid').exists() and time.monotonic() < deadline:
            time.sleep(.02)
        self.assertTrue((worktree / 'descendant.pid').exists())
        return record, worktree

    def test_cancel_waits_for_resistant_owned_descendants_before_release(self):
        for detached in (False, True):
            with self.subTest(detached=detached):
                record, worktree = self.launch_real_worker_fixture(detached=detached)
                self.app.action(argparse.Namespace(command='cancel', id=record['id']))
                stopped = self.app.load(record['id'])
                self.assertEqual(stopped['status'], 'cancelled')
                self.assertTrue(self.app.quiescent(stopped))
                self.app.action(argparse.Namespace(command='release', id=record['id']))
                self.assertEqual(self.app.load(record['id'])['status'], 'released')
                at_release = (worktree / 'src/file.txt').read_text()
                time.sleep(1.4)
                self.assertEqual((worktree / 'src/file.txt').read_text(), at_release)
                self.assertNotEqual(at_release, 'late cancelled worker write\n')

    def test_normal_completion_stops_detached_descendant_before_handoff(self):
        record, worktree = self.launch_real_worker_fixture(detached=True, normal_exit=True)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            latest = self.app.load(record['id'])
            if latest['status'] == 'complete' and self.app.quiescent(latest):
                break
            time.sleep(.02)
        self.assertEqual(latest['status'], 'complete')
        # This fixture-only PID marker is not worker source evidence. The
        # leader has exited and its descendant is quiescent before removal.
        (worktree / 'descendant.pid').unlink()
        audit = self.app.audit(latest)
        self.assertEqual(audit['files'], ['src/file.txt'])
        time.sleep(1.4)
        self.assertEqual((worktree / 'src/file.txt').read_text(), 'worker partial change\n')

    def test_dead_runner_without_quiescence_cannot_release_resume_or_audit(self):
        record, worktree = self.completed_change()
        attempt = self.app.attempt(record)
        Path(attempt['supervisor_status']).write_text('')
        for action in ('release', 'resume', 'handoff'):
            with self.subTest(action=action):
                with self.assertRaisesRegex(ValueError, 'descendants.*not confirmed'):
                    self.app.action(argparse.Namespace(command=action, id=record['id']))
        self.assertEqual(self.app.load(record['id'])['status'], 'complete')

    def test_runner_death_supervisor_stops_detached_descendant_before_release(self):
        record, worktree = self.launch_real_worker_fixture(detached=True)
        current = self.app.load(record['id'])
        os.kill(current['pid'], signal.SIGKILL)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            current = self.app.load(record['id'])
            if self.app.quiescent(current):
                break
            time.sleep(.02)
        self.assertTrue(self.app.quiescent(current))
        self.app.action(argparse.Namespace(command='release', id=record['id']))
        at_release = (worktree / 'src/file.txt').read_text()
        time.sleep(1.4)
        self.assertEqual((worktree / 'src/file.txt').read_text(), at_release)
        self.assertNotEqual(at_release, 'late cancelled worker write\n')

    def test_unsupported_runtime_platform_fails_before_worker_launch(self):
        supervisor = module(FALCON.with_name('process-supervisor.py'))
        status = self.root / 'unsupported-supervisor.json'
        args = argparse.Namespace(status_file=str(status), nonce='unsupported-fixture', command=['must-not-run'])
        with patch.object(supervisor.sys, 'platform', 'darwin'), patch.object(supervisor.subprocess, 'Popen') as launch:
            self.assertEqual(supervisor.supervise(args), 78)
        launch.assert_not_called()
        result = json.loads(status.read_text())
        self.assertTrue(result['quiescent'])
        self.assertIn('no worker was launched', result['error'])

    def test_real_no_model_codex_sandbox_allows_source_but_protects_worktree_git(self):
        codex = shutil.which('codex')
        self.assertIsNotNone(codex, 'real Codex CLI required for F02 acceptance')
        record = self.dispatch()
        worktree = Path(record['worktree'])
        write = 'from pathlib import Path; Path("src/file.txt").write_text("real sandbox edit\\n")'
        result = subprocess.run([codex, 'sandbox', '-C', str(worktree),
                                 '-P', 'falcon-verification', '-c', 'permissions.falcon-verification.extends=":workspace"',
                                 '-c', 'approval_policy="never"',
                                 '--', sys.executable, '-c', write], env=self.env,
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        forbidden = subprocess.run([codex, 'sandbox', '-C', str(worktree),
                                    '-P', 'falcon-verification', '-c', 'permissions.falcon-verification.extends=":workspace"',
                                    '-c', 'approval_policy="never"',
                                    '--', 'git', 'add', '--', 'src/file.txt'], env=self.env,
                                   capture_output=True, text=True, timeout=20)
        self.assertNotEqual(forbidden.returncode, 0)
        self.assertIn('index.lock', forbidden.stderr)
        commit_forbidden = subprocess.run([codex, 'sandbox', '-C', str(worktree),
                                           '-P', 'falcon-verification',
                                           '-c', 'permissions.falcon-verification.extends=":workspace"',
                                           '-c', 'approval_policy="never"', '--', 'git', 'commit', '-am',
                                           'forbidden sandbox worker commit'], env=self.env,
                                          capture_output=True, text=True, timeout=20)
        self.assertNotEqual(commit_forbidden.returncode, 0)
        self.assertIn('index.lock', commit_forbidden.stderr)
        self.assertEqual(self.git('rev-parse', 'HEAD', root=worktree), record['base'])
        self.assertEqual(self.git('diff', '--cached', '--name-only', root=worktree), '')
        record, code, _ = self.worker(record)
        self.assertEqual(code, 0)
        audit = self.app.audit(record)
        result = self.app.steering_commit(record, argparse.Namespace(message='real sandbox steering handoff',
                                         report_hash=audit['report_hash'], diff_hash=audit['diff_hash']))
        self.assertEqual(self.git('show', f'{result["commit"]}:src/file.txt'), 'real sandbox edit')


if __name__ == '__main__':
    unittest.main()
