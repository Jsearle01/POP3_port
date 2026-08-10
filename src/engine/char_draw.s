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
                export  chars_due
* THE BLITTER BY SYMBOL, NOT BY OFFSET (P3.62). This file is LINKED INTO THE BUNDLE
* alongside blit_core.o [build.bat: lwlink ... flame_cels.o blit_core.o char_draw.o],
* so the blitter's addresses are the linker's to resolve and were never this file's to
* know. It had been calling `jsr [BLIT_TAB]` through a hard-coded FLAME_BASE+40 — the
* room's mechanism, which the room needs because it is a SEPARATE program that loads
* the bundle at a fixed address, and which this file copied without needing.
*
* That copy is what bit at P3.54: the offset moved +58 -> +40, the room was updated,
* this file was not, and the build LINKED CLEANLY and BOOTED before jumping into cel
* data. An import cannot drift — a wrong symbol fails the link, where a wrong literal
* fails a minute into the first workload.
                import  blit_cel
                import  blit_save
                import  blit_erase
                endc

FB_STRIDE_4C    equ     80              ; 320 px at 4 px/byte

* THIS FILE NO LONGER KNOWS WHERE THE BUNDLE LIVES, and does not need to (P3.62).
*
* It used FLAME_BASE for exactly two things, BLIT_TAB and CHAR_TAB, and both are gone:
* it is linked INTO the bundle, so the linker resolves what it calls. The declaration
* went with them rather than being left dead — a dead constant is what CHAR_TAB was, and
* CHAR_TAB was also wrong.
*
* FLAME_BASE itself was never the problem and is still handled properly: build.bat passes
* -DFLAME_BASE from one variable, and decb_to_raw refuses an image whose first segment is
* not exactly at the stated base, which ties the link script to the same number. What had
* two homes was the OFFSETS INTO it, and now only cutscene_room.s declares those, because
* only cutscene_room.s is a separate program that has to reach in from outside.

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
* The cels ride the flame track. The peel buffers are just scratch RAM and need no load
* at all, so they are fixed addresses in the free space above the blob.
*
* ★ THE TWO BUNDLE OFFSETS THAT LIVED HERE ARE GONE (P3.62), and the fact they encoded
* now has exactly one home, in cutscene_room.s, which is the only file that legitimately
* needs it — the room is a SEPARATE program that loads the bundle at a fixed address and
* must reach into it by arithmetic. This file is INSIDE the bundle and can just import.
*
*   BLIT_TAB equ FLAME_BASE+40  -> import blit_cel / blit_save / blit_erase (see §OBJTARGET)
*   CHAR_TAB equ FLAME_BASE+54  -> deleted; it had NO USE SITE ANYWHERE, and it was also
*                                  WRONG: chars_tab links at $302E, i.e. +46, so this had
*                                  been stale by 8 bytes since P3.54 and was waiting for
*                                  the first caller to jump into the middle of a pointer.
*
* That is the P3.54 failure with the fuse still in it — the same +58 -> +40 move that
* linked cleanly, booted, read the disk twice, stepped the VM, and only then jumped
* through $303A into cel data. A dead constant is not a harmless one when it is wrong.
* MOVED at P3.25: the peel buffers were at $5200, which is inside the two-track
* bundle's new extent ($4200..$65FF). $6C00 is clear of the bundle, of the disk
* parameter block at $6A00, and of the trace ring at $7800.
*   viz 2 slots x 480 = 960 B   $6C00..$6FBF
*   pri 2 slots x 344 = 688 B   $6FC0..$727F
* 1,648 B total, ending well short of the trace ring.
VIZ_PEEL_BASE   equ     $6C00
PRI_PEEL_BASE   equ     $6C00+VIZ_PEEL*2

* ---------------------------------------------------------------
* THE CEL IMAGE, AND WHY ITS ADDRESS IS A LITERAL HERE (P3.71).
*
* The scene's cel PIXELS no longer live in this bundle. They are their own link unit
* (content/cutscene/chars/cel_image.s, link/pop_cels.link), read off disk into a GIME
* bank that cutscene_room.s maps at CPU $C000 through $FFA6/$FFA7. The bundle had
* reached 11,921 B against a 14,848 B window with five beats still to add, and the cels
* are the half of it that never executes -- so they are the half that can live behind a
* window register.
*
* THIS IS NOT A DUPLICATED CONSTANT, and the distinction matters because "one home per
* fact" would otherwise forbid it. $C000 is not a fact this file shares with the linker:
* it is the address of a DIFFERENT link unit, which lwlink resolves separately and whose
* symbols are unreachable from here by construction. What would be a duplicate is the
* image's SHAPE -- how many cels, starting at which -- and that is exactly why the image
* carries WALK_LO/WALK_N as its own first two bytes and this file READS them rather than
* assembling a second copy. A duplicated layout constant is what CHAR_TAB was.
CEL_BASE        equ     $C000           ; where cutscene_room maps the bank
CEL_WALK_LO     equ     CEL_BASE        ; first cel number the image covers
CEL_WALK_N      equ     CEL_BASE+1      ; how many cels it covers
CEL_WALK_TAB    equ     CEL_BASE+2      ; [cel][facing][phase] -> cel data

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
CH_PAR          equ     13              ; the cel's PARITY BIT — the odd screen pixel

* THE VIRTUAL SCREEN IS THE APPLE'S 280 px, CENTRED — cols 5..74 (P3.59).
* Apple byte 0 -> CoCo col 5, Apple byte 39 -> col 74. Both margins are $00 for all 192
* rows of the room asset, so blanking a spill is an exact restore of the background.
VIS_L           equ     5
VIS_R           equ     74

* THE FOREGROUND PILLAR (P3.60). The oracle composes in planes and draws the foreground
* AFTER the characters [addfore, EQ.S:182 / FRAMEADV.S:823], so a character passing a
* near pillar goes BEHIND it. The port draws a flat converted room and then the
* characters on top, so the vizier walked in front of one. Jay: "he's not occuled
* properly when he walks behind the white pillar in the foreground", and on which one:
* "yes its the rightmost pillar".
*
* Derived from the asset, not guessed (CLAUDE.md §3): cols 60..62 are $FF — solid white,
* all four pixels colour 3 — unbroken from row 104 to row 191. THAT IS WHY THIS NEEDS NO
* SAVED COPY OF THE ROOM: the restore is a fill, so there is no buffer to keep in a
* window that has none to spare, and no second home for the pillar's pixels to drift from.
*
* Rows stop at 151, not 191: a character's baseline is y=151 and the tallest cel is 48
* rows, so nothing can ever be drawn below it. 3 x 48 bytes, and only when someone is
* actually standing on the pillar's columns.
FORE_L          equ     60
FORE_R          equ     62
FORE_T          equ     104
FORE_B          equ     151
CH_PTR          equ     6
CH_PEEL         equ     8
CH_SIZE         equ     14

