#!/usr/bin/env python3
"""The atlas global pack: roster, user-only policy, converter provenance and $atlas-doctor.

The pack mirrors the Claude kit's atlas pack (T053). Nothing here touches the
real ~/.agents or ~/.codex: every home is a temporary directory.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

KIT = Path(__file__).resolve().parents[1]
PACK = KIT/'assets/packs/atlas'
SKILLS = PACK/'global/.agents/skills'
ROSTER = ('map-repo', 'map-ask', 'map-impact', 'diagram', 'diagram-repo', 'diagram-flow', 'atlas-doctor',
          'rea-doctor', 'rea-triage', 'rea-feature', 'rea-binary', 'rea-android', 'rea-electron',
          'rea-diagram', 'rea-map', 'rea-update')
# rea-binary, rea-android and rea-electron (Claude kit T048) are derived when that task merges.
PENDING = ('rea-binary', 'rea-android', 'rea-electron')
COMMANDS = tuple(name for name in ROSTER if name not in PENDING)
VENDORED = ('archify', 'graphify')
# No Graphify, REA, uv or browser on this PATH: the doctor's tool lines are all [missing] and quick, whatever the host has.
HERMETIC_PATH = '/usr/bin:/bin'
SOURCE_KIT = os.environ.get('ATLAS_SOURCE_KIT')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def frontmatter_keys(path):
    match = re.match(r'---\n([\s\S]*?)\n---\n', Path(path).read_text())
    assert match, path
    return re.findall(r'^([A-Za-z][\w-]*):', match.group(1), re.M)


def tree_state(root):
    """Every path under root with its content hash: a run must leave this unchanged."""
    out = {}
    for path in sorted(Path(root).rglob('*')):
        out[path.relative_to(root).as_posix()] = 'dir' if path.is_dir() else sha(path)
    return out


class PackShape(unittest.TestCase):
    def test_roster_is_the_available_commands_and_two_vendored_skills(self):
        names = sorted(p.name for p in SKILLS.iterdir())
        self.assertEqual(names, sorted(COMMANDS + VENDORED))

    def test_every_command_and_vendored_skill_is_user_only(self):
        for name in COMMANDS + VENDORED:
            with self.subTest(skill=name):
                yaml = SKILLS/name/'agents/openai.yaml'
                self.assertTrue(yaml.is_file(), 'missing agents/openai.yaml')
                text = yaml.read_text()
                self.assertRegex(text, r'(?m)^policy:\n  allow_implicit_invocation: false$')
                self.assertRegex(text, r'(?m)^  display_name: "[^"\n]+"$')
                self.assertRegex(text, r'(?m)^  short_description: "[^"\n]+"$')
                self.assertEqual(frontmatter_keys(SKILLS/name/'SKILL.md'), ['name', 'description'])

    def test_pending_commands_are_absent_until_derived(self):
        for name in PENDING:
            self.assertFalse((SKILLS/name).exists(), name)

    def test_commands_carry_no_claude_runtime_text(self):
        slash = re.compile(r'(?<![\w./$-])/(' + '|'.join(ROSTER) + r')\b')
        for name in COMMANDS:
            for path in (SKILLS/name).rglob('*'):
                if not path.is_file() or path.name == 'openai.yaml':
                    continue
                text = path.read_text()
                rel = path.relative_to(SKILLS)
                with self.subTest(file=rel.as_posix()):
                    self.assertNotIn('CLAUDE_CONFIG_DIR', text)
                    # The doctor looks for another client's leftovers in the repository (traces).
                    if rel.as_posix() != 'atlas-doctor/scripts/doctor.sh':
                        self.assertNotRegex(text, r'\.claude\b')
                    self.assertNotIn('claude-bootstrap', text)
                    self.assertNotIn('Claude Code', text)
                    self.assertIsNone(slash.search(text), 'a /command form instead of $command')

    def pack_scripts(self):
        return [p for p in SKILLS.rglob('*.sh') if 'archify' not in p.relative_to(SKILLS).parts[:1]]

    def test_every_shipped_script_parses(self):
        for path in self.pack_scripts():
            with self.subTest(script=path.relative_to(SKILLS).as_posix()):
                shell = 'sh' if path.read_text().startswith('#!/bin/sh') else 'bash'
                run = subprocess.run([shell, '-n', str(path)], capture_output=True, text=True)
                self.assertEqual(run.returncode, 0, run.stderr)

    def test_derived_scripts_have_no_command_substitution_from_the_text_transform(self):
        # A backtick in a double-quoted string would run $HOME/.agents; a /command form would be unconverted.
        slash = re.compile(r'(?<![\w./$-])/(' + '|'.join(ROSTER) + r')\b')
        for path in self.pack_scripts():
            code = [line for line in path.read_text().splitlines() if not line.lstrip().startswith('#')]
            text = '\n'.join(code)
            with self.subTest(script=path.relative_to(SKILLS).as_posix()):
                self.assertNotIn('(`~/.agents`)', text)
                self.assertIsNone(slash.search(text))

    def test_unsupported_operation_line_runs_nothing(self):
        # The wrapper's refusal text names the agents directory; it must print, not execute, it.
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)/'home'
            shutil.copytree(SKILLS, home/'.agents/skills')
            env = {'PATH': HERMETIC_PATH, 'HOME': str(home)}
            for script, args in (('atlas-doctor/scripts/atlas-archify.sh', ['brands', 'capture']),
                                 ('graphify/atlas-graphify.sh', ['hook', 'install'])):
                with self.subTest(script=script):
                    run = subprocess.run(['/bin/sh', str(home/'.agents/skills'/script), *args], cwd=tmp, env=env,
                                         capture_output=True, text=True)
                    self.assertEqual(run.stderr, '')
                    self.assertIn('Not available in the atlas pack', run.stdout)
                    self.assertIn('(~/.agents)', run.stdout)

    def test_graphify_skill_is_the_agents_root_variant_with_codex_paths(self):
        text = (SKILLS/'graphify/SKILL.md').read_text()
        self.assertNotIn('Call the Agent tool multiple times', text)
        self.assertNotIn('CLAUDE_CONFIG_DIR', text)
        self.assertIn('$HOME/.agents/skills/graphify/atlas-graphify.sh', text)
        self.assertEqual(text.count('Modified by the codex-bootstrap atlas pack'), 1)
        refs = sorted(p.name for p in (SKILLS/'graphify/references').iterdir())
        self.assertEqual(refs, ['extraction-spec.md', 'query.md', 'update.md'])

    def test_archify_wrapper_sentence_uses_the_codex_path(self):
        text = (SKILLS/'archify/SKILL.md').read_text()
        self.assertIn('$HOME/.agents/skills/atlas-doctor/scripts/atlas-archify.sh', text)
        self.assertNotIn('CLAUDE_CONFIG_DIR', text)
        self.assertNotIn('disable-model-invocation', text)

    def test_pack_yaml_pins_match_the_claude_pack(self):
        text = (PACK/'pack.yaml').read_text()
        self.assertIn('pinned_commit: "1c2b42d660e4a7571813fb43839c79e3e9ca7720"', text)
        self.assertIn('pinned_commit: "b4e6307bf170f27e0cb888c03f4af9308d531a42"', text)
        self.assertIn('install_scope: global', text)
        self.assertIn('skill-agents.md', text)
        self.assertRegex(text, r'(?m)^  external_prerequisites:')
        self.assertEqual(len(re.findall(r'(?m)^    - id: ', text.split('\ncomponents:')[0])), 6)

    def test_scripts_agree_with_the_external_prerequisite_pins(self):
        check = (SKILLS/'atlas-doctor/scripts/atlas-check.sh').read_text()
        runner = (SKILLS/'graphify/atlas-graphify.sh').read_text()
        self.assertIn('GRAPHIFY_PIN="0.9.85"', runner)
        self.assertIn('ATLAS_REA_PIN="6.4.0"', check)
        self.assertIn('ATLAS_NODE_REA_RANGE="^22.19.0 || ^24.11.0 || >=26.0.0"', check)
        yaml = (PACK/'pack.yaml').read_text()
        for pin in ('value: "0.9.85"', 'value: "6.4.0"', 'value: "18"', 'value: "^22.19.0 || ^24.11.0 || >=26.0.0"'):
            self.assertIn(pin, yaml)

    def test_source_map_records_every_derived_file_and_matches_it(self):
        record = json.loads((KIT/'docs/atlas-source-map.json').read_text())
        self.assertRegex(record['source_commit'], r'^[0-9a-f]{40}$')
        self.assertEqual(record['converter'], 'tools/migrate-atlas.mjs')
        listed = {row['destination'] for row in record['files']}
        shipped = {p.relative_to(PACK).as_posix() for p in (PACK/'global').rglob('*') if p.is_file()
                   and p.name != 'openai.yaml' and p.relative_to(PACK/'global').as_posix() != '.agents/references/atlas-pack-notes.md'}
        self.assertEqual(listed, shipped)
        for row in record['files']:
            self.assertEqual(sha(PACK/row['destination']), row['destination_sha256'], row['destination'])

    def vendor_check(self, skills=None):
        args = ['python3', str(KIT/'verification/vendor-check-atlas.py')] + (['--skills', str(skills)] if skills else [])
        return subprocess.run(args, capture_output=True, text=True, timeout=120)

    def test_recorded_patches_reverse_apply_to_the_pinned_upstream_files(self):
        out = self.vendor_check()
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)

    def test_vendor_check_names_a_drifted_or_unrecorded_change(self):
        with tempfile.TemporaryDirectory() as tmp:
            skills = Path(tmp)/'skills'
            shutil.copytree(SKILLS, skills)
            with open(skills/'graphify/SKILL.md', 'a') as handle:
                handle.write('one more line\n')
            out = self.vendor_check(skills)
            self.assertEqual(out.returncode, 1, out.stdout)
            self.assertIn('graphify/SKILL.md', out.stdout)

    @unittest.skipUnless(SOURCE_KIT, 'set ATLAS_SOURCE_KIT to a Claude kit checkout to re-derive the pack')
    def test_converter_rederives_the_committed_pack(self):
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run(['node', str(KIT/'tools/migrate-atlas.mjs'), SOURCE_KIT, '--out', tmp],
                           check=True, capture_output=True, text=True)
            fresh = tree_state(Path(tmp)/'global/.agents/skills')
        # The skills tree, agents/openai.yaml included, is wholly derived; the notes are native.
        self.assertEqual(fresh, tree_state(SKILLS))


class DoctorTests(unittest.TestCase):
    """$atlas-doctor with client codex, against a stub home. It prints and edits nothing."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='atlas-doctor-'))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.home = self.tmp/'home'
        self.work = self.tmp/'work'
        self.work.mkdir()
        shutil.copytree(SKILLS, self.home/'.agents/skills')
        self.codex = self.home/'.codex'
        self.codex.mkdir()
        self.stamp = self.home/'.agents/bootstrap/packs/atlas.json'
        self.stamp.parent.mkdir(parents=True)
        self.stamp.write_text(json.dumps({'format': 1, 'managed': {
            'skills/archify/SKILL.md': '0', 'skills/graphify/SKILL.md': '0'}}))

    def doctor(self, *args, config=None):
        if config is not None:
            (self.codex/'config.toml').write_text(config)
        env = {'PATH': HERMETIC_PATH, 'HOME': str(self.home), 'CODEX_HOME': str(self.codex), 'LC_ALL': 'C'}
        script = self.home/'.agents/skills/atlas-doctor/scripts/doctor.sh'
        return subprocess.run(['bash', str(script), *(args or ('codex',))], cwd=self.work, env=env,
                              capture_output=True, text=True, timeout=120)

    def lines(self, out):
        return out.stdout.splitlines()

    def test_multi_agent_set_is_ok(self):
        out = self.doctor(config='[features]\nmulti_agent = true\n')
        self.assertIn('[ok] multi_agent', self.lines(out))

    def test_multi_agent_missing_prints_the_two_lines_to_add(self):
        out = self.doctor(config='model = "x"\n')
        lines = self.lines(out)
        at = next(i for i, line in enumerate(lines) if line.startswith('[warn] multi_agent'))
        self.assertIn(str(self.codex/'config.toml'), '\n'.join(lines[at:at + 2]))
        self.assertEqual(lines[at + 2:at + 4], ['[features]', 'multi_agent = true'])

    def test_multi_agent_without_a_config_file_is_a_warning_too(self):
        out = self.doctor()
        self.assertTrue(any(line.startswith('[warn] multi_agent') for line in self.lines(out)), out.stdout)

    def test_multi_agent_false_or_in_another_table_is_not_set(self):
        for config in ('[features]\nmulti_agent = false\n',
                       '[features]\nother = 1\n[tools]\nmulti_agent = true\n',
                       '[profiles.x.features]\nmulti_agent = true\n'):
            with self.subTest(config=config):
                out = self.doctor(config=config)
                self.assertTrue(any(line.startswith('[warn] multi_agent') for line in self.lines(out)), out.stdout)

    def test_multi_agent_accepts_comments_spacing_and_the_dotted_form(self):
        for config in ('[features]   # on\nmulti_agent   =   true   # parallel\n',
                       'features.multi_agent = true\n',
                       'model = "x"\n[other]\na = 1\n[features]\nmulti_agent = true\n'):
            with self.subTest(config=config):
                out = self.doctor(config=config)
                self.assertIn('[ok] multi_agent', self.lines(out), out.stdout)

    def test_crlf_inline_table_and_lookalike_tables(self):
        self.assertIn('[ok] multi_agent', self.lines(self.doctor(config='[features]\r\nmulti_agent = true\r\n')))
        self.assertIn('[ok] multi_agent', self.lines(self.doctor(config='features = { x = 1, multi_agent = true }\n')))
        out = self.doctor(config='features = { multi_agent = false }\n')
        self.assertTrue(any(line.startswith('[warn] multi_agent') for line in self.lines(out)))
        for config in ('# [mcp_servers.rea]\n', '[mcp_servers.reactor]\ncommand = "x"\n'):
            out = self.doctor(config=config)
            self.assertTrue(any(line.startswith('[warn] rea-config') for line in self.lines(out)), config)
        self.assertIn('[ok] rea-config', self.lines(self.doctor(config='[mcp_servers]\nrea = { command = "rea" }\n')))
        self.assertIn('[ok] rea-config', self.lines(self.doctor(config='mcp_servers.rea.command = "rea"\n')))

    def test_codex_home_unset_uses_home_dot_codex_and_a_set_one_wins(self):
        (self.codex/'config.toml').write_text('[features]\nmulti_agent = true\n')
        script = self.home/'.agents/skills/atlas-doctor/scripts/doctor.sh'
        env = {'PATH': HERMETIC_PATH, 'HOME': str(self.home), 'LC_ALL': 'C'}
        out = subprocess.run(['bash', str(script), 'codex'], cwd=self.work, env=env, capture_output=True, text=True)
        self.assertIn('[ok] multi_agent', out.stdout.splitlines())
        other = self.tmp/'other-codex'
        other.mkdir()
        out = subprocess.run(['bash', str(script), 'codex'], cwd=self.work, env={**env, 'CODEX_HOME': str(other)}, capture_output=True, text=True)
        self.assertTrue(any(line.startswith('[warn] multi_agent') for line in out.stdout.splitlines()), out.stdout)

    def test_relative_home_or_codex_home_is_refused_not_trusted(self):
        # Both would resolve against the working directory, which is the untrusted repository.
        script = self.home/'.agents/skills/atlas-doctor/scripts/doctor.sh'
        out = subprocess.run(['bash', str(script), 'codex'], cwd=self.work, env={'PATH': HERMETIC_PATH, 'HOME': 'relative-home'},
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 2)
        self.assertIn('HOME is not an absolute path', out.stderr)
        (self.work/'rel').mkdir()
        (self.work/'rel/config.toml').write_text('[features]\nmulti_agent = true\n[mcp_servers.rea]\n')
        out = self.doctor_with({'CODEX_HOME': 'rel'})
        lines = out.stdout.splitlines()
        self.assertTrue(any(line.startswith('[warn] multi_agent: CODEX_HOME is not an absolute path') for line in lines), out.stdout)
        self.assertNotIn('[ok] multi_agent', lines)

    def doctor_with(self, extra):
        env = {'PATH': HERMETIC_PATH, 'HOME': str(self.home), 'LC_ALL': 'C', **extra}
        script = self.home/'.agents/skills/atlas-doctor/scripts/doctor.sh'
        return subprocess.run(['bash', str(script), 'codex'], cwd=self.work, env=env, capture_output=True, text=True, timeout=120)

    def test_rea_entry_in_config_toml(self):
        out = self.doctor(config='[mcp_servers.rea]\ncommand = "rea"\n')
        self.assertIn('[ok] rea-config', self.lines(out))
        out = self.doctor(config='[features]\nmulti_agent = true\n')
        lines = self.lines(out)
        at = next(i for i, line in enumerate(lines) if line.startswith('[warn] rea-config'))
        self.assertIn('rea setup', lines[at + 1])

    def test_run_leaves_home_codex_home_and_config_byte_identical(self):
        config = '[features]\nmulti_agent = true\n[mcp_servers.rea]\ncommand = "rea"\n'
        (self.codex/'config.toml').write_text(config)
        before_home, before_work = tree_state(self.home), tree_state(self.work)
        self.doctor()
        self.assertEqual(tree_state(self.home), before_home)
        self.assertEqual(tree_state(self.work), before_work)
        self.assertEqual((self.codex/'config.toml').read_text(), config)

    def test_unstamped_archify_or_graphify_gets_the_move_line(self):
        self.stamp.write_text(json.dumps({'format': 1, 'managed': {'skills/graphify/SKILL.md': '0'}}))
        out = self.doctor()
        lines = self.lines(out)
        self.assertIn('[ok] migration-unstamped-graphify', lines)
        at = next(i for i, line in enumerate(lines) if line.startswith('[warn] migration-unstamped-archify'))
        move = re.fullmatch(r"Move it out of the skills directory, then install the pack: mkdir -p '(.*)' && mv '(.*)' '(.*)' && codex-bootstrap --global-only --pack atlas", lines[at + 1])
        self.assertTrue(move, lines[at + 1])
        self.assertEqual(move.group(2), str(self.home/'.agents/skills/archify'))
        self.assertEqual(move.group(3), move.group(1) + '/archify')
        self.assertFalse(move.group(3).startswith(str(self.home/'.agents/skills') + '/'))
        self.stamp.unlink()
        out = self.doctor()
        self.assertTrue(any(line.startswith('[warn] migration-unstamped-graphify') for line in self.lines(out)), out.stdout)

    def test_stamped_skills_and_a_graphify_version_file(self):
        out = self.doctor()
        lines = self.lines(out)
        self.assertIn('[ok] migration-unstamped-archify', lines)
        self.assertIn('[ok] migration-unstamped-graphify', lines)
        self.assertIn('[ok] migration-stamp-agents', lines)
        (self.home/'.agents/skills/graphify/.graphify_version').write_text('0.9.0\n')
        out = self.doctor()
        self.assertTrue(any(line.startswith('[warn] migration-stamp-agents') for line in self.lines(out)), out.stdout)

    def test_archify_symlink_is_reported_not_followed(self):
        target = self.tmp/'elsewhere'
        target.mkdir()
        shutil.rmtree(self.home/'.agents/skills/archify')
        (self.home/'.agents/skills/archify').symlink_to(target)
        out = self.doctor()
        self.assertTrue(any(line.startswith('[warn] migration-archify-link') for line in self.lines(out)), out.stdout)
        self.assertEqual(list(target.iterdir()), [])

    def test_codex_hooks_json_and_agents_md_traces(self):
        (self.work/'.codex').mkdir()
        (self.work/'.codex/hooks.json').write_text(json.dumps(
            {'hooks': {'PreToolUse': [{'hooks': [{'type': 'command', 'command': 'graphify hook'}]}]}}))
        (self.work/'AGENTS.md').write_text('# Project\n## graphify\nuse it\n')
        out = self.doctor()
        lines = self.lines(out)
        self.assertTrue(any(line.startswith('[warn] trace-agents-md') for line in lines), out.stdout)
        warn = next(line for line in lines if line.startswith('[warn] trace-codex-hooks'))
        self.assertIn('.codex/hooks.json', warn)
        self.assertIn('codex uninstall', '\n'.join(lines))

    def test_clean_repository_has_ok_trace_lines(self):
        out = self.doctor()
        lines = self.lines(out)
        for check in ('trace-agents-md', 'trace-codex-hooks', 'gitignore-graphify-out', 'gitignore-archify', 'gemini-key'):
            self.assertTrue(any(line.startswith('[ok] ' + check) for line in lines), (check, out.stdout))

    def test_usage_errors(self):
        for args in (('claude',), ('codex', 'extra'), ()):
            with self.subTest(args=args):
                script = self.home/'.agents/skills/atlas-doctor/scripts/doctor.sh'
                out = subprocess.run(['bash', str(script), *args], cwd=self.work, capture_output=True, text=True,
                                     env={'PATH': HERMETIC_PATH, 'HOME': str(self.home)})
                self.assertEqual(out.returncode, 2, out.stdout + out.stderr)
                self.assertIn('usage: doctor.sh codex', out.stderr)

    def test_shared_script_takes_only_the_codex_client(self):
        check = self.home/'.agents/skills/atlas-doctor/scripts/atlas-check.sh'
        env = {'PATH': HERMETIC_PATH, 'HOME': str(self.home)}
        out = subprocess.run(['bash', str(check), 'claude', 'check', 'uv'], cwd=self.work, env=env, capture_output=True, text=True)
        self.assertEqual(out.returncode, 2)
        self.assertIn('usage: atlas-check.sh codex check', out.stderr)
        out = subprocess.run(['bash', str(check), 'codex', 'check', 'no-such'], cwd=self.work, env=env, capture_output=True, text=True)
        self.assertEqual(out.returncode, 2)

    def test_command_text_runs_the_doctor_with_client_codex(self):
        text = (SKILLS/'atlas-doctor/SKILL.md').read_text()
        self.assertIn('"$HOME/.agents/skills/atlas-doctor/scripts/doctor.sh" codex', text)
        self.assertIn('multi_agent', text)


