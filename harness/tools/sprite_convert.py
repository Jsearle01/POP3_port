#!/usr/bin/env python3
r"""
sprite_convert.py - POP cel (Apple II HGR) -> CoCo3 4-colour packed bytes.

PORTED FROM karateka_coco3 harness/tools/sprite_convert.py (read-only sibling
substrate, CLAUDE.md 2G). Reuse the SUBSTRATE, not the game.

WHAT CHANGED IN THE PORT (and nothing else):
  1. INPUT SOURCE. Karateka read a ca65 disassembly .s file and scraped `.byte`
     directives after a label. POP has real cel BINARIES: the `chtable` records
     inside oracle/source/01 POP Source/Images/IMG.CHTAB*. So extract_sprite_bytes
     (label scraping) is replaced by load_chtable / get_cel (binary records).
  2. HEADER BYTE ORDER - LOAD-BEARING, easy to get silently wrong:
         karateka cel: byte0 = HEIGHT, byte1 = WIDTH(bytes)
         POP cel:      byte0 = WIDTH(bytes), byte1 = HEIGHT
     [ref: HIRES.S:180-186 "Byte 0: width (bytes) / Byte 1: height (lines)"]
     The two are swapped. Reading POP cels with karateka's order yields a
     transposed, garbage sprite that still "converts" without raising.
  3. CLI. --source/--label -> --table/--index (plus --all for batch).

WHAT DID NOT CHANGE - the COLOUR MODEL:
  _classify_row_convert and convert_sprite_to_coco3 below are carried over
  VERBATIM (byte-identical; provable with harness/tools/verify_color_model.py).
  Jay's ruling: the HGR->4-colour colour model TRANSFERS FOR FREE, because POP
  and Karateka are both Apple II HGR sources and the artifact-colour physics
  (parity, NTSC chroma, gap threshold, colour-cell fill) is DISPLAY HARDWARE
  behaviour, not game-specific. No re-derivation was performed or attempted.

THE ONE POP-SPECIFIC VARIABLE - start_col:
  Colour depends on screen_col = start_col + local_col PARITY. POP's source
  gives the mapping exactly (unlike Karateka, where it had to be traced):
    * CVTX (GRAFIX.S:909) splits X into ByteTable[x] (byte col) + OffsetTable[x]
      (sub-byte 0-6). TABLES.S:51-67 generates those as `lup 36` loops, i.e.
      ByteTable[x] == x//7 and OffsetTable[x] == x%7 EXACTLY - so CVTX is a pure
      divmod-7 decomposition and  byte*7 + offset  IS the pixel column.
    * Character cels are queued by ADDMID (GRAFIX.S:341), which stores XCO->midX
      and OFFSET->midOFF - sub-byte precise. (bgX/fgX have no offset field, and
      ADDMIDEZ forces OFFSET=0: background is byte-aligned, characters are not.)
    * ADDCHARX (CTRLSUBS.S:355) gives the cel X as CharX +/- per-frame dx.
  What source CANNOT give is a single VALUE, because there isn't one: CharX is
  live state and the character moves. Per Jay's ruling this is fine - once
  converted, colour is FROZEN as CoCo3 palette indices (0..3), which carry no
  NTSC parity dependence, so a moving sprite's colours never change. start_col
  is a conversion-time input, consumed once. Pass it deliberately; it is
  recorded in the output header.

CoCo3 4-colour palette (unchanged):
  0 = Black   (background / transparent-candidate; see the opacity sidecar)
  1 = Orange  (bit7=1, odd screen col)   [MAME validated, karateka]
  2 = Blue    (bit7=1, even screen col)  [MAME validated, karateka]
  3 = White   (adjacent ON: interior/trailing/leading gap>=2)
"""

import os
import argparse
import pathlib


# ---------------------------------------------------------------- POP cel input
def load_chtable(path, base=0x6000):
    """Read a POP IMG.CHTAB* file -> list of cel dicts (index-aligned).

    Format: [count][ptr0_lo,ptr0_hi][ptr1..]... then the cel records, each
      byte0 = width in BYTES (7 px each), byte1 = height in LINES, then w*h bitmap.
    Pointers are absolute Apple addresses; `base` is the load address ($6000).
    [ref: HIRES.S:180-186; same reader as poc/compiled-sprite/popcc.py load_table]
    """
    b = pathlib.Path(path).read_bytes()
    n = b[0]
    cels = []
    for i in range(1, n + 1):
        p = 1 + 2 * (i - 1)
        off = (b[p] | (b[p + 1] << 8)) - base
        if not (0 <= off < len(b) - 1):
            cels.append(None)          # empty/invalid slot; keep index alignment
            continue
        w, h = b[off], b[off + 1]
        data = list(b[off + 2: off + 2 + w * h])
        cels.append(dict(idx=i, w=w, h=h, data=data))
    return cels


