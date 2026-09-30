"""Canonical native role loading with mock CLI, enforced config flags and TOML."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest
from test_installer import KIT


class NativeAgentTests(unittest.TestCase):
    def test_all_ten_roles_load_native_config_without_model_pins(self):
        with tempfile.TemporaryDirectory(prefix='codex-role-test-') as tmp:
            root=Path(tmp); bin=root/'bin'; bin.mkdir()
            codex=bin/'codex'; codex.write_text('#!/bin/sh\nexit 0\n'); codex.chmod(0o755)
            target=root/'project'; agents=target/'.codex/agents'; agents.mkdir(parents=True)
            prompt=root/'prompt'; prompt.write_text('Bounded read-only verification')
            helper=KIT/'assets/global/.agents/bootstrap/scripts/run-agent.py'
            roles=[p for p in (KIT/'assets').rglob('*.toml') if '/agents/' in str(p)]
            self.assertEqual(len(roles),10)
            for role in roles:
                shutil.copy2(role,agents/role.name)
                result=subprocess.run(['python3',str(helper),'--root',str(target),'--role',role.stem,
                                       '--prompt-file',str(prompt),'--dry-run'],capture_output=True,text=True,
                                      env={**os.environ,'PATH':str(bin)+os.pathsep+os.environ['PATH']})
                self.assertEqual(result.returncode,0,result.stderr)
                argv=json.loads(result.stdout)['command']
                self.assertNotIn('--model',argv)
                self.assertIn('approval_policy="never"',argv)
                role_data=tomllib.loads(role.read_text())
                flags=[tomllib.loads(argv[i+1]) for i,x in enumerate(argv) if x=='-c']
                instructions=next(v['developer_instructions'] for v in flags if 'developer_instructions' in v)
                self.assertEqual(instructions,role_data['developer_instructions'])
                self.assertEqual(argv[argv.index('--sandbox')+1],role_data.get('sandbox_mode','read-only'))

    def test_unsafe_role_and_traversal_refused(self):
        with tempfile.TemporaryDirectory(prefix='codex-role-invalid-') as tmp:
            root=Path(tmp); agents=root/'.codex/agents'; agents.mkdir(parents=True)
            prompt=root/'prompt'; prompt.write_text('Review')
            (agents/'bad.toml').write_text('name="bad"\ndescription="bad"\ndeveloper_instructions="bad"\nsandbox_mode="danger-full-access"\n')
            for role in ('bad','../escape'):
                result=subprocess.run(['python3',str(KIT/'assets/global/.agents/bootstrap/scripts/run-agent.py'),
                                       '--root',str(root),'--role',role,'--prompt-file',str(prompt),'--dry-run'],
                                      capture_output=True,text=True)
                self.assertNotEqual(result.returncode,0)


if __name__=='__main__': unittest.main()
