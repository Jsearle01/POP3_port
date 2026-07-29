* src/engine/char_draw.s
*
* POP CoCo3 — PIECE D's character draw, DISK-RESIDENT (P3.22).
*
* ---------------------------------------------------------------
* WHY THIS IS NOT IN ROOM.BIN
* ---------------------------------------------------------------
* The LOADM ceiling, for the third time. P3.20 hit it twice (the cels + peel
* buffers, then the blit core); P3.22 hit it with this code and PROVED the cause is
* SIZE ALONE: the green baseline plus 175 bytes of dead `rmb` — no code, no new
* logic — reproduces the failure exactly, with probe_status reading $40 and no disk
* reads at all. Jay identified it on sight.
*
* MEASURED BOUND, and it is LOWER than the documented one. link/pop_engine.link says
* a LOADM'd engine must stay under $25FF. Measured here:
*     prog ending $2487  -> boots, 8/8            (the green baseline)
*     prog ending $2535  -> image corrupted        (baseline + 175 B of filler)
* so the real ceiling is ~174 bytes below the documented figure, somewhere in
* $2488-$2535. The documented $25FF is optimistic and should not be trusted as
* headroom. [P3.22 §3B]
*
* ---------------------------------------------------------------
* HOW IT REACHES WHAT IT NEEDS
* ---------------------------------------------------------------
* This bundle links without the HAL, so the two HAL values are passed as ARGUMENTS
* rather than resolved by the linker:
*
*     chars_frame:  A = which buffer is being drawn (0/1),  X = its base address
*
* Everything else is either a constant or lives in this same object — including the
* baked cel data, which means the cel pointers are resolved at link time and the
* run-time patching P3.20 needed is gone.
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                export  chars_frame
                endc

FB_STRIDE_4C    equ     80              ; 320 px at 4 px/byte
FLAME_BASE      equ     $4200

