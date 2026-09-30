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
import subprocess
import sys
import time
import uuid


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()


def save(path, data):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(data, indent=2) + '\n')
    temp.replace(path)


def birth(pid):
    try:
        return subprocess.check_output(['ps', '-o', 'lstart=', '-p', str(pid)], text=True).strip()
    except subprocess.CalledProcessError:
        return ''


def alive(data):
    pid = data.get('pid')
    return bool(pid and data.get('birth') and birth(pid) == data['birth'])


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
        self.state.mkdir(parents=True, exist_ok=True)
        if subprocess.run(['git', '-C', str(self.root), 'check-ignore', '-q', str(self.state / 'probe')]).returncode:
            raise ValueError('Falcon state is not ignored; add .codex/state/tmp/ to .gitignore first')

    @contextmanager
    def locked(self):
        with (self.state / 'registry.lock').open('a+') as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            yield

    def path(self, identifier):
        if not re.fullmatch(r'[a-f0-9]{12}', identifier):
            raise ValueError('dispatch ID must be twelve hexadecimal characters')
        return self.state / f'{identifier}.json'

    def load(self, identifier):
        return json.loads(self.path(identifier).read_text())

    def records(self):
        return [json.loads(p.read_text()) for p in sorted(self.state.glob('????????????.json'))]

    def start_worker(self, record, resume=False):
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
            worktree.parent.mkdir(exist_ok=True)
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
                'Never update Beads, integrate, push, open PRs or change files outside your scope. '
                'Read AGENTS.md. Implement and test the assigned change, commit only your scoped files '
                'to this isolated branch, and return JSON with summary, changed_files, tests, risks. '
                'Stop and report blocked if scope or permissions are insufficient.\n\n' + record['prompt'] +
                '\n\nAmendments:\n' + '\n'.join(record['amendments']))

    def worker(self, identifier, resume):
        # Parent commits launch identity while holding the same registry lock.
        with self.locked():
            record = self.load(identifier)
            record.update(status='running', pid=os.getpid(), birth=birth(os.getpid()))
            save(self.path(identifier), record)
        report = self.state / f'{identifier}.report.json'
        log = self.state / f'{identifier}.log.jsonl'
        if resume and not record.get('session'):
            raise ValueError('no saved Codex session; redispatch or inspect the failed launch')
        if resume:
            command = ['codex', 'exec', 'resume', record['session'], '-c', 'sandbox_mode="workspace-write"',
                       '-c', 'approval_policy="never"', '--json', '--output-last-message', str(report), '-']
        else:
            command = ['codex', 'exec', '--sandbox', 'workspace-write', '-c', 'approval_policy="never"',
                       '-C', record['worktree'], '--json', '--output-schema', str(Path(__file__).with_name('report.schema.json')),
                       '--output-last-message', str(report), '-']
        code = 1
        try:
            with log.open('a') as out:
                child = subprocess.Popen(command, cwd=record['worktree'], stdin=subprocess.PIPE,
                                         stdout=subprocess.PIPE, stderr=out, text=True)
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
                parsed = json.loads(report.read_text())
                if not all(key in parsed for key in ('summary', 'changed_files', 'tests', 'risks')):
                    raise ValueError('worker returned an incomplete report')
        except (OSError, ValueError) as exc:
            with log.open('a') as out:
                out.write(f'Falcon launch/report failure: {exc}\n')
            code = 1
        with self.locked():
            current = self.load(identifier)
            if current['status'] != 'cancelled':
                current.update(status='complete' if code == 0 else 'failed', exit_code=code,
                               report=str(report) if report.exists() else None,
                               report_hash=hashlib.sha256(report.read_bytes()).hexdigest() if report.exists() else None)
                save(self.path(identifier), current)
        return code

    def refresh(self):
        with self.locked():
            for record in self.records():
                if record['status'] in ('starting', 'running') and not alive(record):
                    record['status'] = 'interrupted'; save(self.path(record['id']), record)
                if record.get('pr'):
                    try:
                        result = subprocess.run(['gh', 'pr', 'view', record['pr'], '--json',
                                                 'state,reviewDecision,mergeStateStatus'], cwd=self.root,
                                                capture_output=True, text=True, timeout=15)
                        record['pr_observation'] = json.loads(result.stdout) if result.returncode == 0 else {'error': result.stderr[-500:]}
                        save(self.path(record['id']), record)
                    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
                        record['pr_observation'] = {'error': str(exc)}; save(self.path(record['id']), record)
        return self.records()

    def action(self, args):
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
            elif args.command == 'cancel':
                if alive(r):
                    os.killpg(r['pid'], signal.SIGTERM)
                r['status'] = 'cancelled'; save(self.path(args.id), r)
            elif args.command == 'release':
                if alive(r):
                    raise ValueError('active worker; cancel first. Release keeps the worktree and report for recovery')
                r['status'] = 'released'; save(self.path(args.id), r)
            elif args.command == 'paste':
                print(self.prompt(r))
            elif args.command == 'watch-pr':
                r['pr'] = args.pr; save(self.path(args.id), r)

    def monitor(self, args):
        file = self.state / 'monitor.json'
        with self.locked():
            record = json.loads(file.read_text()) if file.exists() else {}
            if args.action == 'status':
                print(json.dumps({**record, 'running': alive(record)})); return
            if args.action == 'stop':
                if alive(record):
                    os.killpg(record['pid'], signal.SIGTERM)
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
    for name in ('resume', 'amend', 'cancel', 'release', 'paste', 'watch-pr', '_worker'):
        s = sub.add_parser(name); s.add_argument('id')
        if name == 'amend': s.add_argument('message')
        if name == 'watch-pr': s.add_argument('pr')
        if name == '_worker': s.add_argument('--resume', action='store_true')
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
