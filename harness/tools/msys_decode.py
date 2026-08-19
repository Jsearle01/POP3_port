"""msys_decode.py — P4.19: the MSYS note-stream grammar, executed.

★★★ WHAT THIS IS. A faithful re-implementation of MSYS.S's note-stream interpreter
(`MINIT`/`NEWNOTE`/`MPLAY`/`MSEG` and the second-voice twins), run over the real song
bytes from `MUSIC.SET1`. It exists to ANSWER ONE QUESTION: does the decoded grammar
reproduce the CAPTURED speaker trace of the same song?

★★ THAT CHECK IS TIER 2, NOT TIER 3. CLAUDE.md §2 ranks the execution trace above the
source. A hand-walk of the bytes against the listing is source-checking-source; running
the grammar and diffing it against `build/tmp/boot/song_*.txt` — MAME's own record of
the oracle's speaker toggles — puts the decode on the trace.

★ THE SEGMENT COST IS COUNTED FROM THE LISTING, NOT ESTIMATED:

    MSEG straight-line + MADJLP + MLMDI/MDLOOP + MVDIT
      = 5*R8*(1+MLBL300) + 9*MLBL300 + 47                      cycles

  MADJLP runs (R8-R6) times and MVDIT runs R6 times, so the PULSE WIDTH cancels out of
  the PERIOD — that is the constant-period/variable-duty trick (P4.3, note_freq.py) and
  this expression is the same one with `MLBL300` no longer assumed to be 1.

★★★ MLBL300 IS THE CORRECTION note_freq.py DID NOT HAVE. `NEWNOTE` writes 7 into it when
the pitch index is BELOW $19 and 1 otherwise [MSYS.S:294-299], so the bottom two octaves
run the delay loop SEVEN TIMES. note_freq.py assumed 1 throughout and therefore reported
the lowest 24 notes FOUR TIMES TOO HIGH.

The pulse the trace can see:  M30A .. M30B  =  5*R6 + 3 cycles.
"""
import argparse
import pathlib
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# ---------------------------------------------------------------- MSYS tables
# MSYS.S:30-42
NOTE = [122, 254, 238, 226, 214, 202, 190, 178, 170, 158, 150, 142, 134,
        126, 118, 112, 106, 100, 94, 88, 84, 78, 74, 70, 66,
        250, 234, 222, 210, 198, 186, 174, 166, 154, 146, 138, 130,
        122, 114, 108, 102, 96, 90, 84, 80, 74, 70, 66, 62,
        58, 54, 51, 48, 45, 42, 39, 37, 34, 32, 30, 28,
        26, 24, 22, 21, 19, 18, 17, 16, 15, 14, 13, 12,
        11, 10, 9]
LENGTH = [28, 4, 4, 4, 4, 4, 5, 5, 5, 6, 6, 6, 7,
          7, 8, 8, 8, 9, 9, 10, 11, 11, 12, 13, 13,
          14, 15, 16, 17, 18, 19, 20, 21, 23, 24, 25, 27,
          28, 30, 32, 34, 36, 38, 40, 42, 45, 48, 50, 53,
          57, 60, 64, 67, 71, 76, 81, 84, 91, 95, 101, 107,
          113, 121, 125, 134, 139, 151, 158, 165, 181, 191, 201, 213,
          227, 242, 255]


def _hx(s):
    return [int(s[i:i + 2], 16) for i in range(0, len(s), 2)]


# MSYS.S:43-59 — the envelope (MV) patterns.
MV = [
    _hx("0E0100FF"),
    _hx("0E04020100FF"),
    _hx("0E080604020100FF"),
    _hx("0E0A080605040302010100FF"),
    _hx("0E0A08070605040403037F02020202010101010100FF"),
    _hx("010B0DFF"),
    _hx("000103050B0DFF"),
    _hx("000102030405060708090A0B0C0DFF"),
    _hx("010E7F0200FF"),
    _hx("01040E7F040100FF"),
    _hx("010306090E7F0906030100FF"),
    _hx("0E060B040803060205010501040003000200020001000100010001000100FF"),
    _hx("01040E040D040C040B040B040B040B040B040B040B040B040B040B04FF"),
    _hx("040E087F040100FF"),
    _hx("0E02087F040100FF") + _hx("0B030A030903080307030603050304030403FF"),
    _hx("01030B0301030B0301030B0301030B0301030B03"
        "01030B0301030B0301030B0201020401FF"),
]

