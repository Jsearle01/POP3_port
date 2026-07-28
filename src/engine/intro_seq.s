* src/engine/intro_seq.s
*
* POP CoCo3 — THE INTRO SCREEN SEQUENCER.
*
* One mechanism, driven by data, running both opening credits. P3.3 built the
* sequencer with every asset poked in and resident; P3.4 takes the screen off the
* program image entirely and reads it from disk into the framebuffer.
*
* ---------------------------------------------------------------
* WHAT THE ORACLE ACTUALLY DOES (traced — P3.3 for the beats, P3.4 for the loads)
* ---------------------------------------------------------------
* PubCredit unpacks the splash and copies it to both pages; AuthorCredit does
* NOT — it has no unpacksplash and no copy1to2, and draws its byline straight onto
* the picture PubCredit left behind, which CleanScreen had restored to both pages.
* **The two credits are not two screens. They are one screen with two captions.**
* TitleScreen is AuthorCredit's shape again. [MASTER.S:693-830]
*
* Both caption transitions are PAGE FLIPS, and so is the drawing: the oracle flips
* to the clean page, draws on the now-hidden one, and flips back — the caption
* appears in a single frame and the screen checksum does not move once across the
* four frames of drawing. Same on the way out.
*
* AND IT DOES NOT TOUCH THE DISK WHILE ANY OF THAT HAPPENS. A write tap on the
* card window across the whole intro shows three bursts and two long silences:
*   f7..f196      boot + LoadStage1A       <- the entire stage, in one batch
*   f196..f2581   SILENT (39.8 s)          <- both credits, the title, the prologue
*   f2581..f2641  PrincessScene            <- ReloadStuff + LoadStage2
*   f2641..f5600  SILENT (49.3 s)
*   f5600..f5654  the second SetupDHires
* So the cadence is **batch the whole stage, then run many beats with no I/O at
* all** — not one-screen-at-a-time, not load-ahead. This file matches that: every
* asset is read before the first beat, and nothing touches the disk afterwards.
*
* ---------------------------------------------------------------
* WHERE THE SCREEN LIVES, AND WHY IT IS NOT IN THIS FILE ANY MORE
* ---------------------------------------------------------------
* The oracle expands its compressed screen STRAIGHT INTO the display pages and
* never holds an uncompressed copy anywhere. P3.3 did the opposite — 26,880 bytes
* resident, then blitted — and that is what put the program at 94% of its region.
*
* So the screen is stored on raw tracks in the shape it is displayed in (a full
* 160x192 framebuffer) and read directly into the back buffer. The asset's
* destination IS the framebuffer: no blit, no resident copy, and the +20 px
* centring of the virtual-resolution contract is baked into the stored image
* rather than applied at draw time. [harness/tools/make_intro_assets.py]
*
*   P3.3   packed, resident, blitted     26,880 B of program memory
*   P3.4   framebuffer, on disk, direct        0 B of program memory
*
* Resident now: this code, plus the caption patches and the palette (1,588 B read
* off disk into $0A00 at start-up, because they are consulted per-beat).
*
* AND IT RESOLVES THE LOADM CEILING (idioms §23) WITHOUT A BOOTLOADER. A program
* loading at $0200 fills its first granule across $0200-$0AFF, straight through
* DECB's DBUF0/DBUF1/FAT/FCB, and dies with ?FS ERROR before granule 2. With the
* screen gone the program is a few hundred bytes — one granule, ending below
* $0600 — so LOADM"INTROSEQ":EXEC works, and the program then reads its own assets
* with the HAL's WD1773 primitive, long after DECB has finished with those
* buffers. Small resident program, data loaded by its own reader: the oracle's
* shape, and the reason the ceiling stops mattering rather than being worked
* around.
* ---------------------------------------------------------------

                include "src/hal.inc"

                ifdef   OBJTARGET
                section prog
                export  intro_seq_entry
                import  disk_read_init
                import  disk_read_range
                else
                org     $0200
                endc
                ifdef   OBJTARGET
                * setdp is not permitted for the object target (P2.4).
                else
                setdp   0
                endc

