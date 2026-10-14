#!/usr/bin/env python3
r"""engarde_plan.py — P5.37: the guard's en-garde window on the 6809 -- its DATA generated, its EXPECTATION the
oracle's. Emits build/gen/engarde_gen.s (included by kidrun_probe.s -DGA_WINDOW) and build/gen/engarde_expect.json
(read by engarde_test.py).

★★ A TEST BED, NOT A START-UP PATH. Three §2I divergences live in the data this file emits, and each is labelled
where it is emitted:
  1. the kid REPLAYED  -- ga_kid_tab: the oracle's K= record per game frame 179..217 (oracle_path.txt);
  2. the scene SEEDED  -- ga_shad0 / ga_glob0: the guard's record and the globals at the game-frame-179
     boundary, and ga_mapseed: the bytes in which the oracle's map at that boundary (oracle_blueprint.lua's aux
     dump at F8882) differs from the level file's -- the game had already changed them (physics);
  3. EnemyAlert REPLAYED -- ga_ea_tab: per game frame 180..217 (CHECKALERT reads the map; not ported).

What is NOT the oracle's trace: the map itself (ga_bluetype / ga_bluemap) is bg_compose.Blueprint's parse of
LEVEL0 -- the bakes' one reader (§2F) -- proven identical to the oracle's loaded copy by oracle_blueprint.py.
The sequence bytes are the oracle's ASSEMBLED table (SEQTABLE.LST), only the sequences the built code can
reach, every goto operand relocated to a `sq_XXXX` label named by its oracle address. The constants are the
oracle's assembled equates (AUTO/CTRL/CTRLSUBS/SEQTABLE.LST), not retyped.

  python harness/tools/engarde_plan.py --asm build/gen/engarde_gen.s --kd2 0x2A00
"""
import argparse
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import bg_compose as BC                                     # noqa: E402
import bake_chars as B                                      # noqa: E402
import guard_model as GM                                    # noqa: E402  (records/LST readers only)

GF0, GF1 = 180, 217
SPEED = 9                       # display frames per game frame: the oracle's own mean over this window
#                                 (F8890..F9234 = 344 display frames / 38 game frames = 9.05) -- a pace, not a model
HOLD = 90                       # display frames the last game frame is held before the window restarts
GD_TABLE = "chtab4gd"
PEELSZ = 768                    # per page: $3000-$35FF is two of these (guard_ai.s's logs start at $3600)
VECTORS = ROOT / "harness/data/p537_rdblock_vectors.json"
# the jumpseq numbers the BUILT code can name (CTRL.S DoEngarde/DoAdvance/DoRetreat, the kid's fastadvance)
JUMPS = ("guardengarde", "advance", "fastadvance", "retreat")
OPERANDS = {"chx": 1, "chy": 1, "aboutface": 0, "goto": 2, "up": 0, "down": 0, "act": 1, "setfall": 2,
            "ifwtless": 2, "die": 0, "jaru": 0, "jard": 0, "effect": 1, "tap": 1, "nextlevel": 0}
EQU = ["guardengarde", "advance", "fastadvance", "retreat", "space", "pillartop", "gate", "panelwif", "loose",
       "panelwof", "mirror", "slicer", "block", "archtop1", "swordthres", "toofar", "jumpthres", "runthres",
       "ScrnLeft", "ScrnRight", "idmask", "angle", "Ffootmark"] + list(OPERANDS)
# the 96-byte probability table, AUTO.S:109-124, rows in the source's order -- from the ASSEMBLED listing
PROBROWS = ("strikeprob", "restrikeprob", "blockprob", "impblockprob", "advprob", "refractimer",
            "specialcolor", "extrastrength")
GLOBALS = ("justblocked", "gdtimer", "refract", "alertguard", "droppedout", "offguard", "heroic", "guardprog",
           "milestone", "RNDseed", "OppStrength", "KidStrength", "EnemyAlert", "clrF", "clrB", "clrU", "clrD",
           "clrbtn", "JSTKX", "JSTKY", "btn")


def seq_table():
    """seqtab's pointer entries (n -> oracle address) from SEQTABLE.LST's `:n dw name` lines."""
    ent = {}
    for l in (GM.OBJ / "SEQTABLE.LST").read_text(errors="replace").splitlines():
        m = re.match(r"^(30[0-9A-F]{2}): ([0-9A-F]{2}) ([0-9A-F]{2})\s+\d+ :(\d+) dw (\w+)", l)
        if m:
            ent[int(m.group(4))] = (int(m.group(3) + m.group(2), 16), m.group(5))
    n = max(ent)
    assert sorted(ent) == list(range(1, n + 1)), "seqtab entries are not 1..n"
    return ent