# MSYS.S:60-134 — the harmonic (HM) patterns.  Value 1 selects VTBL+0, which is never
# rewritten and is therefore ALWAYS ZERO: a value of 1 is a SILENT segment.
HM = [
    [1, 3, 128],
    [3, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 2, 1, 2, 1,
     1, 1, 1, 2, 1, 1, 2, 1, 1, 1, 2, 1, 1, 1, 2, 1, 1,
     2, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 128],
    [3, 1, 1, 1, 1, 2, 2, 1, 1, 1, 2, 1, 2, 1, 1, 2, 1, 1,
     2, 1, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 128],
    [3, 1, 1, 1, 2, 2, 1, 1, 2, 1, 2, 1, 2, 1, 1, 2, 2, 1, 1, 1, 128],
    [3, 1, 1, 2, 2, 1, 2, 1, 2, 2, 1, 1, 128],
    [3, 1, 1, 1, 1, 2, 1, 2, 1, 1, 2, 1, 1, 1, 2, 2, 1, 1,
     1, 1, 2, 2, 1, 1, 1, 2, 1, 1, 2, 1, 2, 1, 1, 1, 1, 128],
    [3, 1, 2, 2, 2, 1, 128],
    [3, 1, 1, 1, 1, 2, 1, 1, 2, 1, 2, 1, 1, 1, 1, 2, 2, 1, 1,
     1, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 2, 1, 2, 1, 1, 2, 1, 1, 1, 1, 128],
    [3, 1, 1, 2, 1, 2, 2, 1, 1, 2, 2, 1, 2, 1, 1, 128],
    [3, 1, 1, 1, 2, 1, 1, 2, 2, 1, 1, 1, 2, 1, 2, 1, 2,
     1, 1, 1, 2, 2, 1, 1, 2, 1, 1, 1, 128],
    [3, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1,
     1, 1, 1, 2, 1, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 1, 1,
     2, 1, 1, 1, 1, 2, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 2,
     1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 2, 1, 1, 1, 1,
     2, 1, 1, 1, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1,
     1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 128],
    [3, 2, 128],
    [5, 2, 3, 2, 4, 2, 3, 2, 128],
    [4, 1, 1, 1, 1, 1, 2, 2, 1, 2, 1, 1, 2, 1, 2, 1, 1, 1, 3, 1, 1,
     2, 1, 1, 2, 1, 1, 2, 2, 1, 2, 1, 1, 1, 1, 2, 3, 1, 1, 1,
     1, 1, 3, 1, 1, 2, 1, 1, 2, 2, 1, 1, 1, 1, 3, 1, 2, 1, 1, 1, 2,
     1, 1, 3, 1, 1, 2, 1, 1, 1, 2, 1, 3, 1, 1, 1, 1, 2, 2, 1,
     1, 2, 1, 1, 3, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 2, 1, 2, 1, 1,
     1, 2, 1, 1, 2, 1, 1, 3, 1, 1, 1, 2, 1, 2, 1, 1, 2, 1, 2,
     2, 1, 1, 1, 1, 1, 128],
    [4, 1, 1, 1, 2, 2, 2, 1, 2, 1, 2, 1, 3, 1, 1, 2, 2, 1, 2, 1,
     3, 1, 1, 1, 3, 2, 1, 1, 2, 1, 3, 1, 2, 1, 1, 2, 3, 1, 1, 1,
     3, 1, 2, 1, 2, 2, 1, 1, 3, 1, 2, 1, 2, 1, 2, 2, 2, 1, 1, 1,
     128],
    [4, 1, 1, 2, 2, 2, 2, 1, 2, 2, 2, 1, 3, 1, 1, 3, 2, 1, 2, 1,
     3, 2, 1, 1, 3, 2, 1, 2, 2, 1, 3, 1, 2, 2, 1, 2, 3, 1, 1, 2,
     3, 1, 2, 1, 2, 3, 1, 1, 3, 1, 2, 2, 2, 1, 2, 2, 2, 2, 1, 1, 128],
    [4, 1, 1, 1, 1, 2, 2, 1, 2, 1, 2, 1, 2, 1, 1, 2, 2, 1, 2, 1,
     2, 1, 1, 1, 3, 2, 1, 1, 1, 1, 3, 1, 2, 1, 1, 2, 2, 1, 1, 1,
     3, 1, 2, 1, 1, 2, 1, 1, 3, 1, 2, 1, 1, 1, 2, 2, 2, 1, 1, 1,
     3, 1, 1, 1, 2, 2, 2, 1, 1, 1, 2, 1, 3, 1, 1, 2, 1, 1, 2, 1,
     3, 1, 1, 1, 2, 2, 1, 1, 2, 1, 3, 1, 1, 1, 1, 2, 3, 1, 1, 1,
     2, 1, 2, 1, 2, 2, 1, 1, 2, 1, 2, 1, 2, 1, 2, 2, 1, 1, 1, 1,
     128],
    [3, 128],
    _hx("030101010301010103010103010103018E"),
    _hx("030303030303030303030303030303018E"),
    _hx("050305030502040204020402040203018E"),
    [3, 1, 1, 2, 3, 1, 1, 1, 3, 1, 3, 1, 1, 1, 3, 1, 3, 2, 1, 1,
     1, 2, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 3, 1,
     1, 1, 1, 2, 1, 2, 1, 1, 1, 3, 1, 3, 1, 1, 2, 1, 1, 1, 1, 1,
     1, 1, 3, 1, 1, 3, 2, 1, 1, 1, 3, 1, 1, 1, 3, 1, 1, 2, 1, 1,
     3, 1, 1, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 3, 1, 1, 3, 1,
     1, 3, 1, 2, 2, 1, 1, 1, 1, 1, 3, 1, 1, 3, 1, 1, 1, 3, 1, 1,
     1, 1, 1, 1, 3, 1, 1, 2, 1, 1, 1, 2, 3, 1, 1, 2, 1, 1, 3, 1,
     1, 1, 3, 1, 2, 1, 1, 1, 3, 1, 1, 2, 1, 1, 3, 2, 1, 1, 1, 3,
     1, 1, 2, 1, 1, 1, 3, 1, 1, 3, 1, 1, 1, 3, 1, 2, 1, 3, 1, 1,
     128],
    [4, 1, 2, 1, 1, 4, 1, 1, 2, 1, 4, 1, 2, 4, 1, 1, 2, 1, 4,
     1, 3, 1, 2, 4, 1, 3, 1, 2, 1, 1, 1, 3, 1, 4, 1, 3, 1, 2, 1, 3,
     1, 2, 1, 2, 1, 3, 1, 4, 1, 3, 1, 1, 2, 1, 1, 1, 3, 1, 1,
     4, 1, 2, 1, 2, 1, 3, 1, 1, 4, 1, 4, 1, 1, 2, 1, 1, 4, 1, 1, 2,
     1, 3, 1, 4, 1, 1, 2, 1, 4, 1, 1, 1, 2, 1, 1, 4, 1, 1, 1,
     3, 1, 1, 2, 1, 1, 1, 4, 1, 1, 2, 1, 1, 4, 1, 1, 2, 1, 1, 4, 1,
     4, 1, 1, 3, 1, 1, 2, 1, 4, 1, 2, 1, 1, 4, 1, 1, 3, 1, 1,
     4, 1, 1, 3, 1, 4, 1, 2, 1, 4, 1, 1, 4, 1, 1, 2, 1, 2, 1, 4, 1,
     1, 1, 1, 3, 1, 2, 1, 2, 1, 4, 1, 1, 3, 1, 4, 1, 3, 1, 1,
     2, 1, 4, 1, 2, 1, 1, 4, 1, 1, 1, 3, 1, 2, 1, 4, 1, 2, 1, 1, 1,
     4, 1, 1, 2, 1, 4, 1, 3, 1, 4, 1, 1, 2, 1, 1, 2, 1, 1, 1,
     4, 1, 3, 1, 1, 2, 1, 4, 1, 1, 1, 2, 1, 1, 4, 1, 3, 1, 4, 1, 1,
     1, 1, 2, 1, 4, 1, 1, 128],
    [3, 3, 3, 3, 3, 3, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3,
     1, 1, 3, 1, 1, 3, 1, 1, 3, 1, 1, 3, 1, 1, 3, 1, 1, 3, 1, 1, 1,
     3, 1, 1, 1, 3, 1, 1, 1, 3, 1, 1, 1, 3, 1, 1, 1, 3, 1, 1,
     1, 3, 1, 1, 3, 1, 1, 3, 1, 1, 3, 1, 1, 3, 1, 1, 3, 1, 1, 3, 1,
     3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 128],
    [3, 3, 3, 1, 3, 1, 3, 1, 1, 3, 1, 1, 3, 1, 1, 1, 3, 1, 1, 1,
     3, 1, 1, 3, 1, 1, 3, 1, 3, 1, 128],
    [3, 3, 1, 1, 1, 1, 3, 3, 3, 128],
    [3, 3, 1, 1, 3, 1, 3, 1, 1, 128],
    [3, 3, 1, 128],
    _hx("0303030303030103010301030101038D"),
    [3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3,
     1, 1, 3, 1, 1, 3, 1, 3, 1, 3, 3, 3, 3, 3, 1, 3, 1, 146],
    [1, 4, 128],
    [1, 3, 128],
]

