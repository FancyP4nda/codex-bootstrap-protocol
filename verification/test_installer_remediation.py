#!/usr/bin/env python3
"""F01/F04/F14 lifecycle regressions; every installation uses disposable homes.

Run the real shell matrix with BOOTSTRAP_TEST_BASH32 pointing at a separately
built GNU Bash 3.2 binary. Missing that explicit fixture is a skipped platform
gate, never evidence that Bash 3.2 passed.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import unittest

import test_installer as fixtures

KIT = fixtures.KIT
snapshot = fixtures.snapshot


class InstallerRemediationTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.InstallerTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.home = self.fixture.home
        self.target = self.fixture.target
        self.codex = Path(self.fixture.env['CODEX_HOME'])

    def bootstrap(self, *args, ok=True):
        return self.fixture.run_bootstrap(*args, ok=ok)

    def personal_configuration(self):
        self.codex.mkdir(parents=True, exist_ok=True)
        (self.codex/'config.toml').write_text('# Personal comment\nmodel = "personal-model"\n[tui]\nanimations = false\n')
        own = {'hooks': {'SessionStart': [{'matcher': 'startup', 'hooks': [
            {'type': 'command', 'command': 'echo personal handler'}]}]}}
        (self.codex/'hooks.json').write_text(json.dumps(own))
        self.bootstrap('--global-only', '--hooks', '--status-line', '--notifications', '--docs-mcp')

    def test_global_core_update_retains_opt_ins_and_unrelated_configuration(self):
        self.personal_configuration()
        files = ['config.toml', 'hooks.json', 'hooks/session-context.py']
        before = {rel: (self.codex/rel).read_bytes() for rel in files}
        self.bootstrap('--global-only', '--update-global')
        self.bootstrap('--global-only', '--update-global')
        for rel, data in before.items():
            self.assertTrue((self.codex/rel).exists(), f'core update removed optional {rel}')
            self.assertEqual((self.codex/rel).read_bytes(), data)
        stamp = json.loads((self.codex/'bootstrap-managed.json').read_text())
        self.assertFalse({'config.toml', 'hooks.json'} & set(stamp['managed']))
        self.assertEqual(set(stamp['configuration_options']), {'hooks', 'status-line', 'notifications', 'docs-mcp'})

    def test_project_triggered_update_keeps_global_hook_deduplication(self):
        self.personal_configuration()
        self.fixture.install('--hooks', '--update-global')
        self.assertTrue((self.codex/'hooks.json').exists())
        self.assertTrue((self.codex/'hooks/session-context.py').exists())
        self.assertFalse((self.target/'.codex/hooks.json').exists(), 'must not create duplicate project orientation')
        self.assertIn('personal-model', (self.codex/'config.toml').read_text())

    def test_modified_config_and_hooks_are_preserved_without_reapplying_options(self):
        self.personal_configuration()
        config = self.codex/'config.toml'
        config.write_text(config.read_text().replace('personal-model', 'my-new-model').replace('"context-remaining"', '"context-used"'))
        hooks = self.codex/'hooks.json'
        data = json.loads(hooks.read_text()); data['hooks']['Stop'] = []
        hooks.write_text(json.dumps(data))
        before = (config.read_bytes(), hooks.read_bytes())
        self.bootstrap('--global-only', '--update-global')
        self.assertEqual((config.read_bytes(), hooks.read_bytes()), before)
        self.assertTrue((self.codex/'hooks/session-context.py').exists())

    def test_buggy_release_metadata_is_migrated_conservatively(self):
        self.personal_configuration()
        path = self.codex/'bootstrap-managed.json'; stamp = json.loads(path.read_text())
        for category in ('configuration', 'optional_managed'):
            stamp['managed'].update(stamp.pop(category, {}))
        stamp.pop('configuration_options', None)
        for rel in ('config.toml', 'hooks.json', 'hooks/session-context.py'):
            stamp['managed'][rel] = hashlib.sha256((self.codex/rel).read_bytes()).hexdigest()
        path.write_text(json.dumps(stamp))
        self.bootstrap('--global-only', '--update-global')
        self.assertTrue((self.codex/'config.toml').exists())
        self.assertTrue((self.codex/'hooks.json').exists())
        self.assertTrue((self.codex/'hooks/session-context.py').exists())
        stamp = json.loads(path.read_text())
        self.assertNotIn('config.toml', stamp['managed'])
        self.assertIn('config.toml', stamp['configuration'])

    def test_real_obsolete_core_retirement_still_uses_hash_and_backups(self):
        self.personal_configuration()
        base = self.home/'.agents'; stamp_path = base/'bootstrap/managed.json'
        stamp = json.loads(stamp_path.read_text())
        for name in ('removed-core', 'modified-removed-core'):
            (base/name).write_text('old owned core')
            stamp['managed'][name] = hashlib.sha256(b'old owned core').hexdigest()
        (base/'modified-removed-core').write_text('user modification')
        stamp_path.write_text(json.dumps(stamp))
        self.bootstrap('--global-only', '--update-global')
        self.assertFalse((base/'removed-core').exists())
        self.assertEqual((base/'modified-removed-core').read_text(), 'user modification')
        self.assertEqual(next((base/'bootstrap-backups').rglob('removed-core')).read_text(), 'old owned core')
        self.assertTrue((self.codex/'config.toml').exists())

    def test_owned_optional_helper_updates_without_reapplying_user_configuration(self):
        self.personal_configuration()
        before = (self.codex/'config.toml').read_bytes()
        kit = self.fixture.kit_copy()
        source = kit/'assets/native/session-context.py'
        source.write_text(source.read_text()+'\n# Updated owned helper implementation.\n')
        self.fixture.run_bootstrap('--global-only', '--update-global', kit=kit)
        self.assertEqual((self.codex/'hooks/session-context.py').read_bytes(), source.read_bytes())
        self.assertEqual((self.codex/'config.toml').read_bytes(), before)

    def test_local_core_explicit_personal_promotion_records_optional_ownership(self):
        self.fixture.install('--local-core', '--promote-global', '--hooks', '--status-line')
        self.assertFalse((self.home/'.agents').exists())
        stamp = json.loads((self.codex/'bootstrap-managed.json').read_text())
        self.assertIn('config.toml', stamp['configuration'])
        self.assertIn('hooks/session-context.py', stamp['optional_managed'])
        self.assertNotIn('config.toml', stamp['managed'])

    def test_project_only_options_are_not_recorded_as_global_opt_ins(self):
        self.fixture.install('--status-line', '--notifications', '--hooks', '--docs-mcp')
        global_stamp = json.loads((self.codex/'bootstrap-managed.json').read_text())
        self.assertEqual(global_stamp['configuration_options'], [])
        project_stamp = json.loads((self.target/'.codex/bootstrap.json').read_text())
        self.assertEqual(set(project_stamp['configuration_options']),
                         {'status-line', 'notifications', 'hooks', 'docs-mcp'})
        self.assertFalse((self.codex/'config.toml').exists())

    def test_merged_private_configurations_keep_existing_permissions(self):
        for root in (self.codex, self.target/'.codex'):
            root.mkdir(parents=True, exist_ok=True)
            (root/'config.toml').write_text('model = "personal-model"\n')
            (root/'hooks.json').write_text('{"hooks": {}}\n')
            for name in ('config.toml', 'hooks.json'):
                (root/name).chmod(0o600)
        self.bootstrap('--global-only', '--status-line', '--hooks')
        self.fixture.install('--status-line')
        # Global orientation deduplication deliberately avoids project hooks;
        # use a separate fresh fixture to exercise a project hook merge.
        for root in (self.codex, self.target/'.codex'):
            for name in ('config.toml', 'hooks.json'):
                self.assertEqual((root/name).stat().st_mode & 0o777, 0o600)
        other = fixtures.InstallerTests(); other.setUp(); self.addCleanup(other.doCleanups)
        hook = other.target/'.codex/hooks.json'
        hook.parent.mkdir(parents=True); hook.write_text('{"hooks": {}}\n'); hook.chmod(0o600)
        other.install('--hooks')
        self.assertEqual(hook.stat().st_mode & 0o777, 0o600)

    def test_merged_private_shell_profile_keeps_existing_permissions(self):
        profile = self.home/'.bashrc'
        profile.write_text('# Private shell setup\n'); profile.chmod(0o600)
        self.bootstrap('--install-command', '--update-path')
        self.assertEqual(profile.stat().st_mode & 0o777, 0o600)
        self.bootstrap('--uninstall-command', '--update-path')
        self.assertEqual(profile.stat().st_mode & 0o777, 0o600)

    def test_global_only_doctor_does_not_require_optional_beads(self):
        self.bootstrap('--global-only')
        limited = self.fixture.root/'global-only-tools'; limited.mkdir()
        for name in ('bash', 'python3', 'git', 'codex', 'dirname', 'readlink', 'date'):
            resolved = shutil.which(name, path=self.fixture.env['PATH'])
            self.assertIsNotNone(resolved, name)
            (limited/name).symlink_to(resolved)
        result = self.fixture.run_bootstrap('--doctor', '--global-only',
                    env={**self.fixture.env, 'PATH':str(limited)})
        self.assertIn('Beads not required', result.stdout)

    def test_global_only_doctor_does_not_validate_unrelated_project_state(self):
        self.bootstrap('--global-only')
        project_codex = self.target/'.codex'
        project_codex.mkdir(parents=True)
        (project_codex/'config.toml').write_text('[invalid project config')
        (project_codex/'hooks.json').write_text('invalid project hooks')
        (project_codex/'bootstrap.json').write_text('invalid project metadata')
        result = subprocess.run([str(KIT/'bootstrap'), '--doctor', '--global-only'],
                    cwd=self.target, env=self.fixture.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertIn('Health scope: global core', result.stdout)

    def test_doctor_missing_global_core_fails_with_actionable_diagnostics(self):
        result = self.bootstrap('--doctor', ok=False)
        self.assertIn('missing', result.stdout)
        self.assertIn('--global-only', result.stdout)
        self.assertFalse((self.home/'.agents').exists())

    def test_doctor_local_core_uses_project_assets_without_global_installation(self):
        self.fixture.install('--local-core')
        before = snapshot(self.home)
        result = self.bootstrap('--doctor', self.target)
        self.assertIn('local-core', result.stdout)
        self.assertFalse((self.home/'.agents').exists())
        self.assertEqual(snapshot(self.home), before)
        (self.target/'.agents/skills/tdd/SKILL.md').unlink()
        result = self.bootstrap('--doctor', self.target, ok=False)
        self.assertIn('tdd', result.stdout)

    def test_doctor_local_core_explicitly_selected_without_metadata(self):
        self.fixture.install('--local-core')
        (self.target/'.codex/bootstrap.json').unlink()
        self.bootstrap('--doctor', '--local-core', self.target)

    def test_doctor_optional_project_pack_is_not_mistaken_for_local_core(self):
        self.fixture.install('--pack', 'herald')
        result = self.bootstrap('--doctor', self.target)
        self.assertIn('Health scope: global core', result.stdout)
        self.assertFalse((self.target/'.agents/skills/session-start').exists())

    def test_doctor_customization_warns_without_equating_it_with_corruption(self):
        self.bootstrap('--global-only')
        skill = self.home/'.agents/skills/tdd/SKILL.md'
        skill.write_text(skill.read_text()+'\nPersonal workflow addition.\n')
        result = self.bootstrap('--doctor')
        self.assertIn('customized', result.stdout)
        self.assertIn('preserved', result.stdout)
        (self.codex/'agents/reviewer.toml').write_text('[broken')
        self.bootstrap('--doctor', ok=False)

    def test_doctor_valid_toml_with_invalid_role_contract_is_unhealthy(self):
        self.bootstrap('--global-only')
        role = self.codex/'agents/reviewer.toml'
        valid = role.read_text()
        invalid = ['not_a_role = "missing required fields"\n',
                   valid.replace('name = "reviewer"', 'name = "wrong-role"'),
                   valid.replace('sandbox_mode = "read-only"', 'sandbox_mode = "invalid-mode"'),
                   valid.replace('description = "', 'description = "" # ')]
        for content in invalid:
            with self.subTest(content=content[:70]):
                role.write_text(content)
                result = self.bootstrap('--doctor', ok=False)
                self.assertIn('reviewer.toml', result.stdout)
                self.assertEqual(role.read_text(), content)
        role.write_text(valid+'\nmodel = "my-custom-model"\n')
        self.bootstrap('--doctor')

    def test_doctor_skill_missing_required_frontmatter_is_unhealthy(self):
        self.bootstrap('--global-only')
        skill = self.home/'.agents/skills/tdd/SKILL.md'
        valid = skill.read_text()
        for content in ('# Not discoverable\n', valid.replace('name: tdd', 'name: wrong-skill'),
                        valid.replace('description:', 'not-description:'),
                        valid.replace('description:', 'description: #')):
            with self.subTest(content=content[:70]):
                skill.write_text(content)
                self.bootstrap('--doctor', ok=False)
                self.assertEqual(skill.read_text(), content)
        skill.write_text(valid+'\nPersonal addition.\n')
        self.bootstrap('--doctor')

    def test_doctor_skill_empty_block_description_is_unhealthy(self):
        self.bootstrap('--global-only')
        skill = self.home/'.agents/skills/tdd/SKILL.md'
        for description in ('false', '42', '[]', '{}', '>\n', '|\n'):
            with self.subTest(description=description):
                skill.write_text(f'---\nname: tdd\ndescription: {description}\n---\nBody\n')
                self.bootstrap('--doctor', ok=False)
        skill.write_text('---\nname: tdd\ndescription: >-\n  Custom folded description.\n---\nBody\n')
        self.bootstrap('--doctor')

    def test_doctor_invalid_other_hook_events_fail_without_execution(self):
        self.bootstrap('--global-only')
        hooks = self.codex/'hooks.json'
        for data in ({'hooks': {'Stop': 'not an array'}},
                     {'hooks': {'Stop': [{'hooks': 'not an array'}]}},
                     {'hooks': {'Stop': [{'hooks': ['not an object']}]}},
                     {'hooks': {'Stop': [{'hooks': [{'type': 'command', 'command': 42}]}]}}):
            with self.subTest(data=data):
                hooks.write_text(json.dumps(data))
                self.bootstrap('--doctor', ok=False)
        sentinel = self.fixture.root/'must-not-execute'
        hooks.write_text(json.dumps({'hooks': {'Stop': [{'hooks': [
            {'type': 'command', 'command': f'touch "{sentinel}"'}]}]}}))
        self.bootstrap('--doctor')
        self.assertFalse(sentinel.exists())

    def test_doctor_inline_hook_structure_and_missing_orientation_helper(self):
        self.bootstrap('--global-only')
        config = self.codex/'config.toml'
        config.write_text('[hooks]\nStop = "not an array"\n')
        self.bootstrap('--doctor', ok=False)
        command = 'python3 '+shlex.quote(str(self.codex/'hooks/session-context.py'))
        config.write_text('[[hooks.SessionStart]]\nmatcher = "startup"\n'
                          '[[hooks.SessionStart.hooks]]\ntype = "command"\n'
                          f'command = {json.dumps(command)}\n'
                          'statusMessage = "Codex bootstrap orientation"\n')
        result = self.bootstrap('--doctor', ok=False)
        self.assertIn('session-context.py', result.stdout+result.stderr)
        sentinel = self.fixture.root/'inline-must-not-execute'
        config.write_text('[[hooks.Stop]]\n[[hooks.Stop.hooks]]\ntype = "command"\n'
                          f'command = {json.dumps("touch "+str(sentinel))}\n')
        self.bootstrap('--doctor')
        self.assertFalse(sentinel.exists())

    def test_doctor_missing_hook_helper_fails_without_running_configured_commands(self):
        self.personal_configuration()
        (self.codex/'hooks/session-context.py').unlink()
        result = self.bootstrap('--doctor', ok=False)
        self.assertIn('session-context.py', result.stdout+result.stderr)

    def test_doctor_absent_optional_hooks_are_not_a_core_failure(self):
        self.bootstrap('--global-only')
        result = self.bootstrap('--doctor')
        self.assertIn('not configured', result.stdout)

    def test_inventory_is_report_only_while_health_is_strict(self):
        args = ['python3', str(KIT/'verification/check-assets.py'), '--inventory', str(KIT),
                str(self.home/'.agents/skills'), str(self.codex)]
        result = subprocess.run(args, env=self.fixture.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        args[2] = '--installed'
        result = subprocess.run(args, env=self.fixture.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)


@unittest.skipUnless(os.environ.get('BOOTSTRAP_TEST_BASH32'), 'real Bash 3.2 fixture not supplied; platform gate not performed')
class Bash32RemediationTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.InstallerTests(); self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.bash = os.environ['BOOTSTRAP_TEST_BASH32']
        version = subprocess.check_output([self.bash, '--version'], text=True)
        self.assertIn('version 3.2.', version)

    def run_bootstrap(self, *flags, ok=True):
        result = subprocess.run([self.bash, str(KIT/'bootstrap'), *map(str, flags)],
                                env=self.fixture.env, capture_output=True, text=True, timeout=90)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
            self.assertNotIn('unbound variable', result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout+result.stderr)
        return result

    def test_packless_dry_run_no_writes_or_false_success(self):
        before = snapshot(self.fixture.home)
        self.run_bootstrap(self.fixture.target, '--prefix', 'B32', '--dry-run')
        self.assertFalse(self.fixture.target.exists())
        self.assertEqual(snapshot(self.fixture.home), before)

    def test_global_default_installs_complete_metadata(self):
        self.run_bootstrap('--global-only')
        self.assertTrue((Path(self.fixture.env['CODEX_HOME'])/'bootstrap-managed.json').is_file())
        self.assertTrue((self.fixture.home/'.agents/bootstrap/managed.json').is_file())

    def test_project_default_and_repeat_complete_metadata(self):
        self.run_bootstrap(self.fixture.target, '--prefix', 'B32')
        stamp = self.fixture.target/'.codex/bootstrap.json'
        self.assertTrue(stamp.is_file())
        self.run_bootstrap(self.fixture.target)
        self.assertEqual(json.loads(stamp.read_text())['packs'], [])

    def test_local_core_and_configuration_options(self):
        self.run_bootstrap(self.fixture.target, '--prefix', 'B32', '--local-core', '--hooks', '--status-line', '--notifications', '--docs-mcp')
        self.assertTrue((self.fixture.target/'.codex/bootstrap.json').is_file())
        self.assertTrue((self.fixture.target/'.codex/hooks.json').is_file())
        self.assertFalse((self.fixture.home/'.agents').exists())

    def test_conflict_failure_is_truthful_and_write_free(self):
        p = self.fixture.target/'.agents/templates/work-item.md'
        p.parent.mkdir(parents=True); p.write_text('unmanaged collision')
        self.run_bootstrap(self.fixture.target, '--prefix', 'B32', ok=False)
        self.assertFalse((self.fixture.home/'.agents').exists())


if __name__ == '__main__':
    unittest.main()
