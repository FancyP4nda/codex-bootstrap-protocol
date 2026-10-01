"""Negative acceptance fixtures for the separately opt-in native hook smoke."""
import copy
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

spec = importlib.util.spec_from_file_location('trusted_hook_smoke', Path(__file__).with_name('trusted-hook-smoke.py'))
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class NativeHookAcceptance(unittest.TestCase):
    @unittest.skipUnless(shutil.which('codex') and shutil.which('node'), 'Actual disposable EOF check requires Codex and Node')
    def test_closed_input_aborts_without_advancing_trust(self):
        result = subprocess.run([sys.executable, str(Path(__file__).with_name('trusted-hook-smoke.py'))],
                                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Trust/delivery check was not completed', result.stderr)
        self.assertNotIn('Native trust observation:', result.stdout)

    def event(self, entries=None):
        return {'method': 'hook/completed', 'params': {'threadId': 'thread', 'run': {
            'eventName': 'stop', 'sourcePath': '/fixture/.codex/hooks.json',
            'handlerType': 'command', 'status': 'completed', 'entries': entries or []}}}

    def check(self, events, warning):
        smoke.validate_stop_completion(events, 'thread', '/fixture/.codex/hooks.json', warning)

    def test_failed_hook_text_is_not_delivery(self):
        event = self.event([{'kind': 'error', 'text': 'font hook unsupported output'}])
        event['params']['run']['status'] = 'failed'
        with self.assertRaises(RuntimeError): self.check([event], True)

    def test_absent_repeat_hook_is_not_deduplication(self):
        with self.assertRaises(RuntimeError): self.check([], False)

    def test_exact_successful_warning_then_executed_silent_repeat(self):
        event = self.event([{'kind': 'warning', 'text':
            '[impeccable@1] Design hook findings requiring review in ui.css (1 issue(s)): [overused-font] Inter'}])
        self.check([event], True)
        self.check([self.event()], False)
        for field, value in [('eventName', 'postToolUse'), ('sourcePath', '/other/hooks.json'),
                             ('status', 'failed'), ('handlerType', 'prompt')]:
            wrong = copy.deepcopy(event)
            wrong['params']['run'][field] = value
            with self.subTest(field=field), self.assertRaises(RuntimeError): self.check([wrong], True)
