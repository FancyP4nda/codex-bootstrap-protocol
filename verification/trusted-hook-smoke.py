#!/usr/bin/env python3
"""Opt-in real /hooks review and Stop delivery, using only a loopback model.

Run interactively after explicit permission. Type UI keys as lines, or :check
after approving the one disposable handler through /hooks. No trust bypass,
credentials, personal home/configuration or external model is used.
"""
import json
import os
from pathlib import Path
import pty
import re
import select
import selectors
import shutil
import struct
import subprocess
import sys
import tempfile
import termios
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

KIT = Path(__file__).resolve().parents[1]


def validate_stop_completion(observed, thread, source, expect_warning):
    """Require delivered native evidence, not text matching or an absent event."""
    completed = [event['params']['run'] for event in observed
                 if event.get('method') == 'hook/completed'
                 and event.get('params', {}).get('threadId') == thread
                 and event.get('params', {}).get('run', {}).get('eventName') == 'stop'
                 and event['params']['run'].get('sourcePath') == source]
    if len(completed) != 1:
        raise RuntimeError('Expected exactly one completed native Stop handler')
    run = completed[0]
    if run.get('status') != 'completed' or run.get('handlerType') != 'command':
        raise RuntimeError('Native Stop handler did not successfully complete')
    entries = run.get('entries')
    if not isinstance(entries, list) or any(entry.get('kind') == 'error' for entry in entries):
        raise RuntimeError('Native Stop handler delivered invalid/error entries')
    warnings = [entry for entry in entries if entry.get('kind') == 'warning']
    if expect_warning:
        if len(warnings) != 1 or not warnings[0].get('text', '').startswith('[impeccable@1] Design hook findings requiring review in ui.css'):
            raise RuntimeError('Bundled Stop systemMessage warning was not delivered')
        if '[overused-font]' not in warnings[0]['text']:
            raise RuntimeError('Expected bundled detector finding was not delivered')
    elif warnings:
        raise RuntimeError('Repeat Stop warning was not deduplicated')


