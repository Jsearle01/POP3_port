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
* PEEL BUFFERS ARE SIZED TO EACH CHARACTER'S WIDEST CEL, not to the one currently
* drawn. They were sized to the single baked cel (48x5 and 43x5), which is correct
* only while the cel never changes — and the VM's whole job is changing it. Measured
* across the cutscene set, converting each cel at its own parity and allowing the one
* byte a sub-byte phase adds:
*
*     vizier   widest 48 x 10 = 480 B   (cel 62, vturn-10)
*     princess widest 43 x  8 = 344 B   (cel 7,  pturn-9)
*
* Undersized peels do not fail loudly: save writes past its buffer into whatever
* follows, and erase restores garbage. Sizing them here is a Phase 3 prerequisite
* that would otherwise have been found by corruption.
VIZ_PEEL        equ     48*10           ; 480 B — widest vizier cel (62)
PRI_PEEL        equ     43*8            ; 344 B — widest princess cel (7)
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
*   viz 2 slots x 480 = 960 B   $6C00..$6FBF
*   pri 2 slots x 344 = 688 B   $6FC0..$727F
* 1,648 B total, ending well short of the trace ring.
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
*   +8  peel    2 B  peel base for slot 0; slot 1 sits at +PEEL (the widest cel)
*  +11  stride  2 B  the peel SLOT STRIDE — a constant, the character's widest cel.
*
*               IT CANNOT BE h*w OF THE CURRENT CEL, and that was a real bug. Slot 1's
*               peel lives at base + stride; if the stride is computed from whatever
*               cel is loaded, a save at w=6 writes at +258 while the following erase
*               at w=5 reads at +215 — a different address, so the erase restores
*               bytes that were never saved. It showed as exactly 32 wrong pixels that
*               appeared only when the VM stepped, and vanished entirely when the VM
*               was frozen. Sizing the BUFFER to the widest cel (P3.25) was necessary
*               and not sufficient; the STRIDE has to be constant too.
*
*  +10  fdx     the frame's own x offset, signed — ALTSET2's Fdx. The cel table
*               carries it per cel (-1..5 across the cutscene set) and the VM writes
*               it here when it selects a cel. Zero for every cel drawn so far, so
*               applying it is currently a no-op — but a cel with Fdx=3 drawn without
*               it lands three pixels off, and P3.24 flagged that.
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
CH_FDX          equ     10              ; per-frame x offset, from the cel table
CH_STRIDE       equ     11              ; 2 B — constant peel slot stride
CH_PTR          equ     6
CH_PEEL         equ     8
CH_SIZE         equ     13

* Motion step. MUST be a multiple of 4 px: the phase is baked into the cel data
* (P3.19/P3.20), so moving by anything else would need the phase variant for the
* new column and there is exactly one baked cel per character here. 8 px = two byte
* columns. Sub-byte motion is piece E's problem, not a limitation of the blitter.
CH_STEP         equ     8

chars_frame
                stu     vm_now                  ; U = the HAL's real frame count
                stx     ch_base                 ; X = the draw buffer's address
                anda    #1                      ; A = which buffer
                sta     ch_slot

* TWO PHASES, KEPT DISTINCT AS THE ORACLE HAS THEM [FRAMEADV.S]. NextFrame DECIDES --
* it runs the cadence and, on a step boundary, advances each character's sequence and
* sets its cel/x/y. FrameAdv DRAWS what was decided. Collapsing them would let a
* position change part-way through a frame's drawing, and the peel would then restore
* against a position that no longer matches.
* Point each character at its sequence, once. A lazy check rather than an init entry
* point because the room calls straight into here and has no other hook; vm_seq is
* zero until this runs, and vm_step treats a zero stream as "nothing to advance".
                ldd     vm_seq
                bne     cf_running
                ldu     #viz_demo
                stu     vm_seq
                ldu     #pri_demo
                stu     vm_seq+2
cf_running
                jsr     vm_nextframe            ; decide
                jsr     vm_frameadv             ; draw
                rts

* vm_frameadv — the DRAW half: the gated D path, once per character.
vm_frameadv
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

