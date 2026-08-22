#!/usr/bin/env python3
r"""cel_pack.py — P3.78. Pack the scene's cels into GIME blocks, and schedule the map.

WHAT THIS SOLVES, IN ONE SENTENCE. The full scene is 39,682 B of cel image against a bank
that is 31,744 B addressable, and only two of the four window registers are free — so the
cels have to be cut into block-sized PAGES, one page mapped at a time, with the mapping
changing only where no beat is mid-draw.

  bank, physical        5 blocks, $0C..$0F + $18, 40,960 B
                        [P3.66 measured 4, and 4 was the count at 128 KB, where NOTHING is
                         free: $00-$07 are the two framebuffers, $08-$0B the CPU's low map,
                         and $0C-$0F are simultaneously the cel bank AND the aliases of
                         $3C-$3F, the CPU's own $8000-$FFFF. There is no fifth block to
                         find. P5.15 takes the fifth from the 512 KB machine P5.14 made
                         the target — $18 is free there and aliases onto $08, the program's
                         low memory, on a 128 KB one. That is why this is 512 KB ONLY.]
  window                $FFA6 -> $C000-$DFFF (8,192 B)
                        $FFA7 -> $E000-$FFFF, of which $E000-$FDFF is reachable (7,680 B);
                        $FE00-$FEFF is constant RAM (MC3=1) and $FF00+ is I/O
  $FFA4/$FFA5           the framebuffer. Not available. [P3.75 §3B]

THE SHAPE: PIN ONE, ROTATE THE OTHER.

  $FFA6  RESIDENT page, pinned for the whole scene. Holds the magic, the [cel][facing]
         [phase] table, and the cels that more than one page's worth of beats needs.
  $FFA7  ROTATING page, one per group of consecutive beats, chosen from 4 physical
         blocks — and since P5.15 the scene's four pages each get one, so no page is
         re-read mid-scene at all.

WHY THE TABLE FORCES THE PIN. co_variant reads CEL_WALK_TAB on every cel it places, so
the table has to be mapped at every instant. Rotating BOTH registers would mean a copy of
the table in every mapping — 1,360 B duplicated per page, and a second home for a fact
whose whole design point (bake_scene.emit) is that it has one.

★ EVERY PAGE CARRIES ITS OWN SIGNATURE, AND THAT IS THE POINT OF THIS PASS.
P3.77 shipped a guard on ONE image: two bytes at $C000 checked once per frame. Its own
uncertainty flag named what splitting would do to it — "if the packer puts cels in more
than one block, each block needs its own signature or the guard only proves one of them
is mapped." A single magic proves the RESIDENT page is mapped and says nothing about the
rotating one, which is the half that actually changes and therefore the half that can be
wrong. So each page gets a distinct 16-bit magic at its own base, and the schedule carries
the value the current beat's pointers need.

  sig(n) = PAGE_SIG0 + n * PAGE_SIG_STEP     -- distinct, and not a plausible cel byte

★ AND A BEAT THAT NEEDS NO ROTATING PAGE SAYS SO, WITH SIG 0.
Both song holds draw only standing cels, which are resident. Their rotating block is free
— which is exactly why a disk read can hide there. A guard that demanded a valid page
signature during those beats would refuse to draw for the whole hold, so "this beat needs
no rotating page" is a state the schedule can express: signature 0, never a real page's
value. The packer ASSERTS such a beat's set really is a subset of the resident set, so the
marking cannot drift from the content it describes.

THE READS — AND AT FOUR BLOCKS THERE ARE NONE. The machinery below still schedules them,
because it is what proves none are needed: a page arrives mid-scene in a song hold, over a
block whose previous occupant is provably finished (the residency check is `last beat using
it < the read beat`). With a block per page that check has nothing to check, `reads` comes
out empty, and the whole bank is loaded once in the intro's opening batch. What the viewer
loses is the 3.20 s freeze at beat 12 — the one visible disk read in the entire intro
(P5.13 span 15). What boot pays is one more page in the preload: two tracks.

disk_read_range reads WHOLE TRACKS only (its own header: "dr_r_count must be a multiple of
SECS_TRACK"), so a page costs ceil(bytes / 4608) tracks of transfer time whatever its
length -- which is why this packs into FEW BIG pages rather than many small.
"""
import math
import os

