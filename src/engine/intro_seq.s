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
BEAT_COUNT      equ     6
SEQ_MAGIC       equ     $5E92

* --- the disk layout. Raw whole tracks, above the track-17 directory, with the
* --- granules reserved in the FAT so DECB will not allocate over them.
* --- [harness/tools/raw_tracks.py; karateka decb-loadm-boot-gates.md gate G1]
SECS_PER_TRACK  equ     18
* Screens are LZ-packed (harness/tools/lz_pack.py): 30,720 B raw = 7 tracks = 9.0 s
* each became 2 tracks = 2.6 s, measured, and the three of them 21 tracks -> 6.
SCREEN_TRACKS   equ     2
DISK_SCREEN_TRK equ     27              ; the packed Broderbund splash
DISK_SCREEN_SEC equ     SCREEN_TRACKS*SECS_PER_TRACK
DISK_PROLOG1_TRK equ    9               ; the first prologue picture
DISK_PROLOG2_TRK equ    18              ; the second
* Where a packed screen is read to, as an offset from the framebuffer base: the top
* of the usable draw window ($8000-$FDFF = 32,256 B) less the blob. Every screen is
* the same two tracks, so this is one constant rather than a per-screen table.
LZ_LOAD_OFF     equ     32256-SCREEN_TRACKS*4608
* One past the last readable byte of the window: $FE00-$FEFF is held constant by
* MC3=1 and $FF00 up is I/O, so neither belongs to the framebuffer.
LZ_SRC_END      equ     $FE00
* --- the wipe. The oracle's DblExpand IS the sweep (UNPACK.S WipeRgtExp): it walks
* --- 80 columns left to right straight into the page being displayed, and what
* --- LOOKS static is whatever the outgoing and incoming pictures share. Measured on
* --- the running oracle, the moving edge travels x=32..524 of 560 over 81 frames
* --- while the border rows stay quiet -- so the sweep is full-width and the static
* --- border is a property of the DATA, not of a restricted sweep region. Sweeping
* --- the whole content reproduces all four transitions (the splash over a cleared
* --- screen sweeps entirely; prolog1 over the splash shows only its text move).
WIPE_COL0       equ     10              ; first content column (the +20 px margin)
WIPE_COLS       equ     140             ; 280 content px / 2 px per byte
FB_A_BLOCK      equ     $10             ; MUST match gfx.s GFX_DB_A_BLOCK/B_BLOCK --
FB_B_BLOCK      equ     $14             ; lwasm's export does not carry equ symbols,
*                                       ; and P3.10 moved these once already.
DISK_BUNDLE_TRK equ     25              ; two tracks — palette + all three captions
DISK_BUNDLE_SEC equ     2*SECS_PER_TRACK

* --- runtime RAM, all of it ABOVE the LOADM image on purpose. DECB's DBUF0
* --- ($0600), DBUF1 ($0700), FAT ($0800) and FCBs ($094A) sit under $0A00, and
* --- writing over them is only safe once DECB has finished — which it has, by the
* --- time this code is executing. That is exactly why the assets are READ here
* --- rather than LOADED here.
* --- P3.7 moved this block ABOVE the engine. The bundle grew from one track to
* --- two when the title joined it (its patch is 5,909 B against the captions' 885
* --- and 687), and at $0A00 a 9,216-byte bundle would have run through $2000 and
* --- over the engine itself. Everything here is written by the program at run
* --- time, long after DECB is done, so the only constraint is not colliding with
* --- the engine, the trace buffer or the kernel.
BUNDLE          equ     $3000           ; 2 tracks = 9,216 B -> $3000..$52FF
BUNDLE_PAL      equ     BUNDLE+$000     ; 16 B
BUNDLE_PRESENTS equ     BUNDLE+$040
BUNDLE_BYLINE   equ     BUNDLE+$400
BUNDLE_TITLE    equ     BUNDLE+$800
SAVE_BUF        equ     $5400           ; clear of the bundle's end at $52FF
SAVE_MAX        equ     6144            ; the TITLE patch is 5,361 pixel bytes --
*                                       ; 7x the captions', and this buffer has to
*                                       ; hold the largest of them, not the last.

