* src/hal/coco3-dsk/gfx.s
*
* HAL Graphics subsystem — P2.3a implementation.
*
* Purpose:
*   HAL_gfx_init: initialize GIME for 320x192x4 double-buffered mode.
*   HAL_gfx_clear: fill active back buffer with palette index 0.
*   HAL_gfx_present: display buffer page_register identifies; swap displayed/draw buffers.
*
* Adapted from refs/GFXMODE3.ASM (Jay-authored, November 2025,
*   MAME-verified at authorship). Adaptation per P1.6 frame buffer
*   layout ($8000/$C000 instead of asm's $6000/$A000). EDTASM
*   single-quote operand comments converted to lwasm ';' syntax.
*   asm's START routine (ORCC, LDS, TFR A,DP) NOT ported here —
*   those are boot responsibilities, not HAL_gfx_init's job per A3.
*   asm's $FF90-last order REVERSED: P1.6 $8000/$C000 buffers are
*   in ROM territory; $FF90 must fire FIRST (see Step 1 note).
*
* Reference citations:
*   [ref: refs/GFXMODE3.ASM Jay-authored Nov 2025 — GIME register
*          values lines 36, 48-56 (mode/SAM); lines 57-64 (palette);
*          lines 39-45 / 108-113 (clear loop pattern)]
*   [ref: memory-map.md §4.8-4.9 — frame buffer CPU addresses]
*   [ref: memory-map.md §4.10 — initial GIME display state (frame B)]
*   [ref: memory-map.md §5 — GIME init sequence and mandatory order]
*   [ref: memory-map.md §6 — hal.inc address constants (KCOCO3_*)]
*   [ref: GIME-RM §10] — 320x192x4: $FF98=$80, $FF99=$15
*   [ref: GIME-RM §13] — VOFFSET = physical_addr / 8
*   [ref: GIME-RM §14] — init order; §14 prefers $FF90 last; P1.6
*                         $8000/$C000 layout requires FIRST (Step 1)
*   [ref: hal.inc — HAL_gfx_init/HAL_gfx_clear/HAL_gfx_present contracts]
*   [ref: conventions.md §2 — DP $00-$1F HAL scratch band]
*   [ref: conventions.md §3 — calling conventions]
*
* DP allocations (HAL scratch band $00-$1F):
*   $10-$11  hal_frame_hi/lo  (time.s — frame counter; not touched here)
*   $12      gfx_initialized  — $00 at reset; $01 after HAL_gfx_init
*
* P3 REPLACEMENT NOTES:
*   HAL_gfx_present: P2.3a.6-followup-1 implemented real VOFFSET swap.
*     P3 may refine to VBL-gated swap (HAL_time_vbl_wait integration).
*   HAL_gfx_init: P3 may add real MMU slot programming when A7 is
*     discharged (currently accepted as MAME-default MMU floor per plan
*     §A4/A7). HAL_gfx_init calls omitted per plan §4.4.
*
* METHODOLOGY OPEN ITEM (non-blocking):
*   $FF90/$FFD9/$FFDF register values are empirically known-good from
*   GFXMODE3.ASM (MAME-verified Nov 2025). Bit-level derivation from
*   GIME-RM not completed in P2.3a; carried forward as R4/R5 debt.
*   [no-ref: $FF90 INIT0 bit semantics from GIME-RM §4 — discharge P2.3a.1]
*   [no-ref: $FFD9/$FFDF SAM clock/RAM semantics — discharge P2.3a.1]
*
* ERR_NOMEM clause: HAL_gfx_init contract specifies ERR_NOMEM if frame
*   buffers cannot be allocated. In P2.3a, frame buffers are statically
*   allocated per P1.6 memory map ($8000-$BBFF, $C000-$FBFF). No
*   dynamic allocation; ERR_NOMEM is never returned. HAL_gfx_init
*   always returns CC.C clear in this implementation.
* ---------------------------------------------------------------

        setdp   0

* DP allocations and shared constants declared in src/engine/globals.s (P2.3a.3).
* [ref: src/engine/globals.s — canonical home]
*
* Symbols used here (defined in globals.s):
*   gfx_initialized equ $12  ; HAL gfx init flag
*   page_register   equ $50  ; active draw buffer (Option I back buffer)
*   PAGE_A_TOKEN    equ $20  ; draw target = buffer A
*   PAGE_B_TOKEN    equ $40  ; draw target = buffer B
*
* Frame buffer constants (HAL-private; defined locally here)
* [ref: memory-map.md §4.8-4.9]
GFX_FB_A_BASE       equ $8000       ; Frame A CPU base (back buffer initial)
GFX_FB_B_BASE       equ $C000       ; Frame B CPU base (front buffer initial)
GFX_FB_WORDS        equ $1E00       ; $3C00 bytes / 2 = $1E00 word stores

* ---------------------------------------------------------------
* HAL_gfx_init
*
* Initialize GIME for 320x192x4 double-buffered mode.
* Programs GIME mode registers, VOFFSET for initial display of
* frame B, clears both frame buffers, writes palette descriptor 0.
*
* ORIGIN: adapted from refs/GFXMODE3.ASM (Jay-authored Nov 2025,
*   MAME-verified). Register values from asm lines 36, 48-56, 57-64.
*   asm's $6000/$A000 layout DISCARDED per plan §A1 (use $8000/$C000).
*   asm's START sequence (ORCC, LDS, TFR A,DP) NOT ported per §A3.
*
* Args:    A = palette descriptor index (0 = Brøderbund default).
*          Only descriptor 0 is implemented. A != 0 falls through to
*          descriptor 0 (no panic; documented behavior per §A4).
* Returns: CC.C clear (always succeeds; ERR_NOMEM never raised,
*          frame buffers statically allocated per P1.6).
* Preserves: U, Y  [per hal.inc contract]
* Clobbers:  A, B, X, CC
*
* [ref: hal.inc HAL_gfx_init — contract specification]
* [ref: memory-map.md §5 — mandatory GIME init sequence]
* ---------------------------------------------------------------
HAL_gfx_init:
        pshs    u,y                     ; preserve U, Y per contract

* --- Step 1: Activate CoCo3 mode ($FF90) — MUST BE FIRST ---
* GIME INIT ORDERING CONSTRAINTS (empirical, per GFXMODE3.ASM Nov 2025):
*
*   CONSTRAINT A — $FF90 written FIRST:
*     Our framebuffers are at $8000-$FBFF (ROM territory under CoCo1/2 map).
*     $FF90=$4C transitions to CoCo3 map (COCO=0, all-RAM) so the framebuffer
*     is accessible. GFXMODE3 wrote $FF90 last because its framebuffers
*     ($6000-$9BFF) are accessible under either map type. We cannot.
*     [ref: GFXMODE3.ASM line 53-54 — LDA #$4C / STA $FF90]
*
*   CONSTRAINT B — Palette ($FFB0-$FFB3) written LAST:
*     Empirical observation from GFXMODE3 development (P2.3a.6-followup-3).
*     Palette writes do not appear to latch correctly until the GIME's video
*     mode ($FF98/$FF99) is in its final 4-color state. Writing palette before
*     $FF98/$FF99 causes indices 1-2 to render as black regardless of value.
*     NOT documented in SockmasterGime.md; inferred from working GFXMODE3 vs
*     broken pre-reorder HAL_gfx_init. Combined constraint:
*     $FF90 first → clear buffers → mode → VOFFSET → VSCROL → HOFFSET → SAM
*     → palette LAST.
*     [ref: GFXMODE3.ASM lines 48-64 — mode-before-palette ordering]
*
*   IEN PRESERVATION NOTE (HAL_gfx_init IEN fix, 2026-05-20):
*     Value written is $6C, not $4C. $6C = $4C | $20 (adds IEN=1, bit 5).
*     GFXMODE3.ASM used $4C (IEN=0) which is sufficient for a standalone
*     demo without interrupts. karateka-coco3 requires IEN=1 because
*     HAL_time_init (init order step 2) writes $FF90=$6C to enable GIME VBL
*     interrupts; HAL_gfx_init at step 3 must not clobber that bit.
*
*     $FF90 is write-only (reads return hardware status, not last-written
*     value; [ref: docs/project/interrupt-handling.md §8.4]). Read-modify-write is
*     impossible. All bits this function requires are preserved in $6C:
*     COCO=0, MMUEN=1, IEN=1, FEN=0, MC3=1, MC2=1, MC1=0, MC0=0.
*
*     Coupling: this value assumes IEN=1 is the correct state after
*     HAL_time_init. Safe for standalone drivers that omit HAL_time_init:
*     such drivers keep CC.I=1 throughout (per Q001.4/4.c — never opt in
*     to real-VBL). CPU never services IRQ regardless of GIME assertion
*     state, so IEN=1 is harmless in this configuration.
*     [ref: src/hal.inc INIT ORDER — time init (step 2) before gfx (step 3)]
*
        lda     #$6C                    ; == KCOCO3_INIT0_RUN (hal.inc) — IEN=1 MUST be
                                        ; re-asserted here or HAL_time_init's VBL interrupt
                                        ; dies silently. $FF90 is write-only: no RMW possible.
                                        ; Literal, not the symbol: hal.inc uses `import` and
                                        ; cannot be included in a --decb build.
        sta     $FF90                   ; INIT0: COCO=0,MMUEN=1,IEN=1,MC3=1,MC2=1

* --- Step 2: Clear Frame A ($8000-$BBFF, 15,360 bytes) ---
* [ref: GFXMODE3.ASM lines 39-45 — clear pattern]
* [ref: plan O2 — both buffers cleared at init time]
        ldx     #GFX_FB_A_BASE          ; $8000
        ldd     #$0000
        ldy     #GFX_FB_WORDS           ; $1E00 = 7,680 word stores = 15,360 bytes
gfx_init_clear_a:
        std     ,x++
        leay    -1,y
        bne     gfx_init_clear_a

* --- Step 3: Clear Frame B ($C000-$FBFF, 15,360 bytes) ---
        ldx     #GFX_FB_B_BASE          ; $C000
        ldy     #GFX_FB_WORDS
gfx_init_clear_b:
        std     ,x++
        leay    -1,y
        bne     gfx_init_clear_b

* --- Step 4: GIME video mode = 320x192x4 ---
* Mode written BEFORE palette (Constraint B above).
* [ref: GFXMODE3.ASM line 48 — LDD #$8015 / STD $FF98]
* [ref: GIME-RM §10] $FF98=$80 (VMODE: BP=1 graphics); $FF99=$15 (VRES: 320x192x4)
        ldd     #$8015
        std     $FF98                   ; $FF98=$80 VMODE; $FF99=$15 VRES

* --- Step 5: VOFFSET — point GIME at Frame B (initial front buffer) ---
* Initial state: GIME displays Frame B; engine renders to Frame A.
* [ref: memory-map.md §4.10 — "Initial state: GIME displays frame B"]
* [ref: memory-map.md §4.9 — Frame B physical $7C000]
* [ref: GIME-RM §13] VOFFSET = physical_addr / 8 = $7C000 / 8 = $F800
*   $FF9D=$F8 (high byte), $FF9E=$00 (low byte)
* VOFFSET CORRECTNESS: inferred from disassembly; NOT verified in P2.3a.
*   Discharge by P2.3a.1 sentinel test per plan §3.2 R6 amendment.
        ldd     #$F800
        std     $FF9D                   ; $FF9D=$F8 VOFFSET_HI; $FF9E=$00 VOFFSET_LO

* --- Step 6: VSCROL = 0 (REQUIRED; undefined at reset) ---
* [ref: memory-map.md §5 step 8] "$FF9C=$00 VSCROL = 0 (REQUIRED)"
        clr     $FF9C                   ; VSCROL = 0

* --- Step 7: HOFFSET = 0 (REQUIRED; undefined at reset) ---
* [ref: memory-map.md §5 step 9] "$FF9F=$00 HOFFSET = 0 (REQUIRED)"
        clr     $FF9F                   ; HOFFSET = 0

* --- Step 8: SAM clock + RAM ---
* [ref: GFXMODE3.ASM line 36 — STA $FFD9 (A=0, 1.78 MHz clock)]
* [ref: GFXMODE3.ASM line 56 — STA $FFDF (A=0, SAM RAM at $C000)]
* METHODOLOGY NOTE: bit semantics not derived from GIME-RM in P2.3a.
* Values are empirically known-good from MAME-verified asm. Carry as
* non-blocking open item; discharge bit-level derivation in P2.3a.1.
        clra
        sta     $FFD9                   ; SAM: 1.78 MHz CPU clock
        sta     $FFDF                   ; SAM: RAM at $C000 (task 0)

* --- Step 9: Palette descriptor 0 (Brøderbund) — MUST BE LAST ---
* Palette written AFTER all mode/offset/SAM setup (Constraint B above).
* [ref: GIME-RM §8] palette registers $FFB0-$FFB3, 6-bit GIME color codes.
*
* PALETTE FORMAT NOTE (P2.3a.6-followup-2):
* CoCo3 GIME palette registers support two interpretations:
*   1) RGB monitor:   bits 5:0 = R1 G1 B1 R0 G0 B0
*      [ref: docs/ground-truth/SockmasterGime.md lines 218-240]
*   2) Composite monitor: bits 5:4 = intensity (0-3), bits 3:0 = hue (0-15)
*      [ref: docs/ground-truth/SockmasterGime.md lines 241-242]
* MAME emulates CoCo3 in composite mode.
*
* Descriptor 0 (Brøderbund palette) — composite format, MAME-verified:
*   $00 = black     (intensity 0)
*   $26 = orange    (intensity 2, hue 6)   [MAME-verified Nov 2025]
*   $1B = blue/cyan (intensity 1, hue 11)  [MAME-verified Nov 2025]
*   $3F = white     (intensity 3, hue 15)
* [ref: refs/GFXMODE3.ASM lines 57-64 — palette programming]
*
* Only descriptor 0 implemented. A != 0 falls through to descriptor 0.
        lda     #$00
        sta     $FFB0                   ; palette index 0 (background / black)
        lda     #$26
        sta     $FFB1                   ; palette index 1 (orange)    — $26 composite hue 6, intensity 2
        lda     #$1B
        sta     $FFB2                   ; palette index 2 (blue/cyan) — $1B composite hue 11, intensity 1
        lda     #$3F
        sta     $FFB3                   ; palette index 3 (white)     — $3F composite intensity 3

* --- Step 10: Mark initialization complete ---
        lda     #$01
        sta     <gfx_initialized        ; $12 = $01 (init complete)

        puls    u,y                     ; restore U, Y per contract
        andcc   #$FE                    ; CC.C clear = success
        rts

* ---------------------------------------------------------------
* HAL_gfx_clear
*
* Fill active back buffer with palette index 0 (background = $00).
* Never writes to the front buffer (D.3 back-buffer discipline).
*
* Back buffer is determined by page_register (DP $50):
*   PAGE_A token ($20) → back buffer = Frame A ($8000-$BBFF)
*   PAGE_B token ($40) → back buffer = Frame B ($C000-$FBFF)
* page_register MUST be initialized before calling HAL_gfx_clear.
*
* ORIGIN: clear loop pattern from refs/GFXMODE3.ASM lines 108-113.
*   Loop adapted to back-buffer-only discipline; asm cleared all of
*   WORK_SCREEN ($A000) without HAL buffer abstraction.
*
* Args:    none
* Returns: CC.C clear
* Preserves: U  [per hal.inc contract]
* Clobbers:  A, B, X, Y, CC
*
* [ref: hal.inc HAL_gfx_clear — contract; "never writes to front"]
* [ref: src/engine/timer_framesync.s — page_register equ $50]
* ---------------------------------------------------------------
HAL_gfx_clear:
        lda     <page_register               ; read page_register ($50)
        cmpa    #PAGE_A_TOKEN           ; PAGE_A=$20 → back=frame A
        bne     gfx_clear_b_buf
        ldx     #GFX_FB_A_BASE          ; back buffer = Frame A ($8000)
        bra     gfx_clear_common
gfx_clear_b_buf:
        ldx     #GFX_FB_B_BASE          ; back buffer = Frame B ($C000)
gfx_clear_common:
        ldd     #$0000                  ; clear value (palette index 0 = $00 per byte)
        ldy     #GFX_FB_WORDS           ; $1E00 word stores = 15,360 bytes
gfx_clear_loop:
        std     ,x++
        leay    -1,y
        bne     gfx_clear_loop
        andcc   #$FE                    ; CC.C clear = success
        rts

* ---------------------------------------------------------------
* HAL_gfx_present  [P2.3a.5 real implementation]
*
* Swap the GIME-displayed buffer by writing VOFFSET ($FF9D/$FF9E).
* Reads page_register (DP $50) — the CURRENT BACK BUFFER (active draw
* target) — then writes VOFFSET so GIME displays that buffer, making
* the just-drawn content visible.
*
* Option I convention (P2.3a.6-followup-1 — canonical):
*   page_register holds the BACK buffer (draw target). HAL_gfx_present
*   displays the buffer page_register identifies (the one just drawn to).
*   Caller flow: draw → HAL_gfx_present → toggle page_register for next draw.
*
*   PAGE_A_TOKEN ($20) → buffer A was the draw target.
*                        HAL_gfx_present writes VOFFSET for Frame A
*                        ($F000/$00). GIME displays Frame A.
*   PAGE_B_TOKEN ($40) → buffer B was the draw target.
*                        HAL_gfx_present writes VOFFSET for Frame B
*                        ($F800/$00). GIME displays Frame B.
*
* CONVENTION NOTE: "page_register" identifies the BACK buffer (draw
*   target). Convention established in P2.1 with timer_framesync.s.
*   See docs/project/conventions.md §2 frame-coherent band.
*
* NOTE on PAGE_A_TOKEN ($20) / PAGE_B_TOKEN ($40): Apple II heritage.
*   On Apple II, $20/$40 are the high bytes of hires page base addresses
*   ($2000/$4000). On CoCo3 they are opaque draw-target tokens; they have
*   no CoCo3 hardware significance.
*   [ref: src/engine/globals.s — token declarations and heritage note]
*
* CALLER CONTRACT (Option I):
*   - Caller draws to the buffer page_register points at.
*   - Caller calls HAL_gfx_present — displays the just-drawn buffer.
*   - Caller toggles page_register to designate the new draw target.
*   - HAL_gfx_present does NOT modify page_register.
*
* NO VBL gating. This implementation writes VOFFSET immediately without
* waiting for vertical blanking. Tearing may occur if called mid-scanline.
* VBL synchronization is deferred to P3.2.
*
* VOFFSET derivation:
*   Frame A physical $78000: VOFFSET = $78000/8 = $F000 → $FF9D=$F0,$FF9E=$00
*   Frame B physical $7C000: VOFFSET = $7C000/8 = $F800 → $FF9D=$F8,$FF9E=$00
*   [ref: GIME-RM §13] VOFFSET = physical_addr / 8
*   [ref: memory-map.md §4.8-4.9] physical addresses for Frame A/B
*
* Args:    none (reads page_register from DP $50)
* Returns: CC.C clear
* Preserves: U, Y
* Clobbers: A, B, D, CC
*
* [ref: src/engine/timer_framesync.s — page_register equ $50]
* [ref: hal.inc HAL_gfx_present — contract]
* [ref: memory-map.md §4.10 — GIME VOFFSET swap mechanism]
* ---------------------------------------------------------------
HAL_gfx_present:
        pshs    u,y                     ; preserve U, Y per contract

        ; Option I convention (P2.3a.6-followup-1):
        ;   page_register holds the BACK buffer (just drawn to).
        ;   HAL_gfx_present displays the buffer page_register identifies.
        ;   Caller flow: draw → HAL_gfx_present → toggle page_register for next draw.
        lda     <page_register               ; read back-buffer token (buffer just drawn to)
        cmpa    #PAGE_A_TOKEN           ; is frame A the current draw target (back)?
        beq     gfx_present_show_a      ; yes → GIME displays frame A (just drawn)

        ldd     #$F800                  ; frame B VOFFSET ($FF9D=$F8, $FF9E=$00)
        bra     gfx_present_write

gfx_present_show_a:
        ldd     #$F000                  ; frame A VOFFSET ($FF9D=$F0, $FF9E=$00)

gfx_present_write:
        std     $FF9D                   ; write VOFFSET: $FF9D=hi, $FF9E=lo
                                        ; [ref: GIME-RM §13] VOFFSET registers

        puls    u,y                     ; restore U, Y per contract
        andcc   #$FE                    ; CC.C clear = success
        rts

* ---------------------------------------------------------------
* HAL_gfx_blit_sprite  [P2.4.1 sub-byte runtime shifter]
*
* Blit a CoCo3 packed sprite into the active back buffer at a sub-byte-
* precise position. Implements runtime pixel-shift equivalent to the
* Apple II Karateka L1A84 mechanism (karateka_dissasembly_claude/
* src/video.s lines 391-492).
*
* Sprite data format (per P1.2 / tools/sprite_convert.py):
*   byte 0:  height (number of rows)
*   byte 1:  coco3_width (bytes per row; 4 pixels per byte, 2bpp MSB-first)
*   bytes 2+: packed bitmap, row-major, top-to-bottom
*
* Sub-byte shift mechanism (CoCo3 2bpp, 4 pixels per byte):
*   subbyte=0: no shift; byte-aligned blit (fast path)
*   subbyte=1: 2-bit right shift; output=src>>2, overflow=(src&0x03)<<6
*   subbyte=2: 4-bit right shift; output=src>>4, overflow=(src&0x0F)<<4
*   subbyte=3: 6-bit right shift; output=src>>6, overflow=(src&0x3F)<<2
*   Overflow from each source byte is OR-merged into the next dest byte.
*   The effective output width is (sprite_width + 1) bytes when subbyte>0.
*
* Apple II port note: Apple II has 7 pixels per byte (1bpp), so L1A84
* dispatches on 7 shift values (0-6) and uses 1-bit shift units. CoCo3
* has 4 pixels per byte (2bpp), so 4 shift values (0-3) with 2-bit units.
* The LSR/ROR mechanics are identical in structure; only the number of
* shift cases and bits-per-shift differ.
*
* Cycle estimate per source byte (static analysis):
*   subbyte=0: ~10 cy (lda ,x+ + sta ,y+ + loop overhead)
*   subbyte=1: ~47 cy (2×LSR + 2×ROR + OR-blend + overflow handling)
*   subbyte=2: ~55 cy (4×LSR + 4×ROR + OR-blend + overflow)
*   subbyte=3: ~63 cy (6×LSR + 6×ROR + OR-blend + overflow)
* For a 4-byte × 10-row sprite at subbyte=1: ~1880 cycles.
*
* Back buffer selected by page_register (DP $50, Option I convention):
*   PAGE_A_TOKEN ($20) → buffer A ($8000-$BBFF)
*   PAGE_B_TOKEN ($40) → buffer B ($C000-$FBFF)
* Row stride is 80 bytes (320px / 4px per byte).
*
* DP scratch (HAL internal band $08-$0F per conventions.md §2):
*   $08  blit_height  — sprite height (row loop counter)
*   $09  blit_width   — sprite width in bytes (inner loop count per row)
*   $0A  blit_col     — destination byte column (saved from A arg)
*   $0B  blit_row     — destination pixel row (saved from B arg)
*   $0C  blit_subbyte — sub-byte pixel offset 0-3 (set by CALLER before call)
*   $0D  blit_ovf_new — per-byte overflow accumulator (HAL internal, shifted bits)
*   $0E  blit_ovf_prev— per-row overflow carry (HAL internal, OR'd into next dest byte)
*
* Args:    X = pointer to sprite data (height byte + width byte + rows)
*          A = destination byte column (0-79; 4 pixels per byte)
*          B = destination pixel row (0-191)
*          ZP $0C (blit_subbyte) = sub-byte pixel offset (0-3); CALLER MUST SET
* Returns: CC.C clear on success
*          CC.C set, A = ERR_INVALID if sprite extends beyond frame buffer
* Preserves: U
* Clobbers: A, B, X, Y, CC, ZP $0D/$0E
*
* Limitation: bounds check does not account for the +1 overflow byte
* when subbyte>0. Caller must ensure col+width <= 78 when subbyte>0.
*
* [ref: hal.inc HAL_gfx_blit_sprite — contract specification]
* [ref: docs/project/conventions.md §2 — DP $08-$0F HAL internal scratch band]
* [ref: karateka_dissasembly_claude/src/video.s L1A84 lines 391-492]
* [ref: Apple II sub-byte inspection report (2026-05-17)]
* ---------------------------------------------------------------

* HAL-private DP scratch locations for blit (HAL internal band $08-$0F)
blit_height     equ $08                 ; sprite row count (loop counter)
blit_width      equ $09                 ; sprite bytes per row (inner count)
blit_col        equ $0A                 ; destination byte column (0-79)
blit_row        equ $0B                 ; destination pixel row (0-191)
blit_subbyte    equ $0C                 ; sub-byte pixel offset 0-3 (set by caller)
blit_ovf_new    equ $0D                 ; per-byte overflow accumulator (HAL internal)
blit_ovf_prev   equ $0E                 ; per-row overflow carry (HAL internal)
blit_tmp        equ $0F                 ; transparency scratch: source byte during mask sequence
blit_opaque     equ $13                 ; 0=transparent (index-0 keyed), nonzero=opaque (store all)
* ===============================================================
* POP DORMANCY GUARD (P2.1) — everything below is ADOPTED BUT NOT ASSEMBLED.
*
* POP does not use the runtime masked blit. PA.6 measured it at 5.4x the cost the
* design assumed and ruled it INFEASIBLE for POP's per-frame budget; PA.7/PA.9/P1.3
* replaced it with COMPILED SPRITES (harness/tools/sprite_compiler.py emits a
* straight-line draw routine per cel, JSR'd directly). So these six entry points
* have no POP caller.
*
* They are LEFT IN SOURCE, VERBATIM AND UNMODIFIED, per the P2.1 governing rule
* that the HAL stays the same recognizable artifact across Karateka and POP —
* dormant-but-present, not deleted, not rewritten. Re-enable with a single
* assembler flag, no source edit:
*     lwasm -DPOP_HAL_RUNTIME_BLIT ...
*
* Not free to leave assembling: measured at 1,231 of 1,609 bytes = 77% of the
* adopted HAL's code. That is the whole reason this guard exists rather than a
* comment in the audit table.
*
* Everything between `ifdef` and `endc` is byte-identical to karateka's gfx.s.
* ===============================================================
                ifdef   POP_HAL_RUNTIME_BLIT


* HAL_gfx_blit_sprite_opaque — like HAL_gfx_blit_sprite but OPAQUE: every pixel
* (incl. index-0/black) is stored, overwriting the dest. Faithful to the oracle's
* $0F-selected store blend (video.s routine_1927). Use for black shadows / solid
* fills that must show against a (partially black) background. Same args as
* HAL_gfx_blit_sprite (X=sprite, A=col, B=row, blit_subbyte set).
HAL_gfx_blit_sprite_opaque:
        pshs    a
        lda     #$01
        sta     <blit_opaque
        puls    a
        bra     blit_have_mode

HAL_gfx_blit_sprite:
        clr     <blit_opaque            ; default transparent (existing callers unchanged)
blit_have_mode:
        pshs    u                       ; preserve U per contract

        sta     <blit_col               ; $0A = destination byte column
        stb     <blit_row               ; $0B = destination pixel row

        lda     ,x+                     ; A = height
        sta     <blit_height
        lda     ,x+                     ; A = width
        sta     <blit_width

        ; Bounds check: col + width > 80
        lda     <blit_col
        adda    <blit_width
        lbcs    blit_out_of_bounds
        cmpa    #81
        lbhs    blit_out_of_bounds

        ; Bounds check: row + height > 192
        lda     <blit_row
        adda    <blit_height
        lbcs    blit_out_of_bounds
        cmpa    #193
        lbhs    blit_out_of_bounds

        ; Compute buffer base → Y
        lda     <page_register
        cmpa    #PAGE_A_TOKEN
        beq     blit_base_a
        ldy     #GFX_FB_B_BASE
        bra     blit_got_base
blit_base_a:
        ldy     #GFX_FB_A_BASE
blit_got_base:
        lda     #80
        ldb     <blit_row
        mul
        leay    d,y                     ; Y = buffer_base + row*80
        ldb     <blit_col
        leay    b,y                     ; Y = buffer_base + row*80 + col
        ldu     #blit_trans_table_mid   ; U = transparency mask table midpoint
        tst     <blit_opaque            ; opaque mode? -> all-$FF table (store verbatim)
        beq     blit_dispatch
        ldu     #blit_opaque_table_mid

        ; Dispatch to sub-byte-specific row loop
blit_dispatch:                          ; shared entry (HAL_gfx_blit_scroll jumps here w/ Y,U set)
        lda     <blit_subbyte
        beq     blit_do_sb0
        cmpa    #1
        beq     blit_do_sb1
        cmpa    #2
        beq     blit_do_sb2
        lbra    blit_do_sb3             ; subbyte=3

* ---------------------------------------------------------------
* Transparency-aware blit sequence (all subbyte cases):
*   U = blit_trans_table_mid (set before dispatch; table[$80-$FF] below, [$00-$7F] at U)
*   lda b,u: B = source byte → signed offset → correct mask for all 256 values
*   For each output byte A:
*     pshs b              ; save loop counter
*     tfr  a,b            ; B = output (A unchanged; TFR non-destructive)
*     lda  b,u            ; A = mask(output): 11 per non-black pixel pair, 00 per black
*     coma                ; A = ~mask
*     anda ,y             ; A = dest & ~mask (preserve black-keyed positions)
*     stb  <blit_tmp      ; output to DP scratch
*     ora  <blit_tmp      ; A = (dest & ~mask) | output
*     sta  ,y+            ; write result; advance Y (or sta ,y for overflow byte)
*     puls b              ; restore loop counter
* ---------------------------------------------------------------

* ---------------------------------------------------------------
* subbyte=0: byte-aligned (no shift); transparency-aware
* ---------------------------------------------------------------
blit_do_sb0:
        lda     <blit_height
blit_row_sb0:
        ldb     <blit_width
blit_byte_sb0:
        lda     ,x+                     ; source byte
        pshs    b                        ; save loop counter
        tfr     a,b                      ; B = source (TFR: A unchanged)
        lda     b,u                      ; A = mask(source)
        coma                             ; A = ~mask
        anda    ,y                       ; A = dest & ~mask
        stb     <blit_tmp                ; source to DP scratch
        ora     <blit_tmp                ; A = (dest & ~mask) | source
        sta     ,y+                      ; write, advance Y
        puls    b                        ; restore loop counter
        decb
        bne     blit_byte_sb0
        ldb     #80
        subb    <blit_width
        leay    b,y
        dec     <blit_height
        bne     blit_row_sb0
        lbra    blit_done

* ---------------------------------------------------------------
* subbyte=1: 2-bit right shift; transparency-aware
* ---------------------------------------------------------------
blit_do_sb1:
        lda     <blit_height
blit_row_sb1:
        clr     <blit_ovf_prev
        ldb     <blit_width
blit_byte_sb1:
        clr     <blit_ovf_new
        lda     ,x+
        lsra
        ror     <blit_ovf_new
        lsra
        ror     <blit_ovf_new
        ora     <blit_ovf_prev          ; A = shifted output byte
        pshs    b
        tfr     a,b
        lda     b,u
        coma
        anda    ,y
        stb     <blit_tmp
        ora     <blit_tmp
        sta     ,y+
        puls    b
        lda     <blit_ovf_new
        sta     <blit_ovf_prev
        decb
        bne     blit_byte_sb1
        lda     <blit_ovf_prev          ; overflow byte
        tfr     a,b
        lda     b,u
        coma
        anda    ,y
        stb     <blit_tmp
        ora     <blit_tmp
        sta     ,y                       ; write overflow (no Y advance)
        ldb     #80
        subb    <blit_width
        leay    b,y
        dec     <blit_height
        bne     blit_row_sb1
        lbra    blit_done

* ---------------------------------------------------------------
* subbyte=2: 4-bit right shift; transparency-aware
* ---------------------------------------------------------------
blit_do_sb2:
        lda     <blit_height
blit_row_sb2:
        clr     <blit_ovf_prev
        ldb     <blit_width
blit_byte_sb2:
        clr     <blit_ovf_new
        lda     ,x+
        lsra
        ror     <blit_ovf_new
        lsra
        ror     <blit_ovf_new
        lsra
        ror     <blit_ovf_new
        lsra
        ror     <blit_ovf_new
        ora     <blit_ovf_prev
        pshs    b
        tfr     a,b
        lda     b,u
        coma
        anda    ,y
        stb     <blit_tmp
        ora     <blit_tmp
        sta     ,y+
        puls    b
        lda     <blit_ovf_new
        sta     <blit_ovf_prev
        decb
        bne     blit_byte_sb2
        lda     <blit_ovf_prev          ; overflow byte
        tfr     a,b
        lda     b,u
        coma
        anda    ,y
        stb     <blit_tmp
        ora     <blit_tmp
        sta     ,y
        ldb     #80
        subb    <blit_width
        leay    b,y
        dec     <blit_height
        bne     blit_row_sb2
        lbra    blit_done

* ---------------------------------------------------------------
* subbyte=3: 6-bit right shift; transparency-aware
* ---------------------------------------------------------------
blit_do_sb3:
        lda     <blit_height
blit_row_sb3:
        clr     <blit_ovf_prev
        ldb     <blit_width
blit_byte_sb3:
        clr     <blit_ovf_new
        lda     ,x+
        lsra
        ror     <blit_ovf_new
        lsra
        ror     <blit_ovf_new
        lsra
        ror     <blit_ovf_new
        lsra
        ror     <blit_ovf_new
        lsra
        ror     <blit_ovf_new
        lsra
        ror     <blit_ovf_new
        ora     <blit_ovf_prev
        pshs    b
        tfr     a,b
        lda     b,u
        coma
        anda    ,y
        stb     <blit_tmp
        ora     <blit_tmp
        sta     ,y+
        puls    b
        lda     <blit_ovf_new
        sta     <blit_ovf_prev
        decb
        bne     blit_byte_sb3
        lda     <blit_ovf_prev          ; overflow byte
        tfr     a,b
        lda     b,u
        coma
        anda    ,y
        stb     <blit_tmp
        ora     <blit_tmp
        sta     ,y
        ldb     #80
        subb    <blit_width
        leay    b,y
        dec     <blit_height
        bne     blit_row_sb3

blit_done:
        andcc   #$FE                    ; CC.C clear = success
        puls    u
        rts

blit_out_of_bounds:
        lda     #$02                    ; A = ERR_INVALID (2) per hal.inc
        orcc    #$01                    ; CC.C set = error
        puls    u
        rts

* ---------------------------------------------------------------
* HAL_gfx_blit_sprite_mixed — per-REGION mixed-opacity blit (ADDITIVE).
*   Splits a sprite into byte-COLUMN runs; each run is blitted OPAQUE (index-0
*   stored solid) or TRANSPARENT (index-0 keyed) per a descriptor. It WRAPS the
*   existing transparent + opaque blits — their optimized loops are UNCHANGED,
*   so every existing caller stays byte-identical. Reusable: any sprite with
*   region-separable opacity supplies its own run descriptor. NO pixel-format
*   change (2bpp preserved) — the opacity lives in the descriptor, not the data.
*
* Args: X = sprite (height,width,bitmap); A = dest byte col; B = dest row;
*       blit_subbyte ($0C) set; U = descriptor ptr.
* Descriptor: repeating RECTANGLE entries
*       fcb start_col, width, start_row, num_rows, opaque(0=transp,1=opaque)
*       terminated by a width byte of 0. (Row-bands, column-runs, or cells.)
* Per region: extract the rectangle [start_col..+width) x [start_row..+num_rows)
*       to MIX_SCRATCH, then blit via the existing leaf at dest
*       (A+start_col, B+start_row), same sub-byte.
* Uses mix_* ZP ($14-$20) which the inner blits do not touch; blit_subbyte
*       persists across regions (the blits read it, never write it).
* ---------------------------------------------------------------
mix_col         equ $14
mix_row         equ $15
mix_desc        equ $16                 ; 16-bit descriptor ptr
mix_data        equ $18                 ; 16-bit source bitmap ptr
mix_w           equ $1A                 ; source row stride (sprite width)
mix_sc          equ $1B                 ; region start_col
mix_rw          equ $1C                 ; region width
mix_sr          equ $1D                 ; region start_row
mix_nr          equ $1E                 ; region num_rows
mix_op          equ $1F                 ; region opacity
        ifndef  MIX_SCRATCH             ; caller may override BEFORE including gfx.s (large programs
MIX_SCRATCH     equ $3E00               ; whose load reaches $3E00 must relocate it to free RAM).
        endc                            ; default: extracted sub-sprite scratch below FLIP_BUF

HAL_gfx_blit_sprite_mixed:
        sta     <mix_col
        stb     <mix_row
        stu     <mix_desc
        leax    1,x                     ; skip height byte
        lda     ,x+                     ; width
        sta     <mix_w
        stx     <mix_data               ; X -> source bitmap
mix_run:
        ldu     <mix_desc
        lda     ,u                      ; start_col
        sta     <mix_sc
        ldb     1,u                     ; width
        bne     mix_have
        rts                             ; width 0 -> done
mix_have:
        stb     <mix_rw
        lda     2,u                     ; start_row
        sta     <mix_sr
        lda     3,u                     ; num_rows
        sta     <mix_nr
        lda     4,u                     ; opacity
        sta     <mix_op
        leau    5,u
        stu     <mix_desc
        ; build sub-sprite header (num_rows, width) at MIX_SCRATCH
        ldx     #MIX_SCRATCH
        lda     <mix_nr
        sta     ,x+
        lda     <mix_rw
        sta     ,x+                     ; X -> scratch data
        ; Y = mix_data + start_row*width + start_col
        lda     <mix_sr
        ldb     <mix_w
        mul                             ; D = start_row * width
        addd    <mix_data
        addb    <mix_sc
        adca    #0
        tfr     d,y                     ; Y = rectangle top-left source byte
        lda     <mix_nr                 ; row counter
mix_erow:
        pshs    a
        ldb     <mix_rw
mix_ebyte:
        lda     ,y+
        sta     ,x+
        decb
        bne     mix_ebyte
        ldb     <mix_w                  ; skip to next row's region start: Y += (w - rw)
        subb    <mix_rw
        leay    b,y
        puls    a
        deca
        bne     mix_erow
        ; blit the extracted rectangle via the existing leaf at (col+sc, row+sr)
        ldx     #MIX_SCRATCH
        lda     <mix_row
        adda    <mix_sr
        pshs    a                       ; dest row
        lda     <mix_col
        adda    <mix_sc                 ; A = dest col
        ldb     ,s+                     ; B = dest row
        tst     <mix_op
        bne     mix_blit_op
        jsr     HAL_gfx_blit_sprite     ; transparent region
        bra     mix_run
mix_blit_op:
        jsr     HAL_gfx_blit_sprite_opaque  ; opaque region
        bra     mix_run

* ---------------------------------------------------------------
* HAL_gfx_blit_sprite_masked — opaque blit with a per-COLUMN POSITIONAL mask
*   (ADDITIVE, sub-byte precision, NO format change). Where the existing mixed
*   blit splits opacity at BYTE boundaries, this splits it at the PIXEL within a
*   byte: each source byte is merged with the caller's mask byte for that column
*   via the SAME engine the transparent/opaque blits use — result =
*   (dest AND ~mask) OR source. mask bit-pair = 11 -> take source (opaque),
*   00 -> keep dest (transparent). So a column can be opaque on some pixels and
*   transparent on others (e.g. trim a 1px edge off an otherwise-solid byte).
*
*   Like the transparent blit, kept-dest (mask=00) pixels rely on source being
*   index-0 there (the OR contributes 0) — true for black edges/keying.
*
* Args: X = sprite (height,width,bitmap); A = dest byte col; B = dest row;
*       U = mask array ptr (one mask byte per source column, width bytes).
* BYTE-ALIGNED ONLY (no sub-byte shift) — the feet use blit_subbyte=0.
* Reuses blit_height/width/col/row/tmp + mix_data ($18) for the mask base.
* Preserves nothing extra; clobbers A,B,X,Y,U,CC. Bounds-checked like the others.
* ---------------------------------------------------------------
emask_ptr       equ mix_data            ; reuse $18 (16-bit) — disjoint from a mixed-blit call
HAL_gfx_blit_sprite_masked:
        stu     <emask_ptr              ; mask array base (reloaded per row)
        sta     <blit_col
        stb     <blit_row
        lda     ,x+                     ; height
        sta     <blit_height
        lda     ,x+                     ; width
        sta     <blit_width
        lda     <blit_col               ; bounds: col+width <= 80
        adda    <blit_width
        bcs     emask_oob
        cmpa    #81
        bhs     emask_oob
        lda     <blit_row               ; bounds: row+height <= 192
        adda    <blit_height
        bcs     emask_oob
        cmpa    #193
        bhs     emask_oob
        lda     <page_register
        cmpa    #PAGE_A_TOKEN
        beq     emask_base_a
        ldy     #GFX_FB_B_BASE
        bra     emask_got_base
emask_base_a:
        ldy     #GFX_FB_A_BASE
emask_got_base:
        lda     #80
        ldb     <blit_row
        mul
        leay    d,y                     ; Y = base + row*80
        ldb     <blit_col
        leay    b,y                     ; Y = dest top-left
emask_row:
        ldu     <emask_ptr              ; U = mask array (reset each row)
        ldb     <blit_width
emask_byte:
        lda     ,x+                     ; source byte
        sta     <blit_tmp               ; stash source
        lda     ,u+                     ; positional mask for this column
        coma                            ; ~mask
        anda    ,y                      ; dest AND ~mask  (keep dest where mask=00)
        ora     <blit_tmp               ; OR source       (take source where mask=11)
        sta     ,y+                     ; write, advance
        decb
        bne     emask_byte
        ldb     #80
        subb    <blit_width
        leay    b,y                     ; next row
        dec     <blit_height
        bne     emask_row
emask_oob:
        rts

* ---------------------------------------------------------------
* HAL_gfx_blit_stencil_punch — punch a per-PIXEL 2D silhouette to black.
*   (ADDITIVE.) Unlike HAL_gfx_blit_sprite_masked (per-COLUMN mask, reset each
*   row), this walks a FULL 2D mask (width*height bytes, advancing continuously)
*   and writes: dest = dest AND ~mask. Mask bit-pair 11 -> force pixel black
*   (occlude), 00 -> keep dest. Used to occlude a moving actor behind Akuma's
*   exact figure silhouette (mask from fig_974B: 11=figure, 00=surround+gaps),
*   trimmed to his shape (not a rectangle) incl. the interior armpit gaps.
* Args: X = stencil (height,width,maskbytes); A = dest byte col; B = dest row.
* BYTE-ALIGNED. Bounds-checked like the others. Clobbers A,B,X,Y,CC.
* ---------------------------------------------------------------
HAL_gfx_blit_stencil_punch:
        sta     <blit_col
        stb     <blit_row
        lda     ,x+                     ; height
        sta     <blit_height
        lda     ,x+                     ; width
        sta     <blit_width
        lda     <blit_col               ; bounds: col+width <= 80
        adda    <blit_width
        bcs     epun_oob
        cmpa    #81
        bhs     epun_oob
        lda     <blit_row               ; bounds: row+height <= 192
        adda    <blit_height
        bcs     epun_oob
        cmpa    #193
        bhs     epun_oob
        lda     <page_register
        cmpa    #PAGE_A_TOKEN
        beq     epun_base_a
        ldy     #GFX_FB_B_BASE
        bra     epun_got_base
epun_base_a:
        ldy     #GFX_FB_A_BASE
epun_got_base:
        lda     #80
        ldb     <blit_row
        mul
        leay    d,y                     ; Y = base + row*80
        ldb     <blit_col
        leay    b,y                     ; Y = dest top-left
epun_row:
        ldb     <blit_width
epun_byte:
        lda     ,x+                     ; 2D mask byte (advances continuously)
        coma                            ; ~mask
        anda    ,y                      ; dest AND ~mask  (11 -> black, 00 -> keep)
        sta     ,y+
        decb
        bne     epun_byte
        ldb     #80
        subb    <blit_width
        leay    b,y                     ; next row
        dec     <blit_height
        bne     epun_row
epun_oob:
        rts

* ---------------------------------------------------------------
* HAL_gfx_blit_scroll  [R-p26 — full-region scroll blit]
*
* Like HAL_gfx_blit_sprite, but targets a 16-bit physical row (0-391)
* in the COMBINED display region ($8000-$FBFF = physical $78000-$7FBFF,
* CPU- and physically-contiguous), with NO 192-row bounds check. Used by
* the scene-4 VOFFSET sliding-window scroll, which renders lines into a
* ~392-row ring buffer spanning both frame buffers (legal: the display is
* single-buffered per R-p25, so both buffers form one scroll region).
*
* Args:    X = sprite ptr (height,width,bitmap)
*          A = destination byte column (0-79; 4px/byte)
*          s4_dest_row ($66, 16-bit) = destination physical row (0-391)
*          blit_subbyte ($0C) = sub-byte offset 0-3 (CALLER sets)
* Returns: CC.C clear. Preserves U. Clobbers A,B,X,Y,CC,$0D/$0E.
*
* dest = $8000 + row*80 + col. row*80 with row<=391 ($187): row_lo*80
* (<=20400) + (row_hi ? 80<<8 : 0). Shares the sub-byte dispatch/row-loops
* with HAL_gfx_blit_sprite (blit_do_sb0..3 above; row stride is #80).
* Caller guarantees row+height <= 392 and col+width(+1) <= 80.
* ---------------------------------------------------------------
HAL_gfx_blit_scroll:
        pshs    u                       ; preserve U per contract
        sta     <blit_col               ; $0A = destination byte column
        lda     ,x+                     ; A = height
        sta     <blit_height
        lda     ,x+                     ; A = width
        sta     <blit_width
        ; Y = $8000 + s4_dest_row*80 + blit_col
        lda     #80
        ldb     <s4_dest_row+1          ; row low byte
        mul                             ; D = row_lo * 80
        ldu     <s4_dest_row            ; U = full 16-bit row (hi:lo)
        cmpu    #256                    ; row >= 256? (hi byte set)
        blo     blit_scroll_base
        addd    #$5000                  ; + (1 * 80) << 8
blit_scroll_base:
        addd    #GFX_FB_A_BASE          ; + $8000 region base
        tfr     d,y
        ldb     <blit_col
        leay    b,y                     ; Y = $8000 + row*80 + col
        ldu     #blit_trans_table_mid   ; U = transparency table midpoint
        lbra    blit_dispatch           ; shared sub-byte dispatch (Y,U set)

* ---------------------------------------------------------------
* blit_trans_table — 256-byte transparency mask lookup table
*
* Maps each possible source byte to its transparency mask:
*   2bpp pixel pair (2 bits) non-zero → mask bits = 11 (replace dest)
*   2bpp pixel pair zero              → mask bits = 00 (preserve dest)
*
* Table layout uses signed-B indexed addressing trick:
*   U = blit_trans_table_mid (= table_base + 128)
*   lda b,u: B $00-$7F (positive) → accesses [mid+0..mid+127] = masks $00-$7F
*            B $80-$FF (negative) → accesses [mid-128..mid-1]  = masks $80-$FF
*
* Physical memory order:
*   Offset 0-127   (blit_trans_table_base): masks for source bytes $80-$FF
*   Offset 128-255 (blit_trans_table_mid):  masks for source bytes $00-$7F
* ---------------------------------------------------------------
blit_trans_table_base:
* Sources $80-$FF (accessed via negative B offset from mid)
        fcb     $C0,$C3,$C3,$C3,$CC,$CF,$CF,$CF,$CC,$CF,$CF,$CF,$CC,$CF,$CF,$CF  ; src $80-$8F
        fcb     $F0,$F3,$F3,$F3,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF  ; src $90-$9F
        fcb     $F0,$F3,$F3,$F3,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF  ; src $A0-$AF
        fcb     $F0,$F3,$F3,$F3,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF  ; src $B0-$BF
        fcb     $C0,$C3,$C3,$C3,$CC,$CF,$CF,$CF,$CC,$CF,$CF,$CF,$CC,$CF,$CF,$CF  ; src $C0-$CF
        fcb     $F0,$F3,$F3,$F3,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF  ; src $D0-$DF
        fcb     $F0,$F3,$F3,$F3,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF  ; src $E0-$EF
        fcb     $F0,$F3,$F3,$F3,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF  ; src $F0-$FF
blit_trans_table_mid:
* Sources $00-$7F (accessed via positive B offset from mid = U base)
        fcb     $00,$03,$03,$03,$0C,$0F,$0F,$0F,$0C,$0F,$0F,$0F,$0C,$0F,$0F,$0F  ; src $00-$0F
        fcb     $30,$33,$33,$33,$3C,$3F,$3F,$3F,$3C,$3F,$3F,$3F,$3C,$3F,$3F,$3F  ; src $10-$1F
        fcb     $30,$33,$33,$33,$3C,$3F,$3F,$3F,$3C,$3F,$3F,$3F,$3C,$3F,$3F,$3F  ; src $20-$2F
        fcb     $30,$33,$33,$33,$3C,$3F,$3F,$3F,$3C,$3F,$3F,$3F,$3C,$3F,$3F,$3F  ; src $30-$3F
        fcb     $C0,$C3,$C3,$C3,$CC,$CF,$CF,$CF,$CC,$CF,$CF,$CF,$CC,$CF,$CF,$CF  ; src $40-$4F
        fcb     $F0,$F3,$F3,$F3,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF  ; src $50-$5F
        fcb     $F0,$F3,$F3,$F3,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF  ; src $60-$6F
        fcb     $F0,$F3,$F3,$F3,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF,$FC,$FF,$FF,$FF  ; src $70-$7F

* ---------------------------------------------------------------
* blit_opaque_table — 256-byte all-$FF mask. Selected (instead of the
* transparency table) by HAL_gfx_blit_sprite_opaque. mask=$FF -> coma=$00 ->
* anda dest = 0 -> ora output = output, i.e. a plain STORE: every pixel incl.
* index-0/black overwrites the dest. Mid at +128 (same signed-offset indexing).
* ---------------------------------------------------------------
blit_opaque_table_base:
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
blit_opaque_table_mid:
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF


                endc                    ; POP_HAL_RUNTIME_BLIT — end dormancy guard