# MSYS.S:244-249
MVOLTBL = _hx("4A4AEA0A0A4969D0")
MVT2 = _hx("4AEAEAEA0A0F0704")
HTPTBL = [0, 24, 19, 16, 12, 22, 7, 24, 16, 22, 35, 0, 0, 26, 19, 16, 24] + [0] * 15
AMPTBL = [1, 2, 3, 4, 5, 7, 9, 11, 14, 17, 21, 26, 32, 39, 47, 56]

SONG_NAMES = {1: "s_Presents", 2: "s_Byline", 3: "s_Title", 4: "s_Prolog",
              5: "s_Sumup", 7: "s_Princess", 8: "s_Squeek", 9: "s_Vizier",
              10: "s_Buildup", 11: "s_Magic", 12: "s_StTimer"}


# ------------------------------------------------------------ the VATC opcode pair
# ★★ MVOLTBL/MVT2 ARE NOT VOLUME TABLES — THEY ARE OPCODES.  The "voice select"
# command patches two one-byte instruction slots in MPLAY's amplitude path
# [MSYS.S:479-480, patched at MSYS.S:336-340].  $4A=LSR A  $EA=NOP  $0A=ASL A, and
# three entries are TWO-byte instructions whose operand is the SECOND slot.
def apply_vatc(a, op1, op2):
    if op1 == 0x4A:                       # LSR A ; then op2
        a >>= 1
        return apply_vatc_second(a, op2)
    if op1 == 0x0A:                       # ASL A ; then op2
        a = (a << 1) & 0xFF
        return apply_vatc_second(a, op2)
    if op1 == 0xEA:                       # NOP   ; then op2
        return apply_vatc_second(a, op2)
    if op1 == 0x49:                       # EOR #op2
        return a ^ op2
    if op1 == 0x69:                       # ADC #op2   (carry clear on this path)
        return (a + op2) & 0xFF
    if op1 == 0xD0:                       # BNE *+op2  -> skips STA R+11 / INC R+12
        return None                       # amplitude NOT updated
    raise ValueError("unmodelled VATC opcode %02X" % op1)


