* src/engine/blit_core.s
*
* POP CoCo3 — THE SHARED STACK-BLAST BLIT CORE (P3.20, piece D).
*
* ---------------------------------------------------------------
* WHAT THIS REPLACES, AND WHY THE OLD RULING DOES NOT APPLY
* ---------------------------------------------------------------
* gfx.s carries HAL_gfx_blit_sprite behind `ifdef POP_HAL_RUNTIME_BLIT`, ruled
* INFEASIBLE by PA.6 at 54 cy/byte aligned / 88 shifted. That ruling is correct
* about that routine and does not transfer here: it computed the sub-byte shift AT
* RUNTIME, PER BYTE (2-6 LSR + 2-6 ROR + merge) and stack-pushed its loop counter
* per byte. Both are properties of that implementation.
*
* P3.18 measured that each cutscene cel is drawn at only 1-2 of the four sub-byte
* columns, so the shift is affordable to BAKE INTO THE DATA (1.20x RAM, not 4x).
* This blitter therefore never shifts. P3.19 cycle-counted the result at 66% of one
* hardware frame for the heaviest cutscene frame, against the strawman's 5.4x-over.
*
* ---------------------------------------------------------------
* THE CORE: PULU ASCENDS, PSHS DESCENDS, AND THAT IS LOAD-BEARING
* ---------------------------------------------------------------
*     pulu d,y      reads src[0:2]->D, src[2:4]->Y     (U += 4)
*     pshs d,y      writes so ASCENDING from new S: D,Y (S -= 4)
*
* Each GROUP lands in the right order; successive groups land at DESCENDING
* addresses. harness/tools/cel_blit_prep.py bakes each blast segment's groups in
* that consumption order (high address first, 1-3 byte tail last) and PROVES it by
* replaying the 6809 semantics byte-by-byte before emitting. Nothing here is
* trusted to reasoning -- PA.9 shipped an inverted PSHU mapping whose checker was
* structurally unable to see it.
*
* FOUR-BYTE GROUPS, NOT SIX. `pulu d,x,y` would move six, but X is this blitter's
* destination pointer and PULU would clobber it. `pulu d,y` moves four for 18 cy
* = 4.5 cy/byte, inside the 4.5-5.8 band P3.19 measured for real 4-9 byte rows.
*
* S IS THE STACK POINTER. Every entry point here masks interrupts and parks the
* real S. The masked window is the cost P3.19 flagged: a full character draw is a
* few thousand cycles with IRQ off.
*
* ---------------------------------------------------------------
* SEGMENT FORMAT (per row, from cel_blit_prep.py)
* ---------------------------------------------------------------
*   $00            end of row
*   $01 nn         skip nn transparent bytes
*   $02 nn <data>  blast nn opaque bytes (groups pre-reversed)
*   $03 nn <pairs> merge nn bytes as (mask,src): dest = (dest AND mask) OR src
*
* Transparency is index 0 and there is no opacity sidecar (P3.18 3B), so the mask
* is built from index-0 pixels at bake time.
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                export  blit_cel
                export  blit_save
                export  blit_erase
                export  blit_blast
                export  blit_cel_full
                export  blit_save_full
                export  blit_erase_full
                endc

FB_STRIDE       equ     80              ; 320 px at 4 px/byte, the 4-colour mode

SEG_END         equ     $00
SEG_SKIP        equ     $01
SEG_BLAST       equ     $02
SEG_MERGE       equ     $03