* Motion step. MUST be a multiple of 4 px: the phase is baked into the cel data
* (P3.19/P3.20), so moving by anything else would need the phase variant for the
* new column and there is exactly one baked cel per character here. 8 px = two byte
* columns. Sub-byte motion is piece E's problem, not a limitation of the blitter.
CH_STEP         equ     8

* ---------------------------------------------------------------
* chars_due — IS AN ANIMATION STEP DUE? A = 1 yes, 0 no.  U = the HAL's frame count.
*
* THE ROOM DRAWS ONCE PER ANIMATION STEP, NOT ONCE PER LOOP ITERATION (P3.51), which is
* the oracle's own structure: `play` -> `FrameAdv` -> `DoFast` draws the torches, stars,
* sand, hourglass and characters in ONE pass into the hidden page, then flips ONCE
* [SUBS.S:876-914, :967, :1002-1007]. The port had been redrawing and flipping every
* video frame, which is why the measured frame cost was 192% of budget against a per-step
* work figure of 1.92 VBLs in a 2.60-VBL step.
*
* WHY THE ROOM HAS TO ASK, rather than the draw deciding for itself: `flicker` runs BEFORE
* `chars_frame` and advances the torch, so a gate inside `chars_frame` would come too late
* -- the torch would already have stepped. Reordering to chars-then-flicker instead would
* change the draw order, and the torches would paint over the characters where they
* overlap (the room suite reports "20 behind a character", so the overlap is real). Asking
* first is the only order that leaves both alone. [P3.50 §3C]
*
* IT ASKS; IT DOES NOT DECIDE. `vm_nextframe` still owns the step and still advances
* `cad_idx` -- this must stay side-effect free or there are two cadences again, which is
* the exact defect `fl_div` was (a second divider running off loop iterations, giving the
* torches 9.25 Hz against a commented ~20). It reads `vm_due`, writes only `vm_now`, and
* touches no slot record.
*
* The comparison is `vm_nextframe`'s own, verbatim: signed 16-bit, correct until the
* counter passes $7FFF (~9 minutes at 60 Hz).
* ---------------------------------------------------------------
chars_due
                stu     vm_now                  ; the same store chars_frame makes
                ldd     vm_now
                subd    vm_due
                bmi     cd_hold                 ; this step's frames have not elapsed
                lda     #1
                rts
cd_hold
                clra
                rts

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
                ldu     #viz_script             ; the vizier follows a SCRIPT (P3.32)
                stu     vm_scr
                ldu     #viz_stand              ; a non-zero seed; the script's first
                stu     vm_seq                  ;   entry replaces it on step one
                ldu     #pri_stand              ; a non-zero seed; her script's first
                stu     vm_seq+2                ;   entry replaces it on step one
                ldu     #pri_script             ; SHE HAS A SCRIPT NOW TOO (P3.65)
                stu     vm_scr+2
cf_running
                jsr     vm_nextframe            ; decide
                jsr     vm_frameadv             ; draw
                rts

* ---------------------------------------------------------------
* vm_frameadv — the DRAW half. THREE PASSES OVER ALL CHARACTERS, not one pass each.
*
* THIS IS THE FIX FOR THE OVERLAP DEFECT (P3.31 §3D, P3.32). It used to be two calls
* to char_one, and each call did erase -> save -> draw for ONE character before the
* next character ran. So the second character's SAVE happened AFTER the first had
* already been drawn, and what it saved as "background" was the first character's
* PIXELS. One step later it restored them -- painting the vizier back into a place he
* no longer was. The damage compounded, because the next save captured the mess.
*
* THE CORRUPTION WAS ASYMMETRIC, AND THAT IS THE TELL. Jay: "the vizier doesn't get
* corrupted, only the princess." The MOVER is the one whose save straddles the other's
* pixels, so the STATIONARY character is the one that gets vandalised. A fix that only
* tidied the moving character's own footprint would have left this exactly as it was,
* which is why the princess's cleanliness -- not the vizier's -- is the test.
*
* Phasing the frame removes the interleave outright: nothing is drawn until every save
* has been taken, so no save can see anything but the clean room.
*
*     ERASE all  -> the room is clean everywhere a character was
*     SAVE  all  -> every background captured against that clean room
*     DRAW  all  -> and only now does anything reach the screen
*
* The passes cost three walks over the characters instead of one. The walk is the
* cheap part (a variant lookup and a few index bytes); the blits are unchanged in
* number, and they are the cost.
* ---------------------------------------------------------------
CP_ERASE        equ     0
CP_SAVE         equ     1
CP_DRAW         equ     2

vm_frameadv
                jsr     ch_scan                 ; decide the peel for the WHOLE frame
                lda     #CP_ERASE
                bsr     ch_pass
                lda     #CP_SAVE
                bsr     ch_pass
                lda     #CP_DRAW
                bsr     ch_pass
                jsr     co_fore                 ; the foreground plane, over everybody
                rts

* ch_pass — run one pass over every character, in draw order.
ch_pass
                sta     ch_cp
                clr     ch_idx
                ldx     #viz_slot
                jsr     char_one
                lda     #1
                sta     ch_idx
                ldx     #pri_slot
                jsr     char_one
                rts

* ---------------------------------------------------------------
* ch_scan — ch_anymove := did ANY character move (or change cel) this frame?
*
* THE PEEL-SKIP'S PREMISE WAS RE-EXAMINED HERE AND IT WAS FALSE (P3.32). P3.22 skipped
* the peel for a character that had not moved, on the grounds that "the background
* under a static character never changes". That is true only while it is the only
* thing on the screen. The princess does not move -- but the vizier walks over the
* room beneath her, so her background changes without her doing anything, and skipping
* her erase leaves her pixels on screen while HIS save is taken. Three passes do not
* help if one character never enters the first pass.
*
* So the skip is now a property of the FRAME, not of the character: if anything moved,
* everybody peels. One flag, and it is conservative in the safe direction -- a
* character that did not need a peel gets one, which costs time and cannot corrupt.
*
* When nothing moves at all -- which is what the scene does once he has stopped -- the
* skip still applies to everyone, and P3.22's idempotent-merge argument still holds
* exactly as written, because every character is redrawing its own cel over its own
* pixels at its own position:
*
*     ((d AND m) OR s) AND m) OR s  ==  (d AND m) OR s        because s AND m == 0
*
* (the baker sets mask bits only where the source pixels are 0, so s AND m is zero by
* construction -- cel_blit_prep.encode_row). P3.21 measured what it buys: the
* two-character draw with full peel needs two frames, draw-only fits in one.
* ---------------------------------------------------------------
ch_scan
                clr     ch_anymove
                clr     ch_idx
                ldx     #viz_slot
                bsr     ch_scan_one
                lda     #1
                sta     ch_idx
                ldx     #pri_slot
                bsr     ch_scan_one
                rts

