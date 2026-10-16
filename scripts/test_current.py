"""Run the redistributable RTL checks against the selected candidate, not rtl/custom."""
from pathlib import Path
import argparse, datetime, hashlib, json, os, shutil, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
Q = ROOT / 'qa/sc520cs_frame_awb_trial_20261016'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--iverilog-bin', type=Path)
    ap.add_argument('--full', action='store_true')
    args = ap.parse_args()
    bindir = args.iverilog_bin or (Path(os.environ['IVERILOG_BIN']) if 'IVERILOG_BIN' in os.environ else None)
    def tool(name):
        found = str(bindir / (name + ('.exe' if os.name == 'nt' else ''))) if bindir else shutil.which(name)
        if not found or not Path(found).is_file():
            raise SystemExit('Missing simulator; pass --iverilog-bin or set IVERILOG_BIN/PATH')
        return found
    iv, vv = tool('iverilog'), tool('vvp')
    rtl = Q / 'rtl/custom'
    cases = [
        ('frame_awb_small', 'tb_frame_awb', Q/'tb_frame_awb.v', ['custom_frame_awb.v'], [], 'RESULT FRAME_AWB'),
        ('awb_key', 'tb_awb_key_gesture', Q/'tb_awb_key_gesture.v', ['custom_key_mode_request.v'], [], 'RESULT AWB_KEY'),
        ('awb_status', 'tb_awb_status_cdc', Q/'tb_awb_status_cdc.v', ['custom_diag_snapshot_cdc.v'], [], 'RESULT AWB_STATUS'),
        ('closed_ae', 'tb_closed_loop_ae', Q/'tb_closed_loop_ae.v', ['custom_ae_frame_stats.v','custom_closed_loop_ae.v','custom_diag_snapshot_cdc.v','custom_csi_sof_events.v'], [], 'RESULT'),
        ('ae_stats', 'tb_ae_stats', Q/'tb_ae_stats.v', ['custom_ae_frame_stats.v'], [], 'RESULT'),
        ('four_modes', 'tb_custom_processing_top', ROOT/'sim/custom/tb_custom_processing_top.v', ['custom_processing_top.v','custom_gray_threshold.v','custom_rgb_to_gray.v','custom_sobel_4px.v','custom_awb_sof_aligner.v'], [], 'PASS: processing top'),
    ]
    if args.full:
        cases.append(('frame_awb_full','tb_frame_awb',Q/'tb_frame_awb.v',['custom_frame_awb.v'],['-DFULL_FRAME'],'RESULT FRAME_AWB'))
    out = ROOT/'build/current_tests'/datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    out.mkdir(parents=True,exist_ok=False)
    env = os.environ.copy()
    env.update(TMP=str(out), TEMP=str(out))
    print('Evidence:',out.relative_to(ROOT).as_posix(),flush=True)
    results=[]
    for label, top, tb, names, defines, marker in cases:
        sources=[tb]+[rtl/n for n in names]
        image=out/(label+'.vvp')
        cc=subprocess.run([iv,'-g2005','-Wall','-s',top,*defines,'-o',str(image),*map(str,sources)],capture_output=True,text=True,env=env)
        rc=subprocess.run([vv,str(image)],capture_output=True,text=True,timeout=300,env=env) if cc.returncode==0 else None
        raw=cc.stdout+cc.stderr+(rc.stdout+rc.stderr if rc else '')
        (out/(label+'.log')).write_text(raw,encoding='utf-8')
        passed=cc.returncode==0 and rc is not None and rc.returncode==0 and marker in raw and 'errors=0' in raw
        lines=[s for s in raw.splitlines() if 'RESULT' in s or 'PASS' in s or 'FAIL' in s]
        row=dict(case=label,passed=passed,compile_exit=cc.returncode,run_exit=rc.returncode if rc else None,results=lines,
                 sources=[dict(path=p.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest().upper()) for p in sources])
        results.append(row);print(label,passed,lines,flush=True)
    (out/'summary.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    return 0 if all(r['passed'] for r in results) else 1

if __name__=='__main__':
    sys.exit(main())
