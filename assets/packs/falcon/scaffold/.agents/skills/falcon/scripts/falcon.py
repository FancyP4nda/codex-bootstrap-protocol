#!/usr/bin/env python3
"""Local Codex worktree workers and a stoppable monitor; no OS service."""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import tempfile
import time
import uuid


def git(root, *args):
    output = subprocess.check_output(['git', '-C', str(root), *args], text=True)
    return output if '-z' in args else output.strip()


def save(path, data):
    safe_path(path)
    # Refuse a hostile legacy predictable temporary file as well as the target.
    safe_path(path.with_suffix('.tmp'))
    fd, temporary = tempfile.mkstemp(prefix=path.name + '.', suffix='.tmp', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(json.dumps(data, indent=2) + '\n')
            stream.flush()
            os.fsync(stream.fileno())
        safe_path(path)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def safe_path(path, directory=False):
    """Reject existing symlink ancestors/leaves and nonregular managed entries.

    This is fail-closed local-state validation, not protection against an actively
    racing process with the same UID. Python-managed leaf opens also use NOFOLLOW.
    """
    path = Path(path).absolute()
    for parent in reversed(path.parents):
        if parent.is_symlink():
            raise ValueError(f'symlink state ancestor: {parent}')
        if parent.exists() and not parent.is_dir():
            raise ValueError(f'non-directory state ancestor: {parent}')
    try:
        info = path.lstat()
    except FileNotFoundError:
        return path
    if stat.S_ISLNK(info.st_mode):
        raise ValueError(f'symlink state path: {path}')
    if directory:
        if not stat.S_ISDIR(info.st_mode):
            raise ValueError(f'non-directory state path: {path}')
    elif not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError(f'nonregular or multiply-linked state file: {path}')
    return path


def safe_open(path, mode='r', exclusive=False):
    safe_path(path)
    flags = os.O_RDONLY if mode in ('r', 'rb') else os.O_WRONLY | os.O_CREAT
    if mode == 'a' or mode == 'a+':
        flags = os.O_RDWR | os.O_CREAT | os.O_APPEND
    if exclusive:
        flags |= os.O_EXCL
    flags |= os.O_NOFOLLOW | os.O_CLOEXEC
    fd = os.open(path, flags, 0o600)
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        os.close(fd)
        raise ValueError(f'unsafe open state file: {path}')
    return os.fdopen(fd, mode)


def read_json(path):
    with safe_open(path) as stream:
        return json.load(stream)


def validate_report(value):
    keys = {'summary', 'changed_files', 'tests', 'risks'}
    if not isinstance(value, dict) or set(value) != keys or not isinstance(value['summary'], str):
        raise ValueError('worker report does not match report.schema.json')
    for key in keys - {'summary'}:
        if not isinstance(value[key], list) or not all(isinstance(item, str) for item in value[key]):
            raise ValueError(f'worker report {key} must be an array of strings')
    return value


def digest(path):
    with safe_open(path, 'rb') as stream:
        return hashlib.sha256(stream.read()).hexdigest()


def birth(pid):
    if sys.platform == 'linux':
        try:
            fields = Path('/proc', str(pid), 'stat').read_text().rsplit(')', 1)[1].split()
            return '' if fields[0] in ('Z', 'X') else fields[19]
        except (FileNotFoundError, ProcessLookupError):
            return ''
    try:
        return subprocess.check_output(['ps', '-o', 'lstart=', '-p', str(pid)], text=True).strip()
    except subprocess.CalledProcessError:
        return ''


def alive(data):
    pid = data.get('pid')
    previous = data.get('birth')
    if type(pid) is not int or pid <= 0 or not isinstance(previous, str) or not previous:
        return False
    current = birth(pid)
    if not current:
        return False
    if sys.platform == 'linux' and not previous.isdigit():
        # Old releases stored second-resolution ps timestamps. Preserve active
        # legacy ownership conservatively, but never use it to authorize signals.
        try:
            return subprocess.check_output(['ps', '-o', 'lstart=', '-p', str(pid)], text=True).strip() == previous
        except subprocess.CalledProcessError:
            return False
    return current == previous


def signal_owner(data, sig):
    """Signal one persisted owner identity, never a potentially recycled PGID."""
    if sys.platform == 'linux' and not str(data.get('birth', '')).isdigit():
        raise ValueError('legacy process identity cannot authorize signaling; preserve ownership and inspect the old process')
    try:
        descriptor = os.pidfd_open(data['pid'], 0)
    except ProcessLookupError:
        return
    try:
        if data.get('birth') and birth(data['pid']) == data['birth']:
            signal.pidfd_send_signal(descriptor, sig)
    finally:
        os.close(descriptor)


def safe_scope(value):
    p = Path(value)
    if p.is_absolute() or '..' in p.parts or any(c in value for c in '*?[]\n\t') or not p.parts:
        raise ValueError(f'invalid literal scope: {value}')
    if any(c in p.parts for c in ('.git', '.beads')):
        raise ValueError(f'protected worker scope: {value}')
    return p.as_posix().rstrip('/')


def overlaps(a, b):
    return a == b or a.startswith(b + '/') or b.startswith(a + '/')


class Falcon:
    def __init__(self, root):
        self.root = Path(git(root, 'rev-parse', '--show-toplevel')).resolve()
        self.state = self.root / '.codex/state/tmp/falcon'
        # Never route state through a symlink.
        for p in [self.root / '.codex', self.root / '.codex/state', self.root / '.codex/state/tmp', self.state]:
            if p.is_symlink():
                raise ValueError(f'symlink state directory: {p}')
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        if subprocess.run(['git', '-C', str(self.root), 'check-ignore', '-q', str(self.state / 'probe')]).returncode:
            raise ValueError('Falcon state is not ignored; add .codex/state/tmp/ to .gitignore first')

    @contextmanager
    def locked(self):
        with safe_open(self.state / 'registry.lock', 'a+') as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            yield

    def path(self, identifier):
        if not re.fullmatch(r'[a-f0-9]{12}', identifier):
            raise ValueError('dispatch ID must be twelve hexadecimal characters')
        return self.state / f'{identifier}.json'

    def load(self, identifier):
        record = read_json(self.path(identifier))
        if record.get('id') != identifier:
            raise ValueError('dispatch record identity mismatch')
        self.worktree(record)
        return record

    def records(self):
        return [self.load(p.stem) for p in sorted(self.state.glob('????????????.json'))]

    def worktree(self, record):
        expected = self.state / 'worktrees' / record['id']
        if record.get('worktree') != str(expected) or record.get('branch') != f'falcon/{record["id"]}':
            raise ValueError('dispatch worktree/branch identity mismatch')
        safe_path(expected, directory=True)
        safe_path(expected / '.git')
        return expected

    def new_attempt(self, record):
        identifier = uuid.uuid4().hex[:12]
        folder = self.state / 'attempts' / record['id'] / identifier
        safe_path(folder, directory=True)
        folder.mkdir(parents=True, mode=0o700)
        attempt = {'id': identifier, 'report': str(folder / 'report.json'),
                   'log': str(folder / 'log.jsonl'), 'created': time.time(), 'status': 'starting',
                   'supervisor_status': str(folder / 'supervisor.json'),
                   'supervisor_nonce': uuid.uuid4().hex, 'supervisor_pid': None, 'supervisor_birth': None,
                   'supervisor_launch_intent': False}
        # An empty exclusively-created output belongs to this attempt. No output
        # from Codex is invalid JSON, never an earlier attempt's successful report.
        with safe_open(Path(attempt['report']), 'a', exclusive=True):
            pass
        with safe_open(Path(attempt['log']), 'a', exclusive=True):
            pass
        with safe_open(Path(attempt['supervisor_status']), 'a', exclusive=True):
            pass
        record.setdefault('attempts', []).append(attempt)
        record.update(attempt=identifier, report=None, report_hash=None, handoff=None)
        return attempt

    def attempt(self, record):
        identifier = record.get('attempt')
        if not identifier or not re.fullmatch(r'[a-f0-9]{12}', identifier):
            raise ValueError('missing/invalid current attempt identity')
        attempt = next((a for a in record.get('attempts', []) if a.get('id') == identifier), None)
        if attempt is None:
            raise ValueError('current attempt absent from dispatch history')
        folder = self.state / 'attempts' / record['id'] / identifier
        for key, name in [('report', 'report.json'), ('log', 'log.jsonl'), ('supervisor_status', 'supervisor.json')]:
            expected = folder / name
            if attempt.get(key) != str(expected):
                raise ValueError('attempt output identity mismatch')
            safe_path(expected)
        return attempt

    def quiescent(self, record):
        if alive(record):
            return False
        if not record.get('attempt'):
            # A paste-only dispatch never launched any worker. Legacy started
            # records without ownership evidence require manual inspection.
            return record['status'] == 'prepared' and not record.get('pid')
        attempt = self.attempt(record)
        if attempt.get('supervisor_launch_intent') is False:
            # The runner was stopped before recording its durable launch intent.
            # Worker launch records that intent under the same registry lock.
            return True
        owner = {'pid': attempt.get('supervisor_pid'), 'birth': attempt.get('supervisor_birth')}
        if alive(owner):
            return False
        try:
            status = read_json(Path(attempt['supervisor_status']))
        except (OSError, ValueError):
            return False
        return (status.get('nonce') == attempt.get('supervisor_nonce') and
                type(status.get('supervisor_pid')) is int and status['supervisor_pid'] > 0 and
                (owner['pid'] is None or status['supervisor_pid'] == owner['pid']) and
                status.get('quiescent') is True)

    def require_quiescent(self, record):
        if not self.quiescent(record):
            raise ValueError('owned worker descendants are not confirmed stopped; preserve scope and inspect shutdown evidence')

    def start_worker(self, record, resume=False):
        if record.get('pending_commit'):
            raise ValueError('unfinished steering commit; run recover before resume')
        self.require_quiescent(record)
        self.new_attempt(record)
        save(self.path(record['id']), record)
        runner = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--root', str(self.root),
                                   '_worker', record['id'], *( ['--resume'] if resume else [])],
                                  stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL, start_new_session=True)
        record.update(pid=runner.pid, birth=birth(runner.pid), status='starting')
        save(self.path(record['id']), record)

    def dispatch(self, args):
        scopes = [safe_scope(s) for s in args.scope]
        if not scopes:
            raise ValueError('dispatch requires at least one --scope literal path')
        prompt_path = Path(args.prompt_file).resolve(strict=True)
        prompt = prompt_path.read_text()
        with self.locked():
            for item in self.records():
                if item['status'] != 'released' and any(overlaps(a, b) for a in scopes for b in item['scope']):
                    raise ValueError(f'scope locked by {item["id"]}; inspect/release it before redispatch')
            identifier = uuid.uuid4().hex[:12]
            worktree = self.state / 'worktrees' / identifier
            branch = f'falcon/{identifier}'
            safe_path(worktree, directory=True)
            worktree.parent.mkdir(exist_ok=True, mode=0o700)
            git(self.root, 'worktree', 'add', '-b', branch, str(worktree), 'HEAD')
            record = {'id': identifier, 'scope': scopes, 'beads': args.bead, 'branch': branch,
                      'worktree': str(worktree), 'base': git(self.root, 'rev-parse', 'HEAD'),
                      'status': 'prepared', 'prompt': prompt, 'amendments': [], 'session': None,
                      'report': None, 'created': time.time(), 'pr': None}
            save(self.path(identifier), record)
            if not args.paste:
                self.start_worker(record)
            print(json.dumps(record, indent=2))
            if args.paste:
                print(self.prompt(record))

    def prompt(self, record):
        return (f'You are the Codex Falcon worker for {record["id"]}. Work only in {record["worktree"]}. '
                f'Authorized file scope: {record["scope"]}. Beads IDs: {record["beads"]}. '
                f'To read issue context, use bd -C {self.root} --readonly show <id>. '
                'Never update Beads, stage, commit, integrate, push, open PRs or change files outside your scope. '
                'Read AGENTS.md subject to this explicit worker authority: repository session-close '
                'instructions do not authorize staging, committing or publication for this worker. '
                'Implement and test the assigned change, leave scoped source changes uncommitted '
                'for steering to audit and commit, and return JSON with summary, changed_files, tests, risks. '
                'Stop and report blocked if scope or permissions are insufficient.\n\n' + record['prompt'] +
                '\n\nAmendments:\n' + '\n'.join(record['amendments']))

    def worker(self, identifier, resume):
        interrupted = []
        owned_child = []
        previous_handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGTERM, signal.SIGINT)}
        def request_stop(sig, frame):
            interrupted.append(sig)
            if owned_child and owned_child[0].poll() is None:
                owned_child[0].send_signal(signal.SIGTERM)
        for sig in previous_handlers:
            signal.signal(sig, request_stop)
        # Parent commits launch identity while holding the same registry lock.
        with self.locked():
            record = self.load(identifier)
            if not record.get('attempt'):
                self.new_attempt(record)
            attempt = self.attempt(record)
            record.update(status='running', pid=os.getpid(), birth=birth(os.getpid()))
            save(self.path(identifier), record)
        report = Path(attempt['report'])
        log = Path(attempt['log'])
        if resume and not record.get('session'):
            raise ValueError('no saved Codex session; redispatch or inspect the failed launch')
        if resume:
            command = ['codex', 'exec', 'resume', record['session'], '-c', 'sandbox_mode="workspace-write"',
                       '-c', 'approval_policy="never"', '--json',
                       '--output-schema', str(Path(__file__).with_name('report.schema.json')),
                       '--output-last-message', str(report), '-']
        else:
            command = ['codex', 'exec', '--sandbox', 'workspace-write', '-c', 'approval_policy="never"',
                       '-C', record['worktree'], '--json', '--output-schema', str(Path(__file__).with_name('report.schema.json')),
                       '--output-last-message', str(report), '-']
        code = 1
        try:
            with safe_open(log, 'a') as out:
                safe_path(report)
                command = [sys.executable, str(Path(__file__).with_name('process-supervisor.py')),
                           '--status-file', attempt['supervisor_status'], '--nonce', attempt['supervisor_nonce'],
                           '--parent-pid', str(os.getpid()), '--parent-birth',
                           Path('/proc/self/stat').read_text().rsplit(')', 1)[1].split()[19],
                           '--', *command]
                if interrupted:
                    raise ValueError('worker interrupted before launch; shutdown evidence requires inspection')
                with self.locked():
                    current = self.load(identifier)
                    self.attempt(current)['supervisor_launch_intent'] = True
                    save(self.path(identifier), current)
                child = subprocess.Popen(command, cwd=record['worktree'], stdin=subprocess.PIPE,
                                         stdout=subprocess.PIPE, stderr=out, text=True)
                owned_child.append(child)
                with self.locked():
                    current = self.load(identifier)
                    owner = self.attempt(current)
                    owner.update(supervisor_pid=child.pid, supervisor_birth=birth(child.pid))
                    save(self.path(identifier), current)
                if interrupted:
                    child.send_signal(signal.SIGTERM)
                child.stdin.write(self.prompt(record)); child.stdin.close()
                for line in child.stdout:
                    out.write(line); out.flush()
                    try:
                        event = json.loads(line)
                        if event.get('type') == 'thread.started':
                            with self.locked():
                                current = self.load(identifier)
                                current['session'] = event['thread_id']; save(self.path(identifier), current)
                    except (ValueError, KeyError):
                        pass
                code = child.wait()
            if code == 0:
                validate_report(read_json(report))
                ownership = read_json(Path(attempt['supervisor_status']))
                if (ownership.get('nonce') != attempt['supervisor_nonce'] or
                        ownership.get('supervisor_pid') != child.pid or ownership.get('quiescent') is not True):
                    raise ValueError('missing valid owned-descendant quiescence evidence')
        except (OSError, ValueError) as exc:
            with safe_open(log, 'a') as out:
                out.write(f'Falcon launch/report failure: {exc}\n')
            code = 1
        finally:
            for sig, handler in previous_handlers.items():
                signal.signal(sig, handler)
        with self.locked():
            current = self.load(identifier)
            latest = self.attempt(current)
            cancelled = current['status'] in ('cancelled', 'cancelling', 'shutdown-unconfirmed') or interrupted
            latest.update(status='cancelled' if cancelled else
                          ('complete' if code == 0 else 'failed'), exit_code=code)
            if cancelled:
                current.update(status='cancelled', exit_code=code)
            else:
                current.update(status='complete' if code == 0 else 'failed', exit_code=code,
                               report=str(report) if code == 0 else None,
                               report_hash=digest(report) if code == 0 else None)
                latest['report_hash'] = current['report_hash']
            save(self.path(identifier), current)
        return code

    def refresh(self):
        # Network observation never holds the registry lock needed for cancel,
        # worker completion and recovery.
        with self.locked():
            records = self.records()
            for record in records:
                if record['status'] in ('starting', 'running') and not alive(record):
                    record['status'] = 'interrupted'
                    if record.get('attempt'):
                        self.attempt(record)['status'] = 'interrupted'
                    save(self.path(record['id']), record)
        for record in records:
            if record.get('pr'):
                try:
                    result = subprocess.run(['gh', 'pr', 'view', record['pr'], '--json',
                                             'state,reviewDecision,mergeStateStatus'], cwd=self.root,
                                            capture_output=True, text=True, timeout=15)
                    observation = json.loads(result.stdout) if result.returncode == 0 else {'error': result.stderr[-500:]}
                except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
                    observation = {'error': str(exc)}
                with self.locked():
                    current = self.load(record['id'])
                    if current.get('pr') == record['pr']:
                        current['pr_observation'] = observation
                        save(self.path(current['id']), current)
        return self.records()

    def audit(self, record):
        if alive(record) or record['status'] not in ('complete', 'committed'):
            raise ValueError('handoff needs an inactive worker with valid current evidence')
        self.require_quiescent(record)
        attempt = self.attempt(record)
        report = Path(attempt['report'])
        if record.get('report') != str(report) or digest(report) != record.get('report_hash'):
            raise ValueError('current worker report identity/hash mismatch; inspect recovery evidence')
        parsed = validate_report(read_json(report))
        worktree = self.worktree(record)
        head = git(worktree, 'rev-parse', 'HEAD')
        expected = record.get('commit') or record['base']
        if head != expected or git(worktree, 'symbolic-ref', '--short', 'HEAD') != record['branch']:
            raise ValueError('worker Git HEAD/branch changed without steering handoff')
        common = Path(git(worktree, 'rev-parse', '--path-format=absolute', '--git-common-dir'))
        if common != Path(git(self.root, 'rev-parse', '--path-format=absolute', '--git-common-dir')):
            raise ValueError('worker Git common-directory identity mismatch')
        changed = git(worktree, 'diff', '--name-only', '--no-renames', '-z', 'HEAD').split('\0')
        untracked = git(worktree, 'ls-files', '--others', '--exclude-standard', '-z').split('\0')
        files = sorted({name for name in changed + untracked if name})
        for name in files + parsed['changed_files']:
            literal = safe_scope(name)
            if not any(literal == scope or literal.startswith(scope + '/') for scope in record['scope']):
                raise ValueError(f'out-of-scope worker change/report: {name}; recover it before handoff')
            safe_path(worktree / literal)
        # Git's full binary patch plus untracked bytes and executable modes cover
        # staged/unstaged/deleted/new changes, not just worker-declared filenames.
        patch = subprocess.check_output(['git', '-C', str(worktree), 'diff', '--binary', '--no-ext-diff',
                                         '--no-textconv', '--no-renames', 'HEAD'])
        checksum = hashlib.sha256(head.encode() + b'\0' + patch)
        for name in sorted(set(untracked) - {''}):
            path = worktree / name
            with safe_open(path, 'rb') as stream:
                checksum.update(name.encode() + b'\0' + str(path.stat().st_mode).encode() + b'\0' + stream.read())
        return {'id': record['id'], 'attempt': attempt['id'], 'branch': record['branch'],
                'head': head, 'files': files, 'report': str(report),
                'report_hash': record['report_hash'], 'diff_hash': checksum.hexdigest(),
                'summary': parsed['summary'], 'tests': parsed['tests'], 'risks': parsed['risks'],
                'commit': record.get('commit')}

    def steering_commit(self, record, args):
        audit = self.audit(record)
        if audit['report_hash'] != args.report_hash or audit['diff_hash'] != args.diff_hash:
            raise ValueError('handoff evidence changed; rerun handoff and review before commit')
        if not audit['files']:
            if record.get('commit'):
                return audit
            raise ValueError('no scoped changes to commit')
        if not args.message.strip():
            raise ValueError('steering commit needs a nonempty --message')
        worktree = self.worktree(record)
        # A private index stages only reviewed paths; unrelated existing staged
        # content is never included or reset. commit-tree avoids repository hooks
        # and publication; update-ref uses the reviewed HEAD as a CAS guard.
        folder = Path(self.attempt(record)['report']).parent
        fd, name = tempfile.mkstemp(prefix='steering-index-', dir=folder)
        os.close(fd)
        os.unlink(name)  # Git requires either an absent index or a valid index.
        env = {**os.environ, 'GIT_INDEX_FILE': name, 'GIT_LITERAL_PATHSPECS': '1'}
        def command(*values, **options):
            return subprocess.check_output(['git', '-C', str(worktree), *values], env=env,
                                           text=True, **options).strip()
        try:
            command('read-tree', audit['head'])
            command('add', '--', *audit['files'])
            tree = command('write-tree')
            if self.audit(record)['diff_hash'] != audit['diff_hash']:
                raise ValueError('worker files changed during staging; no commit published')
            commit = command('commit-tree', tree, '-p', audit['head'], input=args.message + '\n')
            record['pending_commit'] = {'commit': commit, 'parent': audit['head'],
                                        'tree': tree, 'files': audit['files'], 'audit': audit}
            save(self.path(record['id']), record)
            command('update-ref', f'refs/heads/{record["branch"]}', commit, audit['head'])
            # Update only reviewed index paths to their new HEAD; leave any
            # unrelated entries untouched. Working files are never overwritten.
            subprocess.run(['git', '-C', str(worktree), '--literal-pathspecs', 'reset', '-q', commit,
                            '--', *audit['files']], check=True)
            record.update(status='committed', commit=commit, handoff={**audit, 'commit': commit})
            record.pop('pending_commit', None)
            record.setdefault('commits', []).append(commit)
            save(self.path(record['id']), record)
            return {**audit, 'commit': commit, 'status': 'committed'}
        finally:
            for entry in (Path(name), Path(name + '.lock')):
                safe_path(entry)
                if entry.exists():
                    entry.unlink()

    def recover_commit(self, record):
        if alive(record):
            raise ValueError('active worker; cancel/wait before recovery')
        self.require_quiescent(record)
        pending = record.get('pending_commit')
        if not pending:
            return {'id': record['id'], 'status': record['status'], 'message': 'no pending steering commit'}
        worktree = self.worktree(record)
        commit = pending['commit']
        if (git(worktree, 'rev-parse', f'{commit}^') != pending['parent'] or
                git(worktree, 'rev-parse', f'{commit}^{{tree}}') != pending['tree']):
            raise ValueError('pending commit provenance mismatch; inspect without changing state')
        actual = set(filter(None, git(worktree, 'diff', '--name-only', '--no-renames', '-z',
                                      pending['parent'], commit).split('\0')))
        if actual != set(pending['files']):
            raise ValueError('pending commit file list differs from actual commit diff')
        for name in pending['files']:
            literal = safe_scope(name)
            if not any(literal == scope or literal.startswith(scope + '/') for scope in record['scope']):
                raise ValueError('pending commit has out-of-scope paths')
            safe_path(worktree / literal)
        head = git(worktree, 'rev-parse', 'HEAD')
        if git(worktree, 'symbolic-ref', '--short', 'HEAD') != record['branch']:
            raise ValueError('recovery branch identity mismatch')
        if head == commit:
            subprocess.run(['git', '-C', str(worktree), '--literal-pathspecs', 'reset', '-q', commit,
                            '--', *pending['files']], check=True)
            record.update(status='committed', commit=commit, handoff={**pending['audit'], 'commit': commit})
            if commit not in record.setdefault('commits', []):
                record['commits'].append(commit)
            message = 'recovered steering commit; source files preserved'
        elif head == pending['parent']:
            message = 'branch unchanged; discarded pending publication record, rerun handoff/commit'
        else:
            raise ValueError('recovery HEAD differs from both reviewed parent and commit; inspect manually')
        record.pop('pending_commit')
        save(self.path(record['id']), record)
        return {'id': record['id'], 'status': record['status'], 'commit': record.get('commit'), 'message': message}

    def cancel(self, identifier):
        with self.locked():
            record = self.load(identifier)
            if record['status'] == 'released':
                raise ValueError('released dispatch cannot be cancelled')
            if record['status'] == 'prepared' and not record.get('attempt'):
                record.update(status='cancelled', never_started=True)
                save(self.path(identifier), record)
                return
            record['status'] = 'cancelling'
            save(self.path(identifier), record)
        # Never wait while holding the lock needed by worker finalization.
        if alive(record):
            signal_owner(record, signal.SIGTERM)
        elif record.get('attempt'):
            attempt = self.attempt(record)
            owner = {'pid': attempt.get('supervisor_pid'), 'birth': attempt.get('supervisor_birth')}
            if alive(owner):
                signal_owner(owner, signal.SIGTERM)
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            with self.locked():
                current = self.load(identifier)
                if self.quiescent(current):
                    current['status'] = 'cancelled'
                    self.attempt(current)['status'] = 'cancelled'
                    save(self.path(identifier), current)
                    return
            time.sleep(0.02)
        with self.locked():
            current = self.load(identifier)
            current['status'] = 'shutdown-unconfirmed'
            save(self.path(identifier), current)
        raise ValueError('cancellation could not confirm owned descendants stopped; scope remains locked')

    def action(self, args):
        if args.command == 'cancel':
            self.cancel(args.id)
            return
        with self.locked():
            r = self.load(args.id)
            if args.command == 'amend':
                if r['status'] == 'released':
                    raise ValueError('released dispatch cannot be amended; create a new dispatch')
                r['amendments'].append(args.message)
                save(self.path(args.id), r)
                print('Amendment queued; after worker completion/interruption run resume. No live prompt injection.')
            elif args.command == 'resume':
                if alive(r) or r['status'] == 'released':
                    raise ValueError('worker is active or dispatch released; cannot resume')
                if not r.get('session'):
                    raise ValueError('no saved session. Use dispatch --paste or redispatch after release')
                self.start_worker(r, True)
            elif args.command == 'release':
                if r.get('pending_commit'):
                    raise ValueError('unfinished steering commit; run recover before release')
                if alive(r):
                    raise ValueError('active worker; cancel first. Release keeps the worktree and report for recovery')
                if not r.get('never_started'):
                    self.require_quiescent(r)
                r['status'] = 'released'; save(self.path(args.id), r)
            elif args.command == 'paste':
                print(self.prompt(r))
            elif args.command == 'watch-pr':
                r['pr'] = args.pr; save(self.path(args.id), r)
            elif args.command == 'handoff':
                audit = self.audit(r)
                r['handoff'] = audit; save(self.path(args.id), r)
                print(json.dumps(audit, indent=2))
            elif args.command == 'commit':
                if r.get('pending_commit'):
                    raise ValueError('unfinished steering commit; run recover before retry')
                print(json.dumps(self.steering_commit(r, args), indent=2))
            elif args.command == 'recover':
                print(json.dumps(self.recover_commit(r), indent=2))

    def monitor(self, args):
        file = self.state / 'monitor.json'
        with self.locked():
            safe_path(file)
            record = read_json(file) if file.exists() else {}
            if args.action == 'status':
                print(json.dumps({**record, 'running': alive(record)})); return
            if args.action == 'stop':
                if alive(record):
                    signal_owner(record, signal.SIGTERM)
                record['status'] = 'stopped'; save(file, record); return
            if alive(record):
                print('Monitor already running'); return
            child = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--root', str(self.root),
                                      '_monitor', '--interval', str(args.interval)], start_new_session=True,
                                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            save(file, {'pid': child.pid, 'birth': birth(child.pid), 'interval': args.interval, 'status': 'running'})
            print(f'Monitor started: {child.pid}; stop with monitor stop. No service installed.')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--root', default='.')
    sub = p.add_subparsers(dest='command', required=True)
    d = sub.add_parser('dispatch'); d.add_argument('--prompt-file', required=True)
    d.add_argument('--scope', action='append', default=[]); d.add_argument('--bead', action='append', default=[])
    d.add_argument('--paste', action='store_true')
    sub.add_parser('status')
    for name in ('resume', 'amend', 'cancel', 'release', 'paste', 'watch-pr', 'handoff', 'commit', 'recover', '_worker'):
        s = sub.add_parser(name); s.add_argument('id')
        if name == 'amend': s.add_argument('message')
        if name == 'watch-pr': s.add_argument('pr')
        if name == '_worker': s.add_argument('--resume', action='store_true')
        if name == 'commit':
            s.add_argument('--message', required=True)
            s.add_argument('--report-hash', required=True)
            s.add_argument('--diff-hash', required=True)
    for name in ('monitor', 'autopilot'):
        m = sub.add_parser(name); m.add_argument('action', choices=['start', 'status', 'stop'])
        m.add_argument('--interval', type=float, default=30)
    m = sub.add_parser('_monitor'); m.add_argument('--interval', type=float, default=30)
    args = p.parse_args()
    if getattr(args, 'interval', 30) < 0.1:
        raise ValueError('monitor interval must be at least 0.1 seconds')
    app = Falcon(args.root)
    if args.command == 'dispatch': app.dispatch(args)
    elif args.command == 'status': print(json.dumps(app.refresh(), indent=2))
    elif args.command == '_worker': return app.worker(args.id, args.resume)
    elif args.command in ('monitor', 'autopilot'): app.monitor(args)
    elif args.command == '_monitor':
        while True:
            app.refresh(); time.sleep(args.interval)
    else: app.action(args)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f'falcon: {exc}. Inspect status and dispatch logs; no integration or PR mutation performed.', file=sys.stderr)
        sys.exit(2)