* ---------------------------------------------------------------
* blit_cel — draw one pre-shifted cel, masked, into the framebuffer.
*
*   Entry: X = destination address (top-left of the cel in the draw buffer)
*          U = cel data: byte 0 = rows, byte 1 = width in bytes, then segments
*   Exit:  CC.C clear. A,B,D,X,Y,U clobbered. Interrupts restored to entry state.
*
* The caller supplies the byte column; the PHASE is already in the data, so there
* is no sub-byte argument and nothing to get wrong at the call site.
* ---------------------------------------------------------------
* ---------------------------------------------------------------
* ★★ THE UNCLIPPED ENTRIES — for callers that have no clip window of their own.
*
* The clip window (bc_lead/bc_keep) is GLOBAL, set by co_setup for the character it is
* about to place. The torches are not characters: the room draws them straight through
* blit_tab and never calls co_setup — so on the first build of the clip they inherited
* whatever window the last character draw had left behind, and came back 30 flame bytes
* wrong and 296 room bytes disturbed.
*
* A global that some callers must remember to set is a trap, so the callers who do not
* clip get their own doors instead. blit_cel takes a BOUND, so $FF is "wider than any
* cel"; the peel pair takes a COUNT, so theirs is the width already in B.
* ---------------------------------------------------------------
blit_cel_full
                clr     bc_lead
                lda     #$FF                    ; a bound, not a count — nothing is trimmed
                sta     bc_keep
                bra     blit_cel

blit_save_full
                clr     bc_lead
                stb     bc_keep                 ; B is the width: save all of it
                lbra    blit_save

blit_erase_full
                clr     bc_lead
                stb     bc_keep
                lbra    blit_erase

blit_cel
                pshs    cc
                orcc    #$50                    ; S becomes a data pointer below
                sts     bc_saved_s

                lda     ,u+                     ; rows
                sta     bc_rows
                lda     ,u+                     ; width (bytes) — the row stride
                sta     bc_width
                stx     bc_rowbase
* ★★ THE CLIP WINDOW FOR THIS ROW (P3.78d). bc_lead/bc_keep come from co_setup and are
* offsets into the CEL, so the window in destination addresses is [base+lead,
* base+lead+keep). Both bounds travel with the row, exactly as bc_rowbase does.
*
* A keep of ZERO means the cel is wholly off screen: every segment trims to nothing, the
* row loop still runs, and not one byte is written. That is where the vizier's exit ends
* up, and it has to cost nothing rather than be special-cased at the call site — co_erase
* must walk the same geometry to restore what the save took.
* ★★ SIXTEEN-BIT, BECAUSE `leax a,x` TAKES A AS A **SIGNED** BYTE. blit_cel_full passes
* bc_keep = $FF meaning "wider than any cel", and as a signed offset that is MINUS ONE — so
* clip_hi landed BELOW clip_lo, every segment trimmed to nothing, and the torches stopped
* drawing entirely. The room suite called it "flames did not move between the captures - a
* still picture", which is what a window of negative width looks like from outside.
                ldb     bc_lead
                clra
                leax    d,x                     ; unsigned, 16-bit
                stx     bc_clip_lo
                ldb     bc_keep
                clra
                leax    d,x
                stx     bc_clip_hi              ; one PAST the last writable byte

bc_row
                ldx     bc_rowbase              ; X walks this row's destination

bc_seg
                lda     ,u+                     ; segment opcode
                lbeq    bc_row_done             ; SEG_END (long: the trim grew this)
                cmpa    #SEG_SKIP
                beq     bc_skip
                cmpa    #SEG_BLAST
                beq     bc_blast
* --- SEG_MERGE: dest = (dest AND mask) OR src, one byte at a time --------
* 22 cy/byte, and that is a 6809 FLOOR rather than an estimate: there is no
* 16-bit AND/OR against memory and no register-to-register logic op (no `ora b`),
* so a masked byte cannot be done two at a time. P3.19 counted this exact
* sequence.
                lda     ,u+                     ; count
                sta     bc_count
                bsr     bc_trim                 ; -> bc_pre / bc_run, each 0..count
                lda     bc_pre
                beq     bm_run
                leax    a,x                     ; step over the part left of the window
                lsla                            ; ...TWO source bytes per destination byte
                leau    a,u
bm_run
                lda     bc_run
                beq     bm_post
                sta     bc_count
bc_merge_loop
                lda     ,x                      ; 4  read destination
                anda    ,u+                     ; 6  keep where the cel is clear
                ora     ,u+                     ; 6  take the cel elsewhere
                sta     ,x+                     ; 6  write back
                dec     bc_count
                bne     bc_merge_loop