def skill_blocks(marker):
    """Python bodies of the heredoc blocks in graphify/SKILL.md whose first line is `# <marker>`."""
    text = (SKILLS/'graphify/SKILL.md').read_text()
    bodies = [m.group(1) for m in re.finditer(r"<<'GRAPHIFY_PY'\n([\s\S]*?)\nGRAPHIFY_PY\n", text)]
    found = [b for b in bodies if b.startswith('# ' + marker + '\n')]
    assert len(found) == 1, f'{marker}: {len(found)} blocks'
    return found[0]


class GraphifyDispatchTests(unittest.TestCase):
    """Part B of the Graphify skill is Codex-native: chunk files, native subagents, a serial fallback.

    The blocks the skill tells the session to run are executed here against a fixture graphify-out/,
    standing in for the native subagents (or the session itself) by writing the chunk results.
    """

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='atlas-dispatch-'))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.out = self.tmp/'graphify-out'
        self.out.mkdir()

    def run_block(self, marker):
        return subprocess.run(['python3', '-I', '-c', skill_blocks(marker)], cwd=self.tmp, capture_output=True, text=True)

    def uncached(self, files):
        (self.out/'.graphify_uncached.txt').write_text(''.join(f + '\n' for f in files))

    def chunk_files(self):
        return {p.name: p.read_text().split() for p in sorted(self.out.glob('.graphify_chunk_*.files'))}

    def write_result(self, n, nodes=1):
        (self.out/f'.graphify_chunk_{n:02d}.json').write_text(json.dumps(
            {'nodes': [{'id': f'c{n}n{i}'} for i in range(nodes)], 'edges': [], 'hyperedges': [], 'input_tokens': 0, 'output_tokens': 0}))

    def test_no_claude_dispatch_text_is_left_in_graphify_skill(self):
        text = (SKILLS/'graphify/SKILL.md').read_text()
        for gone in ('Task(', 'Task` tool', 'subagent_type', 'Agent tool', 'Agent call', 'Explore', 'general-purpose'):
            self.assertNotIn(gone, text)
        for named in ('spawn_agent', 'wait_agent', 'close_agent', 'multi_agent', '.graphify_chunk_NN.files'):
            self.assertIn(named, text)
        self.assertRegex(text, r'(?i)serial')

    def test_chunk_write_gives_every_chunk_its_own_file_list(self):
        files = [f'docs/d{d}/f{i:02d}.md' for d in range(3) for i in range(20)] + ['img/a.png', 'img/b.jpg']
        self.uncached(files)
        run = self.run_block('atlas-chunk-write')
        self.assertEqual(run.returncode, 0, run.stderr)
        chunks = self.chunk_files()
        self.assertEqual(sorted(sum(chunks.values(), [])), sorted(files))
        self.assertEqual((self.out/'.graphify_chunk_total').read_text().strip(), str(len(chunks)))
        self.assertTrue(all(len(v) <= 25 for v in chunks.values()))
        self.assertIn(['img/a.png'], chunks.values())
        self.assertIn(['img/b.jpg'], chunks.values())
        # Files of one directory sit together: 60 documents in three directories need three chunks, not scattered ones.
        self.assertEqual(len(chunks), 3 + 2)

    def test_chunk_write_clears_a_dead_run_first(self):
        self.write_result(7)
        (self.out/'.graphify_chunk_07.files').write_text('old\n')
        self.uncached(['a.md'])
        self.assertEqual(self.run_block('atlas-chunk-write').returncode, 0)
        self.assertEqual(sorted(p.name for p in self.out.glob('.graphify_chunk_*')),
                         ['.graphify_chunk_01.files', '.graphify_chunk_total'])

    def collect(self):
        return self.run_block('atlas-chunk-collect')

    def prepare(self, total):
        self.uncached([f'a/{i:02d}.md' for i in range(total * 22)])
        self.assertEqual(self.run_block('atlas-chunk-write').returncode, 0)
        self.assertEqual((self.out/'.graphify_chunk_total').read_text().strip(), str(total))

    def test_collect_accepts_a_full_set(self):
        self.prepare(3)
        for n in (1, 2, 3):
            self.write_result(n)
        run = self.collect()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertEqual((self.out/'.graphify_chunk_failed.txt').read_text(), '')

    def test_collect_names_a_missing_chunk_and_the_serial_retry_clears_it(self):
        self.prepare(4)
        for n in (1, 2, 4):
            self.write_result(n)
        run = self.collect()
        self.assertEqual(run.returncode, 3, run.stdout + run.stderr)
        self.assertIn('chunk 3 missing', run.stdout)
        self.assertEqual((self.out/'.graphify_chunk_failed.txt').read_text().split(), ['3'])
        self.write_result(3)  # the session extracts the chunk itself, as the skill says
        run = self.collect()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertEqual((self.out/'.graphify_chunk_failed.txt').read_text(), '')

    def test_collect_sets_an_invalid_chunk_aside_so_the_merge_skips_it(self):
        self.prepare(3)
        self.write_result(1)
        self.write_result(3)
        (self.out/'.graphify_chunk_02.json').write_text('{"nodes": [')
        run = self.collect()
        self.assertEqual(run.returncode, 3, run.stdout)
        self.assertIn('chunk 2', run.stdout)
        self.assertFalse((self.out/'.graphify_chunk_02.json').exists())
        self.assertTrue((self.out/'.graphify_chunk_02.invalid').exists())
        merge = subprocess.run(['python3', '-I', '-c', skill_blocks('atlas-chunk-merge')], cwd=self.tmp, capture_output=True, text=True)
        self.assertEqual(merge.returncode, 0, merge.stderr)
        merged = json.loads((self.out/'.graphify_semantic_new.json').read_text())
        self.assertEqual(sorted(n['id'] for n in merged['nodes']), ['c1n0', 'c3n0'])

    def test_collect_rejects_json_without_nodes_and_edges(self):
        self.prepare(2)
        self.write_result(1)
        (self.out/'.graphify_chunk_02.json').write_text('[]')
        run = self.collect()
        self.assertEqual(run.returncode, 3)
        self.assertTrue((self.out/'.graphify_chunk_02.invalid').exists())

    def test_collect_with_no_chunk_total_is_an_all_cached_run(self):
        # Every file cached: Steps B1 and B2 are skipped and Step B3 still runs. Step B0 cleared the
        # previous run's scratch, so there is no chunk total, and nothing may be reported missing.
        text = (SKILLS/'graphify/SKILL.md').read_text()
        self.assertIn("for stale in Path('graphify-out').glob('.graphify_chunk_*'):", text)
        run = self.collect()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertEqual((self.out/'.graphify_chunk_failed.txt').read_text(), '')

    def test_chunk_numbers_past_nine_use_one_name_everywhere(self):
        text = (SKILLS/'graphify/SKILL.md').read_text()
        self.assertNotIn('chunk_0N', text)
        self.assertIn("graphify_chunk_%02d.json' \"$PROJECT_ROOT\" \"$N\"", text)
        self.prepare(12)
        for n in range(1, 13):
            self.write_result(n)
        run = self.collect()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertTrue((self.out/'.graphify_chunk_10.files').is_file())
        merge = subprocess.run(['python3', '-I', '-c', skill_blocks('atlas-chunk-merge')], cwd=self.tmp, capture_output=True, text=True)
        self.assertEqual(merge.returncode, 0, merge.stderr)
        merged = json.loads((self.out/'.graphify_semantic_new.json').read_text())
        self.assertEqual(len(merged['nodes']), 12)

    def test_workers_are_told_to_write_with_a_file_tool_and_to_treat_files_as_data(self):
        text = (SKILLS/'graphify/SKILL.md').read_text()
        self.assertEqual(text.count('apply_patch'), 2)  # the spawn message and the serial path
        self.assertEqual(text.count('untrusted data'), 2)

    def test_collect_quarantines_results_whose_entries_would_crash_the_merge(self):
        bad = {
            'node without id': {'nodes': [{}], 'edges': []},
            'node that is not an object': {'nodes': ['a'], 'edges': []},
            'node id not a string': {'nodes': [{'id': 3}], 'edges': []},
            'edge without target': {'nodes': [], 'edges': [{'source': 'a'}]},
            'edge that is not an object': {'nodes': [], 'edges': [None]},
            'hyperedges null': {'nodes': [], 'edges': [], 'hyperedges': None},
            'hyperedge not an object': {'nodes': [], 'edges': [], 'hyperedges': [1]},
            'input_tokens null': {'nodes': [], 'edges': [], 'input_tokens': None},
            'output_tokens a string': {'nodes': [], 'edges': [], 'output_tokens': '5'},
            'tokens a boolean': {'nodes': [], 'edges': [], 'input_tokens': True},
        }
        for name, body in bad.items():
            with self.subTest(name):
                shutil.rmtree(self.out)
                self.out.mkdir()
                self.prepare(2)
                self.write_result(1)
                (self.out/'.graphify_chunk_02.json').write_text(json.dumps(body))
                run = self.collect()
                self.assertEqual(run.returncode, 3, run.stdout + run.stderr)
                self.assertIn('chunk 2', run.stdout)
                self.assertTrue((self.out/'.graphify_chunk_02.invalid').exists())
                self.assertEqual((self.out/'.graphify_chunk_failed.txt').read_text().split(), ['2'])
                merge = subprocess.run(['python3', '-I', '-c', skill_blocks('atlas-chunk-merge')], cwd=self.tmp, capture_output=True, text=True)
                self.assertEqual(merge.returncode, 0, merge.stderr)
                merged = json.loads((self.out/'.graphify_semantic_new.json').read_text())
                self.assertEqual([n['id'] for n in merged['nodes']], ['c1n0'])  # only the good chunk reaches the merge

    def test_a_quarantined_result_is_cleared_by_the_serial_retry(self):
        self.prepare(2)
        self.write_result(1)
        (self.out/'.graphify_chunk_02.json').write_text(json.dumps({'nodes': [{}], 'edges': []}))
        self.assertEqual(self.collect().returncode, 3)
        self.assertEqual((self.out/'.graphify_chunk_failed.txt').read_text().split(), ['2'])
        self.write_result(2)  # the session extracts the chunk itself, as the skill says
        run = self.collect()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertEqual((self.out/'.graphify_chunk_failed.txt').read_text(), '')
        merge = subprocess.run(['python3', '-I', '-c', skill_blocks('atlas-chunk-merge')], cwd=self.tmp, capture_output=True, text=True)
        self.assertEqual(merge.returncode, 0, merge.stderr)
        merged = json.loads((self.out/'.graphify_semantic_new.json').read_text())
        self.assertEqual(sorted(n['id'] for n in merged['nodes']), ['c1n0', 'c2n0'])  # the stale .invalid file is not merged

    def test_collect_accepts_a_result_that_omits_hyperedges_and_token_counts(self):
        self.prepare(1)
        (self.out/'.graphify_chunk_01.json').write_text(json.dumps({'nodes': [{'id': 'a'}], 'edges': []}))
        run = self.collect()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_collect_accepts_a_full_result_with_edges_hyperedges_and_tokens(self):
        self.prepare(1)
        (self.out/'.graphify_chunk_01.json').write_text(json.dumps({
            'nodes': [{'id': 'a', 'label': 'A'}, {'id': 'b'}],
            'edges': [{'source': 'a', 'target': 'b', 'relation': 'uses'}],
            'hyperedges': [{'id': 'h', 'nodes': ['a', 'b']}],
            'input_tokens': 0, 'output_tokens': 0}))
        run = self.collect()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_collect_stops_when_more_than_half_failed(self):
        self.prepare(4)
        self.write_result(1)
        self.write_result(2)
        self.assertEqual(self.collect().returncode, 3)  # exactly half is not more than half
        (self.out/'.graphify_chunk_02.json').unlink()
        run = self.collect()
        self.assertEqual(run.returncode, 4, run.stdout)
        self.assertEqual((self.out/'.graphify_chunk_failed.txt').read_text().split(), ['2', '3', '4'])



if __name__ == '__main__':
    unittest.main()