ch_scan_one
                stx     ch_rec
                bsr     ch_index
                jsr     ch_moved                ; ch_move := 0/1
                lda     ch_move
                ora     ch_anymove
                sta     ch_anymove
                rts

* ch_index — ch_lastoff and ch_bit for this (character, slot).
* ch_last[] index = (character*2 + slot) * 8  — x, y, w, h, parity (3 spare).
*
* THE PARITY HAS TO BE REMEMBERED WITH THE POSITION (P3.58). The erase recomputes
* the old destination from the stored x, and the drawn column is now
* 2*(x-58)+parity+20 — so an erase that assumed parity 0 would restore a byte to
* the LEFT of what the save captured for four of the six walk cels. Fdx has the
* same shape and has always been zeroed here; it is zero for every cel in this
* scene, which is why that never showed.
ch_index
                lda     ch_idx
                lsla
                adda    ch_slot
                lsla
                lsla
                lsla                            ; 8 B per (character, slot)
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
                rts

* --- did the character move since THIS buffer last drew it? ---------------
ch_moved
                ldy     #ch_drawn               ; the cel this buffer last drew
                lda     ch_idx
                lsla
                adda    ch_slot
                ldb     a,y
                stb     ch_lastcel
                ldy     #ch_last
                lda     ch_lastoff
                ldx     ch_rec
                ldb     a,y                     ; last x for this (char, slot)
                cmpb    CH_X,x
                bne     co_moved
                inca
                ldb     a,y                     ; last y
                cmpb    CH_Y,x
                bne     co_moved
* THE CEL COUNTS AS A CHANGE TOO, not just the position. The test compared x and y
* only, so a character that changed CEL WITHOUT MOVING took the static branch: no
* erase, no save, and the new cel drawn straight over the old one's pixels. The merge
* is idempotent for the SAME cel, which is what made the skip safe when P3.22
* introduced it -- but a DIFFERENT cel leaves the previous one showing wherever the
* new one is transparent, and it accumulates. Isolated by ablation: cel-change with
* the position FIXED fails on its own (65/72, captures disagreeing), so this is not a
* movement bug and not an overlap bug.
                lda     ch_lastcel
                cmpa    CH_CEL,x
                beq     co_static
co_moved
                lda     #1
                bra     co_setmove
co_static
                clra
co_setmove
                sta     ch_move
                rts

* ---------------------------------------------------------------
* char_one — do THIS pass's work for one character.
*
*   X -> slot record.  Uses ch_rec as the authority for the record pointer because
*   blit_cel clobbers X (and blit_blast clobbers A,B,D,Y — only X is preserved,
*   which is what P3.20's Bug 1 got wrong by keeping the peel pointer in Y).
*
* The setup below is re-done per pass rather than stashed between them. It is a
* variant lookup and two index bytes; carrying it across three passes would mean a
* per-character copy of six values, which is the parallel state P3.22 was shaped to
* avoid -- and the state that goes stale is the state that gets read stale.
* ---------------------------------------------------------------
char_one
                stx     ch_rec
* RESOLVE THE CEL FIRST, because its DIMENSIONS depend on which variant is chosen.
* A sub-byte phase can add a byte to a cel's width (the shifted pixels spill into one
* more column), so the peel extent is a property of the VARIANT, not of the cel number.
* Reading h/w from the record here -- as this did until P3.31 -- would size the save to
* whichever variant vm_resolve happened to store and erase the other one's footprint
* short by a column: the P3.25 stride bug, one level down.
                jsr     co_variant              ; U = the phase-correct baked cel
* AND IF THERE IS NO CEL, DRAW NOTHING (P3.71).
*
* co_variant's own comment states the contract this enforces: a 0 in the table means the
* walk never puts this cel on this phase, and the fallback exists so the code never
* "blits from address 0". That held while CH_PTR was seeded with a link-time cel label.
* The cels now live in the $C000 image, the seeds are 0, and BOTH arms of co_variant can
* therefore return 0 -- at which point co_dims reads a header out of the 6809 vector area
* and blit_cel walks whatever it finds. That is the wild-blit failure the fallback was
* written to prevent, re-opened from the other side.
*
* Skipping leaves the slot showing what it had, which is the SAME degradation img_map's
* header already names as acceptable: "visible as a stall, not as a crash". The pixel
* check reports a stalled character as wrong bytes, so it stays loud.
                cmpu    #0
                beq     cp_none                 ; no cel: stall the slot, draw nothing
                stu     ch_cel
                jsr     co_dims
                bsr     ch_index

                lda     ch_cp
                cmpa    #CP_DRAW
                lbeq    co_draw                 ; the draw is unconditional
                lda     ch_anymove
                beq     cp_none                 ; nothing moved: no peel this frame
                lda     ch_cp
                cmpa    #CP_ERASE
                bne     co_save
* --- ERASE at the OLD position, if this buffer has one ------------------
* The erase must restore where the character WAS in this buffer, not where it is
* going. P3.20 erased at the new position, which is only harmless while nothing
* moves — and nothing did, because its move path was dead (P3.21 found that).
                lda     ch_bit
                anda    ch_seen
                bne     co_erase
cp_none
                rts
co_erase
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
                inca
                ldb     a,y
                stb     ch_par                  ; the parity the SAVE was taken at
                clr     ch_fdx                  ; the old position already included it
                jsr     co_setup
                ldx     ch_dest
                ldy     ch_peel
                lda     ch_h
                ldb     ch_w
                jsr     blit_erase              ; preserves X,Y,U
                rts
* THE DIMENSIONS NO LONGER HAVE TO BE PUT BACK HERE, because the save is a separate
* pass and re-resolves them from the variant on entry. When the erase and the save ran
* back to back this restore was load-bearing and getting it from the RECORD was a real
* bug (P3.31): the record's CH_H/CH_W are whatever vm_resolve last wrote, and it
* resolves through img_map, which has no entry for the walk's images -- so a walk cel
* saved and drew at the PREVIOUS cel's 48x5 while the cel was 47 rows. Drawn one row
* high, peel one row off, and a trail that grew from 0 to 839 wrong bytes.

