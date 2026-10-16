"""Read-only source/IP/build dependency and selected bit verification."""
from pathlib import Path
import argparse, csv, hashlib, json, re, sys

ROOT=Path(__file__).resolve().parents[1]
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--local',action='store_true',help='Also require restricted local dependencies and programming image')
    args=ap.parse_args()
    cfg=json.loads((ROOT/'release/current.json').read_text(encoding='utf-8'))
    bad=[];checked=withheld=0
    for row in csv.DictReader((ROOT/'release/dependencies.csv').open(encoding='utf-8')):
        p=ROOT/row['path']
        if row['distribution']=='local-only' and not args.local:
            withheld+=1;continue
        if not p.is_file():bad.append('MISSING '+row['path']);continue
        if p.stat().st_size!=int(row['bytes']) or hashlib.file_digest(p.open('rb'),'sha256').hexdigest().upper()!=row['sha256']:
            bad.append('CHANGED '+row['path'])
        checked+=1
    if args.local and (ROOT/cfg['project_entry']).is_file():
        al=ROOT/cfg['project_entry'];text=al.read_text(encoding='utf-8-sig')
        entries=re.findall(r'<File Path="([^"]+)">(.*?)</File>',text,re.S)
        if len(entries)!=70:bad.append('Wrong .al entry count')
        for name,body in entries:
            if not (al.parent/name).resolve().is_file():bad.append('Broken .al path '+name)
        bit=ROOT/cfg['bit']['path']
        if not bit.is_file() or bit.stat().st_size!=cfg['bit']['bytes'] or hashlib.file_digest(bit.open('rb'),'sha256').hexdigest().upper()!=cfg['bit']['sha256']:
            bad.append('Selected bit mismatch')
    for msg in bad[:10]:print(msg)
    print(json.dumps(dict(status='fail' if bad else 'pass',checked=checked,withheld=withheld,errors=len(bad),local=args.local)))
    return bool(bad)
if __name__=='__main__':sys.exit(main())
