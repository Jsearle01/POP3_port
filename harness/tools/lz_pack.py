#!/usr/bin/env python3
"""lz_pack.py — the intro screens' compressor, and the reference decoder.

WHY THIS FORMAT, MEASURED RATHER THAN ASSUMED. The screens are 30,720 B raw
framebuffers = 7 tracks = 9.0 s of disk each, and disk is ~30 s of a ~90 s intro.
Four encodings were measured on the three real screens before anything was built:

    encoding              avg bytes   tracks   note
    PackBits (byte RLE)      25,934       6     images are dithered; runs are rare
    RLE16                    26,965       6     worse -- longer counts don't help
    row-XOR + PackBits       15,102       4     vertical coherence is real
    LZSS 12/4                 6,462       2
    LZ4-style                 5,994       2     best simple decoder
    zlib -9                   4,281       1     needs a Huffman decoder on 6809

Two findings decided it. **Row-XOR helps RLE and HURTS LZ** (10,679 vs 8,445 on the
splash) -- the delta destroys the long literal matches an LZ lives on, so the two
techniques are alternatives, not a stack. And **zlib's extra track is not worth a
Huffman decoder**: 1.3 s per screen against an entropy coder in 6809 assembly.

A lazy parse was tried to reach a ONE-track fit and missed: 4,983 and 4,778 against
a 4,608 B track. Chasing the last 170 B was rejected -- a 1.6% margin that any asset
edit would break is a coincidence with a threshold, not a design.

    21 tracks -> 6 tracks, 27.5 s -> 7.9 s of disk across the intro.

THE FORMAT is LZ4's block layout with one deliberate change: **offsets are BIG-endian**
so the 6809 loads one with a plain `ldd` instead of swapping halves.

    token byte:  high nibble = literal count, low nibble = match length - 4
                 a nibble of 15 means "add the following 255-chain"
    literals:    that many bytes, copied straight out
    offset:      2 bytes, BIG-endian, distance back from the current output position
                 (absent on the final literal-only token, which ends the stream)

IN-PLACE EXPANSION, AND THE 1,536 BYTES THAT MAKE IT FIT. The 128 KB machine has no
spare 30 KB, so a screen is expanded inside the buffer it will be displayed from:
the compressed bytes are read high in the draw window and expanded from the buffer
start. That is safe only while the write pointer stays behind the read pointer, so
the stream must start at least `peak` bytes in, where peak is the high-water mark of
(bytes written - bytes consumed).

Expansion-so-far is NOT monotonic -- a literal run shrinks it, because the token
byte is consumed and produces nothing -- so the peak can occur mid-stream and fall
back. Measured, it sits 7-13 B ABOVE the final value (N - C), which is why placing
the stream flush at the end of a 30,720 B framebuffer misses by a few bytes on all
three screens.

What closes it: the draw window is 4 x 8 KB = 32,768 B while the framebuffer is
30,720, and $FF00-$FFFF is I/O with $FE00-$FEFF held constant by MC3=1. So
$8000-$FDFF = **32,256 usable bytes**, giving 1,536 B above the visible buffer. The
stream is placed flush against THAT ceiling instead:

    stream start = 32,256 - C     (splash 23,952 / prolog1 27,314 / prolog2 27,519)
    peak         = 22,423 / 25,785 / 25,990        -> 1.5 KB of slack on every screen

A screen is therefore stored as a whole number of tracks, header first, stream flush
at the end, and the loader reads the blob to the top of the window. `pack()` checks
the constraint and then VERIFIES it by simulating the in-place expansion exactly as
the 6809 will do it -- decoding out of the same buffer it writes into -- rather than
trusting the arithmetic.
"""
import argparse
import pathlib
import struct
import sys

MIN_MATCH = 4
MAGIC = 0x4C5A            # 'LZ'


def _matcher(d):
    """hash-chain over 4-byte keys; plain dict, since this runs offline."""
    pos_of = {}
    chain = [-1] * len(d)

    def add(i):
        k = bytes(d[i:i + MIN_MATCH])
        chain[i] = pos_of.get(k, -1)
        pos_of[k] = i

    def best(i, tries=512):
        k = bytes(d[i:i + MIN_MATCH])
        j = pos_of.get(k, -1)
        bl, bo = 0, 0
        lim = len(d) - i
        while j != -1 and tries:
            l = MIN_MATCH
            while l < lim and d[j + l] == d[i + l]:
                l += 1
            if l > bl:
                bl, bo = l, i - j
            j = chain[j]
            tries -= 1
        return bl, bo

    return add, best


