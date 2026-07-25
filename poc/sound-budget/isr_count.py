#!/usr/bin/env python3
"""PA.12 — MC6809 cycle count of a REAL CoCo3 FIRQ DAC player ISR.

Source of record: pfiscarelli/Run-Dino-Run @ master, src/dinorun.asm, label `note`
(the "Multi-voice Note Mixer (located in DP for speed)"), lines 137-152.
Counted from the emitted instructions, NOT from the project's headline claim.
Every cycle figure below is the MC6809 (not 6309) count for that addressing mode.
"""
# (mnemonic, operand, addressing mode, cycles, why)
ISR_3VOICE = [
    ("<FIRQ entry>", "",          "hardware", 10, "FIRQ: stacks CC+PC only (E=0)"),
    ("JMP",   "<note",            "direct",    3, "$FEF4 secondary FIRQ vector = $0E,<lo"),
    ("STD",   "<saved+1",         "direct",    5, "save D into the trailing LDD imm"),
    ("LDD",   "#$0000",           "immediate", 3, "voice-1 phase accumulator (self-mod)"),
    ("ADDD",  "#$0000",           "immediate", 4, "voice-1 frequency step (self-mod)"),
    ("STD",   "<sum+1",           "direct",    5, "write accumulator back"),
    ("LDD",   "#$0000",           "immediate", 3, "voice-2 accumulator"),
    ("ADDD",  "#$0000",           "immediate", 4, "voice-2 step"),
    ("STD",   "<sum2+1",          "direct",    5, ""),
    ("LDD",   "#$0000",           "immediate", 3, "voice-3 accumulator"),
    ("ADDD",  "#$0000",           "immediate", 4, "voice-3 step"),
    ("STD",   "<sum3+1",          "direct",    5, ""),
    ("ADDA",  "<sum+1",           "direct",    4, "mix: A + voice1 hi"),
    ("RORA",  "",                 "inherent",  2, "halve (avoid overflow)"),
    ("ADDA",  "<sum2+1",          "direct",    4, "mix: + voice2 hi"),
    ("RORA",  "",                 "inherent",  2, "halve"),
    ("STA",   "$FF20",            "extended",  5, "6-bit DAC (PIA1 side A)"),
    ("LDA",   "$FF93",            "extended",  5, "clear GIME FIRQ status (mandatory)"),
    ("LDD",   "#0000",            "immediate", 3, "restore D (self-modified by STD saved+1)"),
    ("RTI",   "",                 "inherent",  6, "E=0 -> 6 cyc, not 15"),
]

# A minimum-cost 1-voice PCM sample player: the shape POP's TRIGGERED EFFECTS need.
ISR_1VOICE_PCM = [
    ("<FIRQ entry>", "",   "hardware",  10, ""),
    ("JMP",  "<snd",       "direct",     3, "$FEF4 vector"),
    ("STD",  "<saved+1",   "direct",     5, "save D"),
    ("LDX",  "#$0000",     "immediate",  3, "sample pointer (self-mod)"),
    ("LDA",  ",X+",        "indexed",    6, "4 base + 2 for ,R+"),
    ("STX",  "<ptr+1",     "direct",     5, "advance pointer"),
    ("STA",  "$FF20",      "extended",   5, "DAC"),
    ("LDA",  "$FF93",      "extended",   5, "clear GIME FIRQ"),
    ("LDD",  "#0000",      "immediate",  3, "restore D"),
    ("RTI",  "",           "inherent",   6, ""),
]
# NOTE: no end-of-sample test in the above. The cheapest real termination is a
# sentinel checked OUTSIDE the ISR (main loop polls the pointer), which is why it
# is excluded here; a per-sample CMPX/BNE would add 3+3 = 6 cyc (see report).

TIMER_CLK = 3_579_545.0      # $FF91 bit5=1 -> 279.365 ns tick (14.31818 MHz / 4)
TIMER_VAL = 460              # ldd #460 / std $ff94
CPU_FAST  = 1_789_772.5      # $FFD9 double speed  (PA.5 budget basis)
CPU_SLOW  =   894_886.25     # normal speed = disk-safe speed (Karateka rule)

def total(isr): return sum(r[3] for r in isr)

def table(name, isr):
    print(f"\n=== {name} ===")
    print(f"  {'mnem':<14}{'operand':<14}{'mode':<11}{'cyc':>4}  note")
    for m,o,md,c,w in isr:
        print(f"  {m:<14}{o:<14}{md:<11}{c:>4}  {w}")
    print(f"  {'':<39}{'----':>4}")
    print(f"  {'TOTAL per interrupt':<39}{total(isr):>4}")
    return total(isr)

def budget(label, cyc, rate, cpu, cpuname):
    load = cyc * rate
    pct  = 100.0 * load / cpu
    print(f"  {label:<34} {rate:8.1f} Hz x {cyc:3d} cy = {load:10,.0f} cy/s "
          f"= {pct:6.2f}% of {cpuname} ({cpu:,.0f} cy/s)")
    return pct

c3 = table("A. Run Dino Run 3-voice mixer (REAL, counted)", ISR_3VOICE)
c1 = table("B. Minimum 1-voice PCM sample player (POP effect shape)", ISR_1VOICE_PCM)

rate = TIMER_CLK / TIMER_VAL
print(f"\n=== Interrupt rate ===")
print(f"  GIME timer: $FF91 bit5=1 -> {TIMER_CLK:,.0f} Hz tick; $FF94 = {TIMER_VAL}")
print(f"  rate = {TIMER_CLK:,.0f} / {TIMER_VAL} = {rate:,.1f} Hz   (source comment says '8Khz')")

