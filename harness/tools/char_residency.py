#!/usr/bin/env python3
r"""char_residency.py - P5.6. WINDOW residency and RAM residency, measured SEPARATELY.

★★★ THE TWO ARE DIFFERENT SETS OVER DIFFERENT EXTENTS AND THE PROJECT HAS ONE WORD FOR BOTH.
Merging them is this project's signature error, so every figure this prints states what it is a
set OF and over what INTERVAL:

  WINDOW residency  the set that must be CPU-VISIBLE through the 15,872 B MMU window at the
                    instant of a draw. Interval: ONE FRAME. Extent: what that frame draws.
  RAM residency     the set that must be in a physical block so no disk read happens during
                    play. Interval: THE WHOLE RUN (or the whole reachable move graph).
                    Extent: the union, not the peak.

A number is only comparable to another number over the same extent and interval. W0 and W1
[P5.1] are peaks over MOVE-LENGTH intervals, which is a THIRD thing again, and §2.3 of the
report says which of them survives as which.

★★ AND THE CONTIGUITY QUESTION IS NOT A SIZE QUESTION. $FFA7 shows ONE 8 KB block, so a frame
whose cels are spread over two blocks cannot be drawn with one register write however small
those cels are. The test here is exact rather than heuristic:

  "same block" is TRANSITIVE. If A and B are drawn in one frame they share a block; if B and C
  are drawn in another, they share one too — so A, B and C are all in the same block. The
  CONNECTED COMPONENTS of the co-occurrence graph are therefore the finest partition any
  assignment can achieve, and a component larger than 8,192 B is a proof of impossibility, not
  a failure of the strategy tested.

Duplication is the only escape (a cel copied into two blocks breaks transitivity), so the
component report is followed by what duplication would cost.

INPUT: build/tmp/frame_drawset.txt — oracle_frame_drawset.lua's per-frame log, filtered by
frame_drawset.py's exact validator (address in the table's own pointer list AND live w/h equal
to the vendored file's). Records that fail it are not cels; see that file's header.
"""
import argparse
import pathlib
import statistics
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from frame_drawset import TABLES, coco3, load_valid          # noqa: E402

BLOCK = 8192            # what one MMU register shows
WINDOW = 15872          # $FFA6 (8,192) + $FFA7 (7,680)
ROT = 7680
CHAR_KINDS = ("kid", "kid/sword", "opponent")


def read_frames(path):
    """-> [(frame, [(bank, table, addr, w, h), ...])], validated."""
    valid = load_valid()
    rows = []
    for ln in pathlib.Path(path).read_text().splitlines():
        if not ln.startswith("F "):
            continue
        p = ln.split()
        cels = []
        for rec in p[2:]:
            if rec == "-":
                continue
            bank, tb, addr, w, h = rec.split("/")
            bank, tb, addr, w, h = int(bank), int(tb, 16), int(addr, 16), int(w), int(h)
            tv = valid.get((bank, tb))
            if tv is None or tv.get(addr) != (w, h):
                continue
            cels.append((bank, tb, addr, w, h))
        rows.append((int(p[1]), cels))
    return rows


def kind(c):
    return TABLES[(c[0], c[1])][1]


def name(c):
    return "%s@$%04X" % (TABLES[(c[0], c[1])][0], c[2])


def gameplay_span(rows):
    play = [(f, c) for f, c in rows if any(kind(x) == "tile" for x in c)]
    if not play:
        return rows
    lo, hi = play[0][0], play[-1][0]
    return [(f, c) for f, c in rows if lo <= f <= hi]


