#!/usr/bin/env python3
"""Offline real Codex discovery/configuration/trust integration in a temp home."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from test_installer import BD_MOCK, KIT


def run():
    codex=shutil.which('codex')
    if not codex: raise RuntimeError('Codex CLI is required for real integration')
    with tempfile.TemporaryDirectory(prefix='codex-cli-integration-') as tmp:
        root=Path(tmp); home=root/'home'; home.mkdir(); bin=root/'bin'; bin.mkdir()
        bd=bin/'bd'; bd.write_text(BD_MOCK); bd.chmod(0o755)
        project=root/'project'
        env={**os.environ,'HOME':str(home),'CODEX_HOME':str(home/'.codex'),'CI':'1',
             'PATH':str(bin)+os.pathsep+os.environ['PATH']}
        result=subprocess.run([str(KIT/'bootstrap'),str(project),'--prefix','CLI','--non-interactive',
                               '--pack','falcon','--pack','herald','--pack','web-design','--allow-unverified-pack',
                               '--promote-global','--status-line','--notifications','--hooks'],
                              env=env,capture_output=True,text=True,timeout=90)
        if result.returncode: raise RuntimeError(result.stdout+result.stderr)
        captured=[]
        def strings(value):
            if isinstance(value,str): return [value]
            if isinstance(value,dict): return [s for item in value.values() for s in strings(item)]
            if isinstance(value,list): return [s for item in value for s in strings(item)]
            return []
        class MockProvider(BaseHTTPRequestHandler):
            def log_message(self,*args): pass
            def do_POST(self):
                captured.append(json.loads(self.rfile.read(int(self.headers['Content-Length']))))
                message={'id':'msg_bootstrap','type':'message','role':'assistant','status':'completed',
                         'content':[{'type':'output_text','text':'Native skills loaded.','annotations':[]}]}
                events=[('response.created',{'response':{'id':'resp_bootstrap','status':'in_progress','output':[]}}),
                        ('response.output_item.added',{'output_index':0,'item':{**message,'status':'in_progress','content':[]}}),
                        ('response.output_text.delta',{'item_id':'msg_bootstrap','output_index':0,'content_index':0,'delta':'Native skills loaded.'}),
                        ('response.output_item.done',{'output_index':0,'item':message}),
                        ('response.completed',{'response':{'id':'resp_bootstrap','status':'completed','output':[message],
                                                         'usage':{'input_tokens':1,'output_tokens':1,'total_tokens':2}}})]
                self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.end_headers()
                for event,data in events:
                    self.wfile.write((f'event: {event}\ndata: '+json.dumps({'type':event,**data})+'\n\n').encode())
                    self.wfile.flush()
        provider=ThreadingHTTPServer(('127.0.0.1',0),MockProvider)
        threading.Thread(target=provider.serve_forever,daemon=True).start()
        model_config=['-c','model_provider="bootstrap_mock"','-c','model="bootstrap-test"',
                      '-c','model_providers.bootstrap_mock.name="Disposable Mock"',
                      '-c',f'model_providers.bootstrap_mock.base_url="http://127.0.0.1:{provider.server_port}/v1"',
                      '-c','model_providers.bootstrap_mock.wire_api="responses"',
                      '-c','model_providers.bootstrap_mock.requires_openai_auth=false']
        with (root/'server-errors.log').open('w') as err:
            server=subprocess.Popen([codex,'app-server','--strict-config','--stdio',*model_config],env=env,cwd=project,
                                    stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=err,text=True,bufsize=1)
            selector=selectors.DefaultSelector(); selector.register(server.stdout,selectors.EVENT_READ)
            counter=0
            def request(method,params):
                nonlocal counter
                counter+=1; identifier=counter
                server.stdin.write(json.dumps({'id':identifier,'method':method,'params':params})+'\n'); server.stdin.flush()
                deadline=time.monotonic()+30
                while time.monotonic()<deadline:
                    if not selector.select(timeout=0.25):
                        if server.poll() is not None: break
                        continue
                    line=server.stdout.readline()
                    if not line: break
                    value=json.loads(line)
                    if value.get('id')==identifier:
                        if 'error' in value: raise RuntimeError(value['error'])
                        return value.get('result')
                raise RuntimeError(f'app-server did not answer {method}: '+(root/'server-errors.log').read_text())
            try:
                request('initialize',{'clientInfo':{'name':'bootstrap-verification','version':'1.0.0'},
                                      'capabilities':{'experimentalApi':True}})
                server.stdin.write(json.dumps({'method':'initialized'})+'\n'); server.stdin.flush()
                skills=request('skills/list',{'cwds':[str(project)],'forceReload':True})
                found=[]
                def collect(value):
                    if isinstance(value,dict):
                        if 'name' in value and 'path' in value: found.append(value)
                        for item in value.values(): collect(item)
                    elif isinstance(value,list):
                        for item in value: collect(item)
                collect(skills)
                expected={p.parent.name for p in (KIT/'assets').rglob('SKILL.md')}
                actual={v['name'] for v in found}
                missing=expected-actual
                if missing: raise RuntimeError(f'CLI failed to discover {missing}; result: {skills}')
                thread=request('thread/start',{'cwd':str(project),'ephemeral':True,'sandbox':'read-only','approvalPolicy':'never'})
                skill_inputs=[{'type':'skill','name':v['name'],'path':v['path']} for v in found if v['name'] in expected]
                request('turn/start',{'threadId':thread['thread']['id'],
                                     'input':[{'type':'text','text':'Load explicit skills for offline verification only; do not run tools.'},*skill_inputs]})
                deadline=time.monotonic()+30
                while not captured and time.monotonic()<deadline: time.sleep(0.05)
                if not captured: raise RuntimeError('Real CLI did not invoke the mock model with explicit skills')
                request_text='\n'.join(strings(captured))
                invoked=[]
                for skill in (KIT/'assets').rglob('SKILL.md'):
                    body=skill.read_text().split('---',2)[-1].strip()
                    if body not in request_text: raise RuntimeError(f'Explicit ${skill.parent.name} did not expand canonical instructions')
                    invoked.append(skill.parent.name)
                hooks=request('hooks/list',{'cwds':[str(project)]})
                config=request('config/read',{'cwd':str(project),'includeLayers':True})
                config_data=config.get('config',{})
                footer=config_data.get('tui',{}).get('status_line')
                expected_footer=['model-with-reasoning','context-remaining','git-branch','current-dir']
                if footer != expected_footer: raise RuntimeError(f'Native footer mismatch: {footer}')
                # Trust metadata is an observation; this test never calls hooks/write.
                if 'Codex bootstrap orientation' not in json.dumps(hooks):
                    raise RuntimeError(f'CLI did not discover the orientation hook: {hooks}')
                if 'untrusted' not in json.dumps(hooks): raise RuntimeError('Expected untrusted hook definitions')
                print(json.dumps({'cli':subprocess.check_output([codex,'--version'],env=env,text=True).strip(),
                                  'skills':sorted(expected),'hook_trust':'untrusted',
                                  'explicit_skill_invocations':sorted(invoked),
                                  'native_footer':footer,'notifications':config_data.get('tui',{}).get('notifications')},indent=2))
            finally:
                selector.close(); server.terminate()
                try: server.wait(timeout=5)
                except subprocess.TimeoutExpired: server.kill(); server.wait()
                provider.shutdown(); provider.server_close()


if __name__=='__main__': run()