print(f"\n=== CPU load — DOUBLE SPEED (normal gameplay, PA.5 basis) ===")
p_a  = budget("A. 3-voice music @ 7.8 kHz",  c3, rate,       CPU_FAST, "1.79 MHz")
p_a4 = budget("A. 3-voice music @ 3.9 kHz",  c3, rate/2,     CPU_FAST, "1.79 MHz")
p_b  = budget("B. 1-voice PCM  @ 7.8 kHz",   c1, rate,       CPU_FAST, "1.79 MHz")
p_b4 = budget("B. 1-voice PCM  @ 3.9 kHz",   c1, rate/2,     CPU_FAST, "1.79 MHz")

print(f"\n=== CPU load — NORMAL SPEED (disk I/O window, Karateka disk rule) ===")
budget("A. 3-voice music @ 7.8 kHz", c3, rate, CPU_SLOW, "0.89 MHz")
budget("B. 1-voice PCM  @ 7.8 kHz",  c1, rate, CPU_SLOW, "0.89 MHz")

print(f"\n=== FDC lost-data check (WD1773 double density) ===")
BYTE_US = 32.0                     # 250 kbit/s MFM -> 1 byte / 32 us
win_slow = BYTE_US * 1e-6 * CPU_SLOW
print(f"  FDC delivers 1 byte every {BYTE_US:.0f} us -> {win_slow:.1f} CPU cycles @ 0.89 MHz")
for n,c in (("A 3-voice",c3),("B 1-voice PCM",c1)):
    print(f"    ISR {n:<14} = {c:3d} cy = {c/win_slow:4.2f} x the whole DRQ window "
          f"-> {'LOST DATA' if c > win_slow else 'fits'}")

print(f"\n=== PA.5/PA.11 p90 frame + sound (budget = 1.00x) ===")
P90_IDIOMATIC = 0.46
for lbl,p in (("A 3-voice @7.8k",p_a),("A 3-voice @3.9k",p_a4),
              ("B 1-voice @7.8k",p_b),("B 1-voice @3.9k",p_b4)):
    t = P90_IDIOMATIC + p/100.0
    print(f"  p90 idiomatic {P90_IDIOMATIC:.2f}x + {lbl:<16} {p/100:.3f}x = "
          f"{t:.3f}x  -> {'FITS' if t < 1.0 else 'OVER'}  (margin {100*(1-t):+.1f}%)")

# ---------------------------------------------------------------------------
# PART 2 — POP's OWN sound cost on the Apple (the thing being replaced), and the
# disk interaction on the branches Karateka's fdc-read-primitive.md leaves live.
# ---------------------------------------------------------------------------
print("\n\n=== POP's Apple-side effect cost (6502, counted from GRAFIX.S `tone`) ===")
def tone_cost(pitch_lo, pitch_hi, dur):
    """tone: :inloop iny(2) cpy zp(3) bcc(3) = 8/iter, pitch_lo iters.
       midloop repeats pitch_hi+1 times; outloop dur times."""
    inner  = 8 * pitch_lo
    mid    = (pitch_hi + 1) * (2 + inner + 2 + 3 + 3)      # ldy + inner + inx+cpx+bcc
    outer  = dur * (4 + 2 + mid + 2 + 2 + 3)               # bit $c030 + ldx + mid + sec/sbc/bne
    return outer
STEP = 178_968                                             # PA.5 measured game-step budget
for name, (pl, ph, d) in {
    "Footstep    (35,0,3)":  (35, 0, 3),
    "SwordClash  (15,0,50)": (15, 0, 50),
}.items():
    c = tone_cost(pl, ph, d)
    print(f"  {name:<24} = {c:7,d} cy blocking = {100*c/STEP:5.2f}% of a 178,968-cy game step "
          f"({c/1_023_000*1000:5.2f} ms)")
print("  -> POP's in-action effects are CHEAP and BLOCKING. Music is separate and FREEZES the game")
print("     (TOPCTRL.S songcues gates on static? / trobcount / nummob / lightning).")

print("\n=== Disk I/O interaction — branches per karateka docs/project/fdc-read-primitive.md ===")
print("  (branch (a) single-density is RULED OUT there by capacity + DD-only DECB bootstrap)")
SECTOR = 256
for br, cpu, cpuname, loop_us, win_us, halt in (
    ("(b) DD + DRQ->HALT @ 0.89 MHz", CPU_SLOW, "0.89 MHz", 27.0, 32.0, True),
    ("(c) DD + polled     @ 1.79 MHz", CPU_FAST, "1.79 MHz", 13.5, 32.0, False),
):
    print(f"\n  {br}")
    if halt:
        blackout = SECTOR * win_us / 1000.0
        print(f"    DRQ is wired to the 6809 HALT line. A halted 6809 executes NO instructions")
        print(f"    and takes NO interrupts -> the audio FIRQ is SUSPENDED, not merely late.")
        print(f"    Blackout = {SECTOR} bytes x {win_us:.0f} us = {blackout:.1f} ms per sector")
        print(f"             = {blackout/1000*rate:.0f} missed samples @ {rate:,.0f} Hz -> audible dropout")
    slackcy = (win_us - loop_us) * 1e-6 * cpu
    print(f"    Polled slack = ({win_us:.0f} - {loop_us:.1f}) us = {slackcy:.1f} cy @ {cpuname}")
    for n, c in (("A 3-voice", c3), ("B 1-voice PCM", c1)):
        print(f"      ISR {n:<14} {c:3d} cy vs {slackcy:5.1f} cy slack -> "
              f"{'LOST DATA' if c > slackcy else 'fits'}")
print("\n  CONCLUSION: on BOTH live branches the audio FIRQ must be MASKED across the")
print("  sector transfer. Forced, not a workaround -- and it matches the original, which")
print("  loads music from disk (MASTER.S loadmusic1/2/3, track 34) and THEN plays it.")