def apply_vatc_second(a, op2):
    if op2 == 0x4A:
        return a >> 1
    if op2 == 0x0A:
        return (a << 1) & 0xFF
    if op2 == 0xEA:
        return a
    raise ValueError("unmodelled VXAT opcode %02X" % op2)


class Halt(Exception):
    pass


class Voice:
    """One MSYS stream.  Voice 1 is MPLAY/NEWNOTE; voice 2 is MMPLAY/MMNNOTE.

    The two are line-for-line twins over different zero-page slots, so one class
    serves both; `is_second` selects the two places they genuinely differ (the
    call opcode, and what a $0000 event means).
    """

    def __init__(self, mem, base, ptr, is_second=False):
        self.mem = mem
        self.base = base            # $D000
        self.is_second = is_second
        self.ptr = ptr              # R+0/R+1  (or R+22/R+23)
        self.env_i = 0              # R+12 / R+16
        self.hm_i = 0               # R+3  / R+2
        self.transpose = 0          # R+4  / R+5
        self.period = 0             # R+8  / R+19
        self.seglen = 0             # R+9  / R+20
        self.ticks = 0              # R+10 / R+18
        self.amp = 0                # R+11 / $B7
        self.pitch = 0              # R+13 / R+17
        self.in_call = 0            # R+24 / R+27
        self.saved = 0              # R+25/26 / R+28/29
        self.harm_i = 0             # $AF  / $B6
        self.hm = HM[0]             # MBASS1 / MMBASS2
        self.mv = MV[0]             # MVAR6  / MVAR2C
        self.mult = 1               # MLBL300 / MMLM302
        self.vatc = (0xEA, 0xEA)    # VATC1/VXAT1 or VATC2/VXAT2  (MINIT: NOP,NOP)
        self.notes = 0
        self.calls = 0
        self.returns = 0
        self.instruments = []
        self.trace = []             # (kind, offset, byte0, byte1, detail)

    def rd(self, a):
        return self.mem[a - self.base]

    # ---- NEWNOTE: fetch events until one produces sound (RTS) -----------------
    def new_note(self, host):
        guard = 0
        while True:
            guard += 1
            if guard > 20000:
                raise Halt("runaway NEWNOTE")
            self.env_i = 0
            self.hm_i = 0
            self.mult = 1
            self.ptr = (self.ptr + 2) & 0xFFFF
            off = self.ptr - self.base
            if not (0 <= off < len(self.mem) - 1):
                raise Halt("pointer out of the music page: $%04X" % self.ptr)
            b0 = self.rd(self.ptr)
            b1 = self.rd(self.ptr + 1)

            if b1 != 0:
                p = b0 & 0xFC
                self.pitch = p
                if p:
                    self.pitch = ((p >> 2) + self.transpose) & 0xFF
                    if self.pitch < 0x19:
                        self.mult = 7
                # MNOBC1 re-reads byte1; non-zero -> NMSYSM
                if b1 & 0x3F:
                    self._note(b0, b1, off)
                    return
                top = b1 & 0xC0
                if top == 0x80 and not self.is_second:
                    self._chain(b0, off, host)
                    continue
                if top == 0x40 and not self.is_second:
                    self._start_voice2(b0, off, host)
                    continue
                if (top == 0xC0) or (top == 0x00 and not self.is_second):
                    # ★ voice 1: $C0 and $00 both reach MGARY5.  ($00 alone is
                    #   unreachable — byte1==0 was caught above.)  voice 2: $C0 only.
                    self._call_or_return(b0, off)
                    continue
                self.trace.append(("ignored", off, b0, b1, ""))
                continue

            # ---- byte1 == 0: a COMMAND, discriminated on byte0 ----------------
            if b0 == 0x00:
                if self.is_second:
                    self.trace.append(("v2-end", off, b0, b1, "MMINIT: two-voice off"))
                    raise Halt("voice2-end")
                self.trace.append(("restart", off, b0, b1, "MINIT"))
                raise Halt("song-end")
            if b0 == 0xFE:
                if self.in_call:
                    self.ptr = self.saved
                    self.in_call = 0
                    self.returns += 1
                    self.trace.append(("return", off, b0, b1, "-> $%04X" % self.ptr))
                else:
                    self.trace.append(("return-noop", off, b0, b1, "not in a call"))
                continue
            if b0 == 0xFD:
                host.played_flag = True
                self.trace.append(("flag", off, b0, b1, "$1E80,[$1E60] |= $80"))
                continue
            if b0 == 0xFF:
                self.ticks = 0xFF
                self.pitch = 0
                self.period = NOTE[0]
                self.seglen = LENGTH[0]
                self.trace.append(("pause", off, b0, b1, "255 ticks"))
                return
            if b0 < 9:
                self.vatc = (MVOLTBL[b0 - 1], MVT2[b0 - 1])
                self.trace.append(("voice", off, b0, b1,
                                   "VATC=%02X %02X" % self.vatc))
                continue
            # instrument / harmonic select
            a = b0 - 9
            self.transpose = 0
            if a >= 32:
                self.transpose = 12
                a &= 0x1F
            self.harm_i = a
            self.transpose = (self.transpose + HTPTBL[a]) & 0xFF
            self.hm = HM[a]
            self.trace.append(("instr", off, b0, b1,
                               "HM%d, transpose %d" % (a + 1, self.transpose)))
            continue

    def _note(self, b0, b1, off):
        # ★★★ R+10 IS byte1 & $3F, NOT byte1.  `NMSYSM` does `AND #%00111111`
        # and then `JMP NTVJNK`, whose first instruction is `STA R+10` — the
        # accumulator still holds the MASKED value [MSYS.S:369-371, 439].
        # P4.18 §3A read this as the whole byte and would have played every note
        # up to four times too long.
        self.ticks = b1 & 0x3F
        idx = ((b1 & 0xC0) >> 4) | (b0 & 0x03)
        self.amp = AMPTBL[idx]
        self.mv = MV[idx]
        self.period = NOTE[self.pitch]
        self.seglen = LENGTH[self.pitch]
        self.notes += 1
        self.instruments.append(idx)
        self.trace.append(("note", off, b0, b1,
                           "pitch %d  instr %d  ticks %d  NOTE %d  LENGTH %d  x%d"
                           % (self.pitch, idx, self.ticks, self.period,
                              self.seglen, self.mult)))

    def _chain(self, b0, off, host):
        x = (b0 - 1) & 0xFF
        if x & 0x80:                                  # ALTSNG
            if host.played_flag:
                host.next_index = x & 0x7F
                self.trace.append(("altsng", off, b0, 0x80,
                                   "flag SET -> restart as song %d" % (x & 0x7F)))
                raise Halt("altsng")
            self.trace.append(("altsng", off, b0, 0x80, "flag clear -> continue"))
            return
        host.next_index = x
        self.trace.append(("chain", off, b0, 0x80, "INDEX <- %d" % x))

    def _start_voice2(self, b0, off, host):
        delta = (b0 << 1) & 0xFF
        carry = b0 & 0x80
        v2 = Voice(self.mem, self.base, self.ptr, is_second=True)
        host.voice2 = v2
        host.two_voice = True
        host.v2_phase = 1
        if carry:
            self.ptr = (self.ptr + delta + 0x100) & 0xFFFF
        else:
            self.ptr = (self.ptr + delta) & 0xFFFF
        self.trace.append(("voice2", off, b0, 0x40,
                           "v2 from $%04X; v1 -> $%04X" % (v2.ptr, self.ptr)))
        try:
            v2.new_note(host)
        except Halt:
            host.two_voice = False
            host.voice2 = None

    def _call_or_return(self, b0, off):
        if self.in_call:                              # MGARY5 -> MRET1
            self.ptr = self.saved
            self.in_call = 0
            self.returns += 1
            self.trace.append(("return", off, b0, 0xC0, "-> $%04X" % self.ptr))
            return
        self.in_call = 1
        self.saved = self.ptr
        delta = (b0 << 1) & 0xFF
        carry = b0 & 0x80
        if carry:                                     # NOTRP1
            self.ptr = (self.ptr - delta - 0x100) & 0xFFFF
        else:
            self.ptr = (self.ptr - delta) & 0xFFFF
        self.calls += 1
        self.trace.append(("call", off, b0, 0xC0,
                           "back %d B -> $%04X"
                           % (delta + (0x100 if carry else 0), self.ptr)))

    # ---- one MPLAY call: the envelope step, then `seglen` MSEG segments -------
    def tick(self, host):
        # MPLAY head: advance the envelope
        while True:
            v = self.mv[self.env_i] if self.env_i < len(self.mv) else 0xFF
            if v & 0x80:
                break                                   # BMI MESKP: hold
            if v == 0x7F:                               # V8HOLD
                if self.env_i < self.ticks:
                    break
                self.env_i += 1
                continue
            a = apply_vatc(v, *self.vatc)
            if a is not None:
                self.amp = a
                self.env_i += 1
            break
        if self.harm_i == 0:
            self.hm_i = 0
        # NEWMM4: the four pulse widths from the amplitude
        vtbl = [0,
                ((self.amp >> 1) + 1) & 0xFF,
                (self.amp + 1) & 0xFF,
                ((self.amp >> 1) + self.amp + 1) & 0xFF,
                (((self.amp << 1) & 0xFF) + 1) & 0xFF]
        if self.pitch == 0:
            vtbl = [0, 0, 0, 0, 0]

        segs = []
        x = self.seglen
        if x == 0:
            x = 256
        if host.pad_us:
            # ★★ THE PER-TICK GAP IS THE CALLER, NOT MSYS.  `PlaySongI` loops
            # `jsr StartGame? / jsr xmplay` [MASTER.S:1389-1400], and the poll plus
            # the aux/bank wrapper costs a CONSTANT ~4.86 ms between the last
            # toggle of one tick and the first of the next.  It shows up in the
            # capture as one long rest per tick and it is 13% of every song's
            # duration -- drop it and every song runs short.
            segs.append((host.pad_us * host.cpu_hz / 1e6, 0, -1))   # mult -1 = raw
        guard = 0
        while True:
            guard += 1
            if guard > 100000:
                raise Halt("runaway MSEG")
            h = self.hm[self.hm_i] if self.hm_i < len(self.hm) else 0x80
            if h & 0x80:
                self.hm_i = h & 0x7F
                continue
            self.hm_i += 1
            width = vtbl[h - 1] if 1 <= h <= 5 else 0
            segs.append((self.period, width, self.mult))
            x -= 1
            if x == 0:
                break
        self.ticks = (self.ticks - 1) & 0xFF
        if self.ticks == 0:
            self.new_note(host)
        return segs