_DEBUG = bool(os.environ.get('CEL_PACK_DEBUG'))

# --- the machine, measured, not assumed -----------------------------------------
RES_BASE = 0xC000                 # $FFA6's page
ROT_BASE = 0xE000                 # $FFA7's page
RES_CAP = 0xE000 - 0xC000         # 8,192 B, all reachable
ROT_CAP = 0xFE00 - 0xE000         # 7,680 B — MC3=1 shadows the top 512 B
RES_BLOCK = 0x0C                  # pinned at $FFA6
# ★ $18 IS THE 512 KB BLOCK, AND IT IS THE ONLY REASON THE SCENE NEEDS NO READ (P5.15).
# The header says why no fifth block exists at 128 KB. $18-$37 are all free on the 512 KB
# machine; $18 is simply the lowest, sitting immediately above framebuffer B ($14-$17).
ROT_BLOCKS = (0x0D, 0x0E, 0x0F, 0x18)
N_BLOCKS = 1 + len(ROT_BLOCKS)    # derived, so the two cannot drift apart
SECTOR = 256
SECS_PER_TRACK = 18
TRACK = SECTOR * SECS_PER_TRACK   # 4,608 B

# ─── ★★ THE READ GEOMETRY, AND IT IS THE ONE THING THAT MUST NOT BE GOT WRONG ─────────
#
# disk_read_range reads WHOLE TRACKS ONLY -- "dr_r_count must be a multiple of SECS_TRACK;
# a partial-track tail is a DEFERRED capability" (disk_read.s, its own header). A page
# holds up to 7,680 B and therefore needs two tracks, which is 9,216 B of transfer into a
# window that reaches 7,680. THE STRAIGHTFORWARD READ OVERRUNS BY 1,536 BYTES -- through
# $FE00-$FEFF (the constant page, where the disk driver keeps its NMI flag and its motor
# flag) and then straight through $FF00-$FFFF, WHICH IS THE GIME AND THE MMU.
#
# That is not a corruption you debug. Built that way, the machine reset the instant the
# first page landed, $FFA6/$FFA7 came back as $3E/$3F and probe_status read 0 -- which
# looks exactly like "the program never started", the one thing it had not done.
#
# THE FIX IS A SKEW IN THE DISK LAYOUT, and it costs nothing: no HAL change (the driver
# keeps its whole-track contract), no staging RAM, no extra block. Each unit is padded to
# the size of the window it is read into, and its SECOND track is laid out so that reading
# it ENDS exactly at the window's top:
#
#     track A  = padded[0 : 4608]          read to  base
#     track B  = padded[CAP-4608 : CAP]    read to  base + CAP - 4608
#
# The two overlap by (9,216 - CAP) bytes and both write the same bytes there, so the order
# does not matter and the result is the padded unit, exactly. For a page that is
# $E000 + 7,680 - 4,608 = $EC00, ending at $FE00; for the pinned page, $CE00, ending at
# $E000. Neither touches a byte the window does not own.
SKEW_RES = RES_BASE + RES_CAP - TRACK      # $CE00
SKEW_ROT = ROT_BASE + ROT_CAP - TRACK      # $EC00
UNIT_TRACKS = 2                            # every unit, uniformly — see above

CEL_MAGIC = 0xC35A                # the resident page's, unchanged from P3.77
PAGE_SIG0 = 0xA53C                # page 0's
PAGE_SIG_STEP = 0x0111


def page_sig(n):
    """A DISTINCT magic per page — not an ordinal a wrong block could plausibly hold.

    The whole reason P3.77 chose a magic over a plausibility test applies once per page
    now: "a plausibility test on WALK_LO would pass on a wrong block that happened to look
    sane." A page number would too — 0..5 are bytes any cel stream contains. The step is
    odd in both halves so no two pages share a byte in either position.
    """
    v = (PAGE_SIG0 + n * PAGE_SIG_STEP) & 0xFFFF
    assert v not in (0, CEL_MAGIC), "page signature collided with a reserved value"
    return v


