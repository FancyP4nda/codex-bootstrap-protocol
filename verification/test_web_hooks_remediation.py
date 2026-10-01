"""Disposable regressions for nested hooks, conservative QA and native Stop output."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

KIT = Path(__file__).resolve().parents[1]
SOURCE = KIT / 'assets/packs/web-design/scaffold/.agents/skills/impeccable'


@unittest.skipUnless(shutil.which('node'), 'Node is required')
class WebHooksRemediationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='codex-hook-remediation-')
        self.addCleanup(self.tmp.cleanup)
        self.outer = Path(self.tmp.name)
        # Exercise spaces, both quotes, dollar signs and command substitution as DATA.
        self.root = self.outer / 'apps' / "front 'double\" $value $(touch injected)"
        self.skill = self.root / '.agents/skills/impeccable'
        shutil.copytree(SOURCE, self.skill)
        subprocess.run(['git', 'init', '-q', str(self.outer)], check=True)
        self.env = {**os.environ, 'IMPECCABLE_NO_UPDATE_CHECK': '1',
                    'IMPECCABLE_NO_TELEMETRY': '1'}
        self.env.pop('IMPECCABLE_HOOK_DISABLED', None)
        for name in ['IMPECCABLE_HOOK_HARNESS', 'IMPECCABLE_HOOK_DEPTH', 'CLAUDE_HOOK_DEPTH']:
            self.env.pop(name, None)

    def node(self, code):
        result = subprocess.run(['node', '--input-type=module', '-e', code],
                                cwd=self.root, env=self.env, capture_output=True,
                                text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def admin(self, action='on'):
        result = subprocess.run(['node', str(self.skill / 'scripts/hook-admin.mjs'), action],
                                cwd=self.root, env=self.env, capture_output=True,
                                text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def manifest(self, data):
        file = self.root / '.codex/hooks.json'
        file.parent.mkdir(exist_ok=True)
        file.write_text(json.dumps(data))
        return file

    def context(self):
        result = subprocess.run(['node', str(self.skill / 'scripts/context.mjs')],
                                cwd=self.root, env=self.env, capture_output=True,
                                text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def doctor(self):
        uri = (self.skill / 'scripts/lib/staleness-deep.mjs').as_uri()
        return self.node(f'import {{checkHookInstallation}} from {json.dumps(uri)}; '
                         f'console.log(JSON.stringify(checkHookInstallation('
                         f'{{projectRoot:process.cwd(),repoRoot:{json.dumps(str(self.outer))},providerId:"codex"}})));')

    def test_nested_literal_command_executes_and_preserves_other_hooks(self):
        other = {'hooks': [{'type': 'command', 'command': 'echo unrelated'}]}
        self.manifest({'user': 'keep', 'hooks': {'SessionStart': [other]}})
        self.admin()
        file = self.root / '.codex/hooks.json'
        data = json.loads(file.read_text())
        self.assertEqual(data['hooks']['SessionStart'], [other])
        command = data['hooks']['PostToolUse'][0]['hooks'][0]['command']
        self.assertNotIn('git rev-parse', command)
        run = subprocess.run(['sh', '-c', command], cwd=self.root, env=self.env,
                             input='{}', capture_output=True, text=True, timeout=20)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertNotIn('MODULE_NOT_FOUND', run.stderr)
        self.assertFalse((self.root / 'injected').exists())
        first = file.read_text()
        self.admin()
        self.assertEqual(first, file.read_text())
        self.assertEqual(self.doctor(), [])
        self.assertFalse((self.root / '.codex/hooks-trust.json').exists())

    def test_doctor_diagnoses_old_git_root_command_without_running_it(self):
        command = 'node "$(git rev-parse --show-toplevel)/.agents/skills/impeccable/scripts/hook.mjs"'
        self.manifest({'hooks': {'Stop': [{'hooks': [{'type': 'command', 'command': command}]}]}})
        findings = self.doctor()
        self.assertIn('hook-script-missing', [f['id'] for f in findings])

    def test_actual_doctor_cli_uses_git_root_not_logical_context_root(self):
        command = 'node "$(git rev-parse --show-toplevel)/.agents/skills/impeccable/scripts/hook.mjs"'
        self.manifest({'hooks': {'Stop': [{'hooks': [{'type': 'command', 'command': command}]}]}})
        result = subprocess.run(['node', str(self.skill / 'scripts/doctor.mjs'), '--json'],
                                cwd=self.root, env=self.env, capture_output=True,
                                text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        # Context's repoRoot is the logical project root in this non-workspace
        # nested installation. The shell substitution uses the OUTER Git root.
        self.assertEqual(data['repoRoot'], str(self.root))
        self.assertIn('hook-script-missing', [f['id'] for f in data['findings']])

    def test_doctor_unknown_substitution_is_actionable_without_execution(self):
        command = 'node "$(touch injected)/.agents/skills/impeccable/scripts/hook.mjs"'
        self.manifest({'hooks': {'Stop': [{'hooks': [{'type': 'command', 'command': command}]}]}})
        self.assertIn('hook-script-unresolved', [f['id'] for f in self.doctor()])
        self.assertFalse((self.root / 'injected').exists())

    def test_configured_untrusted_hooks_retain_one_manual_pass(self):
        self.admin()
        output = self.context()
        self.assertEqual(output.count('MANUAL_DETECTOR_REQUIRED:'), 1)
        self.assertIn('configured', output)
        self.assertIn('trust', output)

    def test_missing_script_and_disabled_and_malformed_keep_fallback(self):
        self.admin()
        (self.skill / 'scripts/hook.mjs').unlink()
        self.assertIn('MANUAL_DETECTOR_REQUIRED:', self.context())
        self.assertIn('broken', self.context())
        self.admin('off')
        self.assertIn('disabled', self.context())
        self.assertIn('MANUAL_DETECTOR_REQUIRED:', self.context())
        (self.root / '.codex/hooks.json').write_text('{bad')
        (self.root / '.impeccable/config.json').write_text('{}')
        self.assertIn('broken', self.context())
        self.assertIn('MANUAL_DETECTOR_REQUIRED:', self.context())

    def test_unknown_and_env_feature_handler_disables_keep_manual_pass(self):
        self.assertIn('unknown', self.context())
        self.assertEqual(self.context().count('MANUAL_DETECTOR_REQUIRED:'), 1)
        self.admin()
        self.env['IMPECCABLE_HOOK_DISABLED'] = '1'
        self.assertIn('disabled', self.context())
        self.assertEqual(self.context().count('MANUAL_DETECTOR_REQUIRED:'), 1)
        self.env.pop('IMPECCABLE_HOOK_DISABLED')
        config = self.root / '.codex/config.toml'
        config.write_text('[features]\nhooks = false\n')
        self.assertIn('disabled', self.context())
        self.assertIn('MANUAL_DETECTOR_REQUIRED:', self.context())
        config.unlink()
        manifest = self.root / '.codex/hooks.json'
        data = json.loads(manifest.read_text())
        data['hooks']['Stop'][0]['hooks'][0]['enabled'] = False
        manifest.write_text(json.dumps(data))
        self.assertIn('disabled', self.context())
        self.assertIn('MANUAL_DETECTOR_REQUIRED:', self.context())

    def test_marker_in_metadata_is_not_an_executable_hook(self):
        self.manifest({'hooks': {'Stop': [{'hooks': [], 'description':
                       'skills/impeccable/scripts/hook.mjs'}]}})
        self.assertIn('unknown', self.context())
        self.assertIn('MANUAL_DETECTOR_REQUIRED:', self.context())

    def test_malformed_hook_groups_and_missing_script_fail_before_preferences(self):
        file = self.manifest({'hooks': {'Stop': {'invalid': 'not a group array'}}})
        initial = file.read_text()
        result = subprocess.run(['node', str(self.skill / 'scripts/hook-admin.mjs'), 'on'],
                                cwd=self.root, env=self.env, capture_output=True,
                                text=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(initial, file.read_text())
        self.assertFalse((self.root / '.impeccable/config.json').exists())
        self.assertIn('broken', self.context())
        file.unlink()
        (self.skill / 'scripts/hook.mjs').unlink()
        result = subprocess.run(['node', str(self.skill / 'scripts/hook-admin.mjs'), 'on'],
                                cwd=self.root, env=self.env, capture_output=True,
                                text=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / '.impeccable/config.json').exists())
        self.assertFalse((self.root / '.impeccable/config.local.json').exists())

    def test_malformed_native_handlers_fail_before_writes_and_diagnose_consistently(self):
        invalid_groups = [
            {'hooks': ['not a handler object']},
            {'hooks': [None]},
            {'hooks': [{'type': 'command', 'command': 42}]},
            {'hooks': [{'type': 'command'}]},
            {'hooks': [{'type': 'unknown', 'command': 'echo unchanged'}]},
            {'matcher': 42, 'hooks': [{'type': 'command', 'command': 'echo unchanged'}]},
            {'hooks': [{'type': 'mcp_tool', 'server': 'scanner'}]},
            {'hooks': [{'type': 'prompt', 'prompt': 42}]},
        ]
        for group in invalid_groups:
            with self.subTest(group=group):
                file = self.manifest({'personal': 'preserve', 'hooks': {'Stop': [group]}})
                before = file.read_bytes()
                result = subprocess.run(['node', str(self.skill / 'scripts/hook-admin.mjs'), 'on'],
                            cwd=self.root, env=self.env, capture_output=True, text=True, timeout=20)
                self.assertNotEqual(result.returncode, 0, result.stdout+result.stderr)
                self.assertEqual(file.read_bytes(), before)
                self.assertFalse((self.root / '.impeccable/config.json').exists())
                self.assertFalse((self.root / '.impeccable/config.local.json').exists())
                self.assertIn('hook-manifest-malformed', [f['id'] for f in self.doctor()])
                self.assertIn('broken', self.context())
                self.assertIn('MANUAL_DETECTOR_REQUIRED:', self.context())

    def test_on_preserves_nonowned_marker_commands_and_other_native_handler_types(self):
        marker = 'skills/impeccable/scripts/hook.mjs'
        handlers = [
            {'type': 'command', 'command': f"echo '{marker}'", 'statusMessage': 'user audit'},
            {'type': 'mcp_tool', 'server': 'scanner', 'tool': 'inspect', 'input': {'marker': marker}},
            {'type': 'prompt', 'prompt': f'User review mentioning {marker}'},
            {'type': 'agent', 'prompt': 'User agent hook parsed but skipped by Codex'},
        ]
        self.manifest({'personal': 'keep', 'hooks': {'PostToolUse': [{'matcher': 'Bash', 'hooks': handlers}]}})
        self.admin()
        result = json.loads((self.root / '.codex/hooks.json').read_text())
        self.assertEqual(result['hooks']['PostToolUse'][0]['hooks'], handlers)
        self.assertEqual(result['personal'], 'keep')
        self.admin()
        repeated = json.loads((self.root / '.codex/hooks.json').read_text())
        self.assertEqual(repeated['hooks']['PostToolUse'][0]['hooks'], handlers)
        self.assertEqual(len(repeated['hooks']['PostToolUse']), 2)
        self.assertIn('hook-script-unresolved', [f['id'] for f in self.doctor()])
        self.assertFalse((self.root / 'injected').exists())

    def test_doctor_ignores_marker_only_in_metadata(self):
        self.manifest({'hooks': {'Stop': [{'description': 'skills/impeccable/scripts/hook.mjs', 'hooks': []}]}})
        self.assertEqual(self.doctor(), [])

    def test_relocation_is_diagnosed_and_repaired_even_when_old_path_exists(self):
        self.admin()
        relocated = self.outer / 'moved frontend'
        shutil.copytree(self.root, relocated)
        old_root, old_skill = self.root, self.skill
        self.root = relocated
        self.skill = relocated / '.agents/skills/impeccable'
        self.assertIn('hook-script-stale-location', [f['id'] for f in self.doctor()])
        self.admin()
        command = json.loads((self.root / '.codex/hooks.json').read_text())['hooks']['Stop'][0]['hooks'][0]['command']
        self.assertIn(str(relocated), command)
        self.assertNotIn(str(old_root), command)
        self.assertEqual(self.doctor(), [])
        self.assertTrue((old_skill / 'scripts/hook.mjs').exists())

    def test_doctor_missing_literal_and_malformed_file_are_actionable(self):
        self.admin()
        (self.skill / 'scripts/hook.mjs').unlink()
        self.assertIn('hook-script-missing', [f['id'] for f in self.doctor()])
        (self.root / '.codex/hooks.json').write_text('{bad')
        self.assertIn('hook-manifest-malformed', [f['id'] for f in self.doctor()])

    def test_printed_manual_command_runs_bundled_detector_with_quoted_paths(self):
        output = self.context()
        command = re.search(r'`(node [^`]+ --json <changed targets>)`', output).group(1)
        (self.root / 'ui.css').write_text('body { font-family: Inter; }')
        result = subprocess.run(['sh', '-c', command.replace('<changed targets>', 'ui.css')],
                                cwd=self.root, env=self.env, capture_output=True,
                                text=True, timeout=20)
        self.assertIn(result.returncode, (0, 2), result.stderr)
        findings = json.loads(result.stdout)
        self.assertIsInstance(findings, list)
        self.assertTrue(any(f['antipattern'] == 'overused-font' for f in findings))
        self.assertFalse((self.root / 'injected').exists())

    def stop_sequence(self):
        uri = (self.skill / 'scripts/hook-lib.mjs').as_uri()
        return self.node(f'''
            import fs from 'node:fs'; import path from 'node:path';
            import {{runStopHook,persistCache,readCache}} from {json.dumps(uri)};
            const root=process.cwd(), file=path.join(root,'ui.css');
            fs.writeFileSync(file,'body {{ font-family: Inter; }}');
            persistCache(root,{{version:1,sessions:{{s:{{updatedAt:1,files:{{[file]:{{editCount:1,findings:[]}}}}}}}}}});
            let current=[{{antipattern:'overused-font',line:1,message:'Use a deliberate font',snippet:'Inter'}}];
            const detector={{detectText:()=>current}};
            const event={{hook_event_name:'Stop',session_id:'s',cwd:root}};
            const first=await runStopHook({{stdinJson:event,detector}});
            const second=await runStopHook({{stdinJson:event,detector}});
            const active=await runStopHook({{stdinJson:{{...event,stop_hook_active:true}},detector:{{detectText:()=>{{throw Error('must not scan')}}}}}});
            const cache=readCache(root);
            current=[]; await runStopHook({{stdinJson:event,detector}});
            current=[{{antipattern:'overused-font',line:1,message:'Use a deliberate font',snippet:'Inter'}}];
            const reintroduced=await runStopHook({{stdinJson:event,detector}});
            console.log(JSON.stringify({{first,second,active,cache,reintroduced}}));
        ''')

    def test_stop_warning_shape_dedupe_reentrancy_and_reintroduced_finding(self):
        result = self.stop_sequence()
        first = json.loads(result['first']['stdout'])
        self.assertEqual(set(first), {'systemMessage'})
        self.assertIn('font', first['systemMessage'].lower())
        self.assertEqual(result['second']['stdout'], '')
        self.assertEqual(result['active']['stdout'], '')
        self.assertEqual(result['active']['audit']['skipped'], 'stop-hook-active')
        self.assertTrue(result['reintroduced']['stdout'])
        self.assertEqual(result['first']['audit']['delivery'], 'unconfirmed')

    def test_real_hook_entrypoint_and_bundled_detector_attempt_advisory_stop(self):
        self.admin()
        file = self.root / 'ui.css'
        file.write_text('body { font-family: Inter; }')
        cache = self.root / '.impeccable/hook.cache.json'
        cache.write_text(json.dumps({'version': 1, 'sessions': {'s': {
            'updatedAt': 1, 'files': {str(file): {'editCount': 1, 'findings': []}}}}}))
        event = json.dumps({'hook_event_name': 'Stop', 'session_id': 's', 'cwd': str(self.root)})
        command = ['node', str(self.skill / 'scripts/hook.mjs')]
        first = subprocess.run(command, input=event, cwd=self.root, env=self.env,
                               capture_output=True, text=True, timeout=20)
        self.assertEqual(first.returncode, 0, first.stderr)
        warning = json.loads(first.stdout)
        self.assertEqual(set(warning), {'systemMessage'})
        self.assertIn('font', warning['systemMessage'].lower())
        second = subprocess.run(command, input=event, cwd=self.root, env=self.env,
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(second.stdout, '')
        attempt = json.loads(cache.read_text())['sessions']['s']['stopWarningAttempt']
        self.assertEqual(attempt['delivery'], 'unconfirmed')
        # This is the actual script, not a claim that Codex granted trust or
        # delivered its warning; client-side acceptance remains a separate gate.
        self.assertFalse((self.root / '.codex/hooks-trust.json').exists())

    def test_local_execution_is_not_trust_or_current_coverage(self):
        self.admin()
        self.stop_sequence()
        output = self.context()
        self.assertIn('observed-local-execution', output)
        self.assertEqual(output.count('MANUAL_DETECTOR_REQUIRED:'), 1)
        self.assertIn('not proof', output)

    def test_stop_failure_does_not_forget_attempt_and_post_edit_is_separate(self):
        uri = (self.skill / 'scripts/hook-lib.mjs').as_uri()
        result = self.node(f'''
            import fs from 'node:fs'; import path from 'node:path';
            import {{runStopHook,runHook,persistCache,readCache,payload}} from {json.dumps(uri)};
            const root=process.cwd(), file=path.join(root,'ui.css');
            fs.writeFileSync(file,'body {{ color: red; }}');
            persistCache(root,{{version:1,sessions:{{s:{{updatedAt:1,files:{{[file]:{{editCount:1,findings:[]}}}}}}}}}});
            const finding={{antipattern:'overused-font',line:1,message:'Deliberate font',snippet:'Inter'}};
            const event={{hook_event_name:'Stop',session_id:'s',cwd:root}};
            const first=await runStopHook({{stdinJson:event,detector:{{detectText:()=>[finding]}}}});
            const failed=await runStopHook({{stdinJson:event,detector:{{detectText:()=>{{throw Error('failed scan')}}}}}});
            const repeat=await runStopHook({{stdinJson:event,detector:{{detectText:()=>[finding]}}}});
            const post=payload('post edit', 'PostToolUse', 'codex');
            const cache=readCache(root);
            console.log(JSON.stringify({{first,failed,repeat,post,cache}}));
        ''')
        self.assertTrue(result['first']['stdout'])
        self.assertEqual(result['failed']['stdout'], '')
        self.assertEqual(result['repeat']['stdout'], '')
        self.assertEqual(json.loads(result['post'])['hookSpecificOutput']['hookEventName'], 'PostToolUse')
        record = result['cache']['sessions']['s']['stopWarningAttempt']
        self.assertEqual(record['delivery'], 'unconfirmed')
        self.assertEqual(record['event'], 'Stop')
        self.assertEqual(record['findings'], 1)

    def test_context_never_claims_helper_directives_override_authority(self):
        output = self.context()
        self.assertNotIn('AUTONOMY_DIRECTIVE_CHECK', output)
        self.assertNotIn("invocation of this skill is that request", output)
        self.assertIn('DELEGATION_SCOPE:', output)

    def test_on_off_controls_effective_local_override_and_preserves_preferences(self):
        self.admin()
        file = self.root / '.impeccable/config.local.json'
        file.write_text(json.dumps({'personal': 'keep', 'hook': {'enabled': True, 'quiet': True}}))
        self.admin('off')
        uri = (self.skill / 'scripts/hook-lib.mjs').as_uri()
        check = f'import {{readConfig}} from {json.dumps(uri)}; console.log(JSON.stringify(readConfig(process.cwd())));'
        self.assertFalse(self.node(check)['enabled'])
        self.assertEqual(json.loads(file.read_text())['personal'], 'keep')
        self.admin('on')
        self.assertTrue(self.node(check)['enabled'])
        self.assertTrue(self.node(check)['quiet'])
        self.assertEqual(json.loads(file.read_text())['personal'], 'keep')

    def test_malformed_local_preferences_preflight_before_shared_writes(self):
        folder = self.root / '.impeccable'
        folder.mkdir()
        local = folder / 'config.local.json'
        for text in ['{bad', '[]', '"string"']:
            with self.subTest(text=text):
                local.write_text(text)
                result = subprocess.run(['node', str(self.skill / 'scripts/hook-admin.mjs'), 'on'],
                                        cwd=self.root, env=self.env, capture_output=True,
                                        text=True, timeout=20)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(local.read_text(), text)
                self.assertFalse((folder / 'config.json').exists())
                self.assertFalse((self.root / '.codex/hooks.json').exists())


if __name__ == '__main__':
    unittest.main()