class Player:
    def __init__(self, mem, base, index):
        self.mem = mem
        self.base = base
        self.next_index = index
        self.played_flag = False
        self.two_voice = False
        self.voice2 = None
        self.v2_phase = 0
        self.halt = ""
        self.ticks = 0
        self.pad_us = 0.0
        self.cpu_hz = 1020484.0

    def run(self, index, max_ticks=200000):
        lo = self.mem[0:0x68]
        hi = self.mem[0x68:0xD0]
        ptr = hi[index] * 256 + lo[index]
        v1 = Voice(self.mem, self.base, ptr)
        self.voice1 = v1
        self.next_index = index
        segs = []
        ticks = 0
        try:
            v1.new_note(self)
            while ticks < max_ticks:
                ticks += 1
                if self.two_voice:
                    self.v2_phase ^= 1
                    if self.v2_phase == 0:
                        try:
                            segs.extend(self.voice2.tick(self))
                        except Halt as h:
                            # ★★ `MMINIT` IS `LDA #0 / STA R+15 / RTS` [MSYS.S:544-546]
                            # -- voice 2 hitting $0000 turns the SECOND VOICE off and
                            # returns.  It does NOT end the song; voice 1 plays on.
                            # Ending the song here made s_Sumup decode as 18 s against
                            # a 51.6 s trace.
                            if str(h) != "voice2-end":
                                raise
                            self.two_voice = False
                            self.voice2 = None
                        continue
                segs.extend(v1.tick(self))
        except Halt as h:
            self.halt = str(h)
        else:
            self.halt = "tick-limit"
        self.ticks = ticks
        return segs


