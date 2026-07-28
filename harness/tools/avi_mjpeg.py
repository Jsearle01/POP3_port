#!/usr/bin/env python3
"""avi_mjpeg.py — re-encode MAME's uncompressed AVI as MJPEG. No ffmpeg required.

MAME's -aviwrite emits uncompressed 24-bpp DIB frames: correct, playable, and
about 27 MB per emulated second, which is not something to drop into a folder that
syncs to the cloud. There is no ffmpeg on this machine and installing one is not
this task's business, so the transcode is done here: parse the RIFF, JPEG each
frame with PIL, and write a standard MJPEG AVI with the SAME frame rate, so the
result plays at real speed rather than merely containing the right pictures.

Frames are stored BOTTOM-UP and BGR (the DIB convention), which is what the
`'raw', 'BGR', 0, -1` decoder arguments say -- getting either wrong yields an
upside-down or blue-tinted video that still plays, so it is worth stating.
"""
import argparse
import io
import pathlib
import struct
import sys

from PIL import Image


def parse_source(path):
    """-> (width, height, us_per_frame, [(offset, length), ...]) for the frames."""
    f = path.open('rb')
    if f.read(4) != b'RIFF' or f.read(8)[4:] != b'AVI ':
        sys.exit(f'{path} is not a RIFF/AVI file')
    w = h = us = None
    frames = []

    def walk(end):
        nonlocal w, h, us
        while f.tell() < end - 8:
            cid = f.read(4)
            if len(cid) < 4:
                return
            sz = struct.unpack('<I', f.read(4))[0]
            body = f.tell()
            if cid == b'LIST':
                kind = f.read(4)
                if kind == b'movi':
                    while f.tell() < body + sz - 8:
                        c2 = f.read(4)
                        s2 = struct.unpack('<I', f.read(4))[0]
                        if c2[2:] in (b'db', b'dc'):
                            frames.append((f.tell(), s2))
                        f.seek(s2 + (s2 & 1), 1)
                else:
                    walk(body + sz)
            elif cid == b'avih':
                v = struct.unpack('<14I', f.read(56))
                us, w, h = v[0], v[8], v[9]
            f.seek(body + sz + (sz & 1))

    f.seek(0, 2)
    end = f.tell()
    f.seek(12)
    walk(end)
    return w, h, us, frames, f


def fourcc(s):
    return s.encode('ascii')


def write_mjpeg(out, w, h, us_per_frame, jpegs):
    """A minimal, standard MJPEG AVI: hdrl(avih, strl(strh, strf)), movi, idx1."""
    rate_num, rate_den = 1000000, us_per_frame      # frames per second = num/den
    n = len(jpegs)
    biggest = max(len(j) for j in jpegs)

    avih = struct.pack('<14I', us_per_frame, 0, 0, 0x10, n, 0, 1, biggest,
                       w, h, 0, 0, 0, 0)            # 0x10 = AVIF_HASINDEX
    strh = (fourcc('vids') + fourcc('MJPG')
            + struct.pack('<IHHIIIIIIIi', 0, 0, 0, 0, rate_den, rate_num, 0, n,
                          biggest, 0xFFFFFFFF, 0)
            + struct.pack('<4h', 0, 0, w, h))
    strf = struct.pack('<IiiHH4sIiiII', 40, w, h, 1, 24, fourcc('MJPG'),
                       w * h * 3, 0, 0, 0, 0)

    def chunk(cid, data):
        return cid + struct.pack('<I', len(data)) + data + (b'\0' * (len(data) & 1))

    strl = chunk(fourcc('strh'), strh) + chunk(fourcc('strf'), strf)
    hdrl = fourcc('hdrl') + chunk(fourcc('avih'), avih) \
        + chunk(fourcc('LIST'), fourcc('strl') + strl)[0:0] \
        + fourcc('LIST') + struct.pack('<I', 4 + len(strl)) + fourcc('strl') + strl

    movi_body = bytearray()
    index = bytearray()
    for j in jpegs:
        # dwChunkOffset is measured from the 'movi' FOURCC, so the first frame's
        # offset is 4 -- the classic off-by-four that makes seeking wrong while
        # straight playback still works.
        index += fourcc('00dc') + struct.pack('<III', 0x10, 4 + len(movi_body), len(j))
        movi_body += chunk(fourcc('00dc'), j)

    hdrl_chunk = fourcc('LIST') + struct.pack('<I', len(hdrl)) + hdrl
    movi_chunk = fourcc('LIST') + struct.pack('<I', 4 + len(movi_body)) \
        + fourcc('movi') + bytes(movi_body)
    idx1_chunk = chunk(fourcc('idx1'), bytes(index))
    payload = fourcc('AVI ') + hdrl_chunk + movi_chunk + idx1_chunk
    out.write_bytes(fourcc('RIFF') + struct.pack('<I', len(payload)) + payload)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--first', type=int, default=0, help='first source frame to keep')
    ap.add_argument('--last', type=int, default=-1)
    ap.add_argument('--quality', type=int, default=92)
    a = ap.parse_args()

    src = pathlib.Path(a.src)
    w, h, us, frames, f = parse_source(src)
    last = len(frames) - 1 if a.last < 0 else min(a.last, len(frames) - 1)
    keep = frames[a.first:last + 1]
    print(f'{src.name}: {w}x{h}, {len(frames)} frames @ {1e6/us:.3f} fps'
          f'  -> keeping {len(keep)} ({len(keep)*us/1e6:.1f} s)')

    jpegs = []
    for k, (off, ln) in enumerate(keep):
        f.seek(off)
        raw = f.read(ln)
        img = Image.frombytes('RGB', (w, h), raw, 'raw', 'BGR', 0, -1)
        buf = io.BytesIO()
        img.save(buf, 'JPEG', quality=a.quality, subsampling=0)   # 4:4:4 — the art
        jpegs.append(buf.getvalue())                              # is flat colour
        if k % 200 == 0:
            print(f'  {k}/{len(keep)}', flush=True)
    f.close()

    out = pathlib.Path(a.out)
    write_mjpeg(out, w, h, us, jpegs)
    print(f'{out}: {out.stat().st_size/1048576:.1f} MB, {len(jpegs)} frames, '
          f'{len(jpegs)*us/1e6:.1f} s @ {1e6/us:.3f} fps'
          f'  (source was {src.stat().st_size/1048576:.0f} MB)')


if __name__ == '__main__':
    main()
