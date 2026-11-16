import json,sys
from pathlib import Path
from mcp_client import execute
BASE=Path(__file__).resolve().parent.parent
SCRIPT=str(BASE/'_Library/audit_export.py').replace('\\','/')
ORDER=['Vandal','Classic','Bulldog','Phantom','Guardian','Stinger','Spectre','Shorty','Ghost','Sheriff','Judge','Bucky','Marshal','Outlaw','Operator','Ares','Odin','Knife']
def call(expr):
    code=f"p={SCRIPT!r}\nexec(compile(open(p,encoding='utf-8').read(),p,'exec'))\nresult={expr}\n"
    r=execute(code)
    if r.get('status')!='ok': raise RuntimeError(json.dumps(r,indent=2))
    return r['result']
mode=sys.argv[1] if len(sys.argv)>1 else 'audit'
if mode=='lineup':
    print(json.dumps(call('lineup()')),flush=True)
    print(json.dumps(call('lineup(True)')),flush=True)
elif mode=='style':
    from run_remaster import style_sheet
    style_sheet()
else:
    reports=[]
    for gun in sys.argv[2:] or ORDER:
        r=call(f'{mode}({gun!r})'); reports.append(r)
        compact={k:r[k] for k in ['gun','passed','errors','tris'] if k in r}
        if mode=='export': compact=r
        print(json.dumps(compact),flush=True)
    (BASE/'_Library'/f'{mode}-summary.json').write_text(json.dumps(reports,indent=2))