# ★ FITTED, AND SAID SO.  The pitch term 5*period*(1+mult) is COUNTED and the trace
# confirms it to better than 0.1%; the fixed straight-line term is 7.5 cycles per
# segment larger in MAME than a hand count of the listing gives (stretched-cycle /
# page-cross territory).  CLAUDE.md §2 ranks the trace above the source, so the
# constant is fitted to `build/tmp/boot/song_*.txt` rather than argued from the
# listing — and the fit is a CONSTANT OFFSET, not a scale factor, which is what
# says the pitch model itself is right.
SEG_FIT = 7.5


def seg_cycles(period, mult, width=1):
    """MSEG's straight-line + three loops, counted from MSYS.S:512-540.

    A width-0 segment skips M30A/MVDIT/M30B and takes the BEQ, which is 6 cycles
    cheaper -- and, more importantly for a trace comparison, EMITS NO TOGGLE.
    """
    if mult < 0:                     # the caller's per-tick pad, in raw cycles
        return period
    base = 5 * period * (1 + mult) + 9 * mult + (47 if width else 41)
    return base + SEG_FIT


def pulse_cycles(width):
    """M30A -> M30B: MVDIT is 5*width-1, plus M30B's own 4 cycles."""
    return 0 if width == 0 else 5 * width + 3