* --- SAM speed latches. The FDC cannot keep up at 1.78 MHz and HAL_gfx_init has
* --- already set it, so every transfer is bracketed slow/fast (idiom §8:
* --- force-slow -> do-I/O -> restore-speed, owned at the I/O-CALLER layer, not
* --- inside the primitive). CLAUDE.md §2G calls this rule PROVISIONAL, carried
* --- from karateka; POP is the first project to exercise it for real.
DSKREG          equ     $FF40           ; FDC control latch (write-only)
* --- THE SPLASH BANK (P3.11) -------------------------------------
* The Broderbund splash is wanted four times -- twice at beat 1 and twice again at
* beat 6, because a caption beat needs its base in BOTH buffers and the prologue
* pictures take both in between. At 9 s a read that was 36 s of stalling for one
* picture the machine has plenty of room to keep.
*
* Blocks $3C-$3F are free at BOTH ram sizes, and for the same reason: sys.s boots
* $FFA0-$FFA7 = $38-$3F, so $3C-$3F IS the CPU's $8000-$FFFF at boot -- and
* HAL_gfx_set_mode then replaces $FFA4-$FFA7 with the framebuffer, leaving those
* four blocks referenced by nothing. On 128 KB they alias to $0C-$0F (physical
* $18000), clear of the CPU map at $08-$0B and both buffers at $00-$07.
*
* The bank is reached through $FFA2 (CPU $4000-$5FFF), ONE block at a time. That
* slot normally holds part of the asset bundle and the patch save buffer -- but
* remapping does not destroy anything, it only changes what is addressable, and a
* base copy touches neither. $FFA0/$FFA1/$FFA3 are untouched, so the DP band, this
* code, the kernel and the stack all stay put.
*
* NOT the HAL's $FFA4-$FFA7: those are HAL-private (gfx.s says callers must never
* learn a buffer address) and this needs no knowledge of them -- it copies to and
* from HAL_gfx_draw_base like any other drawing code.
BANK_BLOCK      equ     $3C             ; 4 blocks = 32 KB, one screen + 2 KB spare
BANK_MMU        equ     $FFA2           ; the borrowed slot
BANK_MMU_HOME   equ     $3A             ; what sys.s left in it ($FFA0-$FFA7 = $38-$3F)
BANK_WINDOW     equ     $4000           ; CPU address a bank block appears at
BANK_CHUNK      equ     $2000           ; 8 KB per block
BANK_TAIL       equ     30720-3*BANK_CHUNK   ; the 4th block is only part used

SAM_SLOW        equ     $FFD8
SAM_FAST        equ     $FFD9

* Beat descriptor — 8 bytes. The intro is DATA in this table, not code.
BEAT_TRACK      equ     0               ; raw track of this beat's screen, 0 = inherit
BEAT_WIPE       equ     1               ; frames the picture SWEEPS in over (0 = flip)
BEAT_PATCH      equ     2               ; sparse caption patch, in the bundle
BEAT_PRE        equ     4               ; frames the clean base is held first
BEAT_HOLD       equ     6               ; frames the caption stays up

* ---------------------------------------------------------------
intro_seq_entry jmp     seq_start       ; $0200 — EXEC address

probe_status    fcb     0               ; $0203  0=boot, 2+n = beat n, BEAT_COUNT+2 = done
probe_beat      fcb     0               ; $0204  beat index currently running
probe_phase     fcb     0               ; $0205  0=pre 1=caption up 2=cleared
probe_magic     fdb     0               ; $0206
probe_loads     fcb     0               ; $0208  successful disk reads so far
probe_dskerr    fcb     0               ; $0209  WD1773 status of the first failure
probe_wipes     fcb     0               ; $020A  completed sweeps — the harness gates
*                                       ; the base capture on THIS, not on swaps:
*                                       ; a wiped beat never calls HAL_gfx_swap

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
* DONE is BEAT_COUNT+2, not a literal. probe_status carries beat+2, so with three
* beats the last one is 4 -- and a hardcoded 4 for "finished" collided with it.
                lda     #BEAT_COUNT+2
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
* THE INVARIANT, AND ITS LIMIT (corrected P3.9).
*
* A beat that brings a CAPTION leaves BOTH buffers holding its clean base, which is
* what lets the next beat inherit a guaranteed state rather than a hopeful one --
* exactly as AuthorCredit inherits PubCredit's.
*
* A beat that brings only a PICTURE does NOT (P3.8): with no caption there is
* nothing to repair, so it reads its picture once and leaves the previous screen on
* the hidden page. That is deliberate -- the second read costs 9 seconds -- but it
* means "both buffers are clean" is a property of CAPTION beats, not of all beats,
* and a beat may only inherit from a caption beat.
*
* Beat 6 is where that stops being academic: the prologue pictures have taken both
* buffers, so the reprise cannot inherit anything and re-establishes the splash
* itself. It is a caption beat, so it reads twice and restores the invariant for
* whatever follows.
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
                lda     BEAT_WIPE,x
                sta     beat_wipe
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
                lda     beat_wipe
                beq     sq_flip_in