def reach(roots):
    """Instruction starts reachable from `roots`, with ANIMCHAR's operand counts [COLL.S:994-1156]."""
    op = {GM.S[k] & 0xFF: k for k in OPERANDS}
    starts, todo = {}, list(roots)
    while todo:
        a = todo.pop()
        while a not in starts:
            b = GM.SEQ[a]
            if b in op:
                k = op[b]
                starts[a] = (k, [GM.SEQ[a + 1 + i] for i in range(OPERANDS[k])])
                if k in ("goto", "ifwtless"):
                    todo.append(GM.SEQ[a + 1] | GM.SEQ[a + 2] << 8)
                if k == "goto":
                    break
                a += 1 + OPERANDS[k]
            else:
                starts[a] = ("frame", [])
                a += 1
    return starts


def prob_table():
    rows = []
    lines = (GM.OBJ / "AUTO.LST").read_text(errors="replace").splitlines()
    for name in PROBROWS:
        i = next(n for n, l in enumerate(lines) if re.search(r"\d+ %s\s*$" % name, l))
        m = re.match(r"^([0-9A-F]{4}): ", lines[i + 1])
        a = int(m.group(1), 16)
        mem = GM.lst_bytes("AUTO.LST")
        rows.append([mem[a + k] for k in range(12)])
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--asm", required=True)
    ap.add_argument("--kd2", type=lambda v: int(v, 0), required=True, help="kd2's load address (link file)")
    a = ap.parse_args()

    R = GM.records()
    raw = (BC.LEVELS / "LEVEL0").read_bytes()
    bp = BC.Blueprint(raw)
    dump = GM.MAPDUMP.read_bytes()
    if bytes(bp.map) != dump[1952:2048]:
        raise SystemExit("engarde_plan: the oracle's MAP at game frame 179 differs from the level file's -- STOP")
    seed = [(i, dump[i]) for i in range(720) if dump[i] != bp.type[i]]

    ent = seq_table()
    s179 = R[GF0 - 1][1]
    roots = [ent[GM.S[j]][0] for j in JUMPS] + [s179[9] | s179[10] << 8]
    starts = reach(roots)
    for gf in range(GF0, GF1 + 1):
        sq = R[gf][1][9] | R[gf][1][10] << 8
        assert sq in starts, "the oracle's guard Seq $%04X at gf %d is outside the emitted sequences" % (sq, gf)
    for gf in range(GF0 - 1, GF1 + 1):
        assert R[gf][1][2] == 55, "the guard's CharY is not 55 at gf %d (the probe draws at WK_Y)" % gf

    # the guard's images in the window: frames through usealtsets
    frames = {R[gf][1][0] for gf in range(GF0 - 1, GF1 + 1)}
    alt = {}
    for l in (ROOT / "content/chars/frame_table.s").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s+fcb\s+(\d+),(\d+),(\d+),\$([0-9A-F]{2}),(\d+)\s+;\s+(\d+)\s", l)
        if m and int(m.group(6)) >= 150 and int(m.group(5)) == 3:
            alt[int(m.group(6))] = int(m.group(1))
    gimgs = sorted({alt[f] for f in frames})
    # ★ THE PEEL. P5.32 sized the guard's buffers (GD_PEEL, 320 B) for `ready`'s frames only; the advance's
    # frames are larger, and the first 6809 run overran page B's buffer into the self-test's answers. Here he
    # is the only actor, so he takes all of $3000-$35FF: GA_PEELSZ per page, and the build fails if any frame
    # he can show in the window needs more (rows x (w0 + 1): a non-zero phase adds a byte).
    peel = {}
    for n in gimgs:
        v = B.fcb_values(ROOT / ("content/chars/%s/%s_%03d_p0.s" % (GD_TABLE, GD_TABLE, n)))
        peel[n] = v[0] * (v[1] + 1)
    if max(peel.values()) > PEELSZ:
        raise SystemExit("engarde_plan: the guard's largest frame needs %d B of peel, %d per page" % (
            max(peel.values()), PEELSZ))

    L = ["* GENERATED by harness/tools/engarde_plan.py -- do not hand-edit.",
         "* P5.37: THE GUARD'S EN-GARDE WINDOW, game frames %d-%d. A TEST BED, NOT A START-UP PATH." % (GF0, GF1),
         "WK_X0           equ     0               ; (the kid is not drawn in this build)",
         "WK_XMIN         equ     0",
         "WK_Y            equ     55              ; the guard's CharY, constant over the window (checked)",
         "WK_SPEED        equ     %d               ; display frames per game frame -- the oracle's mean here" % SPEED,
         "WK_NIMG         equ     14",
         "GD_X            equ     %d" % s179[1],
         "GD_NIMG         equ     32",
         "GA_GF0          equ     %d" % GF0,
         "GA_NFR          equ     %d" % (GF1 - GF0 + 1),
         "GA_HOLD         equ     %d" % HOLD,
         "GA_PEELSZ       equ     %d              ; per page; the window's largest frame needs %d (image %d)"
         % (PEELSZ, max(peel.values()), max(peel, key=peel.get))]
    L.append("* --- the oracle's assembled equates (AUTO/CTRL/CTRLSUBS/SEQTABLE.LST), not retyped ---")
    for k in EQU:
        L.append("O_%-14s equ     $%02X" % (k.upper(), GM.S[k] & 0xFF))
    L.append("O_NSEQ          equ     %d" % len(ent))
    L.append("* image n -> the kid's stream: none -- the kid is REPLAYED and not drawn in this build")
    L.append("wk_img")
    L += ["                fdb     0"] * 14
    L.append("* image n (CHTAB4.GD #n) -> its baked stream; 0 = not linked")
    L.append("gd_img")
    for n in range(1, 33):
        L.append("                fdb     %s" % (("chtab4gd_%03d_p0" % n) if n in gimgs else "0"))
    L.append("                include \"content/chars/frame_table.s\"")

    D = ["* ===== THE MAP: bg_compose.Blueprint(LEVEL0), the bakes' parser -- WRITABLE RAM =====",
         "* BLUETYPE, 24 screens x 30 blocks (CTRLSUBS.S calcblue: (scrn-1)*30 + y*10 + x)",
         "ga_bluetype"]
    for i in range(0, 720, 30):
        D.append("                fcb     " + ",".join("$%02X" % v for v in bp.type[i:i + 30]))
    D.append("* MAP: 4 per screen -- left, right, up, down [CTRLSUBS.S:244-274]")
    D.append("ga_bluemap")
    for i in range(0, 96, 4):
        D.append("                fcb     " + ",".join("$%02X" % v for v in bp.map[i:i + 4]))
    D.append("* ★ §2I SEEDED SCENE (2 of 3): where the ORACLE's map at the game-frame-179 boundary differs from")
    D.append("* the level file's (oracle_blueprint.lua, aux bank, F8882) -- the game changed them before the window")
    D.append("ga_mapseed")
    for i, v in seed:
        D.append("                fdb     %d              ; screen %d block (%d,%d): $%02X -> $%02X"
                 % (i, i // 30 + 1, i % 10, i % 30 // 10, bp.type[i], v))
        D.append("                fcb     $%02X" % v)
    D.append("                fdb     $FFFF")
    D.append("* ===== SEQTABLE: the oracle's assembled bytes, the sequences the built code reaches =====")
    D.append("ga_seqtab                               ; jumpseq n -> entry (0 = not emitted: the probe traps)")
    for n in range(1, len(ent) + 1):
        ad, name = ent[n]
        D.append("                fdb     %-16s; %d %s" % (("sq_%04X" % ad) if ad in starts else "0", n, name))
    for ad in sorted(starts):
        k, ops = starts[ad]
        if k == "frame":
            D.append("sq_%04X         fcb     %d" % (ad, GM.SEQ[ad]))
        elif k in ("goto", "ifwtless"):
            D.append("sq_%04X         fcb     O_%s" % (ad, k.upper()))
            D.append("                fdb     sq_%04X" % (ops[0] | ops[1] << 8))
        else:
            D.append("sq_%04X         fcb     O_%s%s" % (ad, k.upper(), "".join(",$%02X" % v for v in ops)))
    D.append("* ★ §2I REPLAYED KID (1 of 3): his record per game frame %d..%d, the oracle's K= (oracle_path.txt)."
             % (GF0 - 1, GF1))
    D.append("* Seq is the ORACLE's address, big-endian -- never dereferenced: the kid is not animated here.")
    D.append("ga_kid_tab")
    for gf in range(GF0 - 1, GF1 + 1):
        k = R[gf][0]
        D.append("                fcb     " + ",".join("$%02X" % v for v in k[:9] + bytes([k[10], k[9]]) + k[11:])
                 + "   ; gf %d F%d" % (gf, R[gf][3]))
    D.append("* ★ §2I REPLAYED EnemyAlert (3 of 3), per game frame %d..%d" % (GF0, GF1))
    D.append("ga_ea_tab       fcb     " + ",".join("%d" % R[gf][2]["EnemyAlert"] for gf in range(GF0, GF1 + 1)))
    D.append("* ★ §2I SEEDED SCENE: the guard at the game-frame-179 boundary (F%d), Seq relocated" % R[GF0 - 1][3])
    D.append("ga_shad0        fcb     " + ",".join("$%02X" % v for v in s179[:9]))
    D.append("                fdb     sq_%04X" % (s179[9] | s179[10] << 8))
    D.append("                fcb     " + ",".join("$%02X" % v for v in s179[11:]))
    v179 = R[GF0 - 1][2]
    D.append("* ... and the globals, in ga_glob's order: " + " ".join(GLOBALS))
    D.append("ga_glob0        fcb     " + ",".join("$%02X" % v179[g] for g in GLOBALS))
    D.append("GA_NGLOB        equ     %d" % len(GLOBALS))
    D.append("ga_visscrn0     fcb     %d              ; VisScrn: the kid's screen" % R[GF0 - 1][0][11])
    D.append("* the AC1 self-test: every DISTINCT RDBLOCK query the oracle made in the window (harness/data)")
    vec = json.loads(VECTORS.read_text())
    D.append("GA_NTQ          equ     %d" % len(vec["queries"]))
    D.append("ga_tq")
    for q in vec["queries"]:
        D.append("                fcb     %d,$%02X,$%02X" % (q["scrn"], q["x"], q["y"]))
    D.append("* the 96-byte probability table, AUTO.S:109-124 (rows x guardprog 0..11), from AUTO.LST.")
    D.append("* rnd < p semantics: `cmp strikeprob,x / bcs ]rts` -- even 255 fails 1 in 256. UNUSED in this window.")
    D.append("ga_probtab")
    for name, row in zip(PROBROWS, prob_table()):
        D.append("                fcb     " + ",".join("%d" % v for v in row) + "   ; " + name)

    # sizes and placement
    n_data = (720 + 96 + 3 * len(seed) + 2 + 2 * len(ent) + sum(1 + len(o) for _k, o in starts.values())
              + 16 * (GF1 - GF0 + 2) + (GF1 - GF0 + 1) + 16 + len(GLOBALS) + 1 + 3 * len(vec["queries"]) + 96)
    caps = [("kd1", 0x6A00 - 0x6000 - n_data), ("kd2", 0x3000 - a.kd2), ("kd3", 0x7800 - 0x6B00)]
    if caps[0][1] < 0:
        raise SystemExit("engarde_plan: the window's data (%d B) does not fit kd1" % n_data)
    used = {s: 0 for s, _ in caps}
    where = {}
    for n in gimgs:
        path = "content/chars/%s/%s_%03d_p0.s" % (GD_TABLE, GD_TABLE, n)
        size = len(B.fcb_values(ROOT / path))
        for s, cap in caps:
            if used[s] + size <= cap:
                used[s] += size
                where.setdefault(s, []).append(path)
                break
        else:
            raise SystemExit("engarde_plan: stream %s (%d B) fits no span %r" % (path, size, used))
    L += ["                ifdef   OBJTARGET", "                section kd1", "                endc"] + D
    for s, _ in caps:
        L += ["                ifdef   OBJTARGET", "                section %s" % s, "                endc"]
        for path in where.get(s, []):
            L.append("                include \"%s\"" % path)
    out = pathlib.Path(a.asm)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(L) + "\n", encoding="utf-8", newline="\n")

    exp = dict(gf0=GF0, gf1=GF1,
               guard=[R[gf][1].hex().upper() for gf in range(GF0, GF1 + 1)],
               guardprog=[R[gf][2]["guardprog"] for gf in range(GF0, GF1 + 1)],
               display_frame=[R[gf][3] for gf in range(GF0, GF1 + 1)],
               seq_labels=sorted("%04X" % ad for ad in starts),
               mapseed=seed)
    out.with_name("engarde_expect.json").write_text(json.dumps(exp, indent=1) + "\n", encoding="utf-8")
    print("engarde_plan: map %d+%d B (the oracle's 179 state differs in %d B: %s); %d sequence bytes from %d "
          "roots (%s); kid replay %d records; EnemyAlert %d; vectors %d" %
          (720, 96, len(seed), ["scrn %d (%d,%d)" % (i // 30 + 1, i % 10, i % 30 // 10) for i, _ in seed],
           sum(1 + len(o) for _k, o in starts.values()), len(roots), ",".join(JUMPS) + ",seed",
           GF1 - GF0 + 2, GF1 - GF0 + 1, len(vec["queries"])))
    print("engarde_plan: data %d B in kd1; guard images %s -> kd1 %d B of %d, kd2 %d B of %d, kd3 %d B of %d"
          % (n_data, gimgs, used["kd1"], caps[0][1], used["kd2"], caps[1][1], used["kd3"], caps[2][1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
