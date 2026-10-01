"""Core resource, native-role and documented CLI contract regressions."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

import test_installer as fixtures

KIT = fixtures.KIT


class PromptContracts(unittest.TestCase):
    def test_all_skill_frontmatter_uses_supported_metadata_container(self):
        import yaml
        allowed = {'name', 'description', 'license', 'allowed-tools', 'metadata'}
        for file in (KIT / 'assets').rglob('SKILL.md'):
            header = yaml.safe_load(file.read_text().split('---', 2)[1])
            self.assertFalse(set(header) - allowed, file)
        minion = yaml.safe_load((KIT / 'assets/global/.agents/skills/minion/SKILL.md').read_text().split('---', 2)[1])
        self.assertEqual(minion['metadata'], {'protocol_version': '2.0', 'origin': 'SCAR Labs', 'cognitive_tier': 'Execution'})

    def test_skill_required_resources_resolve_from_loaded_directory(self):
        for skill, relative in (
            ('refine-beads', 'work-item-templates.md'),
            ('plan-to-beads-unified', '../refine-beads/work-item-templates.md'),
            ('tdd', '../../bootstrap/instructions/workflow-execution.md'),
        ):
            folder = KIT/'assets/global/.agents/skills'/skill
            self.assertIn(f']({relative})', (folder/'SKILL.md').read_text())
            self.assertTrue((folder/relative).is_file())

    def test_report_only_native_roles_explicitly_enforce_shell_sandbox(self):
        for file in (KIT/'assets/global/.codex/agents').glob('*.toml'):
            role = tomllib.loads(file.read_text())
            if role['name'] != 'worker':
                self.assertEqual(role.get('sandbox_mode'), 'read-only', file)

    def test_supporting_guides_do_not_advertise_removed_falcon_interfaces(self):
        for base in ('assets/global/.agents', 'assets/global/.codex/agents'):
            for file in (KIT/base).rglob('*'):
                if file.suffix not in ('.md', '.toml'):
                    continue
                text = file.read_text()
                self.assertFalse('falcon work beads' in text, file)
                self.assertFalse('falcon-reports-' in text, file)

    def test_session_supporting_guides_preserve_request_and_repository_authority(self):
        base = KIT/'assets/global/.agents/bootstrap/instructions'
        protocol = (base/'bootstrap-protocol.md').read_text()
        session = (base/'workflow-session.md').read_text()
        execution = (base/'workflow-execution.md').read_text()
        self.assertNotIn('These rules win over', protocol)
        self.assertNotIn('plus a commit', protocol)
        self.assertNotIn('nothing is "done" until it', protocol)
        self.assertNotIn('to commit, push and note', session)
        self.assertNotIn('commits and pushes it all', session)
        self.assertNotIn('ungated', execution)
        self.assertNotIn('`bd dolt push`', execution)

    def test_navigator_resource_lookup_is_project_first_and_steering_can_supply_paths(self):
        for name in ('navigator-survey', 'navigator-maintenance'):
            role = tomllib.loads((KIT/f'assets/global/.codex/agents/{name}.toml').read_text())
            instructions = role['developer_instructions']
            self.assertNotIn('~/.agents/skills/refine-beads', instructions)
            self.assertIn('paths supplied by steering', instructions)
            self.assertIn('core_mode: local', instructions)
            self.assertIn('global selects the user core', instructions)
            self.assertIn('.agents/skills/session-start/SKILL.md sentinel', instructions)
            self.assertIn('not .agents/skills or .agents/bootstrap directories alone', instructions)
            self.assertIn('never replaced by a stale global resource', instructions)
            self.assertIn('also declares local-core even when that file is missing', instructions)

    def test_recon_and_generated_handoffs_do_not_require_absent_global_tools(self):
        role = tomllib.loads((KIT/'assets/global/.codex/agents/navigator-recon.toml').read_text())
        instructions = role['developer_instructions']
        self.assertNotIn('git branch --merged main', instructions)
        self.assertIn('yq only when installed', instructions)
        self.assertIn('skip every Beads query', instructions)
        for name in ('handoff', 'changelog'):
            text = (KIT/f'assets/scaffold/docs/{name}.yaml').read_text()
            self.assertNotIn('~/.agents/skills/', text)
            self.assertIn('loaded session-wrapup/SKILL.md', text)

    def test_planning_label_example_uses_actual_beads_cli(self):
        guide = (KIT/'assets/global/.agents/bootstrap/instructions/workflow-planning.md').read_text()
        example = next(line for line in guide.splitlines() if line.startswith('bd label add AES-42 '))
        import shlex
        argv = shlex.split(example)
        with tempfile.TemporaryDirectory(prefix='codex-prompt-bd-') as tmp:
            root = Path(tmp)
            home = root/'home'; home.mkdir()
            repo = root/'repo'; repo.mkdir()
            env = {**os.environ, 'HOME': str(home), 'CODEX_HOME': str(home/'.codex'), 'CI': '1'}
            subprocess.run(['git', 'init', '-q', str(repo)], check=True, capture_output=True, env=env)
            def bd(*args):
                return subprocess.run(['bd', *args], cwd=repo, env=env, capture_output=True,
                                      text=True, timeout=40)
            result = bd('init', '--prefix', 'PROMPT', '--skip-agents')
            self.assertEqual(result.returncode, 0, result.stderr)
            created = bd('create', 'Disposable example', '--type', 'chore', '--description',
                         'Validate documented label syntax', '--silent')
            self.assertEqual(created.returncode, 0, created.stderr)
            identifier = created.stdout.strip()
            argv[3] = identifier
            result = bd(*argv[1:])
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
            issue = json.loads(bd('show', identifier, '--json').stdout)
            if isinstance(issue, list): issue = issue[0]
            self.assertTrue({'urgent', 'needs-review'} <= set(issue['labels']))


class LocalCoreResources(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.InstallerTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.target, self.home = self.fixture.target, self.fixture.home

    def test_role_loader_never_falls_back_from_declared_local_to_stale_global(self):
        self.fixture.install('--local-core', '--pack', 'herald')
        helper = self.target / '.agents/bootstrap/scripts/run-agent.py'
        # Test canonical updated helper even before the lead regenerates mirrors.
        helper = KIT / 'assets/global/.agents/bootstrap/scripts/run-agent.py'
        prompt = self.target / 'role-prompt.txt'; prompt.write_text('Read-only fixture')
        global_roles = Path(self.fixture.env['CODEX_HOME']) / 'agents'; global_roles.mkdir(parents=True)
        stale = global_roles / 'navigator.toml'
        stale.write_text((self.target / '.codex/agents/navigator.toml').read_text().replace('planning and orientation', 'STALE GLOBAL'))
        def run(role):
            return subprocess.run(['python3', str(helper), '--root', str(self.target), '--role', role,
                                   '--prompt-file', str(prompt), '--dry-run'], env=self.fixture.env,
                                  capture_output=True, text=True, timeout=15)
        self.assertEqual(run('navigator').returncode, 0)
        self.assertEqual(run('herald-a11y').returncode, 0, 'Project pack role must remain loadable')
        (self.target / '.codex/agents/navigator.toml').unlink()
        missing = run('navigator')
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn('stale global fallback refused', missing.stderr)
        stamp = self.target / '.codex/bootstrap.json'
        data = json.loads(stamp.read_text()); data.pop('core_mode'); stamp.write_text(json.dumps(data))
        self.assertNotEqual(run('navigator').returncode, 0, 'Legacy local-core marker is authoritative')
        data['core_mode'] = 'global'; stamp.write_text(json.dumps(data))
        self.assertEqual(run('navigator').returncode, 0, 'Declared global-first can load global role')
        stamp.write_text('{bad')
        self.assertNotEqual(run('navigator').returncode, 0, 'Malformed metadata cannot choose stale global')

    def test_local_resource_links_work_with_absent_and_stale_global_core(self):
        self.fixture.install('--local-core')
        for skill, relative in (
            ('refine-beads', 'work-item-templates.md'),
            ('plan-to-beads-unified', '../refine-beads/work-item-templates.md'),
            ('tdd', '../../bootstrap/instructions/workflow-execution.md'),
        ):
            folder = self.target/'.agents/skills'/skill
            body = (folder/'SKILL.md').read_text()
            self.assertIn(f']({relative})', body)
            local_resource = (folder/relative).resolve()
            self.assertTrue(local_resource.is_relative_to(self.target))
            expected = local_resource.read_bytes()
            global_resource = self.home/'.agents'/local_resource.relative_to(self.target/'.agents')
            global_resource.parent.mkdir(parents=True, exist_ok=True)
            global_resource.write_text('STALE GLOBAL CONTENT MUST NOT WIN')
            self.assertEqual((folder/relative).read_bytes(), expected)
