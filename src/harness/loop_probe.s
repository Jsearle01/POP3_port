* src/harness/loop_probe.s
*
* POP CoCo3 — P1.1 HARNESS-PROOF TARGET ("loop probe").
*
* THIS IS NOT ENGINE CODE, NOT THE HAL, NOT THE SPRITE COMPILER.
* It is the smallest CoCo3 program that exercises every link in the
* build -> boot -> GIME/video write -> VOFFSET swap -> VBL-counted timing
* chain, so that the harness loop can be proven end-to-end before any
* real engine code is written. Delete or supersede it freely once the
* real HAL exists; nothing may come to depend on it.
*
* WHAT IT DOES (the spec the harness checks):
*   1. Sets the GIME to 320x192x4 — the mode the port ships in (PA.2/PA.8).
*   2. Fills frame A with FILL_A and frame B with FILL_B (distinct patterns).
*   3. Displays frame A, then spins EXACTLY VBL_TARGET vertical blanks,
*      counting them itself.
*   4. VOFFSET-swaps to frame B (the page-flip present, ~186 cyc, not a copy).
*   5. Publishes status + its own VBL count + a magic word, then spins.
*
* The harness verifies: magic, status, the 6809's own VBL count, both
* framebuffers' contents, and — the cross-check that makes the timing real —
* that MAME's frame_number advanced by the same number of frames the 6809
* counted. Two independent clocks agreeing is the timing evidence.
*
* AUTHORITY / SUBSTRATE (CLAUDE.md §2G — reuse the substrate, not the game):
*   GIME init order, register values and framebuffer geometry are adapted
*   from karateka_coco3 src/hal/coco3-dsk/gfx.s (MAME-verified), which is
*   read-only reference. Values re-derived and cited inline below.
*
* INTERRUPT POLICY — deliberate, and it sidesteps a known trap:
*   CC.I/F stay SET for the whole run; no vector is installed. VBL is
*   detected by POLLING the GIME interrupt-status latch at $FF92 with the
*   VBORD source enabled. The GIME latches VBORD regardless of whether the
*   CPU services the IRQ, and reading $FF92 acknowledges it.
*   [ref: docs/ground-truth/SockmasterGime.md — "Reading from the register
*    tells you which interrupts came in and acknowledges and resets the
*    interrupt source."]
*   This avoids installing anything at $010C, which DECB's LOADM overwrites
*   [ref: mame-idioms-coco3-port.md §5 — the disk-boot overlap].
*
* BUILD:  lwasm --decb -o build/loop_probe.bin src/harness/loop_probe.s
* LOAD:   DECB  LOADM"PROBE"  then  EXEC   (entry $0200; no autoboot — §1)
* ---------------------------------------------------------------

* ---------------------------------------------------------------
* Constants
* ---------------------------------------------------------------
VBL_TARGET      equ     120             ; spin exactly this many VBLs (~2.00 s @ 59.94 Hz)
PROBE_MAGIC     equ     $BEEF           ; written to probe_magic on completion

* Framebuffer geometry — 320x192x4 (2bpp, 4 px/byte, 80-byte stride).
* [ref: karateka gfx.s GFX_FB_A_BASE/GFX_FB_B_BASE/GFX_FB_WORDS]
FB_A_BASE       equ     $8000           ; CPU addr, physical $78000
FB_B_BASE       equ     $C000           ; CPU addr, physical $7C000
FB_WORDS        equ     $1E00           ; 15,360 bytes / 2 = 7,680 word stores

* VOFFSET = physical_addr / 8   [ref: GIME-RM §13, via karateka gfx.s:319-322]
VOFF_A          equ     $F000           ; $78000 / 8
VOFF_B          equ     $F800           ; $7C000 / 8

* Fill patterns — 2bpp, MSB-first, so each byte is a 4-pixel colour bar.
FILL_A          equ     $1B             ; %00011011 = px 0,1,2,3
FILL_B          equ     $E4             ; %11100100 = px 3,2,1,0 (A reversed)

VBORD_BIT       equ     $08             ; $FF92/$FF93 bit 3 = vertical border

* ---------------------------------------------------------------
* NO $0100 INTERRUPT-DISPATCH BLOCK — deliberate, and load-bearing.
*
* karateka's scripted drivers open with an 18-byte block at $0100-$0111
* (rti/nop stubs for swi3/swi2/swi/nmi/irq/firq). Do NOT copy it here.
* Those drivers are POKED into memory by Lua with the CPU already halted
* at a chosen PC; this probe is loaded by DECB's LOADM, and $010C is
* DECB's LIVE IRQ dispatch vector while LOADM is running.
* [ref: mame-idioms-coco3-port.md §5 — "DECB LOADM overwrites $010C"]
*
* Measured (P1.1, this dispatch): with the block present, LOADM"PROBE"
* completes and the image is correct ($0200 = 7E 02 08), but DECB is left
* executing its own destroyed vector — PC observed wandering
* $010D -> $FEF9 -> $FE0B -> $C60B and never returning to the prompt.
*
* This probe needs no vectors: CC.I/F are masked for the entire run and
* no interrupt is ever serviced. Leaving $0100 alone is both simpler and
* the only thing that makes the DECB boot path work.
* ---------------------------------------------------------------

* ---------------------------------------------------------------
* Main block. Entry $0200.
*
* The observable block sits at a FIXED, KNOWN address immediately after
* the entry jump, so the harness can read it without parsing symbols:
*   $0203  probe_status  1B   0=not started, 1=running, 2=complete
*   $0204  probe_vbls    2B   VBLs the 6809 counted for itself
*   $0206  probe_magic   2B   $BEEF once complete
* ---------------------------------------------------------------
                org     $0200
                setdp   0

probe_entry     jmp     probe_start     ; $0200 — EXEC address

probe_status    fcb     0               ; $0203
probe_vbls      fdb     0               ; $0204
probe_magic     fdb     0               ; $0206

* ---------------------------------------------------------------
* probe_start
* ---------------------------------------------------------------
probe_start
                orcc    #$50            ; mask IRQ+FIRQ at the CPU for the whole run
                clra
                tfr     a,dp            ; DP = 0

* --- Step 1: INIT0 FIRST ---------------------------------------
* $6C = COCO=0, MMUEN=1, IEN=1, FEN=0, MC3=1, MC2=1.
* MUST be first here: the $8000/$C000 framebuffers are in ROM territory
* until MMUEN flips them to RAM, so they cannot be cleared before this.
* IEN=1 is required for the GIME to latch VBORD into $FF92 at all.
* $FF90 is write-only — no read-modify-write is possible.
* [ref: karateka gfx.s Step 1 + IEN PRESERVATION NOTE]
                lda     #$6C
                sta     $FF90

* --- Step 2: fill frame A ($8000, 15,360 B) with FILL_A ---------
                ldx     #FB_A_BASE
                lda     #FILL_A
                tfr     a,b                     ; D = FILL_A:FILL_A
                ldy     #FB_WORDS
fill_a          std     ,x++
                leay    -1,y
                bne     fill_a

* --- Step 3: fill frame B ($C000, 15,360 B) with FILL_B ---------
                ldx     #FB_B_BASE
                lda     #FILL_B
                tfr     a,b
                ldy     #FB_WORDS
fill_b          std     ,x++
                leay    -1,y
                bne     fill_b

* --- Step 4: video mode = 320x192x4 -----------------------------
* $FF98 = $80 VMODE (BP=1 graphics); $FF99 = $15 VRES (192 lines,
* 80 bytes/row, CRES=01 -> 4 colours, 2bpp).
* [ref: GIME-RM §10 via karateka memory-map.md §5; SockmasterGime.md $FF98]
                ldd     #$8015
                std     $FF98

* --- Step 5: VOFFSET -> frame A (the initially displayed buffer) -
                ldd     #VOFF_A
                std     $FF9D

* --- Step 6/7: VSCROL and HOFFSET are UNDEFINED at reset --------
                clr     $FF9C                   ; VSCROL = 0 (REQUIRED)
                clr     $FF9F                   ; HOFFSET = 0 (REQUIRED)

* --- Step 8: SAM — double speed + RAM at $C000 ------------------
* $FFD9 = 1.79 MHz. PA.5's whole cycle budget (29,859 cyc/VBL) assumes it.
                clra
                sta     $FFD9
                sta     $FFDF

* --- Step 9: palette LAST ---------------------------------------
* Palette MUST be written AFTER the video mode, or it does not take.
* [ref: mame-idioms-coco3-port.md §9 — "GIME register write ORDER:
*  palette must be written AFTER video mode"]
                ldx     #palette
                ldy     #$FFB0
                ldb     #4
pal_loop        lda     ,x+
                sta     ,y+
                decb
                bne     pal_loop

* --- Step 10: enable the VBORD source so $FF92 latches ----------
* CPU IRQ stays masked (CC.I set above); this only arms the GIME's
* status latch so the poll below can see vertical blanks.
                lda     #VBORD_BIT
                sta     $FF92
                lda     $FF92                   ; ack anything already pending

                lda     #1
                sta     probe_status            ; -> running (harness marks f_start)

* --- Step 11: count exactly VBL_TARGET vertical blanks ----------
                ldx     #0
vbl_loop        lda     $FF92                   ; read = status + acknowledge
                bita    #VBORD_BIT
                beq     vbl_loop                ; not a VBL yet — keep polling
                leax    1,x
                stx     probe_vbls              ; publish progress each VBL
                cmpx    #VBL_TARGET
                blo     vbl_loop

* --- Step 12: present — VOFFSET swap to frame B -----------------
* The page flip is a register write, NOT a copy.
* [ref: CLAUDE.md §2G — HAL_gfx_present = VOFFSET std $FF9D, ~186 cyc]
                ldd     #VOFF_B
                std     $FF9D

* --- Step 13: publish completion --------------------------------
                lda     #2
                sta     probe_status
                ldd     #PROBE_MAGIC
                std     probe_magic

probe_done      bra     probe_done              ; spin; harness captures here

* ---------------------------------------------------------------
* Palette — 4 entries, $FFB0-$FFB3.
* RGB monitor format, bits 5:0 = R1 G1 B1 R0 G0 B0.
* [ref: SockmasterGime.md palette section; CLAUDE.md §4 — RGB default]
* Chosen for maximum separation so a wrong palette is obvious to the eye.
* ---------------------------------------------------------------
palette         fcb     $00             ; 0 = black
                fcb     $24             ; 1 = red    %100100
                fcb     $12             ; 2 = green  %010010
                fcb     $3F             ; 3 = white  %111111

                end     probe_entry
