#!/usr/bin/env python3
"""Serialize acquisition/recovery of one project's durable manual-edit lease."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import stat
import sys
import tempfile


def safe(path):
    path = Path(path)
    for item in (path, *path.parents):
        if item.is_symlink():
            raise ValueError('unsafe manual-edit ownership symlink')
    return path


def read(path):
    path = safe(path)
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor) as stream:
        value = os.fstat(stream.fileno())
        if not stat.S_ISREG(value.st_mode) or value.st_nlink != 1:
            raise ValueError('unsafe manual-edit ownership file')
        return json.load(stream)


def birth(pid):
    try:
        value = Path('/proc', str(pid), 'stat').read_text()
    except (FileNotFoundError, ProcessLookupError):
        return None
    return value[value.rfind(')') + 2:].split()[19]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--file', required=True)
    parser.add_argument('--cwd', required=True)
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--birth', required=True)
    parser.add_argument('--id', required=True)
    args = parser.parse_args()
    file = safe(Path(args.file).absolute())
    file.parent.mkdir(parents=True, exist_ok=True)
    lock = safe(file.with_name(file.name + '.lock'))
    descriptor = os.open(lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'a+') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError('unsafe manual-edit ownership lock')
        fcntl.flock(stream, fcntl.LOCK_EX)
        proven_previous = []
        if file.exists():
            owner = read(file)
            if (not isinstance(owner, dict) or type(owner.get('version')) is not int or owner['version'] != 1 or owner.get('cwd') != args.cwd or
                    not isinstance(owner.get('id'), str) or not owner['id'] or
                    type(owner.get('pid')) is not int or owner['pid'] <= 0 or
                    not isinstance(owner.get('birth'), str) or not owner['birth'].isascii() or not owner['birth'].isdigit() or
                    type(owner.get('released', False)) is not bool or
                    type(owner.get('externalWriterActive', False)) is not bool or
                    not isinstance(owner.get('workers'), list)):
                raise ValueError('unreadable previous manual-edit ownership; preserve transaction')
            if owner.get('released') is not True and birth(owner['pid']) == owner['birth']:
                raise ValueError('Manual Apply owns this project; wait before Apply, rollback or discard')
            if owner.get('externalWriterActive'):
                raise ValueError('Previous external chat writer is unconfirmed; preserve transaction')
            for worker in owner['workers']:
                try:
                    if (not isinstance(worker, dict) or 'pid' not in worker or
                            not isinstance(worker.get('nonce'), str) or not worker['nonce'] or
                            not isinstance(worker.get('statusPath'), str) or not worker['statusPath']):
                        raise ValueError('invalid recorded supervisor evidence')
                    if worker.get('pid') is not None and (type(worker['pid']) is not int or worker['pid'] <= 0):
                        raise ValueError('invalid recorded supervisor identity')
                    result = read(worker['statusPath'])
                    if not isinstance(result, dict):
                        raise ValueError('invalid supervisor certificate')
                    confirmed = (result.get('nonce') == worker['nonce'] and
                                 result.get('quiescent') is True and
                                 type(result.get('supervisor_pid')) is int and
                                 (result['supervisor_pid'] > 0 or
                                  result['supervisor_pid'] == 0 and result.get('noLauncherStarted') is True and worker.get('pid') is None) and
                                 (worker.get('pid') is None or result['supervisor_pid'] == worker['pid']))
                except (OSError, ValueError, KeyError, TypeError):
                    confirmed = False
                if not confirmed:
                    raise ValueError('Previous manual Apply has no confirmed owned-descendant shutdown; preserve transaction and retry after supervisor finishes')
            prior = owner.get('verifiedPreviousOwnerIds', [])
            if not isinstance(prior, list) or not all(isinstance(item, str) and item for item in prior):
                raise ValueError('invalid previous manual-edit ownership proof')
            proven_previous = list(dict.fromkeys([*prior, owner['id']]))
            # Only the retained transaction needs a historical proof. Do not
            # accumulate one receipt ID per successful Apply indefinitely.
            transaction = file.with_name('manual-edit-apply-transaction.json')
            if transaction.exists():
                retained = read(transaction)
                if not isinstance(retained, dict):
                    raise ValueError('invalid retained transaction; preserve recovery evidence')
                required = retained.get('ownershipId')
                proven_previous = [required] if required in proven_previous else []
            else:
                proven_previous = []
        if birth(args.pid) != args.birth:
            raise ValueError('requesting manual-edit process identity changed')
        owner = {'version': 1, 'id': args.id, 'cwd': args.cwd, 'pid': args.pid,
                 'birth': args.birth, 'workers': [], 'externalWriterActive': False,
                 'released': False, 'verifiedPreviousOwnerIds': proven_previous}
        descriptor, name = tempfile.mkstemp(prefix=file.name + '.', suffix='.tmp', dir=file.parent)
        try:
            with os.fdopen(descriptor, 'w') as output:
                json.dump(owner, output)
                output.flush()
                os.fsync(output.fileno())
            safe(file)
            os.replace(name, file)
        finally:
            if os.path.exists(name):
                os.unlink(name)
        print(json.dumps(owner))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