class PackError(Exception):
    """Raised when the scene does NOT pack. Never softened into a partial answer —
    a packing that silently drops a constraint is the failure the guard exists for."""


def pack(beats, sizes, table_bytes, read_beats, n_rot=len(ROT_BLOCKS),
         _pinned=None, _depth=0):
    """beats:  [(beat_index, name, plays, {variant})]  in play order
       sizes:  {variant: bytes}
       table_bytes: the walk_tab's size, which lives in the resident page
       read_beats:  beat indices at which a mid-scene disk read may be issued
       -> dict(resident=..., pages=[...], beat_page=[...], reads=[...])

    Raises PackError rather than returning something that nearly fits.
    """
    res_budget = RES_CAP - 4 - table_bytes          # 4 = magic + WALK_LO + WALK_N

    def bytes_of(vs):
        return sum(sizes.get(v, 0) for v in vs)

    # --- how many beats each variant is drawn in; the long-span ones are the ones a
    # --- page boundary would otherwise force to be duplicated.
    span = {}
    for bi, _n, _p, vs in beats:
        for v in vs:
            f, l = span.get(v, (bi, bi))
            span[v] = (min(f, bi), max(l, bi))

    def spanlen(v):
        f, l = span[v]
        return l - f + 1

    # ── PHASE 1 — force-resident, and ONLY as far as the arithmetic forces ──────────
    # A beat whose own live set exceeds one rotating page cannot be served by a page at
    # all; the excess has to be pinned. Pback (9,538 B) and the pre-Pslump hold (9,090 B)
    # are the two, measured. Longest-span variants go first: they are the ones most
    # likely to be wanted by a neighbouring beat too, so pinning them buys twice.
    # _pinned carries cels a previous pass found duplicated across pages (see the
    # no-cel-in-two-pages check below). Bounded so a pathological set cannot spin.
    if _depth > 8:
        raise PackError('the pin-and-re-solve loop did not converge in 8 passes')
    resident = set(_pinned) if _pinned else set()
    for bi, name, _p, vs in beats:
        over = bytes_of(vs - resident) - ROT_CAP
        if over <= 0:
            continue
        for v in sorted(vs - resident, key=lambda v: (-spanlen(v), -sizes.get(v, 0), v)):
            resident.add(v)
            over -= sizes.get(v, 0)
            if over <= 0:
                break
        if bytes_of(vs - resident) > ROT_CAP:
            raise PackError(
                "beat %d (%s) needs %s B and one page holds %s B; pinning its whole set "
                "would still not fit" % (bi, name, bytes_of(vs), ROT_CAP))
    # ── PHASE 1a — the TERMINAL beat is resident by definition ──────────────────────
    # The last beat has 0 plays, which means the SCRIPT holds, not that the scene stops:
    # both characters go on drawing whatever their sequences settled on, for as long as
    # the scene is up. No read point can ever follow it and no later beat can free its
    # block, so "reachable for an unbounded time" is exactly what the pinned page means.
    # Leaving it to a page would make the last thing on screen the one thing whose
    # mapping nothing renews.
    if beats and beats[-1][2] == 0:
        term = beats[-1][3]
        if bytes_of(resident | term) > res_budget:
            raise PackError(
                "the terminal beat draws %s B and the resident page has %s B left; the "
                "scene cannot end on cels no page schedule outlives"
                % (bytes_of(term - resident), res_budget - bytes_of(resident)))
        resident |= term

    # ── PHASE 1b — pin what the READ POINTS draw ────────────────────────────────────
    # A read can only be issued at a beat that needs no rotating page, because the block
    # it reads into is a block the window has to be showing. Both song holds draw nothing
    # but the two standing cels, so pinning those (1,761 B for all three) is what turns a
    # hold into a place a track can land. This is the cheapest capacity in the design:
    # standing cels are drawn across most of the scene anyway.
    for r in read_beats:
        want = beats[r][3] - resident
        if bytes_of(resident | (beats[r][3])) <= res_budget:
            resident |= beats[r][3]
    # ── PHASE 1c — pin a beat that would otherwise SPEND A WHOLE BLOCK ON NOTHING ──────
    #
    # A page is not a byte budget, it is a SLOT: there are three rotating blocks and two
    # or three points in the scene where one can be refilled, so a page costs a block for
    # its whole span whether it holds 7,600 bytes or 78. A beat whose set will not union
    # with either neighbour is forced to be its own page — and if that set is tiny, that
    # is a block spent on almost nothing, which then pushes every later page down the
    # block timeline until some page needs refilling at a beat that is not a read point.
    #
    # Measured, and it is why this phase exists: Vraise draws exactly ONE cel the pinned
    # page lacks (v85, 78 B). Beat 12 is 7,678 B against a 7,680 B page, so the union
    # misses by 76 bytes; Vraise therefore took a page of its own, the last page landed on
    # a block whose refill point would have had to be beat 12 or 13, and neither is a hold.
    # The packer reported the whole scene as unpackable over 78 bytes.
    #
    # So: pin such a beat's set outright, cheapest first, while the resident page has room.
    # This is the one place where pinning buys a SLOT rather than bytes, and it is worth
    # far more than the bytes it costs.
    def cannot_merge(i):
        vs = beats[i][3] - resident
        if not vs:
            return False
        for j in (i - 1, i + 1):
            if 0 <= j < len(beats):
                nb = beats[j][3] - resident
                if nb and bytes_of(vs | nb) <= ROT_CAP:
                    return False
        return True

    while True:
        cands = [i for i in range(len(beats))
                 if cannot_merge(i)
                 and bytes_of(resident | beats[i][3]) <= res_budget
                 and bytes_of(beats[i][3] - resident) <= ROT_CAP // 4]
        if not cands:
            break
        i = min(cands, key=lambda i: bytes_of(beats[i][3] - resident))
        resident |= beats[i][3]

    if bytes_of(resident) > res_budget:
        raise PackError("the forced-resident set is %s B against %s B of resident page"
                        % (bytes_of(resident), res_budget))
    live_reads = [r for r in read_beats if beats[r][3] <= resident]

    # ── PHASE 2+3 — group beats into pages AND schedule the blocks, together ────────
    # ★ THESE CANNOT BE DECIDED SEPARATELY, and a greedy pass proved it: filling each
    # page as full as possible put page 1's last beat at 11, which left its block busy
    # past the only read point that could have refilled it for page 4. The grouping is
    # what decides whether a read schedule EXISTS, so the two are one search.
    #
    # A page serves a maximal RUN of consecutive NEEDING beats (a beat drawing only
    # resident cels constrains nothing and is placed afterwards). Page k and page
    # k+n_rot share a physical block, so a read point must fall strictly between the
    # last beat that needs the earlier one and the first that needs the later.
    #
    # Depth-first over cut points, longest-page-first so the natural answer is found
    # first and the search only backtracks where the block timeline forbids it.
    needing = [(bi, vs - resident) for bi, _n, _p, vs in beats if not (vs <= resident)]
    if not needing:
        raise PackError("no beat needs a rotating page — the scene fits the pinned block")

    def search(start, groups, cap):
        if start == len(needing):
            return groups
        # ★★ THE PAGE BUDGET, ADDED AT P5.15. Without it the search is greedy-longest-first
        # and takes whatever run fits, which is NOT optimal for page COUNT -- and page count
        # is what decides whether a mid-scene disk read is needed at all. Worse, a LARGER
        # n_rot made it produce MORE pages: the `k >= n_rot` refill constraint below is what
        # forces a short group, so relaxing it lets an early group run long and pushes the
        # tail into an extra page. Four blocks gave five pages where three blocks gave four.
        #
        # The caller now tries cap = n_rot first (zero reads), then widens. So a packing that
        # needs no read is always preferred to one that does, and the old behaviour is just
        # the first cap that succeeds.
        if len(groups) >= cap:
            return None
        # the longest run from `start` that fits one block, then shorter on backtrack
        acc, longest = set(), 0
        for j in range(start, len(needing)):
            if bytes_of(acc | needing[j][1]) > ROT_CAP:
                break
            acc |= needing[j][1]
            longest = j + 1
        if longest == start:
            return None                    # one beat alone does not fit — Phase 1's job
        for end in range(longest, start, -1):
            grp = (set().union(*[needing[i][1] for i in range(start, end)]),
                   [needing[i][0] for i in range(start, end)])
            k = len(groups)
            if k >= n_rot:
                prev_last = groups[k - n_rot][1][-1]
                if not any(r for r in live_reads if prev_last < r < grp[1][0]):
                    continue               # this cut leaves the block unrefillable
            got = search(end, groups + [grp], cap)
            if got is not None:
                return got
        return None

    # ★ FEWEST PAGES FIRST. cap = n_rot means every page has its own block and the read
    # schedule below is empty; each widening step buys one more page at the cost of one
    # mid-scene read. Trying them in order makes "no read" the preferred answer rather than
    # an accident of how the greedy search happened to cut.
    pages = None
    for cap in range(n_rot, n_rot + len(live_reads) + 1):
        pages = search(0, [], cap)
        if _DEBUG:
            print("    [cap=%d n_rot=%d live_reads=%s needing=%d] -> %s"
                  % (cap, n_rot, live_reads, len(needing),
                     "None" if pages is None else "%d pages" % len(pages)))
        if pages is not None:
            break
    if pages is None:
        raise PackError(
            "no grouping of the beats into <= %d blocks refilled at %s produces a page "
            "schedule; the scene needs another block or another read point"
            % (n_rot, live_reads))
    if len(pages) > n_rot + len(live_reads):
        raise PackError("%d pages against %d blocks + %d usable read points"
                        % (len(pages), n_rot, len(live_reads)))

    # the read schedule falls straight out of the grouping the search accepted
    reads, used = [], set()
    for k in range(n_rot, len(pages)):
        prev_last = pages[k - n_rot][1][-1]
        slot = next(r for r in live_reads
                    if r not in used and prev_last < r < pages[k][1][0])
        used.add(slot)
        reads.append({"at_beat": slot, "page": k, "block": ROT_BLOCKS[k % n_rot]})

    # Now place the beats that need nothing. They carry sig 0, so which block they map is
    # free — except at a read point, where it MUST be the block being read into.
    beat_page = [None] * len(beats)
    for k, (_vs, bs) in enumerate(pages):
        for bi in bs:
            beat_page[bi] = k
    for bi in range(len(beats)):
        if beat_page[bi] is not None:
            continue
        rd = next((r for r in reads if r["at_beat"] == bi), None)
        if rd is not None:
            beat_page[bi] = rd["page"]              # show the block the track lands in
        elif bi and beat_page[bi - 1] is not None:
            beat_page[bi] = beat_page[bi - 1]       # carry the map forward, unchanged
        else:
            beat_page[bi] = next(k for k in range(len(pages))
                                 if pages[k][1][0] > bi)

    # ── ★★★ NO CEL MAY LIVE IN TWO PAGES, AND THE TABLE IS WHY ───────────────────────
    #
    # cel_walk_tab holds ONE absolute address per (cel, facing, phase). A cel placed in two
    # pages sits at a different offset in each, so that single address is right for at most
    # one of them — and at the others the pointer lands on unrelated bytes, co_dims reads
    # them as a cel header, and the peel blits whatever it finds.
    #
    # THIS IS AN INVARIANT THE TABLE ALWAYS IMPLIED AND NOTHING EVER ASSERTED. It never
    # arose while the resident page was large, because a cel carried across a page boundary
    # was pinned; P3.85's re-encode shrank every cel by a quarter, the resident set fell to
    # five, and the packer duplicated `p17_p0` into pages 1, 2 and 3 instead. Measured on
    # the machine: blit_save handed rows=252 width=66 from co_save, and the room reset.
    #
    # The fix is the invariant, not a special case: a cel wanted by beats that map different
    # pages must be RESIDENT. Detect it, pin it, and re-solve — the grouping can change once
    # a cel leaves the pages, so this iterates rather than patching one pass.
    seen_in = {}
    for k, (vs, _bs) in enumerate(pages):
        for v in vs:
            seen_in.setdefault(v, []).append(k)
    dup = sorted((v for v, ks in seen_in.items() if len(ks) > 1), key=str)
    if dup:
        extra = bytes_of(set(dup))
        if bytes_of(resident | set(dup)) > res_budget:
            raise PackError(
                "%d cel(s) are wanted by beats in different pages and must be pinned "
                "(%s B), but the resident page has only %s B left — the lookup table "
                "cannot hold two addresses for one cel"
                % (len(dup), format(extra, ","),
                   format(res_budget - bytes_of(resident), ",")))
        return pack(beats, sizes, table_bytes, read_beats, n_rot,
                    _pinned=(resident | set(dup)), _depth=_depth + 1)

    # ── VERIFY, because a packer that cannot be wrong out loud is the whole hazard ───
    out_pages = []
    for k, (vs, bs) in enumerate(pages):
        n = bytes_of(vs)
        if n > ROT_CAP:
            raise PackError("page %d is %s B against a %s B block" % (k, n, ROT_CAP))
        out_pages.append({"index": k, "variants": vs, "beats": bs, "bytes": n,
                          "block": ROT_BLOCKS[k % n_rot], "sig": page_sig(k),
                          "tracks": max(1, math.ceil(n / TRACK))})

    # Every beat's set must be reachable from what is mapped while it runs. This is the
    # assertion the whole design rests on and it is checked here, on the real sets.
    sched = []
    for bi, name, plays, vs in beats:
        pg = out_pages[beat_page[bi]]
        if not vs <= (resident | pg["variants"]):
            missing = sorted(vs - resident - pg["variants"])
            raise PackError("beat %d (%s) draws %s, which page %d does not hold"
                            % (bi, name, missing, pg["index"]))
        # ★ resident-only beats: signature 0, and the claim is CHECKED not declared.
        res_only = vs <= resident
        sched.append({"beat": bi, "name": name, "plays": plays,
                      "block": pg["block"], "sig": 0 if res_only else pg["sig"],
                      "page": pg["index"], "resident_only": res_only,
                      "read": next((r["page"] for r in reads if r["at_beat"] == bi),
                                   None)})
    for r in reads:
        if not sched[r["at_beat"]]["resident_only"]:
            raise PackError(
                "the read at beat %d would run while that beat still needs a rotating "
                "page — the block being read into is the one it is drawing from"
                % r["at_beat"])
        if sched[r["at_beat"]]["block"] != r["block"]:
            raise PackError("the read at beat %d targets block $%02X but the beat maps "
                            "$%02X" % (r["at_beat"], r["block"],
                                       sched[r["at_beat"]]["block"]))

    return {"resident": resident, "resident_bytes": bytes_of(resident),
            "resident_budget": res_budget, "pages": out_pages,
            "schedule": sched, "reads": reads, "table_bytes": table_bytes}


def report(p, sizes):
    L = []
    L.append("=== the pack ===")
    L.append("  resident page  $%04X  magic + bounds 4 B + table %s B + cels %s B"
             " = %s B of %s"
             % (RES_BASE, format(p["table_bytes"], ","),
                format(p["resident_bytes"], ","),
                format(4 + p["table_bytes"] + p["resident_bytes"], ","),
                format(RES_CAP, ",")))
    L.append("  rotating pages %d, block cap %s B" % (len(p["pages"]), format(ROT_CAP, ",")))
    for pg in p["pages"]:
        L.append("    page %d  block $%02X  sig $%04X  %5s B  %d track(s)  beats %d..%d"
                 % (pg["index"], pg["block"], pg["sig"], format(pg["bytes"], ","),
                    pg["tracks"], pg["beats"][0], pg["beats"][-1]))
    L.append("  mid-scene reads:")
    for r in p["reads"]:
        pg = p["pages"][r["page"]]
        L.append("    at beat %-2d -> page %d into block $%02X (%d track(s))"
                 % (r["at_beat"], r["page"], r["block"], pg["tracks"]))
    L.append("  per-beat map:")
    for s in p["schedule"]:
        L.append("    beat %-2d %-14s plays %-4d block $%02X sig $%04X%s%s"
                 % (s["beat"], s["name"], s["plays"], s["block"], s["sig"],
                    "  (resident-only)" if s["resident_only"] else "",
                    "  <- READ page %d" % s["read"] if s["read"] is not None else ""))
    return "\n".join(L)