def compress(d):
    add, best = _matcher(d)
    out = bytearray()
    i = anchor = 0

    def emit(litlen, mlen, off):
        out.append((min(litlen, 15) << 4) | min(mlen, 15))
        n = litlen - 15
        while n >= 0:
            out.append(min(n, 255)); n -= 255
        out.extend(d[anchor:anchor + litlen])
        if off:
            out.extend(struct.pack('>H', off))   # BIG-endian: one ldd on 6809
            n = mlen - 15
            while n >= 0:
                out.append(min(n, 255)); n -= 255

    while i < len(d) - MIN_MATCH:
        l, o = best(i)
        if l >= MIN_MATCH:
            # lazy: a longer match one byte along is worth the extra literal
            l2, _ = best(i + 1) if i + 1 < len(d) - MIN_MATCH else (0, 0)
            if l2 > l + 1:
                add(i); i += 1
                continue
            emit(i - anchor, l - MIN_MATCH, o)
            for k in range(i, i + l):
                if k < len(d) - MIN_MATCH:
                    add(k)
            i += l
            anchor = i
        else:
            add(i); i += 1
    emit(len(d) - anchor, 0, 0)
    return bytes(out)


def decompress(src, outlen):
    """Reference decoder — the 6809 must agree with this byte for byte."""
    out = bytearray()
    i = 0
    while len(out) < outlen:
        tok = src[i]; i += 1
        litlen = tok >> 4
        if litlen == 15:
            while True:
                b = src[i]; i += 1; litlen += b
                if b != 255:
                    break
        out += src[i:i + litlen]; i += litlen
        if len(out) >= outlen:
            break
        off = struct.unpack('>H', src[i:i + 2])[0]; i += 2
        mlen = (tok & 15) + MIN_MATCH
        if (tok & 15) == 15:
            while True:
                b = src[i]; i += 1; mlen += b
                if b != 255:
                    break
        p = len(out) - off
        for k in range(mlen):          # byte at a time: overlapping runs are legal
            out.append(out[p + k])
    return bytes(out)


def margin(src, outlen):
    """Peak of (bytes written - bytes consumed). The compressed data must start
    at least this far past the output start for in-place expansion to be safe."""
    peak = 0
    produced = consumed = 0
    i = 0
    while produced < outlen:
        tok = src[i]; i += 1
        litlen = tok >> 4
        if litlen == 15:
            while True:
                b = src[i]; i += 1; litlen += b
                if b != 255:
                    break
        i += litlen
        produced += litlen
        consumed = i
        peak = max(peak, produced - consumed)
        if produced >= outlen:
            break
        i += 2
        mlen = (tok & 15) + MIN_MATCH
        if (tok & 15) == 15:
            while True:
                b = src[i]; i += 1; mlen += b
                if b != 255:
                    break
        produced += mlen
        consumed = i
        peak = max(peak, produced - consumed)
    return max(peak, 0)


def inplace_decode(blob, outlen, load_off, cap):
    """Decode EXACTLY as the 6809 will: one buffer, source high in it, output from
    the bottom. Returns the buffer, or dies naming the byte where the writer caught
    the reader. This is the check that matters -- the arithmetic above is only the
    reason to expect it to pass."""
    buf = bytearray(cap)
    buf[load_off:load_off + len(blob)] = blob
    src = load_off + struct.unpack('>H', blob[4:6])[0]
    w = 0
    while w < outlen:
        if w > src:
            sys.exit(f"in-place OVERTAKE: writer at {w} passed reader at {src}")
        tok = buf[src]; src += 1
        litlen = tok >> 4
        if litlen == 15:
            while True:
                b = buf[src]; src += 1; litlen += b
                if b != 255:
                    break
        for _ in range(litlen):
            if w > src:
                sys.exit(f"in-place OVERTAKE in literals: {w} > {src}")
            buf[w] = buf[src]; w += 1; src += 1
        if w >= outlen:
            break
        off = (buf[src] << 8) | buf[src + 1]; src += 2
        mlen = (tok & 15) + MIN_MATCH
        if (tok & 15) == 15:
            while True:
                b = buf[src]; src += 1; mlen += b
                if b != 255:
                    break
        p = w - off
        for _ in range(mlen):
            buf[w] = buf[p]; w += 1; p += 1
    return bytes(buf[:outlen])