def main():
    with tempfile.TemporaryDirectory(prefix='codex-trusted-hook-smoke-') as temporary:
        root = Path(temporary)
        home, project = root / 'home', root / 'project'
        home.mkdir(); project.mkdir(); (home / '.codex').mkdir()
        skill = project / '.agents/skills/impeccable'
        shutil.copytree(KIT / 'assets/packs/web-design/scaffold/.agents/skills/impeccable', skill)
        subprocess.run(['git', 'init', '-q', str(project)], check=True)
        env = {**os.environ, 'HOME': str(home), 'CODEX_HOME': str(home / '.codex'),
               'TERM': 'xterm-256color', 'CI': '1', 'IMPECCABLE_NO_UPDATE_CHECK': '1',
               'IMPECCABLE_NO_TELEMETRY': '1'}
        subprocess.run(['node', str(skill / 'scripts/hook-admin.mjs'), 'on'],
                       cwd=project, env=env, check=True, capture_output=True)
        # Review/trust exactly the bundled Stop command, with no unrelated hook.
        manifest = project / '.codex/hooks.json'
        data = json.loads(manifest.read_text())
        data['hooks'].pop('PostToolUse')
        manifest.write_text(json.dumps(data, indent=2) + '\n')
        (project / 'ui.css').write_text('body { font-family: Inter; }\n')
        captures = []
        class Provider(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass
            def do_POST(self):
                captures.append(json.loads(self.rfile.read(int(self.headers['Content-Length']))))
                message = {'id': 'msg_hook', 'type': 'message', 'role': 'assistant',
                           'status': 'completed', 'content': [{'type': 'output_text',
                           'text': 'Disposable hook delivery check.', 'annotations': []}]}
                events = [('response.created', {'response': {'id': 'resp_hook', 'status': 'in_progress', 'output': []}}),
                          ('response.output_item.added', {'output_index': 0, 'item': {**message, 'status': 'in_progress', 'content': []}}),
                          ('response.output_text.delta', {'item_id': 'msg_hook', 'output_index': 0, 'content_index': 0, 'delta': 'Disposable hook delivery check.'}),
                          ('response.output_item.done', {'output_index': 0, 'item': message}),
                          ('response.completed', {'response': {'id': 'resp_hook', 'status': 'completed', 'output': [message],
                                                              'usage': {'input_tokens': 1, 'output_tokens': 1, 'total_tokens': 2}}})]
                self.send_response(200); self.send_header('Content-Type', 'text/event-stream'); self.end_headers()
                for event, payload in events:
                    self.wfile.write((f'event: {event}\ndata: ' + json.dumps({'type': event, **payload}) + '\n\n').encode())
                    self.wfile.flush()
        provider = ThreadingHTTPServer(('127.0.0.1', 0), Provider)
        threading.Thread(target=provider.serve_forever, daemon=True).start()
        config = ['-c', 'model_provider="hook_mock"', '-c', 'model="hook-test"',
                  '-c', 'model_providers.hook_mock.name="Disposable Mock"',
                  '-c', f'model_providers.hook_mock.base_url="http://127.0.0.1:{provider.server_port}/v1"',
                  '-c', 'model_providers.hook_mock.wire_api="responses"',
                  '-c', 'model_providers.hook_mock.requires_openai_auth=false',
                  '-c', 'features.hooks=true']
        master, slave = pty.openpty()
        fcntl = __import__('fcntl')
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 160, 0, 0))
        tui = subprocess.Popen(['codex', '--no-daemon', '--no-alt-screen', '-C', str(project), *config],
                               env=env, stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        print(f'Disposable fixture: {root}\nOnly hook reviewed: {data["hooks"]["Stop"][0]["hooks"][0]["command"]}', flush=True)
        print('Enter UI text as a line. :enter, :up, :down, :escape, :trust send keys. :check exits TUI and verifies trusted delivery. :quit aborts.', flush=True)
        check = False
        try:
            deadline = time.monotonic() + 300
            while tui.poll() is None and time.monotonic() < deadline:
                ready = select.select([master, sys.stdin], [], [], 0.2)[0]
                if master in ready:
                    try: chunk = os.read(master, 65536)
                    except OSError: break
                    # Keep visible text; suppress terminal control sequences.
                    print(re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', chunk.decode(errors='replace')), end='', flush=True)
                if sys.stdin in ready:
                    raw = sys.stdin.readline()
                    if raw == '':
                        break  # EOF is abort, never implicit Enter or consent.
                    line = raw.rstrip('\n')
                    if line in (':check', ':quit'):
                        check = line == ':check'; break
                    keys = {':enter': b'\r', ':up': b'\x1b[A', ':down': b'\x1b[B', ':escape': b'\x1b', ':trust': b't'}
                    os.write(master, keys.get(line, (line + '\r').encode()))
        finally:
            tui.terminate()
            try: tui.wait(timeout=5)
            except subprocess.TimeoutExpired: tui.kill(); tui.wait()
            os.close(master)
        try:
            if not check:
                raise RuntimeError('Trust/delivery check was not completed')
            verify(project, skill, env, config, captures)
        finally:
            provider.shutdown(); provider.server_close()


def verify(project, skill, env, config, captures):
    server = subprocess.Popen(['codex', 'app-server', '--strict-config', '--stdio', *config],
                              env=env, cwd=project, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, bufsize=0)
    selector = selectors.DefaultSelector(); selector.register(server.stdout, selectors.EVENT_READ)
    events = []
    identifier = 0
    buffered = b''
    def read_until(predicate):
        nonlocal buffered
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if b'\n' not in buffered:
                if not selector.select(0.2): continue
                chunk = os.read(server.stdout.fileno(), 65536)
                if not chunk: break
                buffered += chunk
                continue
            line, buffered = buffered.split(b'\n', 1)
            value = json.loads(line); events.append(value)
            if predicate(value): return value
        raise RuntimeError('Timed out waiting for real Codex event; last event methods: ' +
                           repr([event.get('method', event.get('id')) for event in events[-8:]]))
    def request(method, params):
        nonlocal identifier
        identifier += 1
        server.stdin.write((json.dumps({'id': identifier, 'method': method, 'params': params}) + '\n').encode()); server.stdin.flush()
        result = read_until(lambda value: value.get('id') == identifier)
        if 'error' in result: raise RuntimeError(result['error'])
        return result['result']
    try:
        request('initialize', {'clientInfo': {'name': 'hook-smoke', 'version': '1'}, 'capabilities': {'experimentalApi': True}})
        server.stdin.write(b'{"method":"initialized"}\n'); server.stdin.flush()
        hooks = request('hooks/list', {'cwds': [str(project)]})
        print('Native trust observation: ' + json.dumps(hooks), flush=True)
        handlers = [hook for entry in hooks['data'] for hook in entry['hooks']]
        if len(handlers) != 1 or handlers[0]['trustStatus'] != 'trusted' or handlers[0]['enabled'] is not True:
            raise RuntimeError('UI did not establish one enabled trusted handler; refusing to bypass')
        if handlers[0]['eventName'] != 'stop' or handlers[0]['sourcePath'] != str(project / '.codex/hooks.json'):
            raise RuntimeError('Native trusted hook identity did not match disposable Stop fixture')
        thread = request('thread/start', {'cwd': str(project), 'ephemeral': True, 'sandbox': 'read-only', 'approvalPolicy': 'never'})['thread']['id']
        file = project / 'ui.css'
        (project / '.impeccable/hook.cache.json').write_text(json.dumps({'version': 1, 'sessions': {thread: {
            'updatedAt': 1, 'files': {str(file): {'editCount': 1, 'findings': []}}}}}))
        for turn in range(2):
            start = len(events)
            request('turn/start', {'threadId': thread, 'input': [{'type': 'text', 'text': 'Return one sentence. Do not run tools.'}]})
            completion = read_until(lambda value: value.get('method') == 'turn/completed')
            if completion['params']['turn']['status'] != 'completed':
                raise RuntimeError('Disposable model turn did not complete successfully')
            observed = events[start:]
            print(f'Turn {turn + 1} hook evidence: ' + json.dumps([event for event in observed if 'hook' in event.get('method', '').lower()]), flush=True)
            validate_stop_completion(observed, thread, str(project / '.codex/hooks.json'), turn == 0)
        if len(captures) != 2: raise RuntimeError('Unexpected continuation/model request count')
        if 'Design hook findings requiring review' in json.dumps(captures):
            raise RuntimeError('Advisory Stop warning unexpectedly entered model context')
        print(json.dumps({'trusted_stop_delivery': 'passed', 'repeat_deduplication': 'passed',
                          'model_requests': len(captures), 'automatic_continuation': False,
                          'provider': 'loopback mock; real Codex native hook client',
                          'personal_configuration_changed': False}), flush=True)
    finally:
        selector.close(); server.terminate()
        try: server.wait(timeout=5)
        except subprocess.TimeoutExpired: server.kill(); server.wait()


if __name__ == '__main__':
    main()
