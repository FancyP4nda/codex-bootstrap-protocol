#!/usr/bin/env python3
"""Native hooks, review permissions and Falcon lifecycle behavior."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from test_installer import CODEX_MOCK, KIT

FALCON=KIT/'assets/packs/falcon/scaffold/.agents/skills/falcon/scripts/falcon.py'
REVIEW=KIT/'assets/global/.agents/skills/adversarial-review/scripts/review.py'


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='codex-workflow-test-'); self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name); self.repo=self.root/'repo'; self.repo.mkdir()
        self.bin=self.root/'bin'; self.bin.mkdir()
        self.env={**os.environ,'PATH':str(self.bin)+os.pathsep+os.environ['PATH']}
        (self.bin/'codex').write_text(CODEX_MOCK); (self.bin/'codex').chmod(0o755)
        subprocess.run(['git','init','-q',str(self.repo)],check=True)
        subprocess.run(['git','-C',str(self.repo),'config','user.name','Verification'],check=True)
        subprocess.run(['git','-C',str(self.repo),'config','user.email','verification@example.invalid'],check=True)
        (self.repo/'.gitignore').write_text('.codex/state/tmp/\n')
        (self.repo/'README.md').write_text('Disposable verification repository\n')
        subprocess.run(['git','-C',str(self.repo),'add','.'],check=True)
        subprocess.run(['git','-C',str(self.repo),'commit','-qm','initial'],check=True)
        self.prompt=self.root/'prompt.txt'; self.prompt.write_text('Review and report scoped work.')

    def call(self,*args,ok=True,env=None):
        result=subprocess.run([sys.executable,str(FALCON),'--root',str(self.repo),*args],capture_output=True,
                              text=True,env=env or self.env,timeout=15)
        if ok: self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        else: self.assertNotEqual(result.returncode,0,result.stdout+result.stderr)
        return result

    def dispatch(self,*args):
        result=self.call('dispatch','--prompt-file',str(self.prompt),'--scope','src/module',*args)
        # --paste adds a text prompt after the JSON record.
        return json.JSONDecoder().raw_decode(result.stdout)[0]

    def wait_state(self,identifier,allowed):
        deadline=time.time()+10
        path=self.repo/'.codex/state/tmp/falcon'/f'{identifier}.json'
        while time.time()<deadline:
            value=json.loads(path.read_text())
            if value['status'] in allowed: return value
            time.sleep(0.05)
        self.fail(f'worker did not reach {allowed}: {value}')

    def test_dispatch_completion_amend_resume_release(self):
        record=self.dispatch()
        complete=self.wait_state(record['id'],['complete'])
        self.assertEqual(complete['session'],'thread-mock')
        self.assertIn('falcon/',complete['branch']); self.assertNotEqual(complete['worktree'],str(self.repo))
        self.assertTrue(Path(complete['report']).exists())
        self.call('amend',record['id'],'verify one additional edge case')
        self.call('resume',record['id'])
        self.wait_state(record['id'],['complete'])
        self.call('release',record['id'])
        self.assertEqual(self.wait_state(record['id'],['released'])['status'],'released')

    def test_scope_lock_and_paste(self):
        r=self.dispatch('--paste')
        self.assertEqual(r['status'],'prepared')
        self.call('dispatch','--prompt-file',str(self.prompt),'--scope','src/module/child','--paste',ok=False)
        self.call('paste',r['id'])
        self.call('release',r['id'])
        self.dispatch('--paste')

    def test_launch_failure_and_missing_resume_are_actionable(self):
        result=self.call('dispatch','--prompt-file',str(self.prompt),'--scope','src/module',env={**self.env,'MOCK_CODEX_FAIL':'1'})
        r=json.loads(result.stdout)
        self.assertEqual(self.wait_state(r['id'],['failed'])['exit_code'],7)
        self.call('resume','000000000000',ok=False)

    def test_cancel_running_worker_and_release(self):
        result=self.call('dispatch','--prompt-file',str(self.prompt),'--scope','src/module',env={**self.env,'MOCK_WORKER_DELAY':'3'})
        r=json.loads(result.stdout); self.wait_state(r['id'],['running'])
        self.call('release',r['id'],ok=False)
        self.call('cancel',r['id'])
        time.sleep(0.15)
        self.call('release',r['id'])

    def test_stale_process_record_recovery(self):
        r=self.dispatch('--paste')
        p=self.repo/'.codex/state/tmp/falcon'/f'{r["id"]}.json'
        r.update(status='running',pid=99999999,birth='wrong'); p.write_text(json.dumps(r))
        data=json.loads(self.call('status').stdout)
        self.assertEqual(data[0]['status'],'interrupted')
        self.call('resume',r['id'],ok=False)

    def test_monitor_start_status_stop_and_restart(self):
        self.call('monitor','start','--interval','0.1')
        self.addCleanup(lambda:self.call('monitor','stop'))
        state=json.loads(self.call('monitor','status').stdout); self.assertTrue(state['running'])
        self.call('monitor','start')
        self.call('monitor','stop'); time.sleep(0.1)
        self.assertFalse(json.loads(self.call('monitor','status').stdout)['running'])
        self.call('monitor','start','--interval','0.1')
        self.assertTrue(json.loads(self.call('monitor','status').stdout)['running'])

    def test_scope_traversal_and_state_symlink_rejected(self):
        self.call('dispatch','--prompt-file',str(self.prompt),'--scope','../escape',ok=False)
        # State was created for the invalid dispatch but never through a symlink.
        outside=self.root/'outside'; outside.mkdir()
        for p in (self.repo/'.codex/state/tmp/falcon').iterdir():
            if p.is_file(): p.unlink()
        (self.repo/'.codex/state/tmp/falcon').rmdir()
        (self.repo/'.codex/state/tmp/falcon').symlink_to(outside,target_is_directory=True)
        self.call('status',ok=False)

    def test_codex_review_fallback_has_read_only_and_hooks_disabled(self):
        (self.bin/'codex').write_text('''#!/usr/bin/env python3
import json,sys
assert '--sandbox' in sys.argv and sys.argv[sys.argv.index('--sandbox')+1]=='read-only'
assert 'features.hooks=false' in sys.argv
assert '--ephemeral' in sys.argv and '--ignore-user-config' in sys.argv
print('VERDICT: REVISE')
''')
        result=subprocess.run([sys.executable,str(REVIEW),str(self.prompt),'--provider','codex'],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('same-provider',json.loads(result.stdout)['label'])

    def test_claude_review_is_tool_restricted(self):
        p=self.bin/'claude'; p.write_text('''#!/usr/bin/env python3
import sys
assert sys.argv[sys.argv.index('--tools')+1]=='Read,Grep,Glob'
assert sys.argv[sys.argv.index('--allowedTools')+1]=='Read,Grep,Glob'
assert sys.argv[sys.argv.index('--permission-mode')+1]=='plan'
print('VERDICT: APPROVED')
'''); p.chmod(0o755)
        result=subprocess.run([sys.executable,str(REVIEW),str(self.prompt),'--provider','claude'],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(json.loads(result.stdout)['provider'],'claude')

    def test_hook_compaction_and_plain_repo_payload(self):
        p=KIT/'assets/native/session-context.py'
        for source in ('startup','resume','compact'):
            result=subprocess.run([sys.executable,str(p)],input=json.dumps({'hook_event_name':'SessionStart','source':source,'cwd':str(self.repo)}),
                                  capture_output=True,text=True,check=True)
            payload=json.loads(result.stdout)['hookSpecificOutput']
            self.assertEqual(payload['hookEventName'],'SessionStart')
            self.assertIn('No Beads workspace',payload['additionalContext'])
        result=subprocess.run([sys.executable,str(p)],input='bad-json',capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)


if __name__=='__main__': unittest.main()
