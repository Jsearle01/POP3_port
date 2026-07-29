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
blit_cel
                pshs    cc
                orcc    #$50                    ; S becomes a data pointer below
                sts     bc_saved_s

                lda     ,u+                     ; rows
                sta     bc_rows
                lda     ,u+                     ; width (bytes) — the row stride
                sta     bc_width
                stx     bc_rowbase

bc_row
                ldx     bc_rowbase              ; X walks this row's destination

bc_seg
                lda     ,u+                     ; segment opcode
                beq     bc_row_done             ; SEG_END
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
bc_merge_loop
                lda     ,x                      ; 4  read destination
                anda    ,u+                     ; 6  keep where the cel is clear
                ora     ,u+                     ; 6  take the cel elsewhere
                sta     ,x+                     ; 6  write back
                dec     bc_count
                bne     bc_merge_loop
                bra     bc_seg

bc_skip
                lda     ,u+                     ; count — transparent, draw nothing
                leax    a,x                     ; but the pointer still has to move
                bra     bc_seg

bc_blast
                lda     ,u+                     ; count
                sta     bc_count
                leas    a,x                     ; S = one past this segment's end
                ldy     #bc_blast_back
                sty     bb_ret
                jmp     blit_blast              ; NOT jsr — see blit_blast's header
bc_blast_back
                lda     bc_count
                leax    a,x                     ; X past the segment
                bra     bc_seg

bc_row_done
                ldx     bc_rowbase
                leax    FB_STRIDE,x
                stx     bc_rowbase
                dec     bc_rows
                bne     bc_row

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
                pshs    cc,x,y,u
                sta     bc_prows
                stb     bc_width
                lsrb                            ; hoisted: pairs = width/2
                stb     bc_pairs
                lda     bc_width
                anda    #1
                sta     bc_odd                  ; hoisted: is there a trailing byte
bs_row
                tfr     x,u                     ; U = framebuffer row (source)
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
                lda     bc_odd
                beq     bs_next
                lda     ,u                      ; the odd trailing byte
                sta     ,y+                     ; Y advances past it too
bs_next
                leax    FB_STRIDE,x             ; next framebuffer row
                dec     bc_prows                ; Y is ALREADY on the next peel row
                bne     bs_row
                puls    cc,x,y,u
                rts

blit_erase
                pshs    cc,x,y,u
                sta     bc_prows
                stb     bc_width
                lsrb                            ; hoisted, as in blit_save
                stb     bc_pairs
                lda     bc_width
                anda    #1
                sta     bc_odd
be_row
                tfr     y,u                     ; U = peel row (source)
* THE PAIR COUNTER LIVES IN MEMORY, and `decb` is not an option: `ldd ,u++`
* clobbers B. The shipped version used memory for exactly this reason and a first
* attempt at hoisting moved the counter into B, which decremented a pixel byte
* instead of the counter and hung the room. The win here is hoisting the WIDTH
* arithmetic out of the row loop, not the counter.
                lda     bc_pairs
                sta     bc_count
be_pair
                ldd     ,u++                    ; from the peel
                std     ,x++                    ; back into the framebuffer
                dec     bc_count                ; NOT decb — ldd ,u++ clobbers B
                bne     be_pair
                lda     bc_odd
                beq     be_next
                lda     ,u
                sta     ,x+
be_next
* X has walked exactly `width` bytes across this row, so it needs the REMAINDER of
* the stride, not the whole of it. Y is advanced explicitly because the source
* pointer here is U (a copy of Y), so Y itself never moved.
                lda     bc_width
                leay    a,y                     ; next peel row
                ldd     #FB_STRIDE
                subb    bc_width
                sbca    #0
                leax    d,x                     ; next framebuffer row
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