* The picture SWEEPS in, the way DblExpand does. wipe_in consumes the pre-hold and
* leaves BOTH buffers holding the new picture -- the back because load_screen decoded
* it there, the front because the sweep copied it. That is what the oracle's
* unpacksplash + copy1to2 achieves, and it is why the second read below is not
* needed on a wiped beat.
                jsr     wipe_in
                ldd     #0
                std     beat_pre        ; the sweep WAS the pre-hold
                bra     sq_nobase
sq_flip_in
                jsr     HAL_gfx_swap
* The SECOND read exists only so the caption machinery has a clean copy on the
* hidden page to repair from. A beat with no caption never repairs anything, so it
* reads its picture ONCE -- which matters a great deal here: a 7-track read is ~9.2 s
* and the prologue beats were paying it twice, stalling on the previous screen for
* 18 seconds where the oracle (which batch-loads the whole stage up front) takes
* none at all.
                ldd     beat_patch
                beq     sq_nobase
                lda     beat_track
                jsr     load_screen
                lbne    seq_disk_fail   ; LONG: the sweep pushed this past 8-bit range
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
* A beat with NO patch is a picture and nothing else -- the prologue screens, which
* are the first beats to carry their own base. Everything from here to the repair is
* caption machinery and simply does not apply, so it is skipped rather than fed a
* null pointer (patch_blit on $0000 would walk whatever is at the bottom of memory).
                ldd     beat_patch
                beq     sq_nopatch
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
                bra     sq_beat_end

sq_nopatch
* The picture is already up -- the base load swapped it in at the top of the beat.
* Phase 1 means "this beat's content is showing" for a picture exactly as it does
* for a caption, so a watcher needs no special case.
                lda     #1
                sta     probe_phase
                ldd     beat_hold
                jsr     hold_frames
                lda     #2
                sta     probe_phase

sq_beat_end
                puls    b
                ldx     seq_beat
                leax    BEAT_SIZE,x
                incb
                cmpb    #BEAT_COUNT
                lblo    sq_beat         ; LONG branch: the base-only path pushed the
*                                       ; loop body past the 8-bit range
                rts

* ---------------------------------------------------------------
* load_screen — A = raw track; reads the framebuffer into the BACK buffer.
* Returns Z set on success. Clobbers: A, B, X, U
* ---------------------------------------------------------------
load_screen
* The splash comes from the BANK once the bank holds it; everything else, and the
* splash the very first time, comes from the disk. The first read is unavoidable --
* something has to put the picture in the bank -- so this saves three of the four.
                cmpa    #DISK_SCREEN_TRK
                bne     ls_from_disk
                tst     bank_valid
                beq     ls_from_disk
                lda     #1              ; bank -> back buffer, ~95 ms, no disk
                jsr     bank_copy
                clra                    ; Z set = success
                rts
ls_from_disk
                pshs    a               ; keep the track: the bank test needs it after
                ldx     HAL_gfx_draw_base
                leax    LZ_LOAD_OFF,x   ; the packed blob lands high in the window,
                ldb     #DISK_SCREEN_SEC ; above the picture it is about to become
                jsr     load_tracks
                bne     ls_failed
                ldx     HAL_gfx_draw_base
                jsr     lz_unpack       ; and expands down over itself
                lda     ,s              ; was that the splash, and is the bank empty?
                cmpa    #DISK_SCREEN_TRK
                bne     ls_done
                tst     bank_valid
                bne     ls_done
                clra                    ; back buffer -> bank, once, for free
                jsr     bank_copy
                inc     bank_valid