def dist(vals, label, unit="B"):
    if not vals:
        print("  %-30s (none)" % label)
        return
    v = sorted(vals)
    print("  %-30s min %5d  median %5d  p90 %5d  p99 %5d  MAX %5d %s"
          % (label, v[0], v[len(v) // 2], v[int(len(v) * 0.90)],
             v[int(len(v) * 0.99)], v[-1], unit))


def components(edges, nodes):
    """Connected components of the co-occurrence graph, as a list of node sets."""
    seen, out = set(), []
    adj = {n: set() for n in nodes}
    for a, b in edges:
        adj[a].add(b)
        adj[b].add(a)
    for n in nodes:
        if n in seen:
            continue
        seen.add(n)
        stack, comp = [n], []
        while stack:
            x = stack.pop()
            comp.append(x)
            for y in adj[x]:
                if y not in seen:
                    seen.add(y)
                    stack.append(y)
        out.append(comp)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default="build/tmp/frame_drawset.txt")
    ap.add_argument("--fps", type=float, default=59.92)
    args = ap.parse_args()

    rows = read_frames(args.log)
    span = gameplay_span(rows)
    print("SOURCE: %s — %d frames logged, gameplay span %d..%d (%d frames)"
          % (args.log, len(rows), span[0][0], span[-1][0], len(span)))
    print()

    # =================================================================== 2.1
    print("=" * 78)
    print("2.1 — WINDOW RESIDENCY.  SET OF: the distinct cels ONE FRAME draws.")
    print("      INTERVAL: one frame.  EXTENT: the 15,872 B MMU window.")
    print("=" * 78)
    char_per, tile_per, all_per = [], [], []
    worst_char = (0, None, None)
    for f, cels in span:
        ch = [c for c in cels if kind(c) in CHAR_KINDS]
        ti = [c for c in cels if kind(c) == "tile"]
        cb = sum(coco3(c[3], c[4]) for c in ch)
        tb = sum(coco3(c[3], c[4]) for c in ti)
        if ch:
            char_per.append(cb)
        if ti:
            tile_per.append(tb)
        if cels:
            all_per.append(cb + tb)
        if cb > worst_char[0]:
            worst_char = (cb, f, ch)
    dist(char_per, "CHARACTER cels per frame")
    dist(tile_per, "TILE cels per frame")
    dist(all_per, "BOTH kinds per frame")
    print()
    print("  ★ THE WORST CHARACTER FRAME IS %d, AND HERE IS WHAT IS HAPPENING IN IT:"
          % worst_char[1])
    for c in sorted(worst_char[2], key=lambda c: -coco3(c[3], c[4])):
        print("      %-18s %-9s %2dx%-3d  %5d B"
              % (name(c), kind(c), c[3], c[4], coco3(c[3], c[4])))
    print("      %-18s %-9s %6s  %5d B  of one 8,192 B block -> %s"
          % ("TOTAL", "", "", worst_char[0],
             "FITS, %d spare" % (BLOCK - worst_char[0]) if worst_char[0] <= BLOCK
             else "OVER by %d" % (worst_char[0] - BLOCK)))

    # ---- are the two demands DISJOINT IN TIME? --------------------------
    print()
    print("  ★★ ARE THE TILE AND CHARACTER DEMANDS SIMULTANEOUS? This decides whether the")
    print("     window must hold both at once or merely both in turn.")
    both, comp_and_char, big = 0, 0, 0
    for f, cels in span:
        ch = [c for c in cels if kind(c) in CHAR_KINDS]
        ti = [c for c in cels if kind(c) == "tile"]
        if ch and ti:
            both += 1
        if len(ti) >= 15:
            big += 1
            if ch:
                comp_and_char += 1
    print("     frames drawing BOTH a tile and a character      %4d of %d"
          % (both, len(span)))
    print("     frames that are a FULL-SCREEN composite (>=15 tile cels) %4d" % big)
    print("     ...of those, frames ALSO drawing a character    %4d" % comp_and_char)

    # =================================================================== 2.2
    print()
    print("=" * 78)
    print("2.2 — RAM RESIDENCY.  SET OF: every distinct cel the run EVER draws.")
    print("      INTERVAL: the whole run.  EXTENT: physical RAM, to avoid a disk read.")
    print("=" * 78)
    uni = {}
    for f, cels in span:
        for c in cels:
            uni[c] = coco3(c[3], c[4])
    for k in ("kid", "kid/sword", "opponent", "tile"):
        s = {c: v for c, v in uni.items() if kind(c) == k}
        print("  %-10s %3d distinct cels   %6d B" % (k, len(s), sum(s.values())))
    chars = {c: v for c, v in uni.items() if kind(c) in CHAR_KINDS}
    print("  %-10s %3d distinct cels   %6d B   <- the character RAM set for THIS RUN"
          % ("CHARACTERS", len(chars), sum(chars.values())))
    print()
    print("  ★ THIS IS THE RUN'S UNION, NOT THE MOVE GRAPH'S. The demo plays one path; a")
    print("    player can reach moves it never made. P5.1's W1 is the graph-wide figure and")
    print("    the report says which of the two is the requirement.")

    # =================================================================== 3
    print()
    print("=" * 78)
    print("3 — CONTIGUITY.  Can one frame's CHARACTER cels share a single 8,192 B block?")
    print("=" * 78)
    nodes = list(chars.keys())
    edges = set()
    for f, cels in span:
        ch = sorted({c for c in cels if kind(c) in CHAR_KINDS})
        for i in range(len(ch)):
            for j in range(i + 1, len(ch)):
                edges.add((ch[i], ch[j]))
    comps = components(edges, nodes)
    comps.sort(key=lambda cc: -sum(chars[c] for c in cc))
    print("  co-occurrence graph: %d cels, %d edges -> %d connected component(s)"
          % (len(nodes), len(edges), len(comps)))
    print()
    print("  %-6s %6s %8s   %s" % ("comp", "cels", "bytes", "verdict vs one 8,192 B block"))
    over = 0
    for i, cc in enumerate(comps):
        b = sum(chars[c] for c in cc)
        ok = b <= BLOCK
        if not ok:
            over += 1
        print("  %-6d %6d %8d   %s" % (i, len(cc), b,
                                       "FITS, %d spare" % (BLOCK - b) if ok
                                       else "★ OVER by %d" % (b - BLOCK)))
        if len(comps) <= 3 or not ok:
            for c in sorted(cc, key=lambda c: -chars[c])[:6]:
                print("           %-18s %-9s %5d B" % (name(c), kind(c), chars[c]))
            if len(cc) > 6:
                print("           ... and %d more" % (len(cc) - 6))
    print()
    if over == 0:
        print("  ★ ANSWER: YES for this run. Every frame's character set lies inside one")
        print("    component, and every component fits one block. The finest partition any")
        print("    assignment can reach is these components, so no better strategy is needed")
        print("    and none is possible.")
    else:
        print("  ★ ANSWER: NO for this run. %d component(s) exceed a block, and because" % over)
        print("    'same block' is transitive those cels CANNOT be separated without")
        print("    duplicating one — see the duplication cost below.")

    # ---- the cadence ----------------------------------------------------
    print()
    print("  CADENCE — block switches under the component assignment.")
    blk_of = {}
    for i, cc in enumerate(comps):
        for c in cc:
            blk_of[c] = i
    cur, switches, drawing = None, 0, 0
    for f, cels in span:
        ch = [c for c in cels if kind(c) in CHAR_KINDS]
        if not ch:
            continue
        drawing += 1
        want = blk_of[ch[0]]
        if want != cur:
            switches += 1
            cur = want
    secs = len(span) / args.fps
    print("     character-drawing frames        %4d over %.2f s" % (drawing, secs))
    print("     block switches                  %4d  = %.2f/s" % (switches, switches / secs))
    print("     (a switch is needed only when consecutive drawing frames want DIFFERENT")
    print("      components; with one component the answer is 1 and never again.)")

    # =================================================================== 3b
    print()
    print("=" * 78)
    print("3b — THE COVERING.  A PARTITION is not the only shape, and the component result")
    print("     above rules out only the partition.")
    print("=" * 78)
    print("  A cel may live in MORE THAN ONE block. That breaks the transitivity the")
    print("  component argument rests on, and turns the question from 'partition the cels'")
    print("  into 'COVER every frame-set with some block'. The cost is the duplicated bytes.")
    print()
    print("  ★ THE STRATEGY TESTED IS TEMPORAL, AND THE REASON IS IN THE DATA, NOT IN TASTE:")
    print("    consecutive frames of an animation redraw almost the same cels, so cels that")
    print("    are near in TIME are exactly the ones that must be near in SPACE. Blocks are")
    print("    grown by walking the frames in order and starting a new block whenever the")
    print("    next frame's set will not fit alongside what the current block already holds.")
    print("    A frame-set never straddles a boundary, because a block is only closed at one.")
    print()
    frames_ch = [(f, sorted({c for c in cels if kind(c) in CHAR_KINDS}))
                 for f, cels in span]
    frames_ch = [(f, s) for f, s in frames_ch if s]
    blocks, cur, curb, starts = [], set(), 0, []
    for f, s in frames_ch:
        add = [c for c in s if c not in cur]
        addb = sum(chars[c] for c in add)
        if curb + addb > BLOCK:
            blocks.append((cur, curb))
            starts.append(f)
            cur, curb = set(s), sum(chars[c] for c in s)
        else:
            cur.update(add)
            curb += addb
    if cur:
        blocks.append((cur, curb))
    raw = sum(chars.values())
    held = sum(b for _, b in blocks)
    print("  %-6s %6s %8s   %s" % ("block", "cels", "bytes", "fill"))
    for i, (s, b) in enumerate(blocks):
        print("  %-6d %6d %8d   %5.1f%%" % (i, len(s), b, 100.0 * b / BLOCK))
    print("  %-6s %6s %8d   over %d block(s) = %d B of window/RAM"
          % ("TOTAL", "", held, len(blocks), len(blocks) * BLOCK))
    print()
    print("  distinct cels                    %6d, %6d B (the RAM set, no duplication)"
          % (len(chars), raw))
    print("  cel slots across the blocks      %6d, %6d B"
          % (sum(len(s) for s, _ in blocks), held))
    print("  DUPLICATION                      %6d slots, %6d B (%.1f%% overhead)"
          % (sum(len(s) for s, _ in blocks) - len(chars), held - raw,
             100.0 * (held - raw) / raw))
    print("  lower bound (union / block, no duplication possible below this): %d blocks"
          % -(-raw // BLOCK))
    print()
    print("  CADENCE under this covering: a switch when the frame leaves the current block.")
    sw = 0
    bi = 0
    for f, s in frames_ch:
        while bi < len(blocks) - 1 and not set(s) <= blocks[bi][0]:
            bi += 1
            sw += 1
    print("     block switches %d over %.2f s = %.2f/s" % (sw, secs, sw / secs))
    print("     (one per block boundary — the boundaries are where the animation moves on,")
    print("      not a fixed rate, so a longer run does not switch proportionally faster.)")

    # =================================================================== 3c
    print()
    print("=" * 78)
    print("3c — ★★ AND THE PREMISE ITSELF: IS IT ONE BLOCK, OR TWO?")
    print("=" * 78)
    print("  Everything above answers 'can a frame's cels share ONE 8,192 B block', which is")
    print("  the right question ONLY IF $FFA6 is spoken for by the tile page on every frame.")
    print("  Under the P5.5 design it is not: the tile page is composited into the")
    print("  FRAMEBUFFER once per room change, and the background a character is drawn over")
    print("  afterwards comes from the framebuffer and the peel buffer, not from the page.")
    print("  If that holds, BOTH registers are free during play and the window a frame's")
    print("  characters may occupy is 15,872 B across TWO blocks -- and a frame's set may")
    print("  SPAN them, because both are mapped at once and no cel straddles the boundary.")
    print()
    print("  So: partition the cels by first use into %d-byte blocks with NO duplication," % BLOCK)
    print("  then ask how many distinct blocks each frame's set actually touches.")
    print()
    order = []
    for f, s in frames_ch:
        for c in s:
            if c not in order:
                order.append(c)
    part, cur, curb = [], [], 0
    for c in order:
        if curb + chars[c] > BLOCK:
            part.append(cur)
            cur, curb = [], 0
        cur.append(c)
        curb += chars[c]
    if cur:
        part.append(cur)
    pb = {c: i for i, blk in enumerate(part) for c in blk}
    print("  partition: %d blocks, no duplication, %d B total" % (len(part), raw))
    for i, blk in enumerate(part):
        print("     block %d  %3d cels  %6d B" % (i, len(blk), sum(chars[c] for c in blk)))
    spans = {}
    worst = (0, None, None)
    for f, s in frames_ch:
        n = len({pb[c] for c in s})
        spans[n] = spans.get(n, 0) + 1
        if n > worst[0]:
            worst = (n, f, s)
    print()
    print("  BLOCKS TOUCHED PER FRAME (over %d character-drawing frames):" % len(frames_ch))
    for n in sorted(spans):
        print("     %d block(s)  %4d frames  %5.1f%%   %s"
              % (n, spans[n], 100.0 * spans[n] / len(frames_ch),
                 "-> one register suffices" if n == 1
                 else "-> fits the two-register window" if n == 2
                 else "★ EXCEEDS the two-register window"))
    if worst[0] > 2:
        print()
        print("  ★ THE WORST FRAME IS %d, TOUCHING %d BLOCKS:" % (worst[1], worst[0]))
        for c in sorted(worst[2], key=lambda c: -chars[c]):
            print("       block %d  %-18s %-9s %5d B"
                  % (pb[c], name(c), kind(c), chars[c]))
    bad = sum(v for k, v in spans.items() if k > 2)
    if bad:
        print()
        print("  ★ THE REPAIR, AND ITS COST. A frame touching three blocks is fixed by")
        print("    duplicating its cels OUT OF the two minority blocks INTO the majority one")
        print("    -- the smallest move that makes the frame two-block-clean. Duplication is")
        print("    legitimate here for the reason it was not above: it is a handful of cels,")
        print("    not a partition-wide escape.")
        dup = {}
        for f, s in frames_ch:
            byb = {}
            for c in s:
                byb.setdefault(pb[c], []).append(c)
            if len(byb) <= 2:
                continue
            keep = max(byb, key=lambda b: sum(chars[c] for c in byb[b]))
            moved = [c for b, cs in byb.items() if b != keep for c in cs]
            # keep the largest of the minority blocks as the SECOND mapped block
            second = max((b for b in byb if b != keep),
                         key=lambda b: sum(chars[c] for c in byb[b]))
            moved = [c for b, cs in byb.items() if b not in (keep, second) for c in cs]
            print("      frame %d: blocks %s -> map %d+%d, duplicate %s"
                  % (f, sorted(byb), keep, second,
                     ", ".join("%s (%d B)" % (name(c), chars[c]) for c in moved)))
            for c in moved:
                dup[c] = chars[c]
        print("      distinct cels needing a second home: %d, %d B (%.2f%% of the %d B set)"
              % (len(dup), sum(dup.values()),
                 100.0 * sum(dup.values()) / raw, raw))
    print()
    print("  ★ ANSWER: %s" % (
        "every frame's characters lie in AT MOST TWO blocks of a duplication-free "
        "partition,\n     so the two-register window covers the whole run with ZERO "
        "duplicated bytes." if bad == 0
        else "%d frame(s) touch more than two blocks and would still need duplication."
        % bad))
    return 0


if __name__ == "__main__":
    sys.exit(main())