bm_post
                lda     bc_seglen
                suba    bc_pre
                suba    bc_run                  ; whatever is right of the window
                lbeq    bc_seg
                leax    a,x
                lsla
                leau    a,u
                lbra    bc_seg

bc_skip
                lda     ,u+                     ; count — transparent, draw nothing
                leax    a,x                     ; but the pointer still has to move
                lbra    bc_seg

bc_blast
                lda     ,u+                     ; count
                sta     bc_count
                bsr     bc_trim
                lda     bc_pre
                beq     bb_run
                leax    a,x                     ; ONE source byte per destination byte here
                leau    a,u
bb_run
                lda     bc_run
                beq     bb_post
                sta     bc_count
                leas    a,x                     ; S = one past the part we are keeping
                ldy     #bc_blast_back
                sty     bb_ret
                jmp     blit_blast              ; NOT jsr — see blit_blast's header
bc_blast_back
* ★★★ PUT THE REAL STACK BACK, IMMEDIATELY. This one instruction is the whole of the two
* flame bytes, and blit_blast's own header states the rule I broke:
*
*     "S IS THE DESTINATION POINTER while this runs... Anything that touches S implicitly
*      (jsr, rts, pshs of the return, an interrupt) is unsafe inside a blast."
*
* The pre-clip walker obeyed it by accident: it contained no call of any kind, so S could
* stay a framebuffer pointer from the first blast right through to `lds bc_saved_s` at the
* end of the cel. P3.78d added `bsr bc_trim` to the segment walk — and a `bsr` executed
* after a blast pushes its return address INTO THE FRAMEBUFFER, two bytes below wherever
* the blast left S, and `rts` reads them back from there.
*
* MEASURED, and the data is what proved it rather than the argument: in torch 1 cel 8,
* rows 5 and 6 are the ONLY two rows of thirteen that contain a BLAST segment — and screen
* rows 106 and 107 are exactly the two bytes that were wrong. Each row's merge `bsr`
* landed on the PREVIOUS row's col 50. Two wrong bytes out of thirty-nine, localised, at a
* first column: the extent, the position and the row-selection all follow from it.
                lds     bc_saved_s              ; ...before any bsr/rts can run again
                lda     bc_run
                leax    a,x                     ; X past the kept part
bb_post
                lda     bc_seglen
                suba    bc_pre
                suba    bc_run
                lbeq    bc_seg
                leax    a,x
                leau    a,u
                lbra    bc_seg

* ---------------------------------------------------------------
* bc_trim — how much of this segment lies inside the row's clip window?
*
* Entry: X = the segment's first destination byte, bc_count = its length.
* Exit:  bc_seglen = that length, kept because bc_count is reused as a loop counter
*        bc_pre    = bytes before the window — skip them
*        bc_run    = bytes to write
*        the remainder, seglen - pre - run, lies right of the window.
* Clobbers A, B, bc_segx. X is unchanged.
*
* WHY PER SEGMENT AND NOT PER BYTE. The merge path is a measured 6809 floor at 22 cy/byte
* (P3.19) and a bounds test inside it would cost about a third again. Segments are RUNS, so
* the test happens once per run instead — and for a character fully on screen every segment
* takes the `ble`/`blo` fast exits and nothing is added to the inner loop at all.
*
* THE ADDRESS MATHS IS DONE AS DIFFERENCES, which is what keeps it signed-safe: the
* framebuffer is at $8000-$BBFF, negative as a signed 16-bit number, but every subtraction
* here is between two addresses at most a cel-width apart, so the result is a small signed
* value and `ble` reads it correctly.
* ---------------------------------------------------------------
bc_trim
                stx     bc_segx
                lda     bc_count
                sta     bc_seglen
                clr     bc_pre
                clr     bc_run
* ★ THE UNCLIPPED FAST PATH. blit_cel_full sets bc_keep = $FF to mean "wider than any
* cel", and for those callers — the torches — there is nothing to trim and no reason to
* compute it. Taking the whole segment here skips four 16-bit subtractions per run on a
* path that draws every frame.
                lda     bc_keep
                cmpa    #$FF
                bne     bt_clipped
                lda     bc_seglen
                sta     bc_run                  ; the entire segment, untouched
                rts