* --- the disk primitive's parameter block. These are absolute addresses, and
* --- lwasm's `export` carries labels but not absolute `equ` symbols, so they
* --- cannot be imported -- they are derived here from the SAME -DDR_VARBASE the
* --- kernel is assembled with. build.bat passes one value to both, which is what
* --- keeps caller and primitive pointing at the same seven bytes.
* ---
* --- AND THE VALUE MUST BE WRITTEN 0x1F00, NOT $1F00. lwasm's -D takes a C-style
* --- literal; a `$`-prefixed one is silently accepted and defined as ZERO, with
* --- no warning. That put this block at $0000, on top of the HAL's DP scratch,
* --- and produced a disk read that failed with RNF on a track number some other
* --- routine had overwritten.
                ifndef  DR_VARBASE
DR_VARBASE      equ     $1F00
                endc
dr_track        equ     DR_VARBASE+0
dr_sector       equ     DR_VARBASE+1
dr_dest         equ     DR_VARBASE+2
dr_status       equ     DR_VARBASE+4
dr_r_track      equ     DR_VARBASE+5
dr_r_count      equ     DR_VARBASE+6

* ---------------------------------------------------------------
STACK_TOP       equ     $7F00           ; below the $8000 draw window, above the kernel
FB_STRIDE       equ     160             ; 320x192x16: 2 px/byte
BEAT_SIZE       equ     8
BEAT_COUNT      equ     2
SEQ_MAGIC       equ     $5E92

* --- the disk layout. Raw whole tracks, above the track-17 directory, with the
* --- granules reserved in the FAT so DECB will not allocate over them.
* --- [harness/tools/raw_tracks.py; karateka decb-loadm-boot-gates.md gate G1]
SECS_PER_TRACK  equ     18
DISK_SCREEN_TRK equ     27              ; tracks 27..33 — the 30,720 B framebuffer
DISK_SCREEN_SEC equ     7*SECS_PER_TRACK
DISK_BUNDLE_TRK equ     34              ; one track — palette + both caption patches
DISK_BUNDLE_SEC equ     SECS_PER_TRACK

* --- runtime RAM, all of it ABOVE the LOADM image on purpose. DECB's DBUF0
* --- ($0600), DBUF1 ($0700), FAT ($0800) and FCBs ($094A) sit under $0A00, and
* --- writing over them is only safe once DECB has finished — which it has, by the
* --- time this code is executing. That is exactly why the assets are READ here
* --- rather than LOADED here.
BUNDLE          equ     $0A00
BUNDLE_PAL      equ     BUNDLE+$000     ; 16 B
BUNDLE_PRESENTS equ     BUNDLE+$040
BUNDLE_BYLINE   equ     BUNDLE+$400
SAVE_BUF        equ     $1C00           ; = BUNDLE + one track
SAVE_MAX        equ     768             ; largest patch is 747 pixel bytes

* --- SAM speed latches. The FDC cannot keep up at 1.78 MHz and HAL_gfx_init has
* --- already set it, so every transfer is bracketed slow/fast (idiom §8:
* --- force-slow -> do-I/O -> restore-speed, owned at the I/O-CALLER layer, not
* --- inside the primitive). CLAUDE.md §2G calls this rule PROVISIONAL, carried
* --- from karateka; POP is the first project to exercise it for real.
DSKREG          equ     $FF40           ; FDC control latch (write-only)
SAM_SLOW        equ     $FFD8
SAM_FAST        equ     $FFD9

* Beat descriptor — 8 bytes. The intro is DATA in this table, not code.
BEAT_TRACK      equ     0               ; raw track of this beat's screen, 0 = inherit
BEAT_RSVD       equ     1
BEAT_PATCH      equ     2               ; sparse caption patch, in the bundle
BEAT_PRE        equ     4               ; frames the clean base is held first
BEAT_HOLD       equ     6               ; frames the caption stays up

* ---------------------------------------------------------------
intro_seq_entry jmp     seq_start       ; $0200 — EXEC address