* ---------------------------------------------------------------
* PIECE D — THE CHARACTER DRAW, exercised by HARDCODED position.
*
* No VM, no sequence data: the cel and its (x,y) are written here by hand, which is
* the whole point of building D before C. The draw path is the high-risk piece and
* it is independently testable; the VM has nothing to call until it works.
*
* PLACEMENT, from the oracle:
*   startV0  CharX=197, startP0 CharX=120        [SUBS.S:1131,1147]
*   floorY = 151, and CharY is the BASELINE       [SUBS.S:1040]
* so a cel's top row is floorY - height + 1, the same convention P3.17 confirmed
* for the torches (a 13-row flame ending at 113 starts at 101).
*
* The +20 px centring makes CoCo x = oracle x + 20. 20 is a multiple of 4, so it
* does NOT change the sub-byte phase — the vizier is phase 1 at 197 and still
* phase 1 at 217, which is the phase baked into vstand.s.
*
*   vizier   px 217 -> byte 54, phase 1, 48 rows -> top 104
*   princess px 140 -> byte 35, phase 0, 43 rows -> top 109
*
* PEEL IS PER BUFFER. The page flips every frame, so each character needs its own
* saved background IN EACH BUFFER -- the same slot discipline the flames already
* use, and for the same reason: an erase must restore what was saved INTO THAT
* buffer, not into its twin. Four slots, two per character.
* ---------------------------------------------------------------
* RETIRED at P3.22: VIZ_TOP/VIZ_COL/PRI_TOP/PRI_COL were precomputed placement.
* The slot records carry x=197 / x=120 and y=151 now, and co_setup derives top and
* col from them, because chx mutates x and a precomputed offset cannot be mutated.
* The derivation was cross-checked to reproduce the retired numbers exactly:
*   x=197 y=151 h=48 -> top 104 col 54 phase 1
*   x=120 y=151 h=43 -> top 109 col 35 phase 0
VIZ_PEEL        equ     48*5            ; 240 B — rows x width of the baked cel
PRI_PEEL        equ     43*5            ; 215 B
* PEEL BUFFERS AND CEL DATA LIVE OUTSIDE ROOM.BIN.
* Both were briefly inside it, and that is what broke LOADM: `prog` reached ~$2E70,
* the first segment loaded, and $7900 stayed $FF -- the kernel segment never
* arrived. link/pop_flames.link already documents the rule ("a LOADM'd engine must
* stay under $25FF"); this is the same wall, hit from the other side.
*
* The cels ride the flame track (char_tab at FLAME_BASE+54). The peel buffers are
* just scratch RAM and need no load at all, so they are fixed addresses in the
* free space above the blob.
CHAR_TAB        equ     FLAME_BASE+54
BLIT_TAB        equ     FLAME_BASE+58   ; blit_cel / blit_save / blit_erase
* MOVED at P3.25: the peel buffers were at $5200, which is inside the two-track
* bundle's new extent ($4200..$65FF). $6C00 is clear of the bundle, of the disk
* parameter block at $6A00, and of the trace ring at $7800.
VIZ_PEEL_BASE   equ     $6C00
PRI_PEEL_BASE   equ     $6C00+VIZ_PEEL*2

* ---------------------------------------------------------------
* PIECE D — THE CHARACTER DRAW, and the seed of the VM's character slots.
*
* Still exercised by HARDCODED state: nothing here reads sequence data. But the
* STATE is shaped for piece C to adopt rather than to tear out. POP's engine keeps
* CharID / CharX / CharY / CharFace per character and the VM's chx/chy opcodes
* mutate X and Y [P3.16; SUBS.S:1131,1147]. So a slot record is X/Y-BASED.
*
* IT IS DELIBERATELY NOT A PRECOMPUTED FRAMEBUFFER OFFSET, which is what P3.20 used.
* An offset cannot be mutated by chx without being recomputed, so C would have had
* to replace it on its first day. Computing the offset per frame costs one `mul`
* (11 cy) and makes `chx` a one-byte add.
*
*   +0  x       oracle pixel x        <- chx mutates this
*   +1  y       BASELINE row          <- chy mutates this  [floorY=151, SUBS.S:1040]
*   +2  face    +1 / -1               <- aboutface flips this; unused by D
*   +3  cel     cel id                <- C indexes the cel table with this
*   +4  h       rows
*   +5  w       width in bytes
*   +6  ptr     2 B  resolved cel data address (patched from char_tab at startup)
*   +8  peel    2 B  peel base for slot 0; slot 1 sits at +h*w
*
* WHAT IS DELIBERATELY *NOT* IN THE RECORD: where each buffer last drew this
* character. That is double-buffer bookkeeping, not character state — POP's model is
* cel/x/y/facing and nothing else — so it lives in ch_last[] on the renderer side,
* indexed by (character, slot). Keeping it out leaves the record exactly the shape C
* adopts, and cost ~90 bytes less code, which mattered: the first version put it in
* the record and pushed `prog` 8 bytes past the $25FF LOADM ceiling.
*
* Cross-checked against P3.20's hand-computed constants: x=197,y=151,h=48 gives
* top 104 col 54 phase 1, and x=120,y=151,h=43 gives top 109 col 35 phase 0 —
* exactly VIZ_TOP/VIZ_COL and PRI_TOP/PRI_COL. The record reproduces the placement
* it replaces.
* ---------------------------------------------------------------
CH_X            equ     0
CH_Y            equ     1
CH_FACE         equ     2
CH_CEL          equ     3
CH_H            equ     4
CH_W            equ     5
CH_PTR          equ     6
CH_PEEL         equ     8
CH_SIZE         equ     10

* Motion step. MUST be a multiple of 4 px: the phase is baked into the cel data
* (P3.19/P3.20), so moving by anything else would need the phase variant for the
* new column and there is exactly one baked cel per character here. 8 px = two byte
* columns. Sub-byte motion is piece E's problem, not a limitation of the blitter.
CH_STEP         equ     8

chars_frame
                stx     ch_base                 ; X = the draw buffer's address
                anda    #1                      ; A = which buffer
                sta     ch_slot

* --- MOVE the vizier, slowly, so the peel's moving case is actually exercised ---
* P3.21 found the move path had never run: the position was a constant in the
* descriptor and the column variable it computed was dead. Now the step writes the
* record's x, which is what the draw reads.
                inc     ch_tick
                lda     ch_tick
                anda    #$3F
                bne     cf_nomove
                lda     ch_dir
                nega                            ; +8 <-> -8
                sta     ch_dir
cf_nomove
                lda     ch_tick
                anda    #$1F
                bne     cf_draw
                ldx     #viz_slot
                lda     CH_X,x
                adda    ch_dir
                sta     CH_X,x

cf_draw
                clr     ch_idx
                ldx     #viz_slot
                jsr     char_one
                lda     #1
                sta     ch_idx
                ldx     #pri_slot
                jsr     char_one
                rts

* ---------------------------------------------------------------
* char_one — draw one character from its slot record, peeling ONLY if it moved.
*
*   X -> slot record.  Uses ch_rec as the authority for the record pointer because
*   blit_cel clobbers X (and blit_blast clobbers A,B,D,Y — only X is preserved,
*   which is what P3.20's Bug 1 got wrong by keeping the peel pointer in Y).
*
* WHY SKIPPING THE PEEL IS SAFE WHEN NOTHING MOVED. The background under a static
* character never changes, so there is nothing to restore; and the masked merge is
* IDEMPOTENT, so redrawing in place over its own previous pixels lands the same
* bytes:
*
*     ((d AND m) OR s) AND m) OR s  ==  (d AND m) OR s        because s AND m == 0
*
* (the baker sets mask bits only where the source pixels are 0, so s AND m is zero
* by construction — cel_blit_prep.encode_row). P3.21 measured the consequence: the
* two-character draw with full peel needs two frames (10.0 Hz), and draw-only fits
* in one (20.0 Hz). The peel was redundant work, not slow work.
* ---------------------------------------------------------------
char_one
                stx     ch_rec
                lda     CH_H,x
                sta     ch_h
                lda     CH_W,x
                sta     ch_w

* ch_last[] index = character*4 + slot*2  (two slots, an x/y pair each)
                lda     ch_idx
                lsla
                lsla
                adda    ch_slot
                adda    ch_slot
                sta     ch_lastoff
* FOUR seen bits, not two: one per (character, slot). Keying on the slot alone would
* make character 0 and character 1 share a bit, so the second character would
* inherit the first's "background already saved" and skip a save it needed.
                lda     ch_idx
                lsla
                adda    ch_slot
                ldx     #ch_bits
                lda     a,x
                sta     ch_bit

* --- did the character move since THIS buffer last drew it? ---------------
                ldy     #ch_last
                lda     ch_lastoff
                ldx     ch_rec
                ldb     a,y                     ; last x for this (char, slot)
                cmpb    CH_X,x
                bne     co_moved
                inca
                ldb     a,y                     ; last y
                cmpb    CH_Y,x
                beq     co_static
co_moved
                lda     #1
                bra     co_setmove
co_static
                clra
co_setmove
                sta     ch_move

* --- ERASE at the OLD position, if this buffer has one and we moved ------
* The erase must restore where the character WAS in this buffer, not where it is
* going. P3.20 erased at the new position, which is only harmless while nothing
* moves — and nothing did, because its move path was dead (P3.21 found that).
                tsta
                beq     co_draw                 ; static: no erase, no save
                lda     ch_bit
                anda    ch_seen
                beq     co_save                 ; this buffer has saved nothing yet
                ldy     #ch_last
                lda     ch_lastoff
                ldb     a,y
                stb     ch_tx                   ; old x
                inca
                ldb     a,y
                stb     ch_ty                   ; old y
                jsr     co_setup
                ldx     ch_dest
                ldy     ch_peel
                lda     ch_h
                ldb     ch_w
                jsr     [BLIT_TAB+4]            ; blit_erase (preserves X,Y,U)

co_save
* --- SAVE the background at the NEW position, and record it --------------
                jsr     co_here                 ; ch_tx/ch_ty := the record's x,y
                jsr     co_setup
                ldx     ch_dest
                ldy     ch_peel
                lda     ch_h
                ldb     ch_w
                jsr     [BLIT_TAB+2]            ; blit_save
                ldy     #ch_last
                lda     ch_lastoff
                ldb     ch_tx
                stb     a,y
                inca
                ldb     ch_ty
                stb     a,y
                lda     ch_seen
                ora     ch_bit
                sta     ch_seen

co_draw
* --- DRAW, always -------------------------------------------------------
                jsr     co_here
                jsr     co_setup
                ldx     ch_rec
                ldu     CH_PTR,x                ; the baked cel
                ldx     ch_dest
                jsr     [BLIT_TAB]              ; blit_cel — clobbers X and Y
                rts

* co_here — ch_tx/ch_ty := this record's current x,y
co_here
                ldx     ch_rec
                lda     CH_X,x
                sta     ch_tx
                lda     CH_Y,x
                sta     ch_ty
                rts

* ---------------------------------------------------------------
* co_setup — from ch_tx / ch_ty / ch_h, compute ch_dest and ch_peel.
*
*   col = (x + 20) / 4        the 280->320 centring is +20 px, a multiple of 4, so
*                             it does not change the sub-byte phase
*   top = y - h + 1           CharY is the BASELINE, as P3.17 confirmed for the
*                             torches (a 13-row flame ending at 113 starts at 101)
*   dest = draw_base + top*80 + col
*   peel = peel_base + slot*(h*w)
* ---------------------------------------------------------------
co_setup
                lda     ch_ty
                suba    ch_h
                inca                            ; top = y - h + 1
                ldb     #FB_STRIDE_4C
                mul                             ; D = top * 80
                std     ch_tmp16
                lda     ch_tx
                adda    #20                     ; the centring
                lsra
                lsra                            ; col = (x+20)/4
                tfr     a,b
                clra
                addd    ch_tmp16
                addd    ch_base
                std     ch_dest

                ldx     ch_rec
                ldd     CH_PEEL,x
                std     ch_peel
                lda     ch_slot
                beq     cs_done
                lda     ch_h
                ldb     ch_w
                mul                             ; one slot's footprint
                addd    ch_peel
                std     ch_peel
cs_done
                rts

* --- the baked cels: segment streams for the runtime blitter, from
* --- harness/tools/cel_blit_prep.py. Data, not compiled sprites.
                include "content/cutscene/chars/vstand.s"
                include "content/cutscene/chars/pstand.s"

* --- the two slots, initialised from the oracle's own start positions ----
* startV0 CharX=197, startP0 CharX=120, both CharFace=-1, floorY=151
* [SUBS.S:1131,1147,1040]. These remain the authority for where they stand.
viz_slot        fcb     197,151,-1,54           ; x, y, face, cel id (chtab6.A #54)
                fcb     48,5                    ; h, w
                fdb     vstand                  ; resolved at link time now
                fdb     VIZ_PEEL_BASE
pri_slot        fcb     120,151,-1,25           ; x, y, face, cel id (chtab6.A #25)
                fcb     43,5
                fdb     pstand
                fdb     PRI_PEEL_BASE

ch_base         fdb     0
ch_slot         fcb     0
ch_idx          fcb     0
ch_bit          fcb     0
ch_seen         fcb     0               ; bit per (character,slot): background saved?
ch_move         fcb     0
ch_lastoff      fcb     0
* Renderer-side, NOT character state: where each buffer last drew each character.
* Two characters x two slots x (x,y).
ch_last         fcb     0,0,0,0,0,0,0,0
ch_bits         fcb     1,2,4,8         ; seen bit for (character, slot)
ch_tick         fcb     0
ch_dir          fcb     CH_STEP
ch_tx           fcb     0
ch_ty           fcb     0
ch_h            fcb     0
ch_w            fcb     0
ch_tmp          fcb     0
ch_rec          fdb     0
ch_dest         fdb     0
ch_peel         fdb     0
ch_tmp16        fdb     0