bt_clipped
* pre = clip_lo - X, clamped to [0, seglen]
                ldd     bc_clip_lo
                subd    bc_segx
                ble     bt_run                  ; segment starts at or after the window
                tsta
                bne     bt_allpre               ; more than 255 short of it
                cmpb    bc_seglen
                bhs     bt_allpre               ; the whole segment is left of the window
                stb     bc_pre
bt_run
* run = min(X + seglen, clip_hi) - X - pre
                ldd     bc_segx
                addb    bc_seglen
                adca    #0
                cmpd    bc_clip_hi              ; ADDRESSES, so unsigned
                blo     bt_end
                ldd     bc_clip_hi
bt_end
                subd    bc_segx
                ble     bt_done                 ; the window ends at or before the segment
                subb    bc_pre
                bls     bt_done                 ; the pre already covers all of it
                stb     bc_run
bt_done
                rts
bt_allpre
                lda     bc_seglen
                sta     bc_pre                  ; ...and run stays 0
                rts

bc_row_done
                ldx     bc_rowbase
                leax    FB_STRIDE,x
                stx     bc_rowbase
                ldx     bc_clip_lo              ; the window travels with the row
                leax    FB_STRIDE,x
                stx     bc_clip_lo
                ldx     bc_clip_hi
                leax    FB_STRIDE,x
                stx     bc_clip_hi
                dec     bc_rows
                lbne    bc_row

                lds     bc_saved_s
                puls    cc
                andcc   #$FE
                rts

* ---------------------------------------------------------------
* blit_blast — THE SHARED CORE. Move bc_count bytes: source ascends from U,
* destination descends from S.
*
* Callers: blit_cel's blast segments, blit_save, blit_erase. All three are
* per-frame paths and all three own their data layout, which is what lets them
* share one mover. (The intro's picture blitter does NOT call this -- see the
* note at the foot of this file.)
*
*   Entry: U = source, S = one past the destination end, bc_count = bytes,
*          bb_ret = the return address
*   Exit:  U advanced, S decreased by bc_count. A,B,D,Y clobbered; X PRESERVED.
*          Interrupts must already be masked by the caller.
*
* ENTERED BY JMP, NOT JSR, AND RETURNS THROUGH bb_ret. This is not a style choice:
* S IS THE DESTINATION POINTER while this runs, so a JSR would push its return
* address into the framebuffer -- corrupting the pixels it is about to write AND
* the address it would return to. Caught the first time this ran: the room reached
* the draw and hung. Anything that touches S implicitly (jsr, rts, pshs of the
* return, an interrupt) is unsafe inside a blast, which is also why the callers
* mask interrupts.
* ---------------------------------------------------------------
blit_blast
                lda     bc_count
bb_loop
                cmpa    #4
                blo     bb_tail
                sta     bc_tmp
                pulu    d,y                     ; 9   four bytes in
                pshs    d,y                     ; 9   four bytes out
                lda     bc_tmp
                suba    #4
                bne     bb_loop
                jmp     [bb_ret]
bb_tail
                cmpa    #2
                blo     bb_one
                sta     bc_tmp
                pulu    d                       ; 7
                pshs    d                       ; 7
                lda     bc_tmp
                suba    #2
                beq     bb_done
bb_one
                tsta
                beq     bb_done
                pulu    a                       ; 6
                pshs    a                       ; 6
bb_done
                jmp     [bb_ret]