def pack(raw, track_bytes, cap):
    """A screen as it lives on disk: whole tracks, 6-byte header at the front,
    stream flush against the end so it lands as high in the window as possible."""
    c = compress(raw)
    got = decompress(c, len(raw))
    if got != raw:
        n = next(k for k in range(len(raw)) if got[k] != raw[k])
        sys.exit(f"round-trip FAILED at byte {n}")

    tracks = -(-(len(c) + 6) // track_bytes)
    size = tracks * track_bytes
    load_off = cap - size                       # blob sits at the top of the window
    stream_off = size - len(c)                  # stream flush at the blob's end
    peak = margin(c, len(raw))
    start = load_off + stream_off
    if start < peak:
        sys.exit(f"in-place UNSAFE: stream starts at {start}, needs >= {peak}")

    # $00 unpacked length, $02 packed length, $04 stream offset within the blob
    blob = bytearray(size)
    blob[0:6] = struct.pack('>HHH', len(raw), len(c), stream_off)
    blob[stream_off:stream_off + len(c)] = c

    if inplace_decode(bytes(blob), len(raw), load_off, cap) != raw:
        sys.exit("in-place decode did not reproduce the source")
    return bytes(blob), len(c), tracks, load_off, start - peak


def emit_inc(path, dest_base, cap, size, tracks, clen, outlen, slack):
    """The engine's copy of where the blob lands — generated, because it MOVES.

    `load = base + cap - size` is not a constant a source file can carry: it steps by a
    whole track every time the packed stream crosses one. A hand-kept copy is correct
    right up to the build that grows the bundle, and then it reads the blob from the
    wrong address -- which presents as a machine that hangs, not as a mismatch.
    """
    load = dest_base + cap - size
    pathlib.Path(path).write_text(
        "* GENERATED by harness/tools/lz_pack.py --emit-inc — do not hand-edit.\n"
        "*\n"
        "* The packed cutscene bundle, as actually packed by this build:\n"
        "*   raw %d B -> %d B packed (%.1f%%), %d whole track(s) = %d B\n"
        "*   window $%04X..$%04X (%d B); blob flush against the top of it\n"
        "*   unpacked extent $%04X..$%04X; in-place slack %d B (lz_pack proved it by\n"
        "*   decoding the blob out of one buffer exactly as lz_unpack does)\n"
        "FLAME_LOAD      equ     $%04X\n"
        "FLAME_TRACKS    equ     %d\n"
        "FLAME_RAW       equ     %d\n"
        % (outlen, clen, 100.0 * clen / outlen, tracks, size,
           dest_base, dest_base + cap - 1, cap,
           dest_base, dest_base + outlen - 1, slack,
           load, tracks, outlen),
        encoding='utf-8')
    return load


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('inputs', nargs='+')
    ap.add_argument('--out-dir', required=True)
    ap.add_argument('--track-bytes', type=int, default=4608)
    ap.add_argument('--window-cap', type=int, default=32256,
                    help='usable bytes of the window the blob is expanded inside')
    # THE BUNDLE IS NOT A SCREEN, and the difference is entirely in these two numbers.
    # A screen is expanded inside the 32,256 B draw window from $8000; the cutscene
    # bundle is expanded inside main RAM from FLAME_BASE up to the disk driver's
    # parameter block. Same routine, same in-place proof, different window -- so the
    # window is an argument rather than the constant it used to be.
    ap.add_argument('--dest-base', type=lambda s: int(s, 0), default=0x8000,
                    help='address the expanded image starts at (for the emitted .inc)')
    ap.add_argument('--emit-inc',
                    help='write FLAME_LOAD/FLAME_TRACKS for the assembler')
    a = ap.parse_args()

    total_raw = total_trk = 0
    loads = set()
    for p in map(pathlib.Path, a.inputs):
        raw = p.read_bytes()
        blob, clen, trk, load_off, slack = pack(raw, a.track_bytes, a.window_cap)
        o = pathlib.Path(a.out_dir) / (p.stem + '.lz')
        o.write_bytes(blob)
        raw_trk = -(-len(raw) // a.track_bytes)
        total_raw += raw_trk
        total_trk += trk
        loads.add(load_off)
        print(f"{p.name:20s} {len(raw):6d} -> {clen:6d} B "
              f"({100 * clen / len(raw):4.1f}%), {raw_trk} -> {trk} tracks, "
              f"load at +{load_off}, in-place slack {slack} B")
        if a.emit_inc:
            load = emit_inc(a.emit_inc, a.dest_base, a.window_cap,
                            trk * a.track_bytes, trk, clen, len(raw), slack)
            end = a.dest_base + len(raw) - 1
            print(f"{'':20s} unpacked ${a.dest_base:04X}..${end:04X}; "
                  f"blob loads ${load:04X}..${load + trk * a.track_bytes - 1:04X} "
                  f"({trk} whole tracks); {a.window_cap - len(raw)} B below the window top")
    print(f"{'':20s} {total_raw} tracks -> {total_trk} tracks "
          f"({(total_raw - total_trk) * 1.31:.1f} s of disk saved)")
    if len(loads) == 1:
        print(f"{'':20s} every screen loads to framebuffer +{loads.pop()} "
              f"-- one constant for the engine")
    else:
        print(f"{'':20s} NOTE: differing load offsets {sorted(loads)} — the engine "
              f"needs a per-screen constant")


if __name__ == '__main__':
    main()
