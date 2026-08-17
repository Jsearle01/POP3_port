#!/usr/bin/env python3
"""PA.9 driver — throwaway. Real POP cels for cost/byte-class; a real Karateka cel
WITH an authored opacity.s sidecar to exercise opaque-black on genuine data."""
import pathlib, collections, sys, re
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from popcc import (load_table, hgr_pixels, hgr_to_coco, tokenize, pack,
                   Compiler, simulate, cycles, T)

IMG = pathlib.Path(r"C:/Projects/POP3_port/oracle/source/01 POP Source/Images")
KAR = pathlib.Path(r"C:/Projects/karateka_coco3/content")

def compile_and_check(px, op, label):
    tok = tokenize(px, op); pk = pack(tok)
    c = Compiler(); ins = c.compile_cel(pk); cyc = cycles(ins)
    cls = collections.Counter(b[2] for r in pk for b in r)
    tot = sum(cls.values()); drawn = tot - cls['skip']
    bad = simulate(ins, pk)
    return dict(label=label, tot=tot, skip=cls['skip'], store=cls['store'],
                mixed=cls['mixed'], cyc=cyc, ins=len(ins), bad=bad, drawn=drawn)

def show(r):
    ok = 'OK' if not r['bad'] else f"FAIL({len(r['bad'])})"
    print(f"  {r['label']:34s} bytes {r['tot']:4d} "
          f"(skip {r['skip']:4d} store {r['store']:4d} mixed {r['mixed']:3d})  "
          f"instr {r['ins']:4d} cyc {r['cyc']:6d}  "
          f"cy/B-foot {r['cyc']/r['tot']:5.2f}  cy/B-drawn {r['cyc']/max(1,r['drawn']):5.2f}  {ok}")
    for y,x,k,w,g in r['bad'][:2]:
        print(f"        MISMATCH r{y} c{x} [{k}] want ${w:02X} got ${g:02X}")

# ---------------- N2: real POP cels ----------------
print("=== N2 — real POP cels (CHTAB1/2/3 kid, CHTAB4.GD guard) ===")
res=[]
for tab in ("IMG.CHTAB1","IMG.CHTAB2","IMG.CHTAB3","IMG.CHTAB4.GD"):
    cels = load_table(IMG/tab)
    s = sorted(cels, key=lambda c:c['w']*c['h'])
    for cel,kind in ((s[-1],'large'), (s[len(s)//2],'median'), (s[len(s)//8],'thin')):
        px,op = hgr_to_coco(hgr_pixels(cel))
        r = compile_and_check(px,op,f"{tab.replace('IMG.','')} #{cel['idx']} {cel['w']*7}x{cel['h']} {kind}")
        res.append(r); show(r)

# ---------------- N3: real Karateka cel + authored sidecar ----------------
def load_kar(cel_dir):
    txt=(cel_dir/"converted.s").read_text(errors="replace")
    vals=[]
    for l in txt.splitlines():
        l=l.split(';',1)[0]
        if re.search(r'\bfcb\b',l,re.I):
            for v in re.findall(r'\$?([0-9A-Fa-f]{1,2})\b',l.split('fcb',1)[1]):
                vals.append(int(v,16) if '$' in l else int(v,16))
    h,w=vals[0],vals[1]; data=vals[2:2+h*w]
    px=[[ (data[r*w+c]>>(6-2*k))&3 for c in range(w) for k in range(4)] for r in range(h)]
    return h,w,px

def load_opacity(cel_dir,h,w):
    p=cel_dir/"opacity.s"
    op=[[False]*(w*4) for _ in range(h)]
    if not p.exists(): return op,'none'
    txt=p.read_text(errors="replace")
    fcb=[l.split(';',1)[0] for l in txt.splitlines() if re.search(r'^\s*fcb\s',l)]
    if '_opacity_mixed:' in txt:
        for l in fcb:
            n=[int(v) for v in re.findall(r'\b(\d+)\b',l)]
            if len(n)>=5 and n[1]!=0:
                sc,wd,sr,nr,opq=n[:5]
                if opq:
                    for r in range(sr,min(sr+nr,h)):
                        for c in range(sc,min(sc+wd,w)):
                            for k in range(4): op[r][c*4+k]=True
        return op,'mixed'
    if '_opacity_stencil:' in txt:
        hdr=[int(v) for v in re.findall(r'\b(\d+)\b',fcb[0])]
        hh,ww=hdr[0],hdr[1]
        for r,l in enumerate(fcb[1:1+hh]):
            by=[int(v,16) for v in re.findall(r'\$([0-9A-Fa-f]{2})',l)]
            for c,b in enumerate(by):
                for k in range(4):
                    if (b>>(6-2*k))&3: 
                        if r<h and c*4+k<w*4: op[r][c*4+k]=True
        return op,'stencil'
    return op,'?'

print("\n=== N3 — real Karateka cels WITH authored opacity.s sidecars (opaque black) ===")
sides=sorted(KAR.rglob("opacity.s"))[:4]
for sc in sides:
    d=sc.parent
    try:
        h,w,px=load_kar(d); op,kind=load_opacity(d,h,w)
    except Exception as e:
        print(f"  {d.name}: load failed {e}"); continue
    nblack=sum(1 for r in range(h) for c in range(w*4) if px[r][c]==0)
    nopq=sum(1 for r in range(h) for c in range(w*4) if px[r][c]==0 and op[r][c])
    r1=compile_and_check(px,op,f"{d.name} [{kind}] opaqueblk {nopq}/{nblack}")
    show(r1)
    # control: same cel with the sidecar IGNORED -> all black keyed
    r0=compile_and_check(px,[[False]*(w*4) for _ in range(h)],f"{d.name} [sidecar IGNORED]")
    show(r0)
    print(f"        -> sidecar changes drawn bytes {r0['drawn']} -> {r1['drawn']}, "
          f"cycles {r0['cyc']} -> {r1['cyc']}  (opaque black is STORED, not keyed)")

# ---------------- aggregate ----------------
tb=sum(r['tot'] for r in res); tc=sum(r['cyc'] for r in res)
nd=sum(r['drawn'] for r in res); nm=sum(r['mixed'] for r in res)
fails=sum(1 for r in res if r['bad'])
print(f"\n=== AGGREGATE (POP cels, n={len(res)}) ===")
print(f"  SOUNDNESS            : {'ALL PASS' if fails==0 else str(fails)+' FAILED'}")
print(f"  footprint bytes      : {tb:,}   drawn {nd:,}   skipped {tb-nd:,} ({100*(tb-nd)/tb:.0f}%)")
print(f"  mixed / drawn        : {nm:,} / {nd:,} = {100*nm/max(1,nd):.1f}%")
print(f"  cycles               : {tc:,}")
print(f"  cy/byte (footprint)  : {tc/tb:.2f}     <- vs PA.7 Glen proxy 4.09 (draw only)")
print(f"  cy/byte (drawn only) : {tc/nd:.2f}")