def toggle_pairs(segs):
    """Fold a segment stream into the (pulse, rest) pairs a speaker trace sees.

    ★★ THE CAPTURE'S ROWS ARE NOT SEGMENTS.  A harmonic-pattern value of 1 selects
    VTBL+0, which is always zero, so that segment toggles nothing -- and the default
    pattern HM32 is `1,3,128`, i.e. SILENT, PULSE, repeat.  Half the segments are
    invisible to the trace, and their time lands in the PRECEDING rest.  Comparing
    segments to rows one-for-one is what makes a correct decode look 2x too fast.
    """
    pairs = []
    for per, w, m in segs:
        total = seg_cycles(per, m, w)
        if w == 0:
            if pairs:                       # silence before the FIRST toggle is
                pairs[-1][1] += total       # not a row in the capture either
            continue
        pu = pulse_cycles(w)
        pairs.append([pu, total - pu])
    return [(p, r) for p, r in pairs]


def load_page(path):
    d = pathlib.Path(path).read_bytes()
    if len(d) == 4608:
        return d[512:512 + 1024]
    if len(d) == 1024:
        return d
    raise SystemExit("unrecognised music file size %d" % len(d))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--music", default="oracle/source/Other/MUSIC.SET1")
    ap.add_argument("--song", type=int, default=7)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--events", action="store_true")
    ap.add_argument("--segments", action="store_true")
    ap.add_argument("--cpu-hz", type=float, default=1020484.0)
    ap.add_argument("--compare", help="a build/tmp/boot/song_*.txt capture")
    ap.add_argument("--pad-us", type=float, default=4855.0,
                    help="PlaySongI's per-tick poll overhead; 0 to model MSYS alone")
    args = ap.parse_args()

    mem = load_page(args.music)
    ids = sorted(SONG_NAMES) if args.all else [args.song]
    for sid in ids:
        p = Player(mem, 0xD000, sid)
        p.pad_us = args.pad_us
        p.cpu_hz = args.cpu_hz
        segs = p.run(sid)
        cyc = sum(seg_cycles(per, m, w) for per, w, m in segs)
        secs = cyc / args.cpu_hz
        v1 = p.voice1
        print("=" * 74)
        print("song %d  %s   halt=%s" % (sid, SONG_NAMES.get(sid, "?"), p.halt))
        print("  notes %d   calls %d   returns %d   ticks %d   segments %d"
              % (v1.notes, v1.calls, v1.returns, p.ticks, len(segs)))
        print("  instruments used: %s" % sorted(set(v1.instruments)))
        print("  two-voice: %s" % ("YES" if p.voice2 else "no"))
        if p.voice2:
            print("    v2 notes %d calls %d" % (p.voice2.notes, p.voice2.calls))
        print("  duration %.3f s  = %.1f frames @59.92 Hz  (%d cycles)"
              % (secs, secs * 59.92, cyc))
        if args.events:
            for kind, off, b0, b1, det in v1.trace:
                print("   +%-4d %02X %02X  %-12s %s" % (off, b0, b1, kind, det))
            if p.voice2:
                print("   --- voice 2 ---")
                for kind, off, b0, b1, det in p.voice2.trace:
                    print("   +%-4d %02X %02X  %-12s %s" % (off, b0, b1, kind, det))
        if args.segments:
            for per, w, m in segs:
                print("   per %3d x%d  width %3d   %.3f us  pulse %.3f us"
                      % (per, m, w, seg_cycles(per, m, w) / args.cpu_hz * 1e6,
                         pulse_cycles(w) / args.cpu_hz * 1e6))
        if args.compare:
            compare(segs, args.compare, args.cpu_hz)


