"""Opt-in vendored native helpers retain configuration and require trust."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from test_installer import KIT


@unittest.skipUnless(shutil.which('node'), 'Node is required for web helper checks')
class WebHelperTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='codex-web-helpers-'); self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.skill=self.root/'.agents/skills/impeccable'
        shutil.copytree(KIT/'assets/packs/web-design/scaffold/.agents/skills/impeccable',self.skill)
        subprocess.run(['git','init','-q',str(self.root)],check=True)

    def admin(self,*args,ok=True):
        result=subprocess.run(['node',str(self.skill/'scripts/hook-admin.mjs'),*args],
                              cwd=self.root,capture_output=True,text=True,timeout=15)
        self.assertEqual(result.returncode==0,ok,result.stdout+result.stderr)
        return result

    def test_native_hook_merge_backup_repeat_without_trust(self):
        path=self.root/'.codex/hooks.json'; path.parent.mkdir()
        original={'hooks':{'SessionStart':[{'hooks':[{'type':'command','command':'echo user'}]}]},'user':'keep'}
        path.write_text(json.dumps(original))
        self.admin('on'); data=json.loads(path.read_text())
        self.assertEqual(data['user'],'keep'); self.assertEqual(data['hooks']['SessionStart'],original['hooks']['SessionStart'])
        self.assertIn('PostToolUse',data['hooks']); self.assertIn('Stop',data['hooks'])
        self.assertTrue(list(path.parent.glob('hooks.json.bootstrap-backup-*')))
        first=path.read_text(); self.admin('on'); self.assertEqual(first,path.read_text())
        self.assertFalse((path.parent/'hooks-trust.json').exists())
        self.assertFalse((self.root/'.claude').exists())

    def test_inline_hook_conflict_is_write_free(self):
        path=self.root/'.codex/config.toml'; path.parent.mkdir(); path.write_text('[hooks]\n')
        self.admin('on',ok=False)
        self.assertFalse((self.root/'.impeccable/config.json').exists())
        self.assertFalse((path.parent/'hooks.json').exists())

    def test_malformed_hook_json_preserved(self):
        path=self.root/'.codex/hooks.json'; path.parent.mkdir(); path.write_text('{bad')
        self.admin('on',ok=False); self.assertEqual(path.read_text(),'{bad')
        self.assertFalse((self.root/'.impeccable/config.json').exists())

    def test_symlink_destination_rejected(self):
        outside=self.root/'outside'; outside.mkdir(); (self.root/'.codex').symlink_to(outside)
        self.admin('on',ok=False); self.assertFalse(list(outside.iterdir()))

    def test_ignore_update_retains_user_config_and_backup(self):
        path=self.root/'.impeccable/config.json'; path.parent.mkdir(); path.write_text('{"personal":"keep"}')
        self.admin('ignore-file','src/generated/**')
        data=json.loads(path.read_text()); self.assertEqual(data['personal'],'keep')
        self.assertIn('src/generated/**',data['detector']['ignoreFiles'])
        self.assertTrue(list(path.parent.glob('config.json.bootstrap-backup-*')))

    def test_generated_filename_does_not_execute_shell(self):
        malicious='$(touch injected).css'; (self.root/malicious).write_text('body {}')
        script=self.skill/'scripts/lib/is-generated.mjs'
        code=f'import {{isGeneratedFile}} from {json.dumps(script.as_uri())}; isGeneratedFile(process.argv[1]);'
        subprocess.run(['node','--input-type=module','-e',code,malicious],cwd=self.root,check=True)
        self.assertFalse((self.root/'injected').exists())


if __name__=='__main__': unittest.main()
