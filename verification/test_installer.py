#!/usr/bin/env python3
"""Behavioral installer checks in disposable homes, repos and mocked CLIs."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import tempfile
import time
import tomllib
import unittest

KIT = Path(__file__).resolve().parents[1]

BD_MOCK = '''#!/usr/bin/env python3
import json,os,pathlib,sys
if '--version' in sys.argv: print('bd mock'); sys.exit(0)
if 'stats' in sys.argv: sys.exit(int(os.environ.get('MOCK_STATS_FAIL','0')))
if 'init' in sys.argv:
 if os.environ.get('MOCK_BD_FAIL'): sys.exit(8)
 assert '--skip-agents' in sys.argv
 p=pathlib.Path('.beads'); p.mkdir(exist_ok=True)
 (p/'metadata.json').write_text('{}')
 (p/'init-args.txt').write_text(' '.join(sys.argv))
sys.exit(0)
'''
CODEX_MOCK = '''#!/usr/bin/env python3
import json,os,pathlib,sys,time
if '--version' in sys.argv: print('codex-cli 0.159.2'); sys.exit(0)
if 'login' in sys.argv: sys.exit(0)
if '--output-last-message' in sys.argv:
 p=pathlib.Path(sys.argv[sys.argv.index('--output-last-message')+1])
 time.sleep(float(os.environ.get('MOCK_WORKER_DELAY','0')))
 print(json.dumps({'type':'thread.started','thread_id':'thread-mock'}),flush=True)
 if os.environ.get('MOCK_CODEX_FAIL'): sys.exit(7)
 p.write_text(json.dumps({'summary':'mock scoped result','changed_files':[],'tests':['mock verification'],'risks':[]}))
else: print('mock codex')
'''


def snapshot(root):
    return {str(p.relative_to(root)): ('link:'+os.readlink(p) if p.is_symlink() else hashlib.sha256(p.read_bytes()).hexdigest())
            for p in root.rglob('*') if p.is_file() or p.is_symlink()}


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='codex-installer-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root/'home'; self.home.mkdir()
        self.target = self.root/'project with spaces'
        self.bin = self.root/'bin'; self.bin.mkdir()
        self.env = {**os.environ, 'HOME':str(self.home), 'CODEX_HOME':str(self.home/'custom codex'),
                    'PATH':str(self.bin)+os.pathsep+os.environ['PATH'], 'CI':'1', 'SHELL':'/bin/bash'}
        for name, text in [('bd', BD_MOCK), ('codex', CODEX_MOCK)]:
            p=self.bin/name; p.write_text(text); p.chmod(0o755)

    def run_bootstrap(self, *flags, ok=True, kit=KIT, env=None):
        result = subprocess.run([str(kit/'bootstrap'), *map(str, flags)], capture_output=True, text=True,
                                env=env or self.env, timeout=90)
        if ok: self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        else: self.assertNotEqual(result.returncode, 0, result.stdout+result.stderr)
        return result

    def install(self, *flags, **kwargs):
        return self.run_bootstrap(self.target, '--prefix', 'PWS', '--non-interactive', '--no-launch', *flags, **kwargs)

    def kit_copy(self):
        dest=self.root/'relocated kit with spaces'
        shutil.copytree(KIT,dest,ignore=shutil.ignore_patterns('.git','.beads','__pycache__','.codex/state'))
        return dest

    def test_dry_run_is_immutable(self):
        before=snapshot(self.home)
        self.install('--dry-run', '--hooks', '--status-line', '--promote-global')
        self.assertEqual(snapshot(self.home),before); self.assertFalse(self.target.exists())

    def test_fresh_global_default_and_repeat(self):
        self.install()
        self.assertTrue((self.home/'.agents/skills/session-start/SKILL.md').exists())
        self.assertTrue((self.home/'custom codex/agents/navigator-recon.toml').exists())
        self.assertFalse((self.target/'.agents/skills/session-start').exists())
        self.assertIn('--skip-agents',(self.target/'.beads/init-args.txt').read_text())
        stamp=json.loads((self.target/'.codex/bootstrap.json').read_text())
        self.assertIn('.codex/config.toml',stamp['managed'])
        self.run_bootstrap(self.target,'--non-interactive')

    def test_local_core_is_self_contained(self):
        self.install('--local-core')
        self.assertTrue((self.target/'.agents/skills/session-start/SKILL.md').exists())
        self.assertTrue((self.target/'.codex/agents/reviewer.toml').exists())
        self.assertFalse((self.home/'.agents').exists())

    def test_retrofit_preserves_history_and_claude(self):
        self.target.mkdir()
        files={'AGENTS.md':'# Personal\nKeep me.\n','.gitignore':'local-private/\n','CLAUDE.md':'Claude user instructions',
               'docs/prd.md':'Approved product history', '.env':'secret-placeholder'}
        for rel,text in files.items():
            p=self.target/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(text)
        self.install()
        self.assertTrue((self.target/'AGENTS.md').read_text().startswith(files['AGENTS.md']))
        for rel in ('CLAUDE.md','docs/prd.md','.env'): self.assertEqual((self.target/rel).read_text(),files[rel])
        self.assertIn('local-private/',(self.target/'.gitignore').read_text())
        self.assertFalse((self.target/'.git').exists(), 'retrofit must not initialize unrelated Git')

    def test_existing_beads_failure_before_global_writes(self):
        (self.target/'.beads').mkdir(parents=True)
        env={**self.env,'MOCK_STATS_FAIL':'1'}
        self.install(ok=False,env=env)
        self.assertFalse((self.home/'.agents').exists())

    def test_beads_initialization_failure_before_payload(self):
        self.install(ok=False,env={**self.env,'MOCK_BD_FAIL':'1'})
        self.assertFalse((self.home/'.agents').exists())
        self.assertFalse((self.target/'AGENTS.md').exists())

    def test_missing_prerequisite_before_writes(self):
        tools=self.root/'limited'; tools.mkdir()
        for name in ('bash','python3','git','date','dirname','readlink','mktemp','rm'):
            command=shutil.which(name)
            if command: (tools/name).symlink_to(command)
        self.install(ok=False,env={**self.env,'PATH':str(tools)})
        self.assertFalse(self.target.exists()); self.assertFalse((self.home/'.agents').exists())

    def test_conflict_is_all_or_nothing_and_force_backs_up(self):
        p=self.target/'.agents/templates/work-item.md'; p.parent.mkdir(parents=True); p.write_text('owned content')
        self.install(ok=False)
        self.assertFalse((self.home/'.agents').exists()); self.assertFalse((self.target/'AGENTS.md').exists())
        self.install('--force')
        self.assertEqual(next((self.target/'bootstrap-backups').rglob('work-item.md')).read_text(),'owned content')

    def test_structural_conflict_force_cannot_bypass(self):
        self.target.mkdir(); (self.target/'.agents').write_text('a file')
        self.install('--force',ok=False); self.assertFalse((self.home/'.agents').exists())

    def test_symlink_ancestor_and_leaf_are_rejected(self):
        self.target.mkdir(); outside=self.root/'outside'; outside.mkdir()
        (self.target/'.agents').symlink_to(outside,target_is_directory=True)
        self.install('--force',ok=False); self.assertEqual(list(outside.iterdir()),[])
        self.assertFalse((self.home/'.agents').exists())

    def test_global_symlink_preflight_blocks_project(self):
        outside=self.root/'outside'; outside.mkdir()
        (self.home/'.agents').symlink_to(outside,target_is_directory=True)
        self.install(ok=False); self.assertFalse(self.target.exists())

    def test_global_updates_preserve_extras_and_backup(self):
        self.run_bootstrap('--global-only')
        skill=self.home/'.agents/skills/tdd'
        (skill/'SKILL.md').write_text('custom local skill')
        (skill/'personal.txt').write_text('extra')
        self.run_bootstrap('--global-only')
        self.assertEqual((skill/'SKILL.md').read_text(),'custom local skill')
        self.run_bootstrap('--global-only','--update-global')
        self.assertEqual((skill/'personal.txt').read_text(),'extra')
        self.assertEqual(next((self.home/'.agents/bootstrap-backups').rglob('tdd/SKILL.md')).read_text(),'custom local skill')

    def test_obsolete_hash_policy(self):
        self.run_bootstrap('--global-only')
        base=self.home/'.agents'; stamp=base/'bootstrap/managed.json'; data=json.loads(stamp.read_text())
        for name in ('old-unchanged','old-modified'):
            p=base/name; p.write_text('old'); data['managed'][name]=hashlib.sha256(b'old').hexdigest()
        (base/'old-modified').write_text('my edits'); stamp.write_text(json.dumps(data))
        self.run_bootstrap('--global-only','--update-global')
        self.assertFalse((base/'old-unchanged').exists()); self.assertEqual((base/'old-modified').read_text(),'my edits')

    def test_malformed_stamp_traversal_is_rejected(self):
        p=self.home/'.agents/bootstrap/managed.json'; p.parent.mkdir(parents=True)
        p.write_text(json.dumps({'format':1,'managed':{'../outside':'0'*64}}))
        self.install(ok=False); self.assertFalse(self.target.exists())

    def test_configuration_preservation(self):
        p=self.target/'.codex/config.toml'; p.parent.mkdir(parents=True)
        p.write_text('# personal comment\nmodel = "my-model"\n[tui]\n# keep UI\nstatus_line = ["current-dir"] # footer\nanimations = false\n')
        self.install('--status-line','--notifications','--docs-mcp')
        text=p.read_text(); parsed=tomllib.loads(text)
        self.assertEqual(parsed['model'],'my-model'); self.assertFalse(parsed['tui']['animations'])
        self.assertIn('# personal comment',text); self.assertIn('# keep UI',text); self.assertIn('# footer',text)
        self.assertEqual(parsed['tui']['status_line'],['model-with-reasoning','context-remaining','git-branch','current-dir'])

    def test_invalid_toml_preflight(self):
        p=self.target/'.codex/config.toml'; p.parent.mkdir(parents=True); p.write_text('[broken')
        self.install('--status-line',ok=False); self.assertFalse((self.home/'.agents').exists())

    def test_hooks_preserve_existing_and_never_trust(self):
        p=self.target/'.codex/hooks.json'; p.parent.mkdir(parents=True)
        existing={'hooks':{'SessionStart':[{'matcher':'startup','hooks':[{'type':'command','command':'echo personal'}]}]}}
        p.write_text(json.dumps(existing))
        self.install('--hooks'); self.install('--hooks')
        hooks=json.loads(p.read_text())['hooks']['SessionStart']
        self.assertEqual(len(hooks),2); self.assertEqual(hooks[0],existing['hooks']['SessionStart'][0])
        self.assertFalse(any('trust' in x.name for x in self.home.rglob('*')))
        command=hooks[1]['hooks'][0]['command']
        event={'hook_event_name':'SessionStart','cwd':str(self.target),'source':'compact'}
        result=subprocess.run(command,shell=True,input=json.dumps(event),capture_output=True,text=True,env=self.env)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('additionalContext',json.loads(result.stdout)['hookSpecificOutput'])

    def test_inline_hooks_conflict_before_writes(self):
        p=self.target/'.codex/config.toml'; p.parent.mkdir(parents=True)
        p.write_text('[[hooks.SessionStart]]\nmatcher="startup"\n[[hooks.SessionStart.hooks]]\ntype="command"\ncommand="echo own"\n')
        self.install('--hooks',ok=False); self.assertFalse((self.home/'.agents').exists())

    def test_global_hooks_avoid_duplicate_project_execution(self):
        self.run_bootstrap('--global-only','--hooks')
        self.install('--hooks')
        self.assertFalse((self.target/'.codex/hooks.json').exists())

    def test_each_pack_and_all_packs(self):
        for packs in [('falcon',),('herald',),('web-design',),('falcon','herald','web-design')]:
            with self.subTest(packs=packs):
                self.target=self.root/('-'.join(packs))
                flags=['--allow-unverified-pack']
                for pack in packs: flags+=['--pack',pack]
                self.install(*flags)
                self.assertEqual(json.loads((self.target/'.codex/bootstrap.json').read_text())['packs'],list(packs))

    def test_unverified_pack_requires_explicit_opt_in(self):
        self.install('--pack','web-design',ok=False)
        self.assertFalse(self.target.exists()); self.assertFalse((self.home/'.agents').exists())

    def test_pack_conflict_force_cannot_bypass(self):
        p=self.target/'.agents/skills/herald/SKILL.md'; p.parent.mkdir(parents=True); p.write_text('custom herald')
        self.install('--pack','herald','--force',ok=False); self.assertFalse((self.home/'.agents').exists())

    def test_repeated_install_retains_previously_installed_pack_metadata(self):
        self.install('--pack','herald')
        self.run_bootstrap(self.target,'--non-interactive')
        self.assertEqual(json.loads((self.target/'.codex/bootstrap.json').read_text())['packs'],['herald'])

    def test_invalid_manifest_and_cross_pack_collision(self):
        kit=self.kit_copy(); manifest=kit/'assets/packs/falcon/manifest.txt'
        for line in ('file\t../escape\tcopy\tbad\n','file\t.git/config\tcopy\tbad\n','file\tAGENTS.md\tcopy\tcollision\n'):
            if 'AGENTS' in line: (kit/'assets/packs/falcon/scaffold/AGENTS.md').write_text('collision')
            manifest.write_text(line)
            self.install('--pack','falcon',kit=kit,ok=False)
            self.assertFalse(self.target.exists()); self.assertFalse((self.home/'.agents').exists())

    def test_relocation_and_command_setup_uninstall(self):
        kit=self.kit_copy()
        self.run_bootstrap('--install-command','--update-path',kit=kit)
        command=self.home/'.local/bin/codex-bootstrap'; self.assertTrue(command.is_symlink())
        self.run_bootstrap('--install-command','--update-path',kit=kit)
        self.assertEqual((self.home/'.bashrc').read_text().count('# BEGIN CODEX BOOTSTRAP PATH'),1)
        result=subprocess.run([str(command),'--dry-run',str(self.target),'--prefix','P'],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.run_bootstrap('--uninstall-command','--update-path',kit=kit)
        self.assertFalse(command.exists()); self.assertNotIn('CODEX BOOTSTRAP PATH',(self.home/'.bashrc').read_text())

    def test_command_collision_and_dry_run(self):
        p=self.home/'.local/bin/codex-bootstrap'; p.parent.mkdir(parents=True); p.write_text('user command')
        self.run_bootstrap('--install-command',ok=False); self.assertEqual(p.read_text(),'user command')

    def test_shadowed_command_preflight_does_not_edit_profile(self):
        command=self.bin/'codex-bootstrap'; command.write_text('#!/bin/sh\nexit 0\n'); command.chmod(0o755)
        self.run_bootstrap('--install-command','--update-path',ok=False)
        self.assertFalse((self.home/'.local/bin/codex-bootstrap').exists())
        self.assertFalse((self.home/'.bashrc').exists())

    def test_non_tty_never_prompts(self):
        self.run_bootstrap('--interactive',ok=False)
        self.run_bootstrap('--non-interactive',ok=False)
        self.assertFalse((self.home/'.agents').exists())

    def test_wizard_decline_is_write_free(self):
        master, slave=pty.openpty()
        env={**self.env,'CI':''}
        proc=subprocess.Popen([str(KIT/'bootstrap'),'--interactive'],stdin=slave,stdout=slave,stderr=slave,env=env)
        os.close(slave)
        # update=no, target, prefix, packs x3=no, personal settings x5=no, apply=no
        os.write(master, ('n\n'+str(self.target)+'\nP\n'+'n\n'*9).encode())
        output=b''; deadline=time.time()+60
        while proc.poll() is None and time.time()<deadline:
            if select.select([master],[],[],0.2)[0]:
                try: output+=os.read(master,65536)
                except OSError: break
        if proc.poll() is None: proc.kill()
        proc.wait(); os.close(master)
        self.assertEqual(proc.returncode,0,output.decode(errors='replace'))
        self.assertFalse(self.target.exists()); self.assertFalse((self.home/'.agents').exists())

    def test_obsolete_modified_after_preview_is_preserved(self):
        self.install()
        obsolete=self.home/'.agents/skills/session-start/old-guide.md'; obsolete.write_text('old managed')
        stamp=self.home/'.agents/bootstrap/managed.json'; data=json.loads(stamp.read_text())
        data['managed']['skills/session-start/old-guide.md']=hashlib.sha256(obsolete.read_bytes()).hexdigest()
        stamp.write_text(json.dumps(data))
        master,slave=pty.openpty()
        proc=subprocess.Popen([str(KIT/'bootstrap'),str(self.target),'--interactive','--no-launch'],
                              stdin=slave,stdout=slave,stderr=slave,env={**self.env,'CI':''})
        os.close(slave); os.write(master,('y\n\n'+'n\n'*8).encode())
        output=b''; deadline=time.time()+60; changed=False
        try:
            while proc.poll() is None and time.time()<deadline:
                if select.select([master],[],[],0.2)[0]:
                    try: output+=os.read(master,65536)
                    except OSError: break
                    if not changed and b'Apply this combined project/global plan?' in output:
                        obsolete.write_text('user changed during confirmation')
                        changed=True; os.write(master,b'y\n')
            if proc.poll() is None: proc.kill()
            proc.wait()
        finally: os.close(master)
        self.assertTrue(changed,output.decode(errors='replace'))
        self.assertEqual(proc.returncode,0,output.decode(errors='replace'))
        self.assertEqual(obsolete.read_text(),'user changed during confirmation')


if __name__=='__main__': unittest.main()