probe_status    fcb     0               ; $0203  0=boot 2=beat1 3=beat2 4=done
probe_beat      fcb     0               ; $0204  beat index currently running
probe_phase     fcb     0               ; $0205  0=pre 1=caption up 2=cleared
probe_magic     fdb     0               ; $0206
probe_loads     fcb     0               ; $0208  successful disk reads so far
probe_dskerr    fcb     0               ; $0209  WD1773 status of the first failure

* ---------------------------------------------------------------
seq_start
                orcc    #$50            ; mask while the machine comes up
                lds     #STACK_TOP      ; stack OFF the remapped draw window
                clra
                tfr     a,dp            ; DP = 0

* --- the canonical boot prefix, in order, before anything else ---
* [idioms §21a] Step 0 first, always. Skipping it is the P2.6 interrupt storm.
                jsr     HAL_sys_init            ; step 0 — PIAs, MMU, MC3=1
                jsr     HAL_mem_size_detect     ; step 1 — discover before allocating
                jsr     HAL_time_init           ; step 2 — $010C VBL handler, VBORD
                andcc   #$EF                    ; opt in to real VBL waits (E1.c)

* --- the mode the ORACLE uses for the intro, not gameplay's ------
                lda     #GFX_MODE_320x192x16
                jsr     HAL_gfx_set_mode        ; clears both buffers, maps back @ draw_base

* --- the disk reader ---------------------------------------------
* AFTER HAL_sys_init, which is what puts the GIME in MC3=1 and so makes
* $FE00-$FEFF constant — the primitive lands its NMI handler and completion flag
* there precisely because that page survives every MMU remap the draw window does.
                jsr     disk_read_init

* --- everything the beats will need, in one batch, before the first beat -------
* The oracle's cadence, matched: one burst of I/O up front, then silence.
                ldx     #BUNDLE
                lda     #DISK_BUNDLE_TRK
                ldb     #DISK_BUNDLE_SEC
                jsr     load_tracks
                bne     seq_disk_fail

* --- the artwork's palette, now that it is in memory --------------
* set_mode installs a diagnostic palette (P2.5); this screen needs the Apple DHR
* palette the art was drawn against. MASKED (idioms §22): sixteen consecutive
* hardware writes are one logical update. AFTER the mode registers, never before
* (HAL_gfx_init Constraint B / idiom §9).
                pshs    cc
                orcc    #$50
                ldx     #BUNDLE_PAL
                ldu     #$FFB0
                ldb     #16
sq_pal          lda     ,x+
                sta     ,u+
                decb
                bne     sq_pal
                puls    cc

                jsr     seq_run
                lda     #4
                sta     probe_status
                ldd     #SEQ_MAGIC
                std     probe_magic
sq_hold         bra     sq_hold         ; the clean splash stays up; Jay observes here

seq_disk_fail
* No screen, and no pretending. Leave the status readable and stop — running the
* beats over a half-loaded framebuffer would present as a rendering bug.
                lda     dr_status
                sta     probe_dskerr
                lda     #$FF
                sta     probe_status
sq_dead         bra     sq_dead

* ---------------------------------------------------------------
* load_tracks — A = first track, B = sector count, X = destination.
* Returns Z set on success (Z clear = failed); dr_status holds the WD1773 status.
*
* Three things this wrapper owns that the primitive deliberately does not:
*   * SPEED. The FDC cannot keep up at 1.78 MHz, which HAL_gfx_init has already
*     set. Force slow, transfer, restore (idiom §8).
*   * INTERRUPTS. disk_read_range requires IRQ+FIRQ masked and NMI live: the
*     transfer blocks on the HALT line and the completion signal IS an NMI. By
*     this point the caller has CC.I clear for VBL waits, so mask and restore
*     exactly rather than assuming either state.
*   * The carry. It has to survive the speed restore, so it is captured first.
* Clobbers: A, B, X, U
* ---------------------------------------------------------------
load_tracks
                pshs    cc
                orcc    #$50
                sta     dr_r_track
                stb     dr_r_count
                stx     dr_dest
                clr     lt_err
                sta     SAM_SLOW        ; value irrelevant — the SAM latches on the write
                jsr     disk_read_range
                bcc     lt_ok
                com     lt_err