ls_done
                leas    1,s
                clra                    ; Z set = success
                rts
ls_failed
                leas    1,s
                lda     #1              ; Z clear = failure, as load_tracks reported
                tsta
                rts

* ---------------------------------------------------------------
* wipe_in — sweep the decoded picture onto the DISPLAYED page, column by column,
* left to right, spread over A frames. This is the port's DblExpand.
*
* THE ORACLE HAS ONE PAGE AND DESTROYS IT IN PLACE; we have two and the HAL maps
* only the back one, so the sweep copies BACK -> FRONT with the front paged in
* through $FFA2 (the same window bank_copy uses). Afterwards both buffers hold the
* new picture, which is exactly what unpacksplash + copy1to2 leaves behind.
*
* WHY THE SWEEP IS FULL-WIDTH. Jay saw the border stay still while the text swept,
* and that is real -- but it is not the sweep skipping the border. The oracle walks
* all 80 columns unconditionally; what looks static is whatever the outgoing and
* incoming pictures SHARE. Measured, the shared ring differs per transition:
*   cleared -> splash    cols  10..149 rows   0..191   (everything moves)
*   splash  -> prolog1   cols  17..141 rows  14..167
*   prolog1 -> prolog2   cols  28..126 rows  36..143
* A hard-coded swept region would be wrong for three of the four AND would leave
* 98-192 genuinely-differing cells unwritten. Sweeping everything reproduces all of
* them for free, and matches the running oracle: its moving edge travels x=32..524
* of 560 with the border rows quiet.  [P3.14 §1; UNPACK.S WipeRgtExp]
*
* Pacing is Bresenham -- add WIPE_COLS per frame, emit a column each time the
* accumulator passes the frame count -- because the 6809 has no divide.
* Entry: A = frames to spread the sweep over.  Clobbers: everything.
* ---------------------------------------------------------------
wipe_in
                pshs    y,u
                tfr     a,b             ; A = frames -> D = 0:frames
                clra
                std     wp_total
                std     wp_frames
                ldd     #0
                std     wp_acc
                ldd     #WIPE_COL0
                std     wp_col
                lda     #WIPE_COLS
                sta     wp_nleft
* The front buffer is the one HAL_gfx_cur_back does NOT name.
                lda     HAL_gfx_cur_back
                bne     wi_front_a
                lda     #FB_B_BLOCK
                bra     wi_front_set
wi_front_a      lda     #FB_A_BLOCK
wi_front_set    sta     wp_front
wi_frame
                ldd     wp_acc
                addd    #WIPE_COLS
                std     wp_acc
wi_due
                ldd     wp_acc
                cmpd    wp_total
                blo     wi_wait
                subd    wp_total
                std     wp_acc
                tst     wp_nleft
                beq     wi_wait
                bsr     wipe_col
                dec     wp_nleft
                ldd     wp_col
                addd    #1
                std     wp_col
                bra     wi_due
wi_wait
                jsr     HAL_time_vbl_wait
                ldd     wp_frames
                subd    #1
                std     wp_frames
                bne     wi_frame
wi_flush
                tst     wp_nleft        ; rounding: finish anything still owed, so the
                beq     wi_done         ; picture is COMPLETE when the sweep ends
                bsr     wipe_col
                dec     wp_nleft
                ldd     wp_col
                addd    #1
                std     wp_col
                bra     wi_flush
wi_done
                inc     probe_wipes
                puls    y,u,pc

* wipe_col — one column of 192 bytes, back buffer -> front buffer.
* The destination walks the $FFA2 window and steps to the next block whenever it
* runs off the end; a row is 160 bytes and the window is 8192, so each row crosses
* at most one boundary. B is the row counter and A carries the data -- never D,
* which a load through A would corrupt (idiom 38).
wipe_col
                ldd     HAL_gfx_draw_base
                addd    wp_col
                tfr     d,x             ; X -> the column in the BACK buffer
                ldd     #BANK_WINDOW
                addd    wp_col
                tfr     d,y             ; Y -> the same column in the mapped window
                lda     wp_front
                sta     wp_blk
                orcc    #$50
                sta     BANK_MMU
                andcc   #$AF
                ldb     #192
