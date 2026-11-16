"""Final audits, changed exports, local re-import, lineups and handoff."""
import json
from pathlib import Path
from mcp_client import execute
BASE=Path(__file__).resolve().parent.parent
SCRIPT=str(BASE/'_Library/audit_export.py').replace('\\','/')
ORDER=['Vandal','Classic','Bulldog','Phantom','Guardian','Stinger','Spectre','Shorty','Ghost','Sheriff','Judge','Bucky','Marshal','Outlaw','Operator','Ares','Odin','Knife']
def call(expr):
    r=execute(f"p={SCRIPT!r}\nexec(compile(open(p,encoding='utf-8').read(),p,'exec'))\nresult={expr}\n")
    if r.get('status')!='ok': raise RuntimeError(json.dumps(r))
    return r['result']
changed=['Sheriff','Bucky','Marshal','Outlaw','Operator','Ares']
for gun in changed:
    a=call(f'audit({gun!r})'); print('AUDIT '+gun+' '+str(a['passed']),flush=True)
    if not a['passed']: raise RuntimeError(str(a['errors']))
    e=call(f'export({gun!r})'); print('EXPORTED '+gun,flush=True)
for gun in ORDER:
    r=call(f'roundtrip({gun!r})'); print('FBX CHECK '+gun+' '+str(r['passed']),flush=True)
    if not r['passed']: raise RuntimeError(str(r['errors']))
print(json.dumps(call('lineup()')),flush=True)
print(json.dumps(call('lineup(True)')),flush=True)
for kind,filename in [('audit','audit.json'),('roundtrip','export-check.json')]:
    reports=[json.loads((BASE/gun/filename).read_text()) for gun in ORDER]
    (BASE/'_Library'/f'{kind}-summary.json').write_text(json.dumps(reports,indent=2))
import finish_handoff