lt_ok
                clr     DSKREG          ; RELEASE THE DRIVE: motor off, no drive
*                                       ; selected, HALT disarmed. The primitive
*                                       ; leaves it spinning because karateka's only
*                                       ; client jumps straight into the game and
*                                       ; never runs another frame. The oracle does
*                                       ; the same thing explicitly -- every load in
*                                       ; MASTER.S is bracketed driveon..driveoff.
                sta     SAM_FAST
                puls    cc
                tst     lt_err
                bne     lt_done
                inc     probe_loads
lt_done
* Re-test as the LAST thing before returning. The first `tst` above is not enough:
* INC sets Z from its own result, so bumping the success counter to 1 cleared the
* Z this routine returns its verdict in, and every successful read reported
* failure. It presented as a disk error -- complete with a plausible WD1773 status
* byte, which was the expected end-of-track RNF terminator all along.
                tst     lt_err
                rts

* ---------------------------------------------------------------
* seq_run — walk the beat table.
*
* THE INVARIANT, which is what makes a beat composable: on entry to every beat and
* on exit from every beat, BOTH buffers hold the clean base image. That is what
* lets beat 2 carry no screen of its own — it inherits a guaranteed state rather
* than a hopeful one, exactly as AuthorCredit inherits PubCredit's.
* Clobbers: everything
* ---------------------------------------------------------------
seq_run
                ldx     #beat_table
                clrb
sq_beat
                stb     probe_beat
                stx     seq_beat        ; the beat pointer lives in ONE place
                pshs    b
* probe_status identifies the BEAT and is set once, here, from the loop counter
* that is already in B -- not recomputed mid-beat by reading probe_beat back.
* Re-reading it was the last surviving instance of the pattern this beat's
* descriptor caching removed, and it misread exactly the same way: $42 instead
* of 2 on beat 1, and 2 instead of 3 on beat 2.
                addb    #2
                stb     probe_status

* -- READ THE WHOLE DESCRIPTOR NOW, before anything else runs ------
* Every field is copied out up front and the table is not indexed again for the
* rest of the beat. The previous shape re-derived `ldx seq_beat / ldd FIELD,x`
* after each call, which looks safe and is not: HAL_gfx_swap does not preserve X
* (gfx_map_blocks walks it across $FFA4-$FFA7 and leaves it at $FFA8), so the
* reload had to be correct AND had to actually take effect across every routine
* in between. It did not: measured on the bus, `ldd BEAT_HOLD,x` read $FFAE/$FFAF
* -- the MMU registers -- and handed hold_frames $353F = 13,631 frames, which is
* the "collapsed hold" (it was a 227-second one).
*
* Copying the descriptor once removes the dependency rather than repairing it.
                lda     BEAT_TRACK,x
                sta     beat_track
                ldd     BEAT_PATCH,x
                std     beat_patch
                ldd     BEAT_PRE,x
                std     beat_pre
                ldd     BEAT_HOLD,x
                std     beat_hold

* -- this beat's screen, if it brings one --------------------------
* Read into the back buffer, show it, read again into the other one, so both pages
* hold it. The oracle's copy1to2 is a memory copy; here it is a second read,
* because only ONE buffer is CPU-addressable at a time — the $8000 window maps
* four 8 KB blocks and a 30,720-byte framebuffer needs all four. A chunked
* front-to-back copy through the spare MMU slots would be faster, and is the
* obvious move if this ever happens in front of the player. It does not: both
* reads finish before the first beat is visible.
                lda     beat_track
                beq     sq_nobase
                jsr     load_screen
                bne     seq_disk_fail
                jsr     HAL_gfx_swap
                lda     beat_track
                jsr     load_screen
                bne     seq_disk_fail
sq_nobase