wc_loop
                lda     ,x
                sta     ,y
                leax    FB_STRIDE,x
                leay    FB_STRIDE,y
                cmpy    #BANK_WINDOW+8192
                blo     wc_next
                leay    -8192,y
                inc     wp_blk
                lda     wp_blk
                orcc    #$50
                sta     BANK_MMU
                andcc   #$AF
wc_next
                decb
                bne     wc_loop
                lda     #BANK_MMU_HOME
                orcc    #$50
                sta     BANK_MMU
                andcc   #$AF
                rts

* ---------------------------------------------------------------
* lz_unpack — expand a packed screen IN PLACE. X = framebuffer base, which is both
* where the blob was read to (X+LZ_LOAD_OFF) and where the picture goes (X).
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
                leau    LZ_LOAD_OFF,x   ; U -> the blob's 6-byte header
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

* ---------------------------------------------------------------
* bank_copy — A = 0 copies the back buffer INTO the bank, A != 0 copies the bank
* into the back buffer. 30,720 bytes either way, four blocks through $FFA2.
*
* ~95 ms against a 9-second disk read: 95x, and the difference between an intro
* that stalls for 36 seconds and one that does not.
*
* Interrupts are masked only around the MMU writes themselves (idiom §22 — a
* multi-register hardware update is a critical section), not across the copy: the
* VBL handler lives in the DP band and the kernel, neither of which is remapped
* here, so it is free to run.
* Clobbers: everything
* ---------------------------------------------------------------
bank_copy
                sta     bk_dir
                lda     #BANK_BLOCK
                sta     bk_blk
                ldd     HAL_gfx_draw_base
                std     bk_fb
                lda     #4
                sta     bk_n
bk_block
                pshs    cc
                orcc    #$50
                lda     bk_blk
                sta     BANK_MMU        ; this bank block now answers at $4000
                puls    cc

                ldy     #BANK_CHUNK
                lda     bk_n
                cmpa    #1
                bne     bk_len_ok
                ldy     #BANK_TAIL      ; the 4th block is only 6,144 bytes of screen
bk_len_ok
                ldx     #BANK_WINDOW
                ldu     bk_fb
                tst     bk_dir
                bne     bk_to_fb
bk_to_bank
                ldd     ,u++            ; framebuffer -> bank
                std     ,x++
                leay    -2,y
                bne     bk_to_bank
                bra     bk_block_end
bk_to_fb
                ldd     ,x++            ; bank -> framebuffer
                std     ,u++
                leay    -2,y
                bne     bk_to_fb
