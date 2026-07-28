* src/engine/lz_unpack.s
*
* POP CoCo3 — the shared LZ screen expander.
*
* LIFTED OUT OF intro_seq.s (P3.17) so the cutscene can use it. The routine was
* always general; only its ENTRY was specific -- it derived the blob address from
* LZ_LOAD_OFF, a constant sized for the intro's 2-track screens. The cutscene room
* packs to ONE track, so that constant is wrong for it and right for nothing in
* particular. The caller now passes the blob pointer in U and the module has no
* opinion about asset sizes.
*
* Format, packer, and the in-place safety argument: harness/tools/lz_pack.py.
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                export  lz_unpack
                endc

* One past the last readable byte of the draw window: $FE00-$FEFF is held constant
* by MC3=1 and $FF00 up is I/O, so neither belongs to a framebuffer. This is a
* property of the WINDOW, not of any asset, which is why it lives with the routine
* while the blob address does not.
LZ_SRC_END      equ     $FE00

* ---------------------------------------------------------------
* lz_unpack — expand a packed screen IN PLACE. X = framebuffer base (the output),
* U = the packed blob. The caller owns where the blob lives, so one module
* serves screens of different sizes -- the intro's 2-track 16-colour ones and
* the cutscene room's 1-track 4-colour one -- with no per-asset constant.
*
* The format is LZ4's block layout with offsets stored BIG-endian, so one `ldd`
* picks a distance up instead of two loads and a swap. [harness/tools/lz_pack.py]
*
*   token: high nibble = literal count, low nibble = match length - 4
*          a nibble of 15 means "add the following 255-chain"
*   then:  that many literal bytes, then a 2-byte distance back, then the match
*
* WHY IN PLACE IS SAFE. The writer walks up from X while the reader walks up from
* X+23040, and the writer produces faster than the reader consumes -- so the two
* converge. The packer computes the high-water mark of (written - consumed) for the
* actual stream and places it so the writer never arrives; the measured slack is
* 1,535 bytes on all three screens, and lz_pack.py PROVES it per screen by decoding
* out of a single buffer exactly as this routine does, rather than trusting the sum.
*
* The 1,536 bytes that make it fit are the difference between the 32 KB draw window
* and the 30,720 B framebuffer: $8000-$FDFF is usable, $FE00-$FEFF is held constant
* by MC3=1 and $FF00 up is I/O. [GIME-RM; gfx.s HAL_GFX_MODE_SERVICE]
*
* The match copy is byte-at-a-time on purpose -- a distance shorter than the length
* is how the format encodes a run, so the copy must read bytes this same loop has
* just written.
* Clobbers: everything except the framebuffer pointer the caller re-reads.
* ---------------------------------------------------------------
lz_unpack
                pshs    u,y
                ldd     ,u              ; unpacked length
                leay    d,x
                sty     lz_end          ; stop when the writer reaches here
                ldd     4,u             ; stream offset within the blob
                leau    d,u             ; U -> the stream
lz_token
* The reader must never leave the draw window. Past $FDFF lies constant RAM and
* then I/O -- a desynced stream would read the GIME and then WRITE it, remapping
* memory underneath the routine doing the writing. Stopping here turns a machine
* that scribbles over itself into a picture that is visibly wrong, which is a
* diagnosable failure instead of a destroyed one.
                cmpu    #LZ_SRC_END
                bhs     lz_done
                lda     ,u+
                sta     lz_tok
                lsra
                lsra
                lsra
                lsra                    ; literal count, 0..15
                tfr     a,b
                clra                    ; D = count
                cmpb    #15
                bne     lz_lits
                bsr     lz_extend
* The count CANNOT live in D across a copy loop: `lda ,u+` loads the byte into A,
* which is D's high half, so `subd #1` would be decrementing the data. Count in B
* with the high byte parked in lz_cnt -- B reaching 0 with lz_cnt still set means
* another 256 to go (B wraps to 255 on the next decb, which is exactly right).
lz_lits
                sta     lz_cnt          ; high byte of the count
                bne     lz_lit_loop
                tstb
                beq     lz_lits_done
lz_lit_loop
                lda     ,u+
                sta     ,x+
                decb
                bne     lz_lit_loop
                tst     lz_cnt
                beq     lz_lits_done
                dec     lz_cnt
                bra     lz_lit_loop
lz_lits_done
                cmpx    lz_end          ; the last token is literals and stops here,
                bhs     lz_done         ; with no distance following it
                ldd     ,u++            ; distance back — big-endian, one load
                coma
                comb
                addd    #1              ; D = -distance
                leay    d,x             ; Y -> the match, behind the write pointer
                lda     lz_tok
                anda    #15
                tfr     a,b
                clra
                cmpb    #15
                bne     lz_mlen
                bsr     lz_extend
lz_mlen
                addd    #4              ; MIN_MATCH
                sta     lz_cnt          ; same counting rule as the literals
lz_mloop
                lda     ,y+
                sta     ,x+
                decb
                bne     lz_mloop
                tst     lz_cnt
                beq     lz_mdone
                dec     lz_cnt
                bra     lz_mloop
lz_mdone
                cmpx    lz_end
                blo     lz_token
lz_done
                puls    y,u,pc

* lz_extend — D = the nibble's 15; add the 255-chain that follows at U.
* X is the live write pointer, so it is borrowed and put back.
lz_extend
                pshs    x
                tfr     d,x             ; accumulate in X
lz_ext_loop
                ldb     ,u+
                clra                    ; D = 0:B, so leax d,x is an unsigned add
                leax    d,x
                cmpb    #255
                beq     lz_ext_loop
                tfr     x,d
                puls    x,pc

* --- state ------------------------------------------------------
lz_tok          fcb     0               ; the token being decoded — the match nibble
*                                       ; is needed after the literals are copied
lz_end          fdb     0               ; one past the last output byte
lz_cnt          fcb     0               ; high byte of a copy count (see lz_lits)
