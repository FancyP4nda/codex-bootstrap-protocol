#!/usr/bin/env python3
"""Native TOML role -> isolated Codex exec when a client lacks role selection."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tomllib


def toml_value(value):
    if isinstance(value,dict):
        return '{'+', '.join(json.dumps(key)+' = '+toml_value(item) for key,item in value.items())+'}'
    if isinstance(value,list): return '['+', '.join(toml_value(item) for item in value)+']'
    if value is None: raise ValueError('null is not a native TOML setting')
    return json.dumps(value)


def local_core(root):
    stamp=root/'.codex/bootstrap.json'
    if stamp.exists():
        data=json.loads(stamp.read_text())
        if not isinstance(data,dict) or data.get('format')!=1 or not isinstance(data.get('managed'),dict):
            raise ValueError('invalid project bootstrap metadata; cannot safely select role layer')
        mode=data.get('core_mode')
        if mode not in (None,'global','local'):
            raise ValueError('invalid project core_mode; cannot safely select role layer')
        return mode=='local' or (mode is None and '.agents/skills/session-start/SKILL.md' in data['managed'])
    return (root/'.agents/skills/session-start/SKILL.md').is_file()


def command(args):
    if not re.fullmatch(r'[a-zA-Z0-9_-]+',args.role): raise ValueError('invalid role name')
    root=Path(args.root).resolve(strict=True)
    home=Path(os.environ.get('CODEX_HOME',str(Path.home()/'.codex')))
    choices=[root/'.codex/agents'/f'{args.role}.toml']
    project_local=local_core(root)
    if not project_local: choices.append(home/'agents'/f'{args.role}.toml')
    role=next((p for p in choices if p.exists() or p.is_symlink()),None)
    if role is None:
        raise ValueError(f'role not found: {args.role}'+('; declared local-core requires the project role; stale global fallback refused' if project_local else ''))
    if role.is_symlink(): raise ValueError('symlink role refused')
    if not role.is_file(): raise ValueError('role is not a regular file')
    config=tomllib.loads(role.read_text())
    if any(not isinstance(config.get(k),str) or not config[k] for k in ('name','description','developer_instructions')):
        raise ValueError('role requires name, description and developer_instructions')
    if config['name']!=args.role: raise ValueError('role name and filename mismatch')
    supported={'name','description','developer_instructions','sandbox_mode','model','model_reasoning_effort','mcp_servers','skills'}
    if set(config)-supported: raise ValueError(f'unsupported role settings: {sorted(set(config)-supported)}')
    mode='read-only' if args.read_only else config.get('sandbox_mode','read-only')
    if mode not in ('read-only','workspace-write'): raise ValueError('unsafe role sandbox refused')
    prompt=Path(args.prompt_file).read_text()
    if len(prompt)>100_000: raise ValueError('bounded prompt must be under 100 KB')
    cli=shutil.which('codex')
    if not cli: raise ValueError('Codex CLI is missing')
    result=[cli,'exec','--ephemeral','--sandbox',mode,'-C',str(root),
            '-c','approval_policy="never"','-c','features.hooks=false']
    for key,value in config.items():
        if key not in ('name','description','sandbox_mode'):
            result+=['-c',key+'='+toml_value(value)]
    if args.isolated: result+=['--ignore-user-config']
    result+=['-']
    return result,prompt


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',default=os.getcwd()); parser.add_argument('--role',required=True)
    parser.add_argument('--prompt-file',required=True); parser.add_argument('--read-only',action='store_true')
    parser.add_argument('--isolated',action='store_true',help='Ignore personal config; existing auth still used')
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args()
    try:
        argv,prompt=command(args)
        if args.dry_run: print(json.dumps({'role':args.role,'command':argv})); return 0
        # Explicit native config overrides load developer instructions and
        # sandbox, without pretending generic spawn tools enforce role metadata.
        return subprocess.run(argv,input=prompt,text=True).returncode
    except (OSError,ValueError,tomllib.TOMLDecodeError) as error:
        print(f'native-agent: {error}; no role execution',file=sys.stderr); return 2


if __name__=='__main__': sys.exit(main())