* ---------------------------------------------------------------
* blit_save / blit_erase — POP PEELS.
*
* The room is a still picture and is never cleared, so a character has to put back
* what it covered. save copies the footprint out before the draw; erase puts it back
* before the next one.
*
* THE PEEL IS A PLAIN FORWARD COPY, NOT A STACK-BLAST, and that is a CORRECTION to
* P3.20. That version used blit_blast both ways, on the argument that save and erase
* are exact inverses so a group-reversed peel could never be observed. THE ARGUMENT
* IS FALSE for any width that is not a multiple of 4: blit_blast reverses GROUP
* order, and with a tail the partition is asymmetric, so the permutation is not an
* involution. At width 5 it is a rotation --
*
*     save   peel = [fb4, fb0, fb1, fb2, fb3]
*     erase  fb   = [fb3, fb4, fb0, fb1, fb2]      rotated again, not restored
*
* -- so the background rotated one byte further every frame. That is why the error
* ACCUMULATED, and why two captures twelve frames apart disagreed (36 vs 33 wrong
* bytes) rather than failing identically. Non-determinism was the tell.
*
* CONSEQUENCE FOR "ONE CORE", stated rather than buried: blit_blast now has ONE
* caller (the sprite blast) instead of three. The peel cannot share it because the
* peel's source is live memory whose layout it does not control -- the same reason
* P3.20 gave for not retrofitting the picture blitter, which turns out to apply more
* widely than it looked.
*
*   Entry: X = framebuffer address (top-left), Y = peel buffer,
*          A = rows, B = width in bytes
* ---------------------------------------------------------------
blit_save
* ★ CLIPPED SINCE P3.78d, AND THE PEEL'S STRIDE DELIBERATELY IS NOT. Only the bytes inside
* the window are read from the framebuffer, because only those are the ones blit_cel wrote
* — but the peel row still advances by the CEL's full width, because CH_STRIDE and
* blit_erase both index it by that. co_erase recomputes the identical window from the
* STORED x and width, so the restore covers exactly the span the save took.
                pshs    cc,x,y,u
                sta     bc_prows
                stb     bc_width
                sty     bc_peelrow
bs_row
                tfr     x,u                     ; U = framebuffer row (source)
                ldy     bc_peelrow
                lda     bc_lead
                leau    a,u                     ; both sides step over the off-screen left
                leay    a,y
                lda     bc_keep
                beq     bs_next                 ; wholly off screen: save nothing
                lsra
                sta     bc_pairs
                lda     bc_keep
                anda    #1
                sta     bc_odd
                lda     bc_pairs
                beq     bs_odd                  ; fewer than two bytes in the window
* THE PAIR COUNTER LIVES IN MEMORY, and `decb` is not an option: `ldd ,u++`
* clobbers B. The shipped version used memory for exactly this reason and a first
* attempt at hoisting moved the counter into B, which decremented a pixel byte
* instead of the counter and hung the room. The win here is hoisting the WIDTH
* arithmetic out of the row loop, not the counter.
                lda     bc_pairs
                sta     bc_count
bs_pair
                ldd     ,u++                    ; 8   forward read
                std     ,y++                    ; 8   forward write — a true COPY
                dec     bc_count                ; NOT decb — ldd ,u++ clobbers B
                bne     bs_pair                 ; 3
bs_odd
                lda     bc_odd
                beq     bs_next
                lda     ,u                      ; the odd trailing byte
                sta     ,y+
bs_next
* THE PEEL ROW ADVANCES BY THE CEL'S WIDTH, not by what the window kept — blit_erase and
* CH_STRIDE both index it that way, so a clipped save must still leave the stride intact.
                ldy     bc_peelrow
                lda     bc_width
                leay    a,y
                sty     bc_peelrow
                leax    FB_STRIDE,x             ; next framebuffer row
                dec     bc_prows
                bne     bs_row
                puls    cc,x,y,u
                rts

blit_erase
* The exact mirror of blit_save, window for window — see there for why.
                pshs    cc,x,y,u
                sta     bc_prows
                stb     bc_width
                sty     bc_peelrow
be_row
                tfr     x,u                     ; U = the FRAMEBUFFER row (destination)
                ldy     bc_peelrow
                lda     bc_lead
                leau    a,u
                leay    a,y
                lda     bc_keep
                beq     be_next                 ; wholly off screen: restore nothing
                lsra
                sta     bc_pairs
                lda     bc_keep
                anda    #1
                sta     bc_odd
                lda     bc_pairs
                beq     be_odd