def get_cel(table_path, index):
    """One cel by 1-based index, validated."""
    cels = load_chtable(table_path)
    if not (1 <= index <= len(cels)):
        raise ValueError("index %d out of range 1..%d in %s" % (index, len(cels), table_path))
    cel = cels[index - 1]
    if cel is None:
        raise ValueError("index %d in %s is an empty slot" % (index, table_path))
    if len(cel["data"]) < cel["w"] * cel["h"]:
        raise ValueError("cel %d: truncated (%d < %d)" % (index, len(cel["data"]), cel["w"] * cel["h"]))
    return cel


# ==============================================================================
# COLOUR MODEL - CARRIED VERBATIM FROM KARATEKA. DO NOT EDIT.
# Any change here is out of scope per the P1.2 dispatch (6) and Jay's ruling
# that the model transfers free.
# Verify: python harness/tools/verify_color_model.py
# ==============================================================================

def _classify_row_convert(row_bytes, width_pixels):
    """Pre-scan a row; return col_info mapping ON pixel col -> (pos_in_run, run_len, gap_before, pal_bit)."""
    col_info = {}
    in_run = False
    run_start = 0
    prev_run_end = None

    for col in range(width_pixels + 1):
        if col < width_pixels:
            byte_idx = col // 7
            bit_pos  = col % 7
            p = (row_bytes[byte_idx] >> bit_pos) & 1 if byte_idx < len(row_bytes) else 0
        else:
            p = 0

        if p and not in_run:
            in_run = True
            run_start = col
        elif not p and in_run:
            run_end = col - 1
            run_len = run_end - run_start + 1
            gap = (run_start - prev_run_end - 1) if prev_run_end is not None else run_start
            pal_bit = (row_bytes[run_start // 7] >> 7) & 1 if run_start // 7 < len(row_bytes) else 0
            for i in range(run_len):
                col_info[run_start + i] = (i, run_len, gap, pal_bit)
            prev_run_end = run_end
            in_run = False

    return col_info


def convert_sprite_to_coco3(apple_ii_bytes, height, apple_width_bytes, start_col=0,
                            parity_flip=False, mirror=False):
    """
    Apple II sprite bitmap → CoCo3 4-color packed bytes.

    4-category color model (TASK 4 gate, 2026-05-16):
      isolated → screen-col parity color
      leading of run + gap==1 → screen-col parity color
      leading of run + gap>=2 → White
      interior/trailing → White
    [ref: MAME snap 0083; 113/113 gap=1 chroma, 120/120 gap>=2 White]

    Args:
      apple_ii_bytes: flat list of bitmap bytes (height * apple_width_bytes)
      height: rows
      apple_width_bytes: Apple II bytes per row (7 pixels each)
      start_col: Apple II screen pixel column of sprite left edge
                 Karateka: Logo 1 = 119, Logo 2 = 84
      mirror: horizontally flip the cel — reverse the per-row PIXEL list
              (each pixel = a 2-bit CoCo3 palette index) BEFORE packing, so the
              output is the left-right flip of the input with every pixel's
              palette index PRESERVED. This is a pixel-granularity reversal, NOT
              a byte- or bit-reverse (which would split/corrupt the 2-bit pairs).
              CoCo3-side analog of the oracle's $0900 pixel_flip (7-bit HGR),
              at 2-bit-pixel granularity for the GIME 4-color format. Used to
              pre-bake the guard's draw-B (faces-left) cels at convert time so no
              runtime pixel-mirror primitive is needed [ref: scene6-guard-facing
              STATIC, ae2502e; draw-B scope 4001a0f].
              PARITY NOTE: this reverses SHAPE and PRESERVES each pixel's baked
              color; the chroma (blue/orange) was computed at the pre-mirror
              screen columns, so a mirrored cel's on-screen hue is correct only
              when placed at a render column of matching parity — compose with
              --render-col-byte (the guard's actual column) and, for even
              width_pixels, --flip-parity. See the CLI help + the report.

    Returns:
      (coco3_bitmap: bytearray, coco3_width: int)
    """
    width_pixels = apple_width_bytes * 7
    coco3_width = (width_pixels + 3) // 4
    coco3_bitmap = bytearray()

    for row in range(height):
        row_bytes = apple_ii_bytes[row * apple_width_bytes:(row + 1) * apple_width_bytes]
        col_info = _classify_row_convert(row_bytes, width_pixels)

        row_indices = [0] * width_pixels  # default Black
        for col in range(width_pixels):
            if col in col_info:
                pos_in_run, run_len, gap, pal_bit = col_info[col]
                screen_col = start_col + col

                if run_len == 1:
                    # Isolated pixel: chroma at this col. parity_flip swaps the
                    # blue/orange assignment (for sprites whose real render-column
                    # parity differs from the start_col used) — color-only, no
                    # shape change. [ref: column-parity fix, 2026-06-14]
                    row_indices[col] = (2 if ((screen_col % 2 == 0) ^ parity_flip) else 1) if pal_bit == 1 else 2

                elif pos_in_run == 0 and gap == 1 and col > 0:
                    # NTSC chroma: attributed to this ON pixel, painted at col-1
                    # (-1 sub-pixel render offset). Color from ON pixel's screen col.
                    sc = start_col + col
                    chroma_idx = (2 if ((sc % 2 == 0) ^ parity_flip) else 1) if pal_bit == 1 else 2
                    row_indices[col - 1] = chroma_idx  # overwrite col-1 (was Black)
                    row_indices[col] = 3               # this ON pixel is White

                else:
                    row_indices[col] = 3  # White (interior/trailing/leading gap>=2)
            # OFF pixel: remains 0 (Black, already set)

        # Color-cell fill (Apple II artifact color): a SOLID color region is
        # drawn as an alternating-dot pattern (1010...), so the OFF dot between
        # two same-color ON dots is part of the color cell, not background —
        # the NTSC display merges them into a solid color bar. The naive 1:1
        # dot map leaves those gaps Black, producing vertical color/black
        # striping on solid fills (P4 engine-sandbox gate, 2026-06-13: Akuma
        # orange/blue bodies). Fill any Black dot flanked by the SAME chroma
        # (Orange=1 / Blue=2) on both sides. White (3) runs and isolated thin
        # color features (a lone dot with no same-color neighbor two cells out)
        # are left untouched.
        src_indices = list(row_indices)
        for c in range(1, width_pixels - 1):
            if src_indices[c] == 0:
                left = src_indices[c - 1]
                right = src_indices[c + 1]
                # INTERIOR ONLY: both neighbours must be ON (non-zero). Never fill
                # a black with a 0 neighbour, so exterior transparency around the
                # sprite is preserved and cannot block the floor behind it.
                if left != 0 and right != 0:
                    # Fill with the CHROMA (Blue=2 / Orange=1) of whichever neighbour
                    # is a chroma; a White(3) neighbour yields to the chroma. This
                    # covers BOTH the solid colour cell (blue-0-blue / orange-0-orange,
                    # original rule) AND the chroma cell's leading black at a
                    # white<->chroma boundary — the seam that left solid posts/rails
                    # like floor_9600 / floor_964A with an unfilled (transparent)
                    # slit between their white body and blue edge. White-0-white
                    # (no chroma either side) is left as-is.
                    if left in (1, 2):
                        row_indices[c] = left
                    elif right in (1, 2):
                        row_indices[c] = right

        # Horizontal mirror (opt-in): reverse the per-PIXEL list — each element is
        # a 2-bit CoCo3 palette index — so pixel [x] -> [width_pixels-1-x], every
        # palette index preserved. A pure list reversal at pixel granularity; NOT a
        # byte/bit reverse (which would corrupt the 2-bit pairs). Its own inverse
        # (mirror twice = identity). Done before packing so the packed bytes come
        # out already flipped. [--mirror: pre-baked draw-B cels, 2026-07-12]
        if mirror:
            row_indices = row_indices[::-1]

        for byte_idx in range(coco3_width):
            packed = 0
            for pix_idx in range(4):
                src = byte_idx * 4 + pix_idx
                if src < len(row_indices):
                    packed |= row_indices[src] << (6 - pix_idx * 2)
            coco3_bitmap.append(packed)

    return coco3_bitmap, coco3_width


# ==============================================================================
# END VERBATIM COLOUR MODEL
# ==============================================================================


def write_s_file(output_path, label, height, coco3_width, coco3_bitmap,
                 source_ref, apple_ref, start_col=0):
    """Write CoCo3 cel data as an lwasm .s file (fcb directives).

    OUTPUT CONTRACT - must not drift. Consumed by:
      - harness/tools/sprite_tool/celio.py  (Cel: header fcb H,W then H data rows)
      - poc/compiled-sprite/popcc.py        (PA.9 compiled-sprite pipeline)
    Header is `fcb H,W` = HEIGHT then COCO3_WIDTH. Note the asymmetry: POP's
    INPUT cel is width-first, but the OUTPUT format is karateka's height-first
    one, because that is what the downstream tools parse.
    """
    lines = [
        "* %s" % os.path.basename(str(output_path)),
        "* CoCo3 cel data - converted from POP Apple II HGR source.",
        "*",
        "* ORIGIN: %s" % source_ref,
        "*         POP cel: %s" % apple_ref,
        "* Colour model: adjacency + screen-col parity + colour-cell fill.",
        "*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified",
        "*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).",
        "*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White",
        "*   start_col=%d  screen-col parity=%s" % (start_col, "ODD" if start_col % 2 else "EVEN"),
        "* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]",
        "",
        "%s:" % label,
        "        fcb     %d,%d  ; height=%d rows, coco3_width=%d bytes/row (4px/byte)"
        % (height, coco3_width, height, coco3_width),
    ]
    for row in range(height):
        row_bytes = coco3_bitmap[row * coco3_width:(row + 1) * coco3_width]
        lines.append("        fcb     %s  ; row %d"
                     % (','.join('$%02X' % b for b in row_bytes), row))
    # LF, deliberately: .gitattributes pins `*.s text eol=lf`, so writing CRLF here
    # would make every re-convert show a spurious whole-file whitespace diff against
    # a fresh checkout. celio.Cel detects and preserves whichever style it finds, so
    # the authoring round-trip stays byte-identical either way.
    with open(str(output_path), 'w', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def convert_one(table_path, index, out_path, label, start_col=0,
                parity_flip=False, mirror=False, trim=True, quiet=False):
    """POP cel -> converted.s. Returns a dict describing what happened."""
    cel = get_cel(table_path, index)
    height, apple_width = cel["h"], cel["w"]        # POP order: byte0=W, byte1=H
    bitmap = cel["data"]

    # ------------------------------------------------------------------
    # VERTICAL FLIP AT INGEST — load-bearing. POP cel rows are stored
    # BOTTOM-ROW-FIRST. Three independent code sites in HIRES.S establish it:
    #
    #   1. PREPREP  : IMAGE += 2 past the [width][height] header, so IMAGE
    #                 points at DATA ROW 0 when drawing starts.
    #   2. CROP     : TOPEDGE = YCO - HEIGHT, and YCO is documented and used
    #                 as the "Y-coord of lowest visible line of image".
    #   3. draw loop: "Next line up" — IMAGE += WIDTH (source advances
    #                 FORWARD) while DEC YCO walks the destination UP, until
    #                 YCO reaches TOPEDGE.
    #
    #   => data row 0 is drawn at YCO, the BOTTOM scanline.
    #   => data row h-1 is drawn at TOPEDGE+1, the TOP scanline.
    #
    # The HIRES.S:187 comment "image bytes read left-right, top-bottom"
    # describes sequential storage, not visual orientation; taken as visual it
    # contradicts the three code sites above. CLAUDE.md §2 ranks comments
    # LOWEST and mechanism above them, so the code wins.
    #
    # karateka's cels are the other way round (row 0 = visual top), which is
    # why the colour model — carried over verbatim — needs no change but the
    # ROW ORDER does. Without this flip every converted POP cel, and every
    # compiled sprite built from one, renders upside down.
    # [P1.2-fix; caught by Jay's eye, not by the byte-level spot-check]
    bitmap = [b for r in range(height - 1, -1, -1)
              for b in bitmap[r * apple_width:(r + 1) * apple_width]]

    coco3_bitmap, coco3_width = convert_sprite_to_coco3(
        bitmap, height, apple_width, start_col, parity_flip, mirror)

    original_width = coco3_width
    lead = trail = 0
    if trim and coco3_width > 0:
        has = [any(coco3_bitmap[r * coco3_width + c] != 0 for r in range(height))
               for c in range(coco3_width)]
        if any(has):
            L = next(i for i in range(coco3_width) if has[i])
            R = next(i for i in range(coco3_width - 1, -1, -1) if has[i])
            if R - L + 1 < coco3_width:
                nb = bytearray()
                for r in range(height):
                    nb.extend(coco3_bitmap[r * coco3_width + L: r * coco3_width + R + 1])
                coco3_bitmap, lead, trail = nb, L, coco3_width - R - 1
                coco3_width = R - L + 1

    write_s_file(out_path, label, height, coco3_width, coco3_bitmap,
                 os.path.basename(str(table_path)),
                 "#%d (%dx%d bytes)" % (index, apple_width, height), start_col)

    info = dict(index=index, h=height, apple_w=apple_width, coco_w=coco3_width,
                orig_w=original_width, lead=lead, trail=trail,
                px_w=apple_width * 7, nbytes=height * coco3_width, out=str(out_path))
    if not quiet:
        msg = ("  cel #%-3d %dx%dB (%dx%dpx) -> coco3 %dx%dB"
               % (index, apple_width, height, apple_width * 7, height, coco3_width, height))
        if lead or trail:
            msg += "  [trim lead=%d trail=%d from W=%d]" % (lead, trail, original_width)
        print(msg + "  -> " + str(out_path))
    return info


def main():
    ap = argparse.ArgumentParser(description="POP Apple-II HGR cel -> CoCo3 4-colour converter")
    ap.add_argument('--table', required=True, help='Path to an IMG.CHTAB* file')
    ap.add_argument('--index', type=int, help='1-based cel index within the table')
    ap.add_argument('--all', action='store_true', help='Convert every cel in the table')
    ap.add_argument('--out', required=True,
                    help='Output .s path (--index), or output DIRECTORY (--all / --content-layout)')
    ap.add_argument('--label', default=None, help='CoCo3 label (default: <table>_<index>)')
    ap.add_argument('--start-col', type=int, default=0,
                    help='Apple II SCREEN PIXEL column of the cel left edge; sets blue/orange '
                         'parity. POP: pixel col = midX*7 + midOFF (GRAFIX.S:341 ADDMID). '
                         'Frozen at conversion time per Jay ruling.')
    ap.add_argument('--flip-parity', action='store_true',
                    help='Swap blue/orange (colour only, no shape change).')
    ap.add_argument('--mirror', action='store_true',
                    help='Horizontal flip at PIXEL granularity (2-bit indices preserved).')
    ap.add_argument('--no-trim', action='store_true',
                    help='Keep all-zero leading/trailing byte columns. NOTE: trimming shifts '
                         'the cel origin left by `lead` bytes - the placement table must '
                         'compensate (CLAUDE.md 2F: placement in the table, pixels in converted.s).')
    ap.add_argument('--content-layout', action='store_true',
                    help='Write <out>/<label>/converted.s (the sprite_tool cel-dir layout).')
    ap.add_argument('--quiet', action='store_true')
    args = ap.parse_args()

    if not args.all and args.index is None:
        ap.error("give --index N or --all")

    tbl = pathlib.Path(args.table)
    stem = tbl.name.replace('IMG.', '').replace('.', '_').lower()

    def dest(label):
        if args.content_layout:
            d = pathlib.Path(args.out) / label
            d.mkdir(parents=True, exist_ok=True)
            return d / "converted.s"
        if args.all:
            pathlib.Path(args.out).mkdir(parents=True, exist_ok=True)
            return pathlib.Path(args.out) / (label + ".s")
        return pathlib.Path(args.out)

    if not args.quiet:
        print("POP sprite_convert: %s  start_col=%d (parity %s)"
              % (tbl.name, args.start_col, "ODD" if args.start_col % 2 else "EVEN"))

    if args.all:
        n = 0
        for c in load_chtable(tbl):
            if c is None:
                continue
            label = "%s_%03d" % (stem, c['idx'])
            convert_one(tbl, c['idx'], dest(label), label, args.start_col,
                        args.flip_parity, args.mirror, not args.no_trim, args.quiet)
            n += 1
        print("Converted %d cels -> %s" % (n, args.out))
    else:
        label = args.label or ("%s_%03d" % (stem, args.index))
        convert_one(tbl, args.index, dest(label), label, args.start_col,
                    args.flip_parity, args.mirror, not args.no_trim, args.quiet)


if __name__ == '__main__':
    main()