* -- hold the clean base ------------------------------------------
* probe_phase is deliberately NOT cleared here. Phase 2 from the previous beat and
* phase 0 of this one describe the same visible state -- clean base, no caption --
* and clearing it made phase 2 last only as long as the repair, well under a frame.
* A once-per-frame observer then caught it or missed it by luck; P3.3 got lucky and
* P3.4 did not. Every state a watcher is expected to see now persists for the hold
* that belongs to it.
                ldd     beat_pre
                jsr     hold_frames

* -- draw the caption on the HIDDEN page, then reveal it ----------
                ldd     beat_patch
                std     seq_patch
                clr     seq_restore
                jsr     patch_blit      ; saves the clean bytes, then applies
                jsr     HAL_gfx_swap    ; the caption APPEARS, in one frame
                lda     #1
                sta     probe_phase

                ldd     beat_hold
                jsr     hold_frames

* -- hide it, then repair the page that carries it ----------------
* The flip is the disappearance. The repair happens afterwards, on the page nobody
* is looking at, which is why it can take as long as it likes.
                jsr     HAL_gfx_swap    ; the caption VANISHES, in one frame
                lda     #2
                sta     probe_phase
                lda     #1
                sta     seq_restore
                jsr     patch_blit      ; same runs, from the saved bytes

                puls    b
                ldx     seq_beat
                leax    BEAT_SIZE,x
                incb
                cmpb    #BEAT_COUNT
                blo     sq_beat
                rts

* ---------------------------------------------------------------
* load_screen — A = raw track; reads the framebuffer into the BACK buffer.
* Returns Z set on success. Clobbers: A, B, X, U
* ---------------------------------------------------------------
load_screen
                ldx     HAL_gfx_draw_base
                ldb     #DISK_SCREEN_SEC
                jmp     load_tracks

* ---------------------------------------------------------------
* hold_frames — wait D frames.
*
* 16-bit because the captions hold for 281 and 283 frames and HAL_time_delay takes
* a byte. Every wait is a real VBL: CC.I was cleared at boot, without which
* HAL_time_vbl_wait returns immediately and synthesises the count (Q001 N3=beta) —
* the loop still runs, the counters still advance, and the timing is fiction.
* Clobbers: A, B, CC
* ---------------------------------------------------------------
hold_frames
                pshs    y
                tfr     d,y             ; TFR does not touch CC on the 6809
hf_lp           cmpy    #0
                beq     hf_done
                jsr     HAL_time_vbl_wait
                leay    -1,y
                bra     hf_lp
hf_done         puls    y,pc

* ---------------------------------------------------------------
* patch_blit — apply a sparse caption patch, or take it back off.
*
* ONE ROUTINE, ONE GEOMETRY, TWO DIRECTIONS. Applying, it first copies the bytes
* it is about to overwrite into SAVE_BUF and then writes the patch; restoring, it
* copies those bytes back. Both directions walk the run list identically and
* advance the save pointer identically, so the restore reads back exactly what the
* apply wrote out, in the same order. The repair is therefore guaranteed to cover
* exactly what the caption covered — no second asset, no rectangle to keep in
* sync, nothing to get wrong independently.
*
* P3.3 read the repair bytes from the resident base image instead. That worked and
* cost 26,880 bytes; saving 747 bytes at apply time gets the same result from the
* buffer the caption is being drawn into. It also makes the routine independent of
* where the base came from, which is what let the screen move to disk at all.
*
* Format [harness/tools/dhr_delta.py]:
*     fdb first_row / fcb n_rows / per row: fcb n_runs, per run: fcb col, len, data*
* Coordinates are framebuffer coordinates — a screen patch has no placement
* freedom; it registers against the base picture and nowhere else.
* Clobbers: everything
* ---------------------------------------------------------------
patch_blit
                ldd     #SAVE_BUF
                std     pb_save
                ldx     seq_patch
                ldd     ,x++            ; first row, 16-bit; A is always 0 here
                stb     pb_row          ; rows are 0..191, so the low byte is the row
                lda     ,x+
                sta     pb_nrows