co_save
* --- SAVE the background at the NEW position, and record it --------------
                jsr     co_here                 ; ch_tx/ch_ty := the record's x,y
                jsr     co_setup
                ldx     ch_dest
                ldy     ch_peel
                lda     ch_h
                ldb     ch_w
                jsr     blit_save
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
                inca
                ldb     ch_par                  ; and the PARITY it was placed at
                stb     a,y
                lda     ch_seen
                ora     ch_bit
                sta     ch_seen
                rts                             ; the draw is a separate pass now

co_draw
* --- DRAW, always -------------------------------------------------------
                jsr     co_here
                jsr     co_setup
                ldu     ch_cel                  ; the variant char_one resolved
                ldx     ch_dest
                jsr     blit_cel                ; clobbers X and Y
                jsr     co_clip
* DID THIS CHARACTER LAND ON THE PILLAR? Recorded, not acted on: the foreground must go
* down after EVERY character, not after each one, or the second character would draw
* over a pillar the first had already put back.
                lda     ch_col
                cmpa    #FORE_R+1
                bhs     cd_nofore
                adda    ch_w
                cmpa    #FORE_L+1
                blo     cd_nofore
                lda     #1
                sta     ch_fore
cd_nofore

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

* ---------------------------------------------------------------
* co_variant — U := the baked cel for THIS cel number at THIS sub-byte phase.
*
* RESOLVED AT DRAW TIME, NOT WHEN THE CEL IS CHOSEN. The phase comes from x, and `chx`
* moves x in the same step that selects the cel, so a pointer fixed at selection time
* would be one step stale -- the same one-step lag that had the checker reporting 139
* wrong bytes in P3.29. char_one runs inside vm_frameadv, after vm_nextframe has
* decided, so the record read here is the state this frame will actually draw.
*
* Most cels have one baked phase and CH_PTR is it. The walk is different: its deltas
* net 10 px per cycle and 10 mod 4 = 2, so each of cels 48-53 is drawn at exactly TWO
* phases and has two baked variants. WHICH two is not written here or in the bake --
* both take it from walk_phases.py, because P3.30 wrote it by hand and produced the
* exact complement of the truth (it dropped `Vwalk db chx,1`, the one-off entry step
* that moves x before cel 48 is ever drawn).
*
* THE PHASE EXPRESSION IS co_setup'S, TERM FOR TERM -- x + Fdx + 20. Fdx is 0 for every
* walk cel, so dropping it would compute the same answer today and a wrong one for the
* first cel that carries one; two places deriving the same quantity by different
* expressions is how the arithmetic drifts in the first place.
*
* A 0 in the table means "the walk never puts this cel on this phase" and falls back to
* the record's own pointer rather than blitting from address 0. The fallback is not a
* correctness path: if it ever fires, the previous cel is drawn and the pixel check
* reports it as wrong bytes, which is the loud failure we want over a silent one.
*
*   Entry: ch_rec -> the slot record
*   Exit:  U = the cel data to blit.  Clobbers A, X.
* ---------------------------------------------------------------
co_variant
                ldx     ch_rec
                lda     CH_CEL,x
                suba    CEL_WALK_LO             ; the IMAGE's own first two bytes,
                bcs     cv_plain                ; below the walk's range
                cmpa    CEL_WALK_N              ; read at run time (P3.71)
                bhs     cv_plain                ; above it
* EIGHT SLOTS PER CEL NOW, NOT FOUR (P3.65, piece G): two facings x four phases. The
* oracle mirrors at DRAW time — OPACITY bit 7 sends LAY to MLAY [HIRES.S:655] — and the
* port cannot: blit_cel walks segment runs left to right, so a runtime mirror would need
* reverse traversal AND bit-reversal inside each byte, against a merge path already at a
* 6809 floor of 22 cy/byte. So the mirror is BAKED, and the facing selects which half of
* this row to read.
* SIXTEEN-BIT THROUGHOUT, and both halves of that are load-bearing.
*
* `ldu a,x` takes A as a SIGNED byte, so the old 4-slot form worked only while the table
* stayed under 128 bytes — the signed-offset trap shift_row.s documents for its own
* tables. That much was expected.
*
* THE ONE THAT BIT: the CEL INDEX overflows too. The table now spans cels 11..56, so
* (cel - WALK_LO) reaches 45 and *8 is 360 — past a byte. Widening only the final index
* left `lsla lsla lsla` truncating to 104, and the walk drew from the wrong rows: 180-odd
* wrong bytes per capture with the POSITIONS all still correct, which is what an index
* fault looks like from the outside. Every step of the arithmetic is 16-bit now.
                tfr     a,b
                clra                            ; D = cel - WALK_LO
                lslb
                rola
                lslb
                rola
                lslb
                rola                            ; D = that * 8 (two facings x four phases)
                std     cv_ix
                lda     CH_FACE,x
                bmi     cv_lface                ; -1 = left = NORMAL [FRAMEADV.S:1970]
                ldd     cv_ix
                addd    #4                      ; facing right -> the mirrored half
                std     cv_ix
cv_lface
                lda     CH_X,x
                adda    CH_FDX,x                ; ...indexed by the sub-byte phase,
                lsla                            ; 2*(x+Fdx) — mod 4 is all this needs
                adda    CH_PAR,x                ; + the odd pixel
                anda    #3                      ; co_setup's expression, mod 4
                tfr     a,b
                clra
                addd    cv_ix
                lslb
                rola                            ; D = index * 2, unsigned in 16 bits
                ldx     #CEL_WALK_TAB
                ldu     d,x
                cmpu    #0
                bne     cv_done
cv_plain
                ldx     ch_rec
                ldu     CH_PTR,x                ; single-phase cel
cv_done
                rts

