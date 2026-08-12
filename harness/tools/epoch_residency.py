"""P3.76 §2 — the per-EPOCH resident sets, which is what a block schedule needs.

The per-step live sets (1,334-2,028 B) say a swapped-in working set can be small. They do
NOT say where the scene can be cut. A block may only change at a point where nothing a
later beat draws is sitting in it — so the question is, for each candidate switch point:

    RETIRED   last drawn BEFORE the cut  -> its space can be reused
    CARRIED   spans the cut              -> must survive it (pinned, or duplicated)
    ARRIVING  first drawn AFTER the cut   -> can be read in at the cut

The song holds are the only places a read can hide, so they are the candidate cuts.
"""
import sys, pathlib
ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
import beat_recost as B

SCRATCH = pathlib.Path(
    "C:/Users/jayse/AppData/Local/Temp/claude/c--Projects-POP3-port/"
    "39e1686b-c31a-43f2-9efa-17977499dbce/scratchpad/p373")

viz, pri, bounds = B.port_trace()
n = len(viz.drawn)
occ_v, occ_p = B.occupancy(viz), B.occupancy(pri)
sz = {}
for who, occ in (("viz", occ_v), ("pri", occ_p)):
    s = B.measure(occ, SCRATCH / who,
                  lambda c, w=who: ("v" if w == "viz" else "p") + str(c))
    for (c, ph), b in s.items():
        if b:
            sz[(who, c, ph)] = b
sp = {}
for who, ch in (("viz", viz), ("pri", pri)):
    for k, v in B.spans(ch, lambda c, p, w=who: (w, c, p)).items():
        sp[k] = v

total = sum(sz.get(k, 0) for k in sp)
BANK = 2 * (0xFE00 - 0xC000)          # 31,744 B addressable across two mappings
print("  total cel bytes over the scene   %s B" % format(total, ","))
print("  bank addressable                 %s B  -> %s B must arrive mid-scene\n"
      % (format(BANK, ","), format(total - BANK, ",")))

# the holds, from PORT_PLAN's bounds: s_Princess ends ~116, s_Vizier ~141..192
print("  %-26s %-11s %-11s %s" % ("cut at", "RETIRED", "CARRIED", "ARRIVING"))
for cut, label in ((116, "end of s_Princess"), (192, "end of s_Vizier"),
                   (229, "his second stop"), (248, "before Vexit")):
    ret = car = arr = 0
    retn = []
    for k, (f, l, _x) in sp.items():
        b = sz.get(k, 0)
        if l < cut:
            ret += b; retn.append(k[0][0] + str(k[1]))
        elif f > cut:
            arr += b
        else:
            car += b
    print("  step %-4d %-15s %-11s %-11s %s"
          % (cut, label, format(ret, ","), format(car, ","), format(arr, ",")))
    if cut == 192:
        print("      retirable by then: %s" % " ".join(sorted(set(retn))))
