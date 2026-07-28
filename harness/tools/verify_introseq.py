#!/usr/bin/env python3
"""verify_introseq.py — check the five captured screens against the assets.

The sequencer's correctness is not "a picture appeared". It is four specific
claims, and each one is a byte comparison against something built independently
of the 6809 code:

  1. the base screen is the converted splash, centred per the virtual-resolution
     contract (content at bytes 10..149 of each 160-byte row)
  2. the caption screen is that base with the patch applied -- so both the run
     decoder and the +20 px column bias are right, not merely plausible
  3. the caption's removal is EXACT: after the flip, the visible page is
     byte-identical to the base screen. Not "close" -- identical.
  4. the second caption's screen carries the byline and NO TRACE of the first.
     This is the real test of the undo path: the byline is drawn onto the page
     the "Presents" caption was drawn on, so a failed repair shows up here as
     two captions at once, which is exactly how it would look on screen.

Any mismatch is reported as a count plus the first differing row/column, because
"N bytes differ" without a location is not a diagnosis.
"""
import argparse
import pathlib
import sys

FB_STRIDE = 160
ROWS = 192
SRC_STRIDE = 140
LEFT_MARGIN = 10


def base_framebuffer(packed, fill):
    fb = bytearray([fill]) * (FB_STRIDE * ROWS)
    for y in range(ROWS):
        o = y * FB_STRIDE + LEFT_MARGIN
        fb[o:o + SRC_STRIDE] = packed[y * SRC_STRIDE:(y + 1) * SRC_STRIDE]
    return fb


def apply_patch(fb, blob):
    """Replay the sparse run list — the same walk patch_blit does in 6809."""
    row = blob[0] * 256 + blob[1]
    nrows = blob[2]
    i = 3
    runs = 0
    for r in range(row, row + nrows):
        nruns = blob[i]; i += 1
        for _ in range(nruns):
            col, ln = blob[i], blob[i + 1]; i += 2
            fb[r * FB_STRIDE + col:r * FB_STRIDE + col + ln] = blob[i:i + ln]
            i += ln
            runs += 1
    if i != len(blob):
        sys.exit(f"patch stream desync: consumed {i} of {len(blob)} bytes")
    return runs


def first_diff(a, b):
    for i in range(min(len(a), len(b))):
        if a[i] != b[i]:
            return i // FB_STRIDE, i % FB_STRIDE, a[i], b[i]
    return None


def compare(name, got, want):
    if len(got) != len(want):
        print(f"  FAIL {name}: {len(got)} bytes, expected {len(want)}")
        return False
    n = sum(1 for x, y in zip(got, want) if x != y)
    if n == 0:
        print(f"  PASS {name}: {len(got)} bytes byte-identical")
        return True
    r, c, g, w = first_diff(got, want)
    print(f"  FAIL {name}: {n} bytes differ; first at row {r} col {c} "
          f"(got ${g:02X} want ${w:02X})")
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dumps', required=True)
    ap.add_argument('--base', default='content/intro/broderbund_splash.bin')
    ap.add_argument('--presents', default='content/intro/delta_presents.bin')
    ap.add_argument('--byline', default='content/intro/delta_byline.bin')
    ap.add_argument('--title', default='content/intro/delta_title.bin')
    ap.add_argument('--prolog1', default='content/intro/prolog1.bin')
    ap.add_argument('--prolog2', default='content/intro/prolog2.bin')
    a = ap.parse_args()

    d = pathlib.Path(a.dumps)
    got = {}
    for tag in ('1_base', '2_presents_up', '3_presents_clear', '4_byline_up',
                '5_byline_clear', '6_title_up', '7_title_clear',
                '8_prolog1', '9_prolog2', '10_title_reprise', '11_done'):
        p = d / f'{tag}.bin'
        if not p.exists():
            sys.exit(f"missing capture {p} — the sequence did not reach that state")
        got[tag] = p.read_bytes()

    packed = pathlib.Path(a.base).read_bytes()
    fill = got['1_base'][0]
    margin = got['1_base'][:LEFT_MARGIN]
    if any(b != fill for b in margin):
        print(f"  note: left margin is not uniform ({margin.hex()})")
    print(f"background fill observed: ${fill:02X}")

    base_fb = base_framebuffer(packed, fill)
    pres_fb = bytearray(base_fb)
    n1 = apply_patch(pres_fb, pathlib.Path(a.presents).read_bytes())
    byl_fb = bytearray(base_fb)
    n2 = apply_patch(byl_fb, pathlib.Path(a.byline).read_bytes())
    ttl_fb = bytearray(base_fb)
    n3 = apply_patch(ttl_fb, pathlib.Path(a.title).read_bytes())
    print(f"patches replayed offline: presents {n1} runs, byline {n2} runs, "
          f"title {n3} runs")

    ok = True
    ok &= compare("base screen == converted splash, centred", got['1_base'], base_fb)
    ok &= compare("caption 1 == base + presents patch", got['2_presents_up'], pres_fb)
    ok &= compare("caption 1 removal is exact", got['3_presents_clear'], base_fb)
    ok &= compare("caption 2 == base + byline patch ONLY", got['4_byline_up'], byl_fb)
    ok &= compare("caption 2 removal is exact", got['5_byline_clear'], base_fb)
    ok &= compare("title == base + title patch ONLY", got['6_title_up'], ttl_fb)
    ok &= compare("title removal is exact", got['7_title_clear'], base_fb)
    # the prologue beats replace the picture outright -- their own framebuffer,
    # no patch, so the check is against the converted image itself
    for tag, src in (('8_prolog1', a.prolog1), ('9_prolog2', a.prolog2)):
        want = base_framebuffer(pathlib.Path(src).read_bytes(), fill)
        ok &= compare(f"{tag} == its own converted picture", got[tag], want)
    # the reprise re-establishes the splash from disk and stamps the SAME title
    # patch on it -- so it must equal beat 3's title screen exactly, byte for byte,
    # despite having got there by a completely different route.
    ok &= compare("reprise == the SAME screen as beat 3's title",
                  got['10_title_reprise'], ttl_fb)
    ok &= compare("reprise removal is exact", got['11_done'], base_fb)

    print("VERDICT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