* co_clip — blank whatever fell outside the virtual screen.
*
* THE ORACLE CLIPS EVERY IMAGE TO LEFTCUT..RIGHTCUT, in BYTES, RIGHTCUT normally 40
* [HIRES.S CROP] — so the vizier entering at FCharX 277 is XCO 39 with VISWIDTH 1 and
* shows as a single byte at the edge, growing as he walks in. The port drew all of him,
* twenty pixels into a margin the Apple does not have. Jay: "he's not clipped properly
* to the right screen virtual egde (x=279)."
*
* Blanking after the fact rather than clipping inside the blitter is deliberate: the
* segments encode runs, not columns, so a width clamp cannot be applied to a stream
* without a bounds test on every byte, and blit_cel's merge path is already a 6809 floor
* at 22 cy/byte. This costs nothing on a character that is fully on screen, which is all
* of them for all but the first few steps.
*
* The wrap is handled for free: a spill of nine bytes from col 75 runs 75..79 then 0..3
* of the row below, which is exactly where the blit put it — both walk the same linear
* memory.
co_clip
                lda     ch_col
                cmpa    #VIS_L
                bhs     cc_right
                ldb     #VIS_L
                subb    ch_col                  ; B = bytes off the LEFT edge
                ldx     ch_dest                 ; which start at ch_dest itself
                bra     cc_blank
cc_right
                adda    ch_w
                cmpa    #VIS_R+1
                bls     cc_done                 ; entirely inside the window
                suba    #VIS_R+1
                tfr     a,b                     ; B = bytes past the RIGHT edge
                lda     #VIS_R+1
                suba    ch_col                  ; A = distance from ch_col to col 75
                ldx     ch_dest
                leax    a,x
cc_blank
                lda     ch_h
cc_row
                pshs    a,b,x
cc_byte
                clr     ,x+
                decb
                bne     cc_byte
                puls    a,b,x
                leax    FB_STRIDE_4C,x
                deca
                bne     cc_row
cc_done
                rts

* ---------------------------------------------------------------
* co_fore — put the foreground pillar back, over whatever was drawn.
*
* Runs once, after every character, which is the ordering that makes it a PLANE rather
* than a per-character fix-up. Skipped entirely unless someone actually drew on those
* columns, so it costs one compare on the frames it does not apply to — which is most of
* them, since the vizier crosses the pillar for a few steps of a 30-step walk.
co_fore
                lda     ch_fore
                beq     cf_done
                clr     ch_fore
                ldx     ch_base
                leax    FORE_T*FB_STRIDE_4C+FORE_L,x
                lda     #FORE_B-FORE_T+1        ; rows
cf_row
                ldb     #$FF
                stb     ,x
                stb     1,x
                stb     2,x
                leax    FB_STRIDE_4C,x
                deca
                bne     cf_row
cf_done
                rts

* ---------------------------------------------------------------
* co_dims — ch_h/ch_w := the RESOLVED VARIANT's own header, which is the only thing
* that knows how big this draw is. One routine because both callers must agree: the
* extent a peel is saved with has to be the extent it is drawn with, and the two are
* set 40 lines apart.
co_dims
                ldu     ch_cel
                lda     ,u                      ; rows
                sta     ch_h
                lda     1,u                     ; width in bytes
                sta     ch_w
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
                lda     CH_PAR,x
                sta     ch_par
                rts

* ---------------------------------------------------------------
* co_setup — from ch_tx / ch_ty / ch_h, compute ch_dest and ch_peel.
*
*   px  = 2*(x + Fdx - 58) + parity + 20        SETUPCHAR [CTRLSUBS.S:794-840]
*   col = px / 4
*
* CHARX IS IN TWO-PIXEL UNITS and the parity bit is the odd pixel (P3.58). This read
* `x + 20` — half scale, no parity — from P3.17 until Jay said "theres still a visible
* hitch in his walk thats not in the oracle visually". The hitch itself is authentic
* (`Vwalk db 51,chx,-1` [SEQTABLE.S:1518], verified six ways). What was wrong is the
* SCALE: at half scale the same leg artwork carries him half as far, so his planted foot
* slides backwards, and an authentic +1 px against a 20 px stride becomes +2 against 10
* — a fifth of the stride instead of a twentieth, which is the difference between
* invisible and a stumble.
*
* The port's OWN converter had the formula all along: cel_parity_rule.draw_x, written
* "for the record" and wired to nothing, is what stamped start_col 279 into the walk
* cels and 124/125 into the princess's. Two halves of one tree encoding one fact, and
* only the half nobody read was right.
*
* WHY IT SURVIVED EVERY GATE: the two formulas agree at x=116. The princess sits at 120,
* so she rendered 4 px off — invisible — and she is what placement was validated against.
* The vizier was 82 px off. ScrnLeft = 58 [EQ.S:479], and 2*(197-58) = 278 is the
* right-hand door, which is where he is supposed to come in.
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
                tfr     a,b
                clra
                lslb
                rola                            ; D = 2*(x + Fdx)
                addb    ch_par                  ; + the odd pixel
                adca    #0
                addd    #20-116                 ; + centring, - 2*ScrnLeft
                lsra
                rorb
                lsra
                rorb                            ; col = px / 4
                stb     ch_col                  ; kept for co_clip
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
* ★ POLICY REVISIT (P3.55, Jay). "Floor at SPEED, overrun naturally" gave 2.70
* frames/step, and at that rate the torches run 20.0 Hz — MEASURED, against the oracle's
* 15.4 Hz in the condition that compares (characters animating). Jay, on the live gate:
* "the flames do seem a bit fast to the eye." He had passed the pacing at 22 Hz when the
* torches were still on their own slow divider; with one clock driving both, the flame
* rate is what the step rate looks like, and it reads too fast.
*
* THIS OVERRIDES THE §PACING POLICY ABOVE, WHICH IS JAY'S TO OVERRIDE. That policy chose
* the oracle's INTENT (SPEED 7 = 2.6 frames) over its OBSERVED rate (3.9 when animating),
* on the reasoning that hard-coding 3.9 "would mean inserting delay to reproduce the
* Apple's inability to keep up — porting a limitation as if it were a design." That
* argument is unchanged and still correct in principle. It is overruled by the eye, which
* CLAUDE.md §2 ranks first, and the policy's own caveat — "REVISITABLE BY EYE (Jay's
* caveat) — if it looks wrong side by side with the oracle, the policy changes, not the
* measurement" — is the clause being exercised.
*
* 19 frames over 5 steps = 3.8, against the oracle's measured 3.9. The shape keeps a
* spread rather than flattening to a constant, for the reason the note below gives.
* P3.57: THE TABLE'S LENGTH MUST DIVIDE THE GAIT, and 5 does not divide 6. With
* CAD_LEN 5 against Vwalk's six-step cycle the short hold ROTATES: cycle 0 clips pose
* 4, cycle 1 clips pose 3, cycle 2 pose 2 ... a different pose is held one frame short
* every cycle. That is a limp, it has a 30-step period, and the walk is only about 45
* steps, so it never settles. It is OURS -- the oracle sets a flat `SPEED 7` for this
* scene [SUBS.S:683] and has no such beat. Jay: "the x change in his walk is off ...
* he moves back a bit while walking forward."
*
* Six entries pin each pose to its own hold for good. 23/6 = 3.833 f/step against the
* old 19/5 = 3.800 and the oracle's measured 3.9 -- so this is also NEARER the oracle
* in rate, not a trade of pace for rhythm.
*
* The step Jay saw go backwards is NOT this and is not a defect: Vwalk really does
* carry `db 51,chx,-1` [SEQTABLE.S:1518] and Fdx is 0 for all six walk frames
* [FRAMEDEF.S:378-383], so his x genuinely runs 187 -> 188 -> 187 once per cycle in the
* original. Checked against ADDCHARX [CTRLSUBS.S:353] and ANIMCHAR [COLL.S:994] for the
* facing-negate and the opcode/frame pairing. We reproduce that exactly; what we ALSO
* did was clip a rotating pose on top of it.
cad_tab         fcb     4,4,4,4,4,3     ; 23 frames over 6 steps = 3.833, one per gait pose
CAD_LEN         equ     6
cad_idx         fcb     0
vm_now          fdb     0               ; the HAL's frame count, handed in per call
vm_due          fdb     0               ; the frame this step is due to fire on

