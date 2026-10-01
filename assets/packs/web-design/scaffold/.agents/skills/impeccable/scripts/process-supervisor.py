#!/usr/bin/env python3
"""Linux owned-descendant supervisor. No model calls or sandbox bypass."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tempfile
import time

GRACE_SECONDS = 0.25
KILL_SECONDS = 1.0


def process_table():
    result = {}
    for name in os.listdir('/proc'):
        if not name.isdigit():
            continue
        try:
            value = Path('/proc', name, 'stat').read_text()
        except (FileNotFoundError, ProcessLookupError):
            continue
        fields = value[value.rfind(')') + 2:].split()
        result[int(name)] = {'state': fields[0], 'parent': int(fields[1]),
                             'birth': fields[19]}
    return result


def descendants(table, root):
    owned = set()
    parents = {root}
    while parents:
        children = {pid for pid, value in table.items()
                    if value['parent'] in parents and pid not in owned}
        owned.update(children)
        parents = children
    return {pid: table[pid] for pid in owned}


def signal_owned(owned, sig):
    # pidfds bind signaling to one process, closing the PID-reuse gap between
    # checking /proc identity and delivering a signal.
    for pid, previous in owned.items():
        descriptor = None
        try:
            descriptor = os.pidfd_open(pid, 0)
            value = Path('/proc', str(pid), 'stat').read_text()
            fields = value[value.rfind(')') + 2:].split()
            if fields[19] == previous['birth'] and fields[0] not in ('Z', 'X'):
                signal.pidfd_send_signal(descriptor, sig)
        except (FileNotFoundError, ProcessLookupError):
            pass
        finally:
            if descriptor is not None:
                os.close(descriptor)


def persist(path, value):
    path = Path(path).absolute()
    for candidate in (path, *path.parents):
        if candidate.is_symlink():
            raise ValueError('symlink supervisor output path')
    if path.exists():
        info = path.stat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError('unsafe supervisor output file')
    fd, temporary = tempfile.mkstemp(prefix=path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def children_exhausted():
    """Kernel barrier, called only after Popen reaped its direct child.

    /proc enumeration can miss a just-forked adopted child. ECHILD proves no
    children remain; waitpid==0 means some live child still exists. Subreaper
    adoption makes even detached descendants part of this kernel accounting.
    """
    while True:
        try:
            pid, _ = os.waitpid(-1, os.WNOHANG)
        except ChildProcessError:
            return True
        if pid == 0:
            return False


def supervise(args):
    self_pid = os.getpid()
    outcome = {'nonce': args.nonce, 'supervisor_pid': self_pid, 'quiescent': False}
    try:
        # Linux subreaper adoption closes the ancestry gap when a descendant calls
        # setsid(), double-forks, or outlives the original CLI. Never infer ownership
        # from process names, a foreign process group, or an unrelated UID.
        if sys.platform != 'linux':
            outcome.update(quiescent=True, error='Owned-descendant supervision currently requires Linux or WSL; no worker was launched')
            persist(args.status_file, outcome)
            print(outcome['error'], file=sys.stderr)
            return 78
        if ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) != 0:
            raise OSError(ctypes.get_errno(), 'cannot enable owned-descendant subreaper')
        try:
            descriptor = os.pidfd_open(self_pid, 0)
            os.close(descriptor)
            if not hasattr(signal, 'pidfd_send_signal'):
                raise RuntimeError('Python lacks pidfd signaling')
        except (AttributeError, OSError, RuntimeError) as exc:
            outcome.update(quiescent=True, error=f'Owned-descendant supervision needs Linux pidfd support: {exc}; no worker was launched')
            persist(args.status_file, outcome)
            print(outcome['error'], file=sys.stderr)
            return 78
        # The launcher records its own identity BEFORE spawning us. Capturing
        # getppid() here can mistake PID 1/a new adopter for the original caller
        # if that caller died during interpreter startup or imports.
        original_parent = args.parent_pid
        parent_identity = args.parent_birth
        if (type(original_parent) is not int or original_parent <= 0 or
                not isinstance(parent_identity, str) or not parent_identity.isdigit()):
            raise ValueError('invalid explicit launcher identity')
        parent = process_table().get(original_parent)
        if not parent or parent['state'] in ('Z', 'X') or parent['birth'] != parent_identity:
            raise ValueError('original launcher already stopped')
        interrupted = []
        def request_stop(sig, frame):
            interrupted.append(sig)
        signal.signal(signal.SIGTERM, request_stop)
        signal.signal(signal.SIGINT, request_stop)
        child = subprocess.Popen(args.command, start_new_session=True)
    except Exception as exc:
        # Before Popen returns, no worker command has successfully launched.
        # Python reaps its failed exec child before raising. Certify only this
        # prelaunch boundary; postlaunch errors retain ownership below.
        outcome.update(quiescent=True, error=f'{exc}; no worker was launched')
        persist(args.status_file, outcome)
        print(outcome['error'], file=sys.stderr)
        return 78
    # A caller signal cannot kill the supervisor while its children still write.
    # It requests bounded shutdown; an unexpected parent death also requests it.
    deadline = None
    force = False
    try:
        while True:
            code = child.poll()
            table = process_table()
            parent = table.get(original_parent)
            if not parent or parent['state'] in ('Z', 'X') or parent['birth'] != parent_identity:
                interrupted.append(signal.SIGTERM)
            owned = descendants(table, self_pid)
            live = {pid: item for pid, item in owned.items() if item['state'] not in ('Z', 'X')}
            # Reap adopted zombies without stealing Popen's direct-child status.
            for pid, item in owned.items():
                if pid != child.pid and item['parent'] == self_pid and item['state'] in ('Z', 'X'):
                    try:
                        os.waitpid(pid, os.WNOHANG)
                    except ChildProcessError:
                        pass
            if code is not None and not live and children_exhausted():
                outcome.update(quiescent=True, child_returncode=code,
                               interrupted=bool(interrupted))
                persist(args.status_file, outcome)
                return 128 + interrupted[0] if interrupted else (code if code >= 0 else 128 - code)
            if code is not None or interrupted:
                if deadline is None:
                    deadline = time.monotonic() + GRACE_SECONDS
                if not force and time.monotonic() >= deadline:
                    force = True
                    deadline = time.monotonic() + KILL_SECONDS
                signal_owned(live, signal.SIGKILL if force else signal.SIGTERM)
                if force and time.monotonic() >= deadline:
                    outcome.update(error='Owned descendants did not become quiescent; preserve transaction/scope and do not retry')
                    persist(args.status_file, outcome)
                    # Remain their subreaper/owner, continue attempting shutdown.
                    # Parent must retain its lock rather than interpreting exit
                    # or an empty original process group as permission to retry.
                    while True:
                        table = process_table()
                        live = {pid: item for pid, item in descendants(table, self_pid).items()
                                if item['state'] not in ('Z', 'X')}
                        code = child.poll()
                        if code is not None and not live and children_exhausted():
                            outcome.update(quiescent=True, child_returncode=code,
                                           interrupted=bool(interrupted))
                            persist(args.status_file, outcome)
                            return 128 + signal.SIGTERM
                        signal_owned(live, signal.SIGKILL)
                        time.sleep(0.1)
            time.sleep(0.02)
    except BaseException as exc:
        # A failed inspection/persistence is never permission to orphan writers.
        # Retain subreaper ownership; the caller's bounded wait fails closed.
        outcome['error'] = str(exc)
        try:
            persist(args.status_file, outcome)
        except Exception:
            pass
        try:
            child.kill()
        except ProcessLookupError:
            pass
        while True:
            try:
                code = child.poll()
                table = process_table()
                owned = descendants(table, self_pid)
                live = {pid: item for pid, item in owned.items() if item['state'] not in ('Z', 'X')}
                signal_owned(live, signal.SIGKILL)
                for pid, item in owned.items():
                    if pid != child.pid and item['parent'] == self_pid and item['state'] in ('Z', 'X'):
                        try:
                            os.waitpid(pid, os.WNOHANG)
                        except ChildProcessError:
                            pass
                if code is not None and not live and children_exhausted():
                    outcome.update(quiescent=True, child_returncode=code, interrupted=True)
                    persist(args.status_file, outcome)
                    return 128 + signal.SIGTERM
            except (OSError, ValueError):
                pass
            time.sleep(0.1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--status-file', required=True)
    parser.add_argument('--nonce', required=True)
    parser.add_argument('--parent-pid', type=int, required=True)
    parser.add_argument('--parent-birth', required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command[:1] == ['--']:
        args.command = args.command[1:]
    if not args.command:
        parser.error('worker command required')
    return supervise(args)


if __name__ == '__main__':
    sys.exit(main())
