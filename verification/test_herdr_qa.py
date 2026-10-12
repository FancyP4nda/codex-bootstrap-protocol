#!/usr/bin/env python3
"""herdr-qa wrapper and qa reviewer provisioning, in disposable homes with a recording fake codex."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest

KIT = Path(__file__).resolve().parents[1]
WRAPPER = KIT/'bin/herdr-qa'
QA_PROFILE = KIT/'assets/global/.codex/qa.config.toml'
REVIEWER = KIT/'assets/global/.codex/agents/reviewer.toml'

# Records how it was started, so a test can assert on the exec without a model session.
FAKE_CODEX = '''#!/usr/bin/env python3
import json,os,sys
if '--version' in sys.argv: print('codex-cli 0.162.1'); sys.exit(0)
if '--help' in sys.argv: print('  --no-alt-screen'); sys.exit(0)
record=os.environ.get('FAKE_CODEX_RECORD')
if record:
    with open(record,'w') as fh: json.dump({'argv':sys.argv[1:],'cwd':os.getcwd(),'pid':os.getpid()},fh)
'''


class HerdrQaTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='herdr-qa-test-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.home = self.root/'home'; self.home.mkdir()
        self.codex_home = self.home/'codex home'
        self.project = self.root/'project with spaces'; self.project.mkdir()
        self.bin = self.root/'bin'; self.bin.mkdir()
        fake = self.bin/'codex'; fake.write_text(FAKE_CODEX); fake.chmod(0o755)
        self.record = self.root/'codex-record.json'
        # The real codex must never be reachable: only system tools plus the fake.
        self.env = {'HOME': str(self.home), 'CODEX_HOME': str(self.codex_home), 'PATH': f'{self.bin}:/usr/bin:/bin',
                    'FAKE_CODEX_RECORD': str(self.record), 'CI': '1', 'SHELL': '/bin/bash', 'LANG': 'C.UTF-8'}

    def provision(self, profile=True, reviewer=True):
        (self.codex_home/'agents').mkdir(parents=True, exist_ok=True)
        if profile: shutil.copyfile(QA_PROFILE, self.codex_home/'qa.config.toml')
        if reviewer: shutil.copyfile(REVIEWER, self.codex_home/'agents/reviewer.toml')

    def qa(self, *args, env=None, command=WRAPPER):
        return subprocess.run([str(command), *map(str, args)], capture_output=True, text=True, env=env or self.env, timeout=60)

    def last_line(self, result):
        lines = [l for l in (result.stdout+result.stderr).splitlines() if l.strip()]
        return lines[-1] if lines else ''

    def launched(self):
        return json.loads(self.record.read_text())

    def instructions(self, argv):
        value = next(a for a in argv if a.startswith('developer_instructions='))
        return tomllib.loads(value)['developer_instructions']  # as codex parses -c values

    # --- shipped payloads ------------------------------------------------------

    def test_profile_and_reviewer_payloads(self):
        self.assertEqual(QA_PROFILE.read_bytes(),
                         b'model = "gpt-6-astra"\nmodel_reasoning_effort = "high"\nsandbox_mode = "read-only"\n')
        text = REVIEWER.read_text()
        for needle in ('report-only', 'VERDICT: PASS', 'Reviewed commit:', 'Critical', 'Important', 'Nit',
                       'Checks run:', 'Checks not performed:', 'acceptance', 'security', 'regression'):
            self.assertIn(needle, text)

    # --- herdr-qa --help / --check ---------------------------------------------

    def test_help_lists_no_alt_screen(self):
        result = self.qa('--help')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout, r'(^|\s)--no-alt-screen(\s|$)')
        self.assertIn('--check', result.stdout)

    def test_check_passes_without_starting_codex(self):
        self.provision()
        result = self.qa('--check', self.project)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertFalse(self.record.exists(), 'check must not start a codex session')

    def test_check_names_each_missing_piece(self):
        cases = {
            'no profile': (dict(profile=False), None, 'qa.config.toml'),
            'no reviewer': (dict(reviewer=False), None, 'reviewer.toml'),
            'profile without model': (dict(), lambda: (self.codex_home/'qa.config.toml').write_text('model_reasoning_effort = "high"\n'), 'model'),
            'legacy table': (dict(), lambda: (self.codex_home/'config.toml').write_text('[profiles.qa]\nmodel = "x"\n'), 'profiles.qa'),
            'legacy selector': (dict(), lambda: (self.codex_home/'config.toml').write_text('profile = "qa"\n'), 'profile = "qa"'),
            'legacy dotted key': (dict(), lambda: (self.codex_home/'config.toml').write_text('profiles.qa.model = "x"\n'), 'profiles.qa'),
            'legacy inline table': (dict(), lambda: (self.codex_home/'config.toml').write_text('[profiles]\nqa = { model = "x" }\n'), 'profiles.qa'),
            'stale reviewer': (dict(), lambda: (self.codex_home/'agents/reviewer.toml').write_text('name = "reviewer"\ndeveloper_instructions = "old"\n'), '--update-global'),
            'reviewer without instructions': (dict(), lambda: (self.codex_home/'agents/reviewer.toml').write_text('name = "reviewer"\n'), 'developer_instructions'),
        }
        for name, (provision, breakage, needle) in cases.items():
            with self.subTest(name):
                shutil.rmtree(self.codex_home, ignore_errors=True)
                self.provision(**provision)
                if breakage: breakage()
                result = self.qa('--check', self.project)
                self.assertNotEqual(result.returncode, 0, name)
                self.assertIn(needle, self.last_line(result))
                self.assertFalse(self.record.exists())

    def test_check_fails_without_codex_or_directory(self):
        if shutil.which('codex', path='/usr/bin:/bin'):
            self.skipTest('a system codex in /usr/bin or /bin cannot be hidden from this check')
        self.provision()
        (self.bin/'codex').unlink()
        result = self.qa('--check', self.project)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('codex', self.last_line(result))
        (self.bin/'codex').write_text(FAKE_CODEX); (self.bin/'codex').chmod(0o755)
        result = self.qa('--check', self.root/'missing dir')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('missing dir', self.last_line(result))

    def test_bad_arguments_are_refused(self):
        for args in ([], ['--bogus', self.project], [self.project, self.project], ['--check']):
            with self.subTest(args=args):
                result = self.qa(*args)
                self.assertEqual(result.returncode, 2, result.stdout+result.stderr)
                self.assertFalse(self.record.exists())

    # --- herdr-qa <dir> ---------------------------------------------------------

    def test_launch_execs_codex_with_qa_profile(self):
        self.provision()
        proc = subprocess.Popen([str(WRAPPER), str(self.project), '--no-alt-screen'], env=self.env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        out, err = proc.communicate(timeout=60)
        self.assertEqual(proc.returncode, 0, out+err)
        run = self.launched()
        self.assertEqual(run['pid'], proc.pid, 'herdr-qa must exec codex so herdr sees a codex process')
        self.assertEqual(run['cwd'], str(self.project))
        argv = run['argv']
        self.assertEqual(argv[argv.index('--profile')+1], 'qa')
        self.assertEqual(argv[argv.index('--sandbox')+1], 'read-only')
        self.assertEqual(argv[argv.index('-C')+1], str(self.project))
        self.assertIn('--no-alt-screen', argv)
        text = self.instructions(argv)
        self.assertIn('VERDICT: PASS', text)
        self.assertNotIn('HERDR_TEAM_MANIFEST', text)

    def test_launch_without_inline_flag_and_relative_dir(self):
        self.provision()
        decoy = self.root/'decoy'/self.project.name; decoy.mkdir(parents=True)
        env = {**self.env, 'CDPATH': str(decoy.parent)}  # cd must not pick this over ./<dir>
        result = subprocess.run([str(WRAPPER), self.project.name], cwd=self.root, env=env, capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr)
        argv = self.launched()['argv']
        self.assertNotIn('--no-alt-screen', argv)
        self.assertEqual(argv[argv.index('-C')+1], str(self.project))

    def test_launch_keeps_non_ascii_instructions_valid_toml(self):
        self.provision()
        role = self.codex_home/'agents/reviewer.toml'
        role.write_text(role.read_text().replace('You are a review subagent', 'You are a review subagent \U0001F50D \u00e9'))
        self.assertEqual(self.qa(self.project).returncode, 0)
        self.assertIn('\U0001F50D \u00e9', self.instructions(self.launched()['argv']))

    def test_launch_adds_team_manifest_and_protocol(self):
        self.provision()
        manifest = self.root/'state dir/runtime-manifest.json'; manifest.parent.mkdir(); manifest.write_text('{}')
        env = {**self.env, 'HERDR_TEAM_MANIFEST': str(manifest)}
        self.assertEqual(self.qa(self.project, '--no-alt-screen', env=env).returncode, 0)
        text = self.instructions(self.launched()['argv'])
        self.assertIn(str(manifest), text)
        self.assertNotIn('PROTOCOL.md', text)
        protocol = self.home/'.claude/skills/herdr-team/PROTOCOL.md'; protocol.parent.mkdir(parents=True); protocol.write_text('p')
        self.assertEqual(self.qa(self.project, env=env).returncode, 0)
        self.assertIn(str(protocol), self.instructions(self.launched()['argv']))

    def test_launch_refuses_when_configuration_is_incomplete(self):
        self.provision(profile=False)
        result = self.qa(self.project, '--no-alt-screen')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('qa.config.toml', self.last_line(result))
        self.assertFalse(self.record.exists())

    # --- installation through bootstrap -----------------------------------------

    def bootstrap(self, *flags, ok=True):
        result = subprocess.run([str(KIT/'bootstrap'), *map(str, flags)], capture_output=True, text=True, env=self.env, timeout=120)
        (self.assertEqual if ok else self.assertNotEqual)(result.returncode, 0, result.stdout+result.stderr)
        return result

    def test_install_command_links_herdr_qa_and_end_to_end(self):
        self.bootstrap('--install-command')
        link = self.home/'.local/bin/herdr-qa'
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), WRAPPER.resolve())
        self.bootstrap('--install-command')  # idempotent
        self.bootstrap('--global-only')
        self.assertEqual((self.codex_home/'qa.config.toml').read_bytes(), QA_PROFILE.read_bytes())
        self.assertEqual((self.codex_home/'agents/reviewer.toml').read_bytes(), REVIEWER.read_bytes())
        self.assertIn('0 planned non-identical operations', self.bootstrap('--global-only').stdout)
        result = self.qa('--check', self.project, command=link)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertIn('--no-alt-screen', self.qa('--help', command=link).stdout)
        self.assertEqual(self.qa(self.project, '--no-alt-screen', command=link).returncode, 0)
        self.assertEqual(self.launched()['argv'][self.launched()['argv'].index('--profile')+1], 'qa')
        self.bootstrap('--uninstall-command')
        self.assertFalse(link.exists() or link.is_symlink())
        self.assertFalse((self.home/'.local/bin/codex-bootstrap').exists())

    def test_install_command_collision_writes_nothing(self):
        link = self.home/'.local/bin/herdr-qa'; link.parent.mkdir(parents=True); link.write_text('user command')
        self.bootstrap('--install-command', ok=False)
        self.assertEqual(link.read_text(), 'user command')
        self.assertFalse((self.home/'.local/bin/codex-bootstrap').exists())

    def test_existing_identical_profile_is_left_alone(self):
        self.codex_home.mkdir(parents=True)
        shutil.copyfile(QA_PROFILE, self.codex_home/'qa.config.toml')
        before = (self.codex_home/'qa.config.toml').stat().st_mtime_ns
        out = self.bootstrap('--global-only').stdout
        self.assertNotIn('qa.config.toml', out)
        self.assertEqual((self.codex_home/'qa.config.toml').stat().st_mtime_ns, before)
        self.assertFalse(list(self.codex_home.glob('bootstrap-backups/*/qa.config.toml')))

    def test_existing_different_profile_needs_update_global(self):
        self.codex_home.mkdir(parents=True)
        custom = 'model = "my-model"\n'
        (self.codex_home/'qa.config.toml').write_text(custom)
        out = self.bootstrap('--global-only').stdout
        self.assertRegex(out, r'keep\s+.*qa\.config\.toml')
        self.assertEqual((self.codex_home/'qa.config.toml').read_text(), custom)
        self.bootstrap('--global-only', '--update-global')
        self.assertEqual((self.codex_home/'qa.config.toml').read_bytes(), QA_PROFILE.read_bytes())
        self.assertEqual([p.read_text() for p in self.codex_home.glob('bootstrap-backups/*/qa.config.toml')], [custom])

    def test_doctor_reports_the_global_profile(self):
        self.assertIn('core profile qa', self.bootstrap('--doctor', '--global-only', ok=False).stdout)
        self.bootstrap('--global-only')
        out = self.bootstrap('--doctor', '--global-only').stdout
        self.assertRegex(out, r'core profile qa \(.*qa\.config\.toml\): current')

    def test_local_core_does_not_put_a_profile_in_the_project(self):
        bd = self.bin/'bd'
        bd.write_text("#!/usr/bin/env python3\nimport pathlib,sys\nif 'init' in sys.argv:\n p=pathlib.Path('.beads'); p.mkdir(exist_ok=True); (p/'metadata.json').write_text('{}')\n")
        bd.chmod(0o755)
        self.bootstrap(self.project, '--prefix', 'QA', '--non-interactive', '--no-launch', '--local-core')
        self.assertTrue((self.project/'.codex/agents/reviewer.toml').is_file())
        self.assertFalse((self.project/'.codex/qa.config.toml').exists())


if __name__ == '__main__':
    unittest.main()