* --- image index -> the baked cel that holds it --------------------------
* Only the cels actually baked can be drawn. The cel TABLE covers all 49, but baking
* the rest needs the per-cel parity conversion volume, which is E's scope. A cel
* whose image is not here leaves the slot showing what it had -- visible as a stall,
* not as a crash.
* P3.58: every entry now names the variant baked at the parity SETUPCHAR actually
* places it at. vstand.s and pstand.s were converted/shifted for the half-scale
* placement and are superseded: vstand_src.s carried start_col 197 — the raw CharX —
* where the oracle's own FCharX for that cel is 279, so it had the wrong colour parity
* baked in and has been re-derived. pstand's source column (125) was already right; only
* its shift was wrong (phase 0, needs 1).
* REDUCED TO ONE ENTRY AT P3.71, and the reason is measured rather than tidy. The four
* walk entries (25 -> p11_p1, 80/81/82 -> v54/55/56_p1) named cels that now live in the
* $C000 image, which this link unit cannot resolve. They could not simply be re-pointed,
* so the question was what they were FOR:
*
*   CH_PTR -- consulted only by co_variant's cv_plain fallback, which cannot fire for a
*             cel the bank table covers, and the bank table covers every one of them.
*   CH_H/CH_W -- written here and READ BY NOTHING. Measured, not assumed: building with
*             -DSEED_BADHDR=52 forces both to $FF for the vizier's cel 52 and the walk
*             suite stays byte-exact across all 28 captures (seed verified present by
*             symbol, vr_done $3B9B -> vr_noseed $3BA7). blit_cel takes its own rows and
*             width from the cel header at blit_core.s:82-84; the record's copy is an
*             unused declaration with a live-looking name.
*
* So the entries had no live consumer once the cels moved, and removing them is the
* whole of the change. pslump stays because it is a bundle-resident cel and genuinely
* resolves here.
img_map         fcb     10
                fdb     pslump
                fcb     0               ; terminator

vm_seq          fdb     0,0             ; sequence pointer per character
vm_scr          fdb     0,0             ; scene-script cursor per character (0 = none)
vm_cnt          fcb     0,0             ; plays left on the current script entry
vm_ix           fcb     0
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
* AND THE PARITY — DERIVED, not read (P3.65, piece G).
*
* +3 was a parity column baked by the generator against ONE CharFace, and cel_table.s
* said what that cost: "a character that TURNS invalidates this column". Both characters
* turn inside this scene — Palert ends `aboutface,chx,9` and Vexit ends `aboutface,chx,16`
* — so each spends part of it at the other parity and a baked column cannot describe them.
*
* +3 is now raw Fcheck and the rule lives here, which is where SETUPCHAR keeps it:
* parity = 1 when bit7(Fcheck) == bit7(CharFace) [CTRLSUBS.S:833-838]. EORA sets N from
* the result, so the test is the EOR itself — no mask, no compare.
                lda     3,x                     ; Fcheck
                eora    CH_FACE,u               ; N = 1 when the hibits DIFFER
                bmi     vr_even
                lda     #1                      ; hibits match -> ODD x, +1 pixel
                bra     vr_parst
vr_even
                clra                            ; hibits differ -> EVEN x
vr_parst
                sta     CH_PAR,u

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
* ===============================================================
* SEEDED FAULT — P3.71 §2, the positive control. Guarded by -DSEED_BADHDR and absent
* from every normal build. It forges exactly the failure a $C000 re-base can cause:
* CH_H/CH_W read from an address the cel no longer occupies, i.e. two bytes of
* whatever-is-there instead of the header. blit_cel reads its OWN rows/width from the
* cel (blit_core.s:82-84), so this cannot corrupt the DRAW -- it corrupts the PEEL, and
* blit_erase writes the peel back INTO the framebuffer. If the observed damage is a
* runaway erase, this reproduces its shape; if it is not, this rules the shape out.
* The cel number is the discriminator P3.70 measured: capture 05 is cel 52's first draw.
*
* IT SITS AFTER vr_done DELIBERATELY. Placed inside the vr_found arm it never fired,
* because cel 52's image index is NOT in img_map at all -- vr_find falls out at its
* terminator and leaves the record's h/w alone. That is a measurement, not a mishap:
* img_map is not the path a $C000 re-base could strand for this cel.
                ifdef   SEED_BADHDR
                lda     CH_CEL,u
                cmpa    #SEED_BADHDR
                bne     vr_noseed
                lda     #$FF
                sta     CH_H,u
                sta     CH_W,u
vr_noseed
                endc
* ===============================================================
                puls    u
                rts