pb_rowlp
                lda     pb_row
                ldb     #FB_STRIDE
                mul                     ; 191*160 = 30,560, comfortably 16-bit
                addd    HAL_gfx_draw_base
                std     pb_dst
                lda     ,x+             ; runs in this row
                beq     pb_rownext
                sta     pb_nruns
pb_runlp
                clra
                ldb     ,x+             ; col, 0..159
                addd    pb_dst
                tfr     d,u             ; U = destination
                ldb     ,x+
                stb     pb_len
                ldy     pb_save
                tst     seq_restore
                bne     pb_restore

                pshs    u               ; --- save the clean bytes, then apply ---
pb_sv           lda     ,u+
                sta     ,y+
                decb
                bne     pb_sv
                sty     pb_save
                puls    u
                ldb     pb_len
pb_ap           lda     ,x+
                sta     ,u+
                decb
                bne     pb_ap
                bra     pb_runnext

pb_restore                              ; --- put the saved bytes back ---
pb_rs           lda     ,y+
                sta     ,u+
                decb
                bne     pb_rs
                sty     pb_save
                ldb     pb_len
                abx                     ; step over the patch's pixel bytes.
*                                       ; ABX is UNSIGNED. `leax b,x` is SIGNED
*                                       ; -128..+127 — the exact trap that sent the
*                                       ; P2.7 probe walking backwards into itself.
pb_runnext
                dec     pb_nruns
                bne     pb_runlp
pb_rownext
                inc     pb_row
                dec     pb_nrows
                bne     pb_rowlp
                rts

* ---------------------------------------------------------------
* State
* ---------------------------------------------------------------
beat_track      fcb     0               ; the current descriptor, copied out ONCE
beat_patch      fdb     0               ;   at beat entry. Nothing indexes the table
beat_pre        fdb     0               ;   again for the rest of the beat.
beat_hold       fdb     0
seq_beat        fdb     0               ; the beat under way. Held in a variable
*                                       ; rather than re-read from 1,S after every
*                                       ; call: the stack offset was correct but it
*                                       ; made every routine in between part of the
*                                       ; contract, and debugging that cost more
*                                       ; than the two bytes this costs.
seq_patch       fdb     0
seq_restore     fcb     0
lt_err          fcb     0
pb_row          fcb     0
pb_nrows        fcb     0
pb_nruns        fcb     0
pb_len          fcb     0
pb_dst          fdb     0
pb_save         fdb     0

* ---------------------------------------------------------------
* THE INTRO, AS DATA
*
* Frame counts are the measured on-screen transitions (P3.3), not tpause units:
*   beat 1  base up f306, caption in f405 (+99), out f686 (+281)
*   beat 2  caption in f782 (+96 from the clear), out f1065 (+283)
*
* Beat 2's track is 0 on purpose. It is not an omission and not an optimisation —
* AuthorCredit has no unpacksplash. The Mechner byline is a second caption on the
* Broderbund picture.
*
* The third beat is TitleScreen, structurally identical: track 0 (it reuses the
* splash), its own patch, 73 and 536. It is not here because its patch has not
* been converted — no longer because it does not fit, which was the point of P3.4.
* ---------------------------------------------------------------
beat_table
                fcb     DISK_SCREEN_TRK ; BEAT_TRACK   the Broderbund splash
                fcb     0               ; BEAT_RSVD
                fdb     BUNDLE_PRESENTS ; BEAT_PATCH   "Broderbund Software Presents"
                fdb     99              ; BEAT_PRE
                fdb     281             ; BEAT_HOLD

                fcb     0               ; BEAT_TRACK   none — inherit beat 1's picture
                fcb     0               ; BEAT_RSVD
                fdb     BUNDLE_BYLINE   ; BEAT_PATCH   "A Game by Jordan Mechner"
                fdb     96              ; BEAT_PRE
                fdb     283             ; BEAT_HOLD

                ifdef   OBJTARGET
                endsection
                else
                end     intro_seq_entry
                endc
