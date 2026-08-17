* src/engine/intro_splash.s
*
* POP CoCo3 — the first intro screen: the Broderbund splash.
*
* THIS IS THE FIRST ENGINE CODE. Everything before it was probes and kernel. It
* drives the real kernel ABI to put a real converted image on screen.
*
* WHAT IT RENDERS, and why that was a finding rather than a choice (P3.1):
*   The oracle's first displayed screen is PubCredit's splash, traced through
*   MASTER.S FIRSTBOOT -> AttractLoop -> PubCredit. It is DOUBLE hi-res -- 140x192
*   in 16 colours -- NOT the 280x192x4 of gameplay. MASTER.S groups it under a
*   literal "* Double hi-res (stage 1)" header, and SETDHIRES programs ADCOLon +
*   HIRESon + DHIRESon. That is why this uses GFX_MODE_320x192x16.
*   [ref: reports/*-p3-1-first-intro-screen.md]
*
* THE VIRTUAL-RESOLUTION CONTRACT (Jay, governing — every screen, forever):
*   The game is DESIGNED in 280x192. Double-hires content is 140 colour pixels
*   wide and maps 140 -> 280 at its natural 2x, landing in that same 280 space.
*   280 -> 320 hardware is CENTERED: 20 px of border each side. Purely horizontal;
*   rows are 1:1.
*
*   The centring is already baked into the converted asset -- harness/tools/
*   dhr_convert.py emits a full 160-byte-per-row framebuffer with the content at
*   bytes 10..149 and 10 bytes of border each side. One DHR colour pixel is
*   exactly one framebuffer byte (2 px/byte x 2x horizontal), so the mapping is
*   exact: no scaling, no rounding, no dropped columns. This file therefore just
*   copies rows; it does not compute offsets, which is the point -- the contract
*   lives in one place.
*
* BOOT CONTRACT (idioms §21a): the canonical machine-config prefix runs FIRST,
*   before any memory or graphics access. Skipping step 0 is the P2.6 interrupt
*   storm; hand-rolling bring-up is the whole P2.5/P2.6/P2.7 family.
*
* STACK: moved off the draw window before any MMU work. HAL_gfx_set_mode remaps
*   $FFA3-$FFA6 (CPU $6000-$DFFF) and DECB leaves S at about $7F2B, inside it.
*   [ref: src/hal.inc — HAL_gfx_set_mode CALLER REQUIREMENT]
* ---------------------------------------------------------------

                include "src/hal.inc"

                ifdef   OBJTARGET
                section prog
                export  intro_entry
                else
                org     $0200
                endc
                ifdef   OBJTARGET
                * setdp is not permitted for the object target (P2.4).
                else
                setdp   0
                endc

* ---------------------------------------------------------------
STACK_TOP       equ     $7F00           ; BELOW the $8000 draw window (P3.2 moved it)
FB_STRIDE       equ     160             ; 320x192x16: 2 px/byte
SCREEN_ROWS     equ     192
SRC_STRIDE      equ     140             ; 280 virtual px at 4 bits = 140 bytes
LEFT_MARGIN     equ     10              ; 20 px / 2 px-per-byte -> the 280->320 centring
PROBE_MAGIC     equ     $B0DE           ; "Broderbund" done

* ---------------------------------------------------------------
intro_entry     jmp     intro_start     ; $0200 — EXEC address

probe_status    fcb     0               ; $0203  0=not started 1=drawn 2=complete
probe_vres      fcb     0               ; $0204  HAL_gfx_cur_vres
probe_stride    fcb     0               ; $0205  HAL_gfx_cur_stride
probe_magic     fdb     0               ; $0206

* ---------------------------------------------------------------
intro_start
                orcc    #$50            ; mask while we bring the machine up
                lds     #STACK_TOP      ; stack OFF the remapped draw window
                clra
                tfr     a,dp            ; DP = 0

* --- the canonical boot prefix, in order, before anything else ---
                jsr     HAL_sys_init            ; step 0 — PIAs, MMU, all-RAM
                jsr     HAL_mem_size_detect     ; step 1 — discover before allocating
                jsr     HAL_time_init           ; step 2 — $010C VBL handler, VBORD
                andcc   #$EF                    ; opt in to real VBL (E1.c: HAL won't)

* --- the mode the ORACLE uses for this screen, not gameplay's ----
                lda     #GFX_MODE_320x192x16
                jsr     HAL_gfx_set_mode        ; clears both buffers, maps back @ draw_base

* --- the IMAGE's palette, not the mode's diagnostic one ----------
* HAL_gfx_set_mode loads a diagnostic 16-colour palette (P2.5) chosen so the
* colour COUNT is visible. This screen needs the Apple DHR palette the artwork was
* authored against, converted to CoCo3 RGB by dhr_convert.py.
*
* Written from engine code because hal.inc's HAL_gfx_set_palette is still a P3
* STUB (`equ *`). That is a layering compromise and it is flagged, not hidden:
* per-image palettes belong behind the HAL entry once it exists.
*
* MASKED, per idioms §22: sixteen consecutive hardware register writes are a
* multi-register update, and the interrupt context can observe them half-applied.
* Same rule that made gfx_map_blocks a critical section in P2.9.
*
* AFTER the mode registers, never before: palette writes do not latch until
* $FF98/$FF99 hold their final values (HAL_gfx_init Constraint B). set_mode has
* already set them, so this ordering is safe.
                pshs    cc
                orcc    #$50
                ldx     #splash_palette
                ldu     #$FFB0
                ldb     #16
isp_pal
                lda     ,x+
                sta     ,u+
                decb
                bne     isp_pal
                puls    cc

                lda     HAL_gfx_cur_vres
                sta     probe_vres
                lda     HAL_gfx_cur_stride
                sta     probe_stride

* --- draw the splash into the BACK buffer ------------------------
                jsr     blit_splash
                lda     #1
                sta     probe_status

* --- show it ------------------------------------------------------
* HAL_gfx_swap waits for vertical blank, writes VOFFSET, then maps the other buffer
* in. Drawing into BOTH halves keeps the picture stable whichever is displayed.
                jsr     HAL_gfx_swap
                jsr     blit_splash

                lda     #2
                sta     probe_status
                ldd     #PROBE_MAGIC
                std     probe_magic

intro_hold      bra     intro_hold      ; hold the screen; harness/Jay observe here

* ---------------------------------------------------------------
* blit_splash — copy the packed asset into the back buffer, CENTERED.
*
* THE VIRTUAL-RESOLUTION CONTRACT LIVES HERE, and under the DISPLAY-faithful asset
* it collapses to a straight copy. A source row is 140 bytes = 280 virtual pixels at
* 4 bits; the CoCo3 16-colour mode packs 2 pixels per byte, so 280 virtual pixels are
* also 140 framebuffer bytes. The row lands on framebuffer bytes LEFT_MARGIN..
* LEFT_MARGIN+139 -- the +20 px centring -- with no expansion and no rounding.
*
* (The earlier DATA-faithful asset held 140 colour pixels doubled to 280 and needed a
* nibble expand. The display-faithful asset carries 280 DISTINCT pixels, because the
* NTSC fringing it reproduces lives BETWEEN the data's colour pixels -- there is no
* room for it at 140.)
*
* The margins are not written: HAL_gfx_set_mode cleared both buffers, so they already
* hold the background index.
* Clobbers: A, B, X, Y, U, CC
* ---------------------------------------------------------------
blit_splash
                ldx     #splash_data
                ldu     HAL_gfx_draw_base
                leau    LEFT_MARGIN,u           ; +20 px: the 280 -> 320 centring
                ldy     #SCREEN_ROWS
bs_row
                pshs    y
                ldy     #SRC_STRIDE/2           ; 140 bytes = 70 word moves
bs_px
                ldd     ,x++
                std     ,u++
                leay    -1,y
                bne     bs_px
                leau    (FB_STRIDE-SRC_STRIDE),u    ; skip both margins
                puls    y
                leay    -1,y
                bne     bs_row
                rts

* ---------------------------------------------------------------
* The converted splash: a full CoCo3 320x192x16 framebuffer, 30,720 bytes,
* content centered at bytes 10..149 of each 160-byte row.
*
* Source: the RUNNING oracle's unpacked double-hires page 1 (MAIN+AUX banks,
* dumped at the frame Jay identified as the Broderbund screen), converted by
* harness/tools/dhr_convert.py. POP's crunch decompressor was never ported --
* letting the game unpack and dumping the result is both cheaper and, per
* CLAUDE.md §2, the higher authority.
* ---------------------------------------------------------------
splash_palette
                includebin "content/intro/broderbund_splash.pal"

splash_data
                includebin "content/intro/broderbund_splash.bin"

                ifdef   OBJTARGET
                endsection
                else
                end     intro_entry
                endc