* ---------------------------------------------------------------
* vm_step — advance ONE character's sequence by one animation step.
*   X -> slot record, ch_idx = character index.
* ---------------------------------------------------------------
vm_step
                stx     vm_rec
                jsr     vm_script_tick          ; has this sequence had its N plays?
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
* vm_script_tick / vm_advance — the oracle's `play N`, ported (P3.32).
*
* A SEQUENCE DOES NOT KNOW WHEN TO STOP. `Vwalk` ends `goto Vwalk1` and walks forever;
* what ends it is the SCENE, which in the oracle is a run of vjumpseq/play pairs
* [SUBS.S:687-716]:
*
*     lda #Vapproach / jsr vjumpseq / lda #30 / jsr play
*     lda #Vstop     / jsr vjumpseq / lda #4  / jsr play   ;stops in front of princess
*
* and `play N` is N animation steps [SUBS.S:876]. So the script is a list of
* (sequence, plays) and the counter ticks once per step, which is exactly here.
*
* THIS IS NOT PlayCut0 (out of scope) -- it is the two calls that make Vstop mean
* anything. Without it, porting Vstop as data would change nothing: nothing would ever
* leave Vwalk, and the vizier would keep walking through the princess exactly as he did
* before, which would have looked like the walk was simply unfixed.
*
* A count of 0 means "hold here", and the cursor is zeroed when one is loaded so the
* next tick cannot walk off the end of the table. The princess has no script at all
* (cursor 0), which is the same path.
* ---------------------------------------------------------------
vm_script_tick
                lda     ch_idx
                lsla
                ldx     #vm_scr
                ldu     a,x
                cmpu    #0
                beq     vt_done                 ; no script: this sequence holds
                ldx     #vm_cnt
                lda     ch_idx
                ldb     a,x
                bne     vt_dec
                bsr     vm_advance              ; spent: take the next entry
                ldx     #vm_cnt
                lda     ch_idx
                ldb     a,x
vt_dec
                tstb
                beq     vt_done                 ; 0 plays = hold forever
                decb
                stb     a,x
vt_done
                rts

* vm_advance — load the next (sequence, plays) pair and advance the cursor.
* vjumpseq restarts the sequence from its FIRST byte, which for Vwalk means its one-off
* `chx,1` entry step runs again — that is the behaviour, not an accident of the port.
vm_advance
                lda     ch_idx
                lsla
                sta     vm_ix
                ldx     #vm_scr
                ldu     a,x                     ; U -> the cursor
                ldy     ,u++                    ; the sequence
                ldb     ,u+                     ; its play count
                lda     vm_ix
                ldx     #vm_seq
                sty     a,x
                lda     ch_idx
                ldx     #vm_cnt
                stb     a,x
                tstb
                bne     va_keep
                ldu     #0                      ; last entry: never advance again
va_keep
                lda     vm_ix
                ldx     #vm_scr
                stu     a,x
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
* Pstand [SEQTABLE.S:1558] — `db 11,goto / dw Pstand`. One cel, held, and she does not
* move at all. THIS IS WHAT SHE IS ACTUALLY DOING during the vizier's approach (P3.61).
*
* The oracle's princess side of PlayCut0 is startP0 (CharX 120, Pstand) -> play 2 ->
* play 5 -> Palert -> play 9 [SUBS.S:658-680], and Palert itself ENDS in Pstand:
*
*     Palert  db 2,3,4,5,6,7,8,9
*             db aboutface,chx,9
*             db 11,goto / dw Pstand      [SEQTABLE.S:1565]
*
* so she reacts to the door, turns, and is standing still well before the final approach
* — which is the only part of the script the port renders. Jay, once the vizier was
* right: "the princess is still flailing around."
*
* WHAT SHE WAS DOING INSTEAD was pri_demo, a P3.25 PLACEHOLDER whose only purpose was to
* exercise the interpreter's opcodes before any real sequence could run. It stepped her
* back and forth 8 px, and P3.58 doubled that to 16 — the scale fix made a placeholder
* that had always been wrong twice as visible, which is why it surfaced now.
*
* SHE IS FACING AWAY FROM HIM, and getting to the truth of that took two wrong turns
* which are recorded rather than tidied. P3.61 said she faces away; Jay said "no shes
* facing him"; P3.61a wrote that up, reasoning that her art must simply be drawn facing
* right; Jay then corrected himself — "sorry i was incorrect she is facing away." The
* first answer was right. FCharFace -1 is NORMAL, i.e. unmirrored [FRAMEADV.S:1970 `lda
* #-1 ;normal`], both characters start there, and both sets of art face LEFT.
*
* So the mirror IS a prerequisite here, and piece G is on this scene's path after all.
* The oracle's princess, once Palert's `aboutface,chx,9` has run — which happens well
* before the approach the port renders — stands TURNED and 9 CharX units along:
*
*                     CharX  CharFace  parity  CoCo px  col  phase
*     the port         120     -1         1      145     36    1     pstand_p1
*     the oracle       129      0         0      162     40    2     needs a MIRRORED
*                                                                    pstand at phase 2
*
* Three things, and they only work together: a mirrored conversion of image 25; that cel
* baked at phase 2; and her slot moved to CharX 129 with CharFace 0. Note the parity
* FLIPS with the facing — cel_table's parity column is generated for CharFace=left and
* says 1, while she needs 0, which is the "a character that TURNS invalidates this
* column" caveat coming due. The durable fix is for vm_resolve to carry Fcheck and derive
* parity against CH_FACE at runtime, rather than read a column baked for one facing.
*
* Left for Jay to call: it is a spatial correction (CLAUDE.md §3) and an 18 px move.
*
* pri_demo is KEPT, not deleted: harness/tools/peel_matrix.py rewrites its body to drive
* the peel matrix and finds its end by matching the marker line above it. It is simply no
* longer what the scene runs.
pri_stand       fcb     11,SEQ_GOTO
                fdb     pri_stand