* THE PAIR COUNTER LIVES IN MEMORY, and `decb` is not an option: `ldd ,u++`
* clobbers B. The shipped version used memory for exactly this reason and a first
* attempt at hoisting moved the counter into B, which decremented a pixel byte
* instead of the counter and hung the room. The win here is hoisting the WIDTH
* arithmetic out of the row loop, not the counter.
                lda     bc_pairs
                sta     bc_count
be_pair
                ldd     ,y++                    ; from the peel
                std     ,u++                    ; back into the framebuffer
                dec     bc_count                ; NOT decb — ldd ,y++ clobbers B
                bne     be_pair
be_odd
                lda     bc_odd
                beq     be_next
                lda     ,y
                sta     ,u
be_next
* X is the ROW BASE now and is never walked — U does the walking, from a copy of it — so
* the framebuffer advance is the whole stride rather than the remainder the old form had
* to compute. The peel advances by the CEL's width, for the reason blit_save states.
                ldy     bc_peelrow
                lda     bc_width
                leay    a,y
                sty     bc_peelrow
                leax    FB_STRIDE,x             ; next framebuffer row
                dec     bc_prows
                bne     be_row
                puls    cc,x,y,u
                rts


* ---------------------------------------------------------------
* WHY THE INTRO'S PICTURE BLITTER DOES NOT CALL blit_blast
* ---------------------------------------------------------------
* The dispatch asked for the picture path to be retrofitted to this core "where
* the work is genuinely the same". It is not, and the reason is the core's own
* contract rather than reluctance:
*
*   1. blit_blast writes DESCENDING. Its callers can only feed it because they
*      own their data layout -- the sprite stream is baked group-reversed, and the
*      peel buffer is written and read by the same pair. blit_splash's source is
*      `includebin content/intro/broderbund_splash.bin`, a raw asset in normal
*      order. Feeding it forward would emit every group back to front.
*   2. Fixing that means re-laying-out the asset at build time. That is an asset
*      transformation, gated by the protection catalog (CLAUDE.md 2B), for a blit
*      that runs ONCE PER SCREEN rather than per frame.
*   3. It is a different MODE: the splash is 16-colour, 140 B/row at 4bpp; this
*      core serves the 4-colour 80 B/row path.
*
* Sharing it would mean either an asset change or a mode/direction flag inside the
* mover -- the "flag-ridden routine" the dispatch explicitly warned against. The
* core is shared by the three per-frame callers instead. Recorded as a deviation
* rather than quietly skipped.
* ---------------------------------------------------------------

bc_saved_s      rmb     2               ; the real stack, parked while S blits
bc_rowbase      rmb     2
bc_rows         rmb     1
bc_prows        rmb     1
bc_width        rmb     1
bc_count        rmb     1
bc_tmp          rmb     1
bc_pairs        rmb     1       ; hoisted width/2 — recomputing these per
bc_odd          rmb     1       ;   row cost 127 cy/row instead of ~83
bb_ret          rmb     2       ; software return — S is busy being the destination

* --- THE CLIP WINDOW (P3.78d) -----------------------------------------------
* bc_lead / bc_keep are the CALLER's: co_setup computes them once per placement and all
* three primitives read them, which is what makes the draw, the save and the erase agree
* on one span. Exported because char_draw.s is a different object in the same bundle.
                ifdef   OBJTARGET
                export  bc_lead
                export  bc_keep
                endc
bc_lead         rmb     1       ; bytes of the cel suppressed at its LEFT
bc_keep         rmb     1       ; bytes actually written; 0 = wholly off screen
bc_clip_lo      rmb     2       ; the window in destination addresses, for this row
bc_clip_hi      rmb     2       ;   (hi is one PAST the last writable byte)
bc_pre          rmb     1       ; bc_trim's answer for the segment in hand
bc_run          rmb     1
bc_seglen       rmb     1       ; the segment's length, kept while bc_count counts
bc_segx         rmb     2       ; ...and its start, so the address maths can use subd
bc_peelrow      rmb     2       ; the peel row, advanced by the CEL width not the window