bk_block_end
                stu     bk_fb           ; U advanced over the framebuffer either way

                pshs    cc
                orcc    #$50
                lda     #BANK_MMU_HOME
                sta     BANK_MMU        ; give the slot back before anything reads it
                puls    cc

                inc     bk_blk
                dec     bk_n
                bne     bk_block
                rts

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
bank_valid      fcb     0               ; the bank holds the splash
bk_dir          fcb     0
bk_blk          fcb     0
bk_n            fcb     0
bk_fb           fdb     0
lz_tok          fcb     0               ; the token being decoded — the match nibble
*                                       ; is needed after the literals are copied
lz_end          fdb     0               ; one past the last output byte
lz_cnt          fcb     0               ; high byte of a copy count (see lz_lits)
beat_wipe       fcb     0               ; this beat's sweep duration, from the table
wp_total        fdb     0               ; Bresenham: columns per frame without a divide
wp_frames       fdb     0
wp_acc          fdb     0
wp_col          fdb     0
wp_nleft        fcb     0
wp_front        fcb     0               ; the DISPLAYED buffer's first block
wp_blk          fcb     0
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
* The third beat is TitleScreen, and P3.7 confirmed it from the source rather than
* from its comment. MASTER.S:823 reads "* Unpack title onto page 1" and then calls
* DeltaExpPop with delTitle — a `del*` blob, the same family as delPresents and
* delByline, NOT `unpacksplash`/DblExpand with a `pac*` one. SilentTitle settles
* it: it does unpacksplash + copy1to2 FIRST and only then DeltaExpPop delTitle,
* which would be pointless if the title carried its own picture.
*
* So the title is a THIRD CAPTION over the same Broderbund splash. Its track is 0
* like Mechner's. It is simply a much bigger caption -- 5,909 bytes against 885 and
* 687, and 34 frames to draw against 3.
* ---------------------------------------------------------------
beat_table
                fcb     DISK_SCREEN_TRK ; BEAT_TRACK   the Broderbund splash
                fcb      99               ; BEAT_WIPE    over a CLEARED screen, so the whole picture moves
                fdb     BUNDLE_PRESENTS ; BEAT_PATCH   "Broderbund Software Presents"
                fdb     99              ; BEAT_PRE
                fdb     281             ; BEAT_HOLD

                fcb     0               ; BEAT_TRACK   none — inherit beat 1's picture
                fcb       0               ; BEAT_WIPE    no track — a caption over the picture already up
                fdb     BUNDLE_BYLINE   ; BEAT_PATCH   "A Game by Jordan Mechner"
                fdb     96              ; BEAT_PRE
                fdb     283             ; BEAT_HOLD

                fcb     0               ; BEAT_TRACK   none — the title is a caption too
                fcb       0               ; BEAT_WIPE    same
                fdb     BUNDLE_TITLE    ; BEAT_PATCH   "Prince of Persia"
                fdb     112             ; BEAT_PRE     f1183 - f1065 = 118, MINUS the
*                                       ; ~6 frames patch_blit needs for a 5,361-byte
*                                       ; patch. The captions draw in well under a
*                                       ; frame so their pre IS the interval; this one
*                                       ; is big enough that the draw has to be paid
*                                       ; out of the hold to land on the oracle's frame.
                fdb     537             ; BEAT_HOLD    f1720 - f1183

                fcb     DISK_PROLOG1_TRK ; BEAT_TRACK  its OWN picture — first beat to
                fcb     101               ; BEAT_WIPE    measured: the oracle's edge runs x=32..524 in 81 frames
                fdb     0                ; BEAT_PATCH   none: the picture IS the beat
                fdb     101              ; BEAT_PRE     the oracle spends these wiping
*                                        ;              the picture in over the splash
                fdb     760              ; BEAT_HOLD    f1822 - f2582

                fcb     DISK_PROLOG2_TRK ; BEAT_TRACK   the second prologue picture
                fcb     101               ; BEAT_WIPE    CHOSEN, NOT oracle-derived — this beat's PRE is 0 because
*                                       ; the oracle's gap here is the
*                                       ; PrincessScene cutscene we have
*                                       ; not built (P3.13 §3D)
                fdb     0                ; BEAT_PATCH   none
                fdb     0                ; BEAT_PRE     back-to-back: the oracle's gap
*                                        ;              here is the PrincessScene
*                                        ;              cutscene, which is not built
                fdb     1564             ; BEAT_HOLD    f5753 - f7317

                fcb     DISK_SCREEN_TRK ; BEAT_TRACK   RE-ESTABLISH the splash. It is
*                                       ; not resident anywhere -- P3.4 put the
*                                       ; picture on disk and nowhere else -- and the
*                                       ; prologue has taken both buffers, so this
*                                       ; beat reads it back. SilentTitle does the
*                                       ; same thing for the same reason:
*                                       ; unpacksplash + copy1to2 BEFORE delTitle,
*                                       ; where TitleScreen (beat 3) just inherited.
                fcb     178               ; BEAT_WIPE    the reprise re-establishes the splash, then the title
                fdb     BUNDLE_TITLE    ; BEAT_PATCH   the SAME resident title caption
                fdb     178             ; BEAT_PRE     f7501 - f7317 = 184, less the
*                                       ; ~6 frames the title patch takes to draw
                fdb     310             ; BEAT_HOLD    f7811 - f7501

                ifdef   OBJTARGET
                endsection
                else
                end     intro_seq_entry
                endc