* Palert [SEQTABLE.S:1565] — "princess hears something..." [SUBS.S:675]. THE SCENE'S
* OPENING, BUILT AND THEN BACKED OUT, and the reason is worth keeping:
*
*     Palert  db 2,3,4,5,6,7,8,9 / aboutface,chx,9 / 11,goto Pstand
*
* It works and it does not FIT. Its eight turn cels take the bundle to 17,929 B against a
* 14,848 B window — over by 3,081 — and lz_pack refuses it. P3.63 measured the scene's
* PEAK residency at 5,631 B of cels and showed that fits comfortably; the peak is only
* reachable if cels arrive DURING the scene, and this bundle loads ONCE. The wall is the
* absence of a per-beat load (Jay's P3.45 question), not the window and not the encoding.
*
* WHAT SURVIVES IS THE MACHINERY IT NEEDED, which is piece G and is in the tree: parity
* derived at run time from Fcheck ^ CH_FACE, a facing dimension on walk_tab, and a
* mirroring bake. Her turn is one PLAN line in bake_scene.py the day the loader can stage.
*
* The sequence data is deliberately NOT left here. An unused declaration is an unverified
* one with a live-looking name, and this project has already been bitten by exactly that
* (CHAR_TAB, dead and wrong by 8 bytes since P3.54).

pri_demo
                fcb     11
                fcb     SEQ_CHX,4
                fcb     1
                fcb     SEQ_CHX,4
                fcb     11
                fcb     SEQ_CHX,-4
                fcb     1
                fcb     SEQ_CHX,-4
                fcb     SEQ_GOTO
                fdb     pri_demo

* --- the vizier's sequence: Vwalk, ported verbatim -----------------------
* (harness/tools/peel_matrix.py rewrites pri_demo's body and finds its end by matching
* the line above this one. Keep them in step: the marker is in that file too.)
*
*     Vwalk    db chx,1              <- a ONE-OFF entry step, OUTSIDE the loop
*     Vwalk1   db 48,chx,2
*     Vwalk2   db 49,chx,6
*              db 50,chx,1
*              db 51,chx,-1
*              db 52,chx,1
*              db 53,chx,1
*              db goto / dw Vwalk1   <- loops to Vwalk1, NOT to Vwalk
*     [SEQTABLE.S:1513-1522]
*
* THE GOTO TARGET IS LOAD-BEARING. Looping to Vwalk would repeat the entry step every
* cycle and net 11 px instead of 10; 11 mod 4 = 3 puts every cel on FOUR phases, which
* needs 24 baked cels instead of 12 and would present as a vizier that is subtly wrong
* half the time rather than as an error.
*
* AND SO IS THE ENTRY STEP ITSELF, for a reason that only shows up in the bake: it
* moves x from 197 to 196 before cel 48 is ever drawn, which shifts every phase in the
* walk by one delta. P3.30 computed the phases without it (see co_variant).
*
* chx is mirrored by facing in the VM (P3.25-verified) and startV0 sets CharFace=-1
* [SUBS.S:1147], so these positive deltas carry him LEFT from 197 toward the princess
* at 120 -- 10 px per cycle, reaching her at step 45.
viz_walk        fcb     SEQ_CHX,1               ; the one-off entry step
viz_walk1       fcb     48,SEQ_CHX,2
                fcb     49,SEQ_CHX,6
                fcb     50,SEQ_CHX,1
                fcb     51,SEQ_CHX,-1
                fcb     52,SEQ_CHX,1
                fcb     53,SEQ_CHX,1
                fcb     SEQ_GOTO
                fdb     viz_walk1

* Vstop [SEQTABLE.S:1527] — one more step, the two stopping cels, then he holds.
*
*     Vstop  db chx,1
*            db 55,56
*            db goto / dw Vstand
*
* HE DOES NOT WALK INTO HER, and that is the point of this sequence: the scene's
* destination is the vizier standing in front of the princess [SUBS.S:716 "stops in
* front of princess"], not passing through her. It is NOT what fixed the overlap
* though -- the three-pass frame is (see vm_frameadv). Vstop stops him, and stopping
* him would have HIDDEN the overlap defect rather than fixed it, which is why the
* order here was fix first, then stop.
viz_stop        fcb     SEQ_CHX,1
                fcb     55,56
                fcb     SEQ_GOTO
                fdb     viz_stand

* Vstand [SEQTABLE.S:1496] — `db 54,goto / dw Vstand`, one cel, held.
viz_stand       fcb     54,SEQ_GOTO
                fdb     viz_stand

* --- the VM's cel-id table, generated from ALTSET2 ---------------------
                include "content/cutscene/cel_table.s"

* --- the baked cels: segment streams for the runtime blitter, from
* --- harness/tools/cel_blit_prep.py. Data, not compiled sprites.
                include "content/cutscene/chars/pslump.s"

* --- the walk: 6 cels x 2 sub-byte phases, and the table that picks between
* --- them. Both generated by harness/tools/bake_walk.py from one derivation.
* --- the SCRIPTS only. The cel pixels and the [cel][facing][phase] table went to
* --- content/cutscene/chars/cel_image.s, linked at $C000 and read off disk (P3.71).
                include "content/cutscene/chars/walk_scripts.s"

* --- the two slots, initialised from the oracle's own start positions ----
* startV0 CharX=197, startP0 CharX=120, both CharFace=-1, floorY=151
* [SUBS.S:1131,1147,1040]. These remain the authority for where they stand.
viz_slot        fcb     197,151,-1,54           ; x, y, face, cel id (chtab6.A #54)
                fcb     48,5                    ; h, w
                fdb     0                       ; CH_PTR: the cel is in the $C000 image
                fdb     VIZ_PEEL_BASE
                fcb     0                       ; Fdx — the VM writes this per cel
                fdb     VIZ_PEEL                ; slot stride: widest vizier cel
                fcb     1                       ; parity of cel 54 (Fcheck $80, ODD)
pri_slot        fcb     120,151,-1,25           ; x, y, face, cel id (chtab6.A #25)
                fcb     43,5
                fdb     0                       ; CH_PTR: the cel is in the $C000 image
                fdb     PRI_PEEL_BASE
                fcb     0                       ; Fdx
                fdb     PRI_PEEL                ; slot stride: widest princess cel
                fcb     1                       ; parity of cel 11 (Fcheck $80, ODD)

ch_base         fdb     0
ch_slot         fcb     0
ch_idx          fcb     0
ch_bit          fcb     0
ch_seen         fcb     0               ; bit per (character,slot): background saved?
ch_move         fcb     0
ch_cp           fcb     0               ; which pass is running (CP_ERASE/SAVE/DRAW)
ch_anymove      fcb     0               ; did ANYTHING move this frame — see ch_scan
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
ch_last         rmb     32              ; 2 chars x 2 slots x (x,y,w,h,par + 3 spare)
ch_drawn        rmb     4               ; the cel each buffer was last DRAWN with
ch_bits         fcb     1,2,4,8         ; seen bit for (character, slot)
ch_tick         fcb     0
ch_dir          fcb     CH_STEP
ch_tx           fcb     0
ch_ty           fcb     0
ch_h            fcb     0
ch_w            fcb     0
ch_fdx          fcb     0
ch_lastcel      fcb     0
ch_par          fcb     0               ; the parity of the cel being placed
ch_col          fcb     0               ; the byte column co_setup placed the cel at
cv_ix           rmb     2               ; co_variant's 16-bit table index (P3.65)
ch_fore         fcb     0               ; did anyone draw on the pillar this frame?
ch_tmp          fcb     0
ch_cel          fdb     0               ; the variant resolved for THIS draw — not
*                                       ; state, a value carried from char_one to
*                                       ; co_draw so the phase is resolved once
ch_rec          fdb     0
ch_dest         fdb     0
ch_peel         fdb     0
ch_tmp16        fdb     0