* ch_last[] index = (character*2 + slot) * 4  — four bytes: x, y, w, h
                lda     ch_idx
                lsla
                adda    ch_slot
                lsla
                lsla
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
                lbeq    co_draw                 ; static: no erase, no save (long — the
                                                ; erase block below grew past a short
                                                ; branch's reach)
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
                inca
                ldb     a,y
                stb     ch_w                    ; the width it was SAVED with
                inca
                ldb     a,y
                stb     ch_h                    ; and the height
                clr     ch_fdx                  ; the old position already included it
                jsr     co_setup
                ldx     ch_dest
                ldy     ch_peel
                lda     ch_h
                ldb     ch_w
                jsr     [BLIT_TAB+4]            ; blit_erase (preserves X,Y,U)
* Put the CURRENT cel's dimensions back: the save and draw below are the new cel's.
                ldx     ch_rec
                lda     CH_H,x
                sta     ch_h
                lda     CH_W,x
                sta     ch_w

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
                inca
                ldb     ch_w                    ; remember the extent, not just where
                stb     a,y
                inca
                ldb     ch_h
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

* RECORD WHAT WAS ACTUALLY DRAWN INTO THIS BUFFER, for the checker to read.
*
* The pixel check used to read CH_CEL from the slot record at CAPTURE time, but the
* buffer being captured was drawn a FRAME EARLIER and may still hold the previous
* cel — so the check compared this frame's cel against last frame's pixels. That is
* the fourth variant of one mistake in this project (assume the position, assume the
* input provenance, assume the cel, assume the cel is CURRENT): a checker that
* assumes any part of the state it checks cannot tell "wrong" from "changed".
*
* Indexed by (character, slot) because each buffer holds its own last-drawn cel.
                ldx     ch_rec
                lda     CH_CEL,x
                ldb     ch_idx
                lslb
                addb    ch_slot
                ldx     #ch_drawn
                stb     ch_tmp
                ldb     ch_tmp
                sta     b,x
                rts

* co_here — ch_tx/ch_ty := this record's current x,y
co_here
                ldx     ch_rec
                lda     CH_X,x
                sta     ch_tx
                lda     CH_Y,x
                sta     ch_ty
                lda     CH_FDX,x
                sta     ch_fdx
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
                adda    ch_fdx                  ; the frame's own offset (signed)
                adda    #20                     ; the centring
                lsra
                lsra                            ; col = (x + Fdx + 20)/4
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
                ldd     CH_STRIDE,x             ; the CONSTANT slot stride
                addd    ch_peel
                std     ch_peel
cs_done
                rts


* ---------------------------------------------------------------
* PIECE C — THE SEQUENCE INTERPRETER (the animation engine).
*
* The cutscene is DATA over this, not a subsystem (P3.16). A sequence is a byte
* stream where a POSITIVE byte is a cel number and a NEGATIVE byte is an opcode
* [SEQTABLE.S]. `Vwalk1 db 48,chx,2` reads literally: cel 48, then move x by 2.
*
* OPCODES PRECEDE THE CEL THEY AFFECT. `Vwalk db chx,1` / `Vwalk1 db 48,chx,2`
* means entering Vwalk applies chx 1 and THEN draws 48; the chx 2 after 48 applies
* before 49. So a step consumes opcodes until it reaches a cel, sets that cel, and
* returns -- one cel per animation step, which is what `play` does per iteration.
*
* IT MUTATES THE P3.22 SLOT RECORDS. There is no parallel state: cel/x/y/facing live
* in the record the draw path already reads, which is why P3.22 shaped it that way.
* ---------------------------------------------------------------
SEQ_GOTO        equ     $FF             ; goto      = -1, followed by a 2-byte target
SEQ_ABOUTFACE   equ     $FE             ; aboutface = -2
SEQ_CHX         equ     $FB             ; chx       = -5, signed operand
SEQ_CHY         equ     $FA             ; chy       = -6, signed operand
SEQ_SETFALL     equ     $F8             ; setfall   = -8, operand consumed unused

* ---------------------------------------------------------------
* PACING POLICY: "FLOOR AT SPEED, OVERRUN NATURALLY"  (Jay, P3.27)
* ---------------------------------------------------------------
* The cadence table is a MINIMUM, not a target. A step waits at least its listed
* frames; if the draw takes longer, the step takes longer. Nothing clamps the rate.
*
* THIS PORTS THE MECHANISM, NOT EITHER MEASURED NUMBER. The oracle's `play` does
* `lda SPEED / jsr pause` [SUBS.S:876-881] -- a minimum delay -- so its observed rate
* is that floor plus whatever its draw overran by. Measured (P3.26): 2.6 frames/step
* with characters static, 3.9 with them animating. The 3.9 is not a pace it aimed at;
* it is a 6502 draw against a 2.6-frame floor.
*
* WHY NOT MATCH THE 3.9. Hard-coding it would mean inserting delay to reproduce the
* Apple's inability to keep up -- porting a limitation as if it were a design. It also
* would not generalise: gameplay load varies by room and actor count, so one scene's
* Apple-specific draw cost is the wrong constant everywhere else.
*
* CLAUDE.md §2 -- "trace wins on fact; source wins on intent". This chooses INTENT for
* the floor (SPEED 7 means 2.6 frames) and lets the achieved rate be an observed
* consequence of OUR draw cost, exactly as 3.9 was a consequence of the oracle's.
*
* ACKNOWLEDGED COST: ~1.4x the oracle's animated rate (21.9 vs 15.6 Hz at the floor).
* Faster than the original ran this motion. REVISITABLE BY EYE (Jay's caveat) -- if it
* looks wrong side by side with the oracle, the policy changes, not the measurement.
*
* Applies to E-H and the demo. Not to be re-litigated per scene.
* ---------------------------------------------------------------

* --- THE CADENCE, from P3.23's measurement -------------------------------
* Frame counts transfer 1:1 (CoCo3 16.683 ms vs Apple 16.688 ms, 0.03% apart), so a
* SPEED expressed in Apple frames is the same integer here. SPEED 7 is 2.6 frames:
* a constant 3 runs +15.3% slow, which IS the 20.0-vs-22.8 Hz gap carried since
* P3.17. A 13/5 cadence lands within 0.01 ms of the oracle AND reproduces its own
* measured 2-3 frame spread instead of flattening it.
cad_tab         fcb     3,3,2,3,2       ; 13 frames over 5 steps = 2.6
CAD_LEN         equ     5
cad_idx         fcb     0
vm_now          fdb     0               ; the HAL's frame count, handed in per call
vm_due          fdb     0               ; the frame this step is due to fire on

* --- image index -> the baked cel that holds it --------------------------
* Only the cels actually baked can be drawn. The cel TABLE covers all 49, but baking
* the rest needs the per-cel parity conversion volume, which is E's scope. A cel
* whose image is not here leaves the slot showing what it had -- visible as a stall,
* not as a crash.
img_map         fcb     10
                fdb     pslump
                fcb     25
                fdb     pstand
                fcb     80
                fdb     vstand
                fcb     0               ; terminator

vm_seq          fdb     0,0             ; sequence pointer per character
vm_rec          fdb     0
vm_img          fcb     0

* ---------------------------------------------------------------
* vm_resolve — cel number in A -> the record's cel fields.
*
* Resolves through the generated table (image index, Fdx, Fdy, parity) exactly as
* getfindex/getaltframe2 do, then maps the image index to a baked cel and takes h/w
* from that cel's own header so the peel extent always matches what will be drawn.
*   Preserves U (the caller's sequence pointer).
* ---------------------------------------------------------------
vm_resolve
                pshs    u
                ldu     vm_rec
                sta     CH_CEL,u                ; remember the cel number
                suba    #CEL_LO
                ldb     #CEL_ENTSZ
                mul                             ; D = offset into the table
                ldx     #cel_table
                leax    d,x
                lda     ,x                      ; image index
                sta     vm_img
                lda     1,x                     ; Fdx, signed
                sta     CH_FDX,u

                ldx     #img_map
vr_find
                lda     ,x
                beq     vr_done                 ; not baked — leave the slot as it was
                cmpa    vm_img
                beq     vr_found
                leax    3,x
                bra     vr_find
vr_found
                ldd     1,x                     ; the baked cel's address
                std     CH_PTR,u
                tfr     d,x
                lda     ,x                      ; the cel's own header: rows, width
                sta     CH_H,u
                lda     1,x
                sta     CH_W,u
vr_done
                puls    u
                rts

* ---------------------------------------------------------------
* vm_step — advance ONE character's sequence by one animation step.
*   X -> slot record, ch_idx = character index.
* ---------------------------------------------------------------
vm_step
                stx     vm_rec
                lda     ch_idx
                lsla
                ldx     #vm_seq
                ldu     a,x                     ; U = this character's stream position
                cmpu    #0
                beq     vs_none                 ; no sequence assigned
vs_loop
                lda     ,u+
                bpl     vs_cel                  ; positive = a cel number
                cmpa    #SEQ_GOTO
                beq     vs_goto
                cmpa    #SEQ_ABOUTFACE
                beq     vs_face
                cmpa    #SEQ_CHX
                beq     vs_chx
                cmpa    #SEQ_CHY
                beq     vs_chy
                leau    1,u                     ; setfall and friends: skip the operand
                bra     vs_loop

vs_goto
                ldu     ,u                      ; the 2-byte target replaces the pointer
                bra     vs_loop

vs_face
* aboutface flips CharFace — AND THEREFORE THE REQUIRED PARITY, because the rule is
* bit7(Fcheck) == bit7(CharFace) (P3.24). The cels baked here carry ONE parity, the
* one for CharFace=-1, so a turn would need the opposite variant of every cel drawn
* after it. The flip is implemented because the VM must not silently drop an opcode;
* the parity consequence is DEFERRED to G (the turn), and this is the note P3.24
* asked for rather than an assumption buried in code.
                ldx     vm_rec
                lda     CH_FACE,x
                nega
                sta     CH_FACE,x
                bra     vs_loop

vs_chx
                lda     ,u+                     ; signed delta
                ldx     vm_rec
                ldb     CH_FACE,x
                bpl     vs_chx_add              ; facing right: add as-is
                nega                            ; facing left: the delta is mirrored
vs_chx_add
                adda    CH_X,x
                sta     CH_X,x
                bra     vs_loop

vs_chy
                lda     ,u+
                ldx     vm_rec
                adda    CH_Y,x
                sta     CH_Y,x
                bra     vs_loop

vs_cel
                jsr     vm_resolve              ; A = cel number; preserves U
                lda     ch_idx
                lsla
                ldx     #vm_seq
                stu     a,x                     ; remember where we stopped
vs_none
                rts

* ---------------------------------------------------------------
* vm_nextframe — the DECIDE half. Runs the cadence; on a step boundary it advances
* both characters' sequences. Nothing here draws.
* ---------------------------------------------------------------
* PACED OFF REAL VBLs. The old version decremented a counter once per call, which
* is once per LOOP ITERATION -- and P3.25 measured 0.84 iterations per video frame,
* so a 2.60-iteration step took 3.09 frames. The table was always in the right unit;
* the counter was not. Comparing against the HAL's frame count makes a step take the
* frames it says regardless of how long an iteration costs.
*
* Signed 16-bit compare, so it is correct until the counter passes $7FFF -- about
* nine minutes at 60 Hz. Fine for a cutscene, noted rather than assumed away.
vm_nextframe
                ldd     vm_now
                subd    vm_due
                bmi     vn_hold                 ; this step's frames have not elapsed
                lda     cad_idx                 ; next entry in the 3,3,2,3,2 cycle
                inca
                cmpa    #CAD_LEN
                blo     vn_wrap
                clra
vn_wrap
                sta     cad_idx
                ldx     #cad_tab
                lda     a,x                     ; frames this step should last
                tfr     a,b
                clra                            ; D = that count, zero-extended
                addd    vm_now
                std     vm_due                  ; fire again at now + count

                clr     ch_idx                  ; step both characters
                ldx     #viz_slot
                jsr     vm_step
                lda     #1
                sta     ch_idx
                ldx     #pri_slot
                jsr     vm_step
vn_hold
                rts

* ---------------------------------------------------------------
* vm_start — point a character at a sequence.
*   X -> slot record's sequence entry index in A, U = the stream.
* ---------------------------------------------------------------
vm_start
                lsla
                ldx     #vm_seq
                stu     a,x
                rts

* --- the demonstration sequence, and why it is this one ------------------
* The dispatch asked for Vstand holding then a short Vwalk. VWALK CANNOT RUN YET: its
* cels (48-53) are not baked, and baking them needs the per-cel parity conversion
* volume that is E's scope. So the proof uses the cels that ARE baked -- and it still
* exercises every opcode the interpreter implements except aboutface (see vs_face):
* cel bytes, chx in both directions, and goto looping.
*
* The princess stands, steps 8 px, slumps, steps back, and repeats. 8 px keeps her on
* one sub-byte phase, which one baked cel can serve; sub-byte steps need the phase
* variants and are piece E.
pri_demo        fcb     11,11,11,11             ; Pstand's cel, four steps
                fcb     SEQ_CHX,8               ; step right 8 px (mirrored by face)
                fcb     1,1,1,1                 ; Pslump's cel
                fcb     SEQ_CHX,-8              ; and back
                fcb     SEQ_GOTO
                fdb     pri_demo

* The vizier holds Vstand, driven by the VM rather than by a hardcoded call — which
* is the point: his cel now comes from data too.
viz_demo        fcb     54
                fcb     SEQ_GOTO
                fdb     viz_demo

* --- the VM's cel-id table, generated from ALTSET2 ---------------------
                include "content/cutscene/cel_table.s"

* --- the baked cels: segment streams for the runtime blitter, from
* --- harness/tools/cel_blit_prep.py. Data, not compiled sprites.
                include "content/cutscene/chars/vstand.s"
                include "content/cutscene/chars/pstand.s"
                include "content/cutscene/chars/pslump.s"

* --- the two slots, initialised from the oracle's own start positions ----
* startV0 CharX=197, startP0 CharX=120, both CharFace=-1, floorY=151
* [SUBS.S:1131,1147,1040]. These remain the authority for where they stand.
viz_slot        fcb     197,151,-1,54           ; x, y, face, cel id (chtab6.A #54)
                fcb     48,5                    ; h, w
                fdb     vstand                  ; resolved at link time now
                fdb     VIZ_PEEL_BASE
                fcb     0                       ; Fdx — the VM writes this per cel
                fdb     VIZ_PEEL                ; slot stride: widest vizier cel
pri_slot        fcb     120,151,-1,25           ; x, y, face, cel id (chtab6.A #25)
                fcb     43,5
                fdb     pstand
                fdb     PRI_PEEL_BASE
                fcb     0                       ; Fdx
                fdb     PRI_PEEL                ; slot stride: widest princess cel

ch_base         fdb     0
ch_slot         fcb     0
ch_idx          fcb     0
ch_bit          fcb     0
ch_seen         fcb     0               ; bit per (character,slot): background saved?
ch_move         fcb     0
ch_lastoff      fcb     0
* Renderer-side, NOT character state: what each buffer last drew for each character —
* x, y, WIDTH and HEIGHT. Two characters x two slots x 4 bytes.
*
* THE DIMENSIONS ARE HERE BECAUSE THE VM CHANGES THEM. A peel must be erased with the
* extent it was SAVED with; once an interpreter switches cels, the record's current
* w/h belong to the NEW cel. Erasing pstand's 43x5 save with pslump's 43x6 restored a
* column that was never saved — visible as $AA, the uninitialised-peel signature, and
* as captures that disagreed because the error accumulated. Found the moment the VM
* first switched a cel, which is what D's checks could not reach on a fixed cel.
ch_last         rmb     16              ; 2 chars x 2 slots x (x,y,w,h)
ch_drawn        rmb     4               ; the cel each buffer was last DRAWN with
ch_bits         fcb     1,2,4,8         ; seen bit for (character, slot)
ch_tick         fcb     0
ch_dir          fcb     CH_STEP
ch_tx           fcb     0
ch_ty           fcb     0
ch_h            fcb     0
ch_w            fcb     0
ch_fdx          fcb     0
ch_tmp          fcb     0
ch_rec          fdb     0
ch_dest         fdb     0
ch_peel         fdb     0
ch_tmp16        fdb     0

