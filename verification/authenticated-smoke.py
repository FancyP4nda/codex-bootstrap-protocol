#!/usr/bin/env python3
"""Opt-in disposable real Beads/Codex smoke; uses existing auth, never copies it."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import fcntl
import pty
import re
import select
import struct
import termios
import time

KIT = Path(__file__).resolve().parents[1]


def footer_smoke(project,env):
    master,slave=pty.openpty()
    fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',40,160,0,0))
    args=['codex','--no-alt-screen','-C',str(project),'-c','features.hooks=false',
          '-c',f'projects.{json.dumps(str(project))}.trust_level="trusted"']
    process=subprocess.Popen(args,env={**env,'TERM':'xterm-256color'},stdin=slave,stdout=slave,stderr=slave)
    os.close(slave); output=b''; deadline=time.monotonic()+25
    branch=subprocess.check_output(['git','-C',str(project),'branch','--show-current'],text=True).strip()
    passed=False
    try:
        while process.poll() is None and time.monotonic()<deadline:
            if select.select([master],[],[],0.2)[0]:
                try: output+=os.read(master,65536)
                except OSError: break
                screen=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',output.decode(errors='replace'))
                if branch in screen and 'project' in screen and re.search(r'gpt-|GPT-',screen) and '%' in screen:
                    passed=True; break
    finally:
        try: os.write(master,b'\x03\x03')
        except OSError: pass
        try: process.wait(timeout=3)
        except subprocess.TimeoutExpired: process.terminate(); process.wait(timeout=3)
        os.close(master)
    if not passed: raise RuntimeError('Native TUI footer was not observed: '+output.decode(errors='replace')[-1800:])
    return 'model/reasoning, context percentage, Git branch and current directory observed in real PTY'


def run():
    for command in ('git', 'bd', 'codex'):
        if not shutil.which(command):
            raise RuntimeError(f'{command} is required')
    auth_home = os.environ.get('CODEX_HOME', str(Path.home()/'.codex'))
    with tempfile.TemporaryDirectory(prefix='codex-authenticated-smoke-') as tmp:
        root = Path(tmp); home = root/'home'; home.mkdir(); project = root/'project'
        env = {**os.environ, 'HOME':str(home), 'CODEX_HOME':str(home/'.codex'), 'CI':'1'}
        isolated_codex = home/'.codex'; isolated_codex.mkdir()
        existing_auth = Path(auth_home)/'auth.json'
        if not existing_auth.is_file():
            raise RuntimeError('Smoke requires existing file-backed Codex login; run codex login separately')
        # Read existing login through a temporary link, without copying secrets
        # or putting disposable session logs in the personal Codex directory.
        (isolated_codex/'auth.json').symlink_to(existing_auth)
        install = subprocess.run([str(KIT/'bootstrap'), str(project), '--prefix', 'SMOKE',
                                  '--local-core', '--non-interactive', '--pack', 'falcon',
                                  '--pack', 'herald', '--status-line', '--no-launch'],
                                 env=env, capture_output=True, text=True, timeout=90)
        if install.returncode:
            raise RuntimeError('Real Beads install failed: '+install.stdout+install.stderr)
        for args in (['config','user.name','Disposable Verification'],
                     ['config','user.email','verification@example.invalid'], ['add','.'],
                     ['commit','-qm','Disposable native smoke baseline']):
            subprocess.run(['git','-C',str(project),*args], env=env,check=True,capture_output=True)
        # Unique role proves project-local native TOML loading, not a personal role.
        role = project/'.codex/agents/bootstrap-smoke-reviewer.toml'
        role.write_text((KIT/'assets/global/.codex/agents/reviewer.toml').read_text().replace(
            'name = "reviewer"', 'name = "bootstrap-smoke-reviewer"', 1))
        schema = root/'report-schema.json'
        schema.write_text(json.dumps({'type':'object','additionalProperties':False,
            'properties':{'session_start':{'type':'boolean'},'native_agent_loaded':{'type':'boolean'},
                          'beads_read_only':{'type':'boolean'},'summary':{'type':'string'}},
            'required':['session_start','native_agent_loaded','beads_read_only','summary']}))
        prompt = ('$session-start\nDisposable integration verification only. Read context and run bd --readonly stats; '
                  'do not claim/update issues, edit files, commit, push or install anything. '
                  'Use no workers. Return session_start and beads_read_only truthfully; native_agent_loaded must be false '
                  'because the separate native config role smoke runs after this session.')
        # Config override is ephemeral project trust for this disposable test only;
        # no persistent trust record or hook consent is written.
        args = [shutil.which('codex'), 'exec', '--ignore-user-config',
                '--sandbox','workspace-write','-c','approval_policy="never"', '-c','features.hooks=false',
                '-c',f'projects.{json.dumps(str(project))}.trust_level="trusted"',
                '-C',str(project),'--json','--output-schema',str(schema),
                '--output-last-message',str(root/'report.json'),prompt]
        try:
            result = subprocess.run(args, env=env, stdin=subprocess.DEVNULL,
                                    capture_output=True,text=True,timeout=240)
        except subprocess.TimeoutExpired as error:
            raise RuntimeError('Authenticated session timed out; no production project was changed') from error
        if result.returncode:
            # Logs can include private model/config details; print only a bounded error tail.
            raise RuntimeError('Authenticated Codex failed: '+result.stderr[-2000:])
        report = json.loads((root/'report.json').read_text())
        review_prompt=root/'review-prompt.txt'
        review_prompt.write_text('Review AGENTS.md read-only. Return one sentence with a concrete finding or no findings. Do not edit or run Beads. Do not delegate.')
        reviewer=subprocess.run(['python3',str(project/'.agents/bootstrap/scripts/run-agent.py'),
                                 '--root',str(project),'--role','bootstrap-smoke-reviewer',
                                 '--prompt-file',str(review_prompt),'--read-only','--isolated'],
                                env=env,capture_output=True,text=True,timeout=120)
        if reviewer.returncode: raise RuntimeError('Native config role failed: '+reviewer.stderr[-1000:])
        if not reviewer.stdout.strip(): raise RuntimeError('Native reviewer returned no findings')
        report['native_agent_loaded']=True
        report['native_agent_loading_path']='parsed canonical TOML -> supported native exec config (role-selector compatibility)'
        report['reviewer_findings']=reviewer.stdout.strip()[-1500:]
        subprocess.run(['git','-C',str(project),'diff','--exit-code'],check=True,capture_output=True)
        report['native_footer_rendering']=footer_smoke(project,env)
        if not all(report[k] for k in ('session_start','native_agent_loaded','beads_read_only')):
            raise RuntimeError(f'Incomplete smoke evidence: {report}')
        print(json.dumps({'cli':subprocess.check_output(['codex','--version'],text=True).strip(),
                          'real_beads_install':'passed', 'authenticated_session':report},indent=2))


if __name__ == '__main__':
    run()