def compare(segs, path, cpu_hz, tol=0.02, show=6):
    rows = []
    for line in pathlib.Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        a, b = line.split()
        rows.append((float(a), float(b)))
    dec = [(p / cpu_hz * 1e6, r / cpu_hz * 1e6) for p, r in toggle_pairs(segs)]
    cap_span = sum(a + b for a, b in rows) / 1e6
    dec_span = sum(a + b for a, b in dec) / 1e6
    print("  --- compare against %s" % path)
    print("      captured toggle-pairs %d   decoded toggle-pairs %d   (%+d)"
          % (len(rows), len(dec), len(dec) - len(rows)))
    print("      captured span %.3f s (%.1f frames)   decoded span %.3f s "
          "(%.1f frames)   ratio %.4f"
          % (cap_span, cap_span * 59.92, dec_span, dec_span * 59.92,
             (dec_span / cap_span) if cap_span else 0))
    n = min(len(rows), len(dec))
    # ★★★ PERIOD AND PULSE ARE REPORTED SEPARATELY BECAUSE THEY CARRY DIFFERENT THINGS
    # AND QUANTISE DIFFERENTLY. The PERIOD is the PITCH, and both the GIME timer and the
    # divider are fine enough to hold it to a fraction of a percent. The PULSE is the
    # AMPLITUDE, and it is emitted by a 5-cycle delay loop -- at 1.7898 MHz that is a
    # 2.79 us quantum, against an oracle minimum pulse of 7.83. A single pass/fail on both
    # reports the volume's unavoidable quantisation as a pitch failure.
    pe, we = [], []
    for i in range(n):
        cp, cr = rows[i]
        dp, dr = dec[i]
        if cp + cr > 0:
            pe.append(abs((dp + dr) - (cp + cr)) / (cp + cr))
        we.append(abs(dp - cp))
    if pe:
        pe.sort()
        print("      PERIOD (the pitch):  mean %.3f%%  median %.3f%%  worst %.2f%%"
              % (100 * sum(pe) / len(pe), 100 * pe[len(pe) // 2], 100 * pe[-1]))
    if we:
        we.sort()
        print("      PULSE  (the volume): mean %.2f us  median %.2f us  worst %.2f us"
              % (sum(we) / len(we), we[len(we) // 2], we[-1]))
        print("                           (the port's pulse quantum is 2.79 us -- one"
              " iteration of a 5-cycle loop at 1.7898 MHz)")
    bad = [i for i in range(n)
           if abs((dec[i][0] + dec[i][1]) - (rows[i][0] + rows[i][1]))
           > tol * max(rows[i][0] + rows[i][1], 1.0)]
    print("      pairs whose PERIOD is off by more than %.0f%%: %d / %d  (%.2f%%)"
          % (100 * tol, len(bad), n, 100.0 * len(bad) / n if n else 0))
    for i in bad[:show]:
        print("        row %5d  captured %8.3f/%9.3f   decoded %8.3f/%9.3f"
              % (i, rows[i][0], rows[i][1], dec[i][0], dec[i][1]))


if __name__ == "__main__":
    main()
