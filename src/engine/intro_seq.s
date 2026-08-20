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
        import  disk_read_motor_off
                import  lz_unpack
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
BEAT_SIZE       equ     9       ; +1 for BEAT_SONG (P3.52)
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

* --- THE MUSIC PLAYER, read like every other asset -------------------------
* ★★★ IT IS NOT IN THE LOADM IMAGE, AND CLAUDE.md §2L IS WHY: the LOADM ceiling binds on
* what must be resident when Disk BASIC hands over, and nothing after. The player is
* 4,456 B carrying all thirteen songs; it arrives the same way the captions, the screens,
* the scene program and the cel pages do.
* ★★ ITS ENTRY POINTS ARE FIXED OFFSETS, not linker symbols — a unit read off a track has
* no symbols for its caller to import. Same relationship cutscene_room.s has with the
* flame bundle, and char_draw.s records what a moved offset costs.
DISK_MSYS_TRK   equ     32
DISK_MSYS_SEC   equ     1*SECS_PER_TRACK
MSYS_BASE       equ     $0A00
msys_init       equ     MSYS_BASE+0
msys_play       equ     MSYS_BASE+3     ; A = song id
msys_stop       equ     MSYS_BASE+6
msys_playing    equ     MSYS_BASE+9
MSYS_SIG        equ     $7E             ; the entry table opens with a JMP

* ★★ THE INTRO CARRIES FIVE SONGS, NOT TWELVE — read off the beat table below, which is
* the PLAN and the only home for the mapping:
*     beat 1 s_Presents   beat 2 s_Byline   beat 3 s_Title
*     beat 4 s_Prolog     beat 5 BEAT_SONG 0 (the PrincessScene gap)   beat 6 s_Sumup
* ★★★ THE OTHER SIX (ids 7-12) ARE THE CUTSCENE'S AND HAVE NO CALL SITE ANYWHERE. The
* player holds them and its entry table resolves them, but neither cutscene_room.s nor
* char_draw.s's beat schedule ever plays one: "song hold" in those files names a DURATION
* the disk reads are scheduled inside, not a song trigger. Wiring them is a mechanism that
* does not exist yet, not a widening of this one.

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

* ---------------------------------------------------------------
* ★★★ THE PRINCESS SCENE (P3.107) — a CALL BETWEEN BEATS, not a seventh beat.
*
* The oracle's own order [MASTER.S:695-709] is Prolog1, PrincessScene, SetupDHires,
* Prolog2, SilentTitle — so the scene sits between beat 4 (prolog1) and beat 5 (prolog2).
* It is not expressed as a beat because a beat's fields are track / wipe / patch / pre /
* hold / song, and the scene is none of those; MASTER.S calls PrincessScene as a peer of
* Prolog1 rather than a variant of it.
*
* ★★ THE SCENE OVERWRITES THE CAPTIONS AND THEY ARE RELOADED, WHICH IS THE ORACLE'S OWN
* MODEL. CUTPRINCESS calls LoadStage2, whose comment says it DISPLACES bgtab1-2 and
* chtab4. The scene's bundle expands to $3000..$4883, straight over BUNDLE_PRESENTS
* ($3040), BUNDLE_BYLINE ($3400) and BUNDLE_TITLE ($3800) — and beat 6 patches
* BUNDLE_TITLE, so they must come back. There is nowhere to hide them: P3.105 measured the
* GIME bank and all four free blocks at 128 KB are the scene's ($0C pinned, $0D/$0E/$0F
* rotating). Reload is not a preference, it is the only shape available.
*
* ★★★ AND THE $5400 OVERLAP IS SAFE ONLY BECAUSE BEATS 4 AND 5 CARRY NO PATCH.
* patch_blit saves what it overwrites into SAVE_BUF, and the TITLE caption's save is 5,361
* B — $5400..$68F1 — which runs straight through the scene's packed-bundle landing zone at
* $5800..$69FF [harness/tools/intro_patch_extent.py]. Nothing is live in SAVE_BUF across
* this call because beat 4 and beat 5 both have BEAT_PATCH 0. ★ That is a CONDITION, not a
* property, and beat_patch_check.py asserts it at build time rather than trusting this
* comment — a comment describing an unenforced discipline has failed here twice.
SCENE_AFTER_BEAT equ    3               ; 0-based: beat 4, prolog1
DISK_SCENE_TRK  equ     24              ; ★ NOT 17 — that is the RS-DOS DIRECTORY track,
*                                       ;   which carries no asset and is not free (P3.106)
                ifndef  SCENE_BASE
SCENE_BASE      equ     $2500
                endc
                ifndef  SCENE_CALL_OFF
SCENE_CALL_OFF  equ     11
                endc
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
BEAT_SONG       equ     8               ; the SONG whose length this beat's hold is (0 = none)

* --- the oracle's song numbers, Set 1 (title) [MASTER.S:114-121] ---------
S_PRESENTS      equ     1
S_BYLINE        equ     2
S_TITLE         equ     3
S_PROLOG        equ     4
S_SUMUP         equ     5

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

* --- the music player, in the SAME burst, before anything is on screen -----
* ★★★ IT CANNOT LAND VISIBLY, AND THAT IS STRUCTURAL RATHER THAN LUCKY. $0A00 is not in
* the draw window — HAL maps the back buffer at $8000 — so this read touches no
* framebuffer byte. It also happens inside the existing one-burst-of-I/O before the first
* beat, so it adds no second pause where the oracle has none.
                ldx     #MSYS_BASE
                lda     #DISK_MSYS_TRK
                ldb     #DISK_MSYS_SEC
                jsr     load_tracks
                bne     seq_disk_fail
* ★★ AND CHECK WHAT LANDED. A whole-track read ends on RNF by design, so "no error" is a
* weak claim; the entry table opens with a JMP. Without this, a bad read means the first
* beat JSRs into whatever is at $0A00. P4.21's probe found the same gap and closed it the
* same way.
                lda     MSYS_BASE
                cmpa    #MSYS_SIG
                bne     seq_disk_fail
                jsr     msys_init

* --- the artwork's palette, now that it is in memory --------------
* set_mode installs a diagnostic palette (P2.5); this screen needs the Apple DHR
* palette the art was drawn against. MASKED (idioms §22): sixteen consecutive
* hardware writes are one logical update. AFTER the mode registers, never before
* (HAL_gfx_init Constraint B / idiom §9).
                jsr     set_dhr_palette

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
                jsr     disk_read_motor_off  ; RELEASE THE DRIVE through the HAL (P3.76)
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
                lda     BEAT_SONG,x
                sta     beat_song

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

                ldx     beat_hold
                lda     beat_song
                jsr     play_song       ; the caption stays up for its song's length

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
                ldx     beat_hold
                lda     beat_song
                jsr     play_song       ; the picture stays up for its song's length
                lda     #2
                sta     probe_phase

sq_beat_end
                puls    b
* ★ THE SCENE GOES HERE — after beat 4 has finished and before the loop takes beat 5.
                cmpb    #SCENE_AFTER_BEAT
                bne     sq_no_scene
                pshs    b
                bsr     run_scene
                puls    b
sq_no_scene
                ldx     seq_beat
                leax    BEAT_SIZE,x
                incb
                cmpb    #BEAT_COUNT
                lblo    sq_beat         ; LONG branch: the base-only path pushed the
*                                       ; loop body past the 8-bit range
                rts

* ---------------------------------------------------------------
* set_dhr_palette — the sixteen registers the artwork was drawn against.
*
* ★★★ ONE HOME SINCE P3.107, AND IT WAS INLINE AND CALLED ONCE BEFORE THAT. set_mode
* installs a DIAGNOSTIC palette (P2.5), so anything that changes the video mode leaves the
* wrong sixteen colours behind — and the scene changes the mode twice, on the way in and on
* the way out. `load_screen` does NOT re-apply it: the startup path did, once, and that was
* enough while nothing else ever called set_mode.
*
* ★ Jay caught the consequence by eye — "you need to restore the DHRes palette" — after the
* mode restore was already in. The restore list in cutscene_room.s had called the palette
* self-correcting and cited this file's startup comment as though it described the
* per-screen path. It does not; it describes the one call there used to be.
*
* MASKED (idioms §22): sixteen consecutive hardware writes are one logical update. AFTER
* the mode registers, never before (HAL_gfx_init Constraint B / idiom §9).
* ★ It reads BUNDLE_PAL, so the CAPTIONS MUST BE BACK before this is called — the scene
* expands its bundle over $3000 and BUNDLE_PAL is at $3000+$000.
* Clobbers: A, B, X, U, CC
* ---------------------------------------------------------------
set_dhr_palette
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
                rts

* ---------------------------------------------------------------
* run_scene — read the scene's program, call it, put the captions back.
*
* ★★ NEITHER READ CAN LAND ON A PICTURE BEING BUILT, and that is the read-before-reveal
* discipline rather than a coincidence. It has regressed twice (P3.72f, then P3.78c — Jay
* caught the second live: "the initial disk load is occurring with the static screen
* shown"), so the destinations are stated: $2500 is the scene's program region and $3000
* is the caption bundle. NEITHER IS A FRAMEBUFFER. What is on screen throughout is the
* scene's own finished last frame, which is a completed picture and not a partial one —
* the same relationship the intro's own beats already have, where load_screen reads into
* the BACK buffer while the previous beat's picture is displayed.
*
* The scene's program is re-read on every pass rather than kept: it is 1,196 B and the
* intro reaches this point exactly once, so caching it would be state to get wrong for no
* gain.
* ---------------------------------------------------------------
run_scene
                ldx     #SCENE_BASE
                lda     #DISK_SCENE_TRK
                ldb     #SECS_PER_TRACK
                jsr     load_tracks
                bne     rs_out          ; a failed read leaves the intro running
                jsr     SCENE_BASE+SCENE_CALL_OFF
* ---------------------------------------------------------------
* ★★★ THE SPLASH CACHE IS GONE, AND IT IS A 128 KB FACT.
*
* BANK_BLOCK is $3C and the bank is four blocks — $3C,$3D,$3E,$3F. The GIME masks a block
* number to the RAM actually installed [gfx.s:406], so on a STOCK 128 KB machine those are
* $0C,$0D,$0E,$0F — and those are precisely the scene's cel bank: CEL_RES_BLOCK $0C pinned
* plus $0D/$0E/$0F rotating (P3.105 §3B measured that all four free blocks are the
* scene's). The scene overwrites every one of them.
*
* So beat 6, which re-establishes the splash, must NOT take it from the bank: bank_valid
* is cleared and the read goes to disk. One extra read, and the alternative is beat 6
* copying cel data onto the screen.
*
* ★★ 512 KB WOULD NOT HAVE CAUGHT THIS. There, $3C-$3F and $0C-$0F are different physical
* blocks and the cache survives. CLAUDE.md §2K: "512 KB can pass while a masking assumption
* is wrong; the reverse does not happen." introseq's reprise check found it at 128 KB —
* "19717 bytes differ; first at row 0 col 10" — which is the whole reason the suites run
* on the target machine first.
* ---------------------------------------------------------------
                clr     bank_valid      ; the scene used the bank's blocks as its cel bank
* THE CAPTIONS, BACK. The scene expanded its bundle over all three of them.
                ldx     #BUNDLE
                lda     #DISK_BUNDLE_TRK
                ldb     #DISK_BUNDLE_SEC
                jsr     load_tracks
                bne     rs_out
* ★★★ AND THE PALETTE, WHICH MUST COME AFTER THAT READ. The scene's exit calls set_mode to
* put the 16-colour mode back, and set_mode installs the DIAGNOSTIC palette — so the
* artwork's sixteen colours have to be re-installed or every beat after this one is drawn
* in the wrong ones. BUNDLE_PAL lives at $3000+$000, inside the bundle the line above has
* just restored: doing this first would install whatever the scene left there.
                jsr     set_dhr_palette
rs_out
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
                leau    LZ_LOAD_OFF,x   ; U -> the blob; the module has no constant
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
* ---------------------------------------------------------------
* play_song — the oracle's PlaySongI, in the state this port is actually in.
*
*   Entry: A = song number (MASTER.S:114-121),  X = frames the song lasts
*   Exit:  the frames are spent.  Clobbers D.
*
* THE INTERVAL IS THIS ROUTINE'S BODY, NOT A DELAY BESIDE IT. The intro's "pauses"
* are not pauses: `PlaySongI` BLOCKS while the music plays [SUBS.S:822-842] and
* contains no wait instruction at all. On the Apple II sound is bit-banged, so a
* routine that plays a note is indistinguishable from one that waits -- the duration
* is a CONSEQUENCE of the song, not a designed hold. Recording it as a bare frame
* count loses that, and a reader cannot then tell a song's length from a deliberate
* pause. BEAT_SONG carries the cause; this routine owns the interval.
*
* WHY THAT MATTERS MORE THAN THE CODE: when sound arrives it replaces this BODY.
* There is no delay sitting next to a call for someone to remember to delete, and no
* comment asking them to. (P3.41: a lesson recorded is not a lesson applied -- a fix
* that was documented and not made hung the machine one dispatch later. A structure
* that makes the wrong thing impossible beats a note asking for care.)
*
* AND THE ORACLE ALREADY DEFINES THIS EXACT STUB. With sound off, PlaySongI is
* `txa / beq ]rts / jmp play` -- song ignored, X frames spent animating. So the
* contract (A = song, X = frames) is Mechner's, not an invention, and the
* sound-disabled path is the state this port is in.
*
* IT WAITS RATHER THAN ANIMATING, and that is established rather than assumed: the
* things the oracle's song loop drives -- `pburn`, `pstars`, `pflow` -- are the
* PRINCESS ROOM's torches, stars and hourglass, drawn at fixed coordinates from
* scene state the intro never initialises. Nothing on these six screens moves; the
* port's own intro regression holds all twelve of them byte-identical. If a beat
* ever gains a live element, it is driven from here.
*
* A = 0 means NO SONG -- a real designed pause. Beat 5 is the only one: the oracle's
* gap there is the PrincessScene cutscene, which is not built.
* ★★★ SOUND ARRIVED, AND THIS IS THE BODY THE COMMENT ABOVE PROMISED IT WOULD REPLACE.
*
* ★★ THE FRAME COUNT STILL OWNS THE INTERVAL. `hold_frames` runs exactly as before, on the
* beat's traced count — the song plays INSIDE it and does not extend it. That is what
* "duration is an input in the port" means (P4.1), and it is why wiring audio cannot move
* a beat boundary or re-time the intro. If a song is longer than its beat, `msys_stop`
* cuts it; if shorter, the rest of the beat is silent. Both are visible to the ear gate
* and neither is allowed to change the pace Jay already accepted (P3.87).
*
* ★ `msys_stop` RUNS ON EVERY PATH, including the silent one and including a beat whose
* song was never started. It is idempotent, and a hold that returned with a live FIRQ
* would hand the next beat an interrupt it does not know about.
* ★★★ ALL FIVE OF THE INTRO'S SONGS, SINCE P4.23. The scaffolding comparison that held
* this to `s_Presents` alone is gone — it existed so that P4.21's two defects would surface
* in ONE place rather than five, and both did: the shared-latch hang and the x7 rest
* multiplier. Neither is per-song, so neither can come back one song at a time.
* ★★ NOTE WHAT DID NOT CHANGE: no new mechanism, no per-song data, no second call site.
* The player already carries all thirteen songs and its entry table resolves the id, so
* widening this was DELETING two instructions.
play_song
                tsta
                beq     ps_hold         ; A = 0 — a designed pause, not a song
* ★ -DMSYS_SILENT builds the CONTROL for the cost measurement: every beat runs its exact
*   code path with no song. It is the only way to attribute spins to the music rather than
*   to whatever else differs between two beats (P4.21 measured beat 1 against beat 5 and
*   got a meaningless 30%).
                ifdef   MSYS_SILENT
                bra     ps_hold
                endc
                pshs    x
                jsr     msys_play       ; returns at once; the FIRQ does the rest
                puls    x
ps_hold
                tfr     x,d             ; the beat's frame count, unchanged
                bsr     hold_frames
                jsr     msys_stop       ; ★ tear down, always
                rts

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
beat_song       fcb     0               ; which song this beat's hold is the length of
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
                fcb       0               ; BEAT_WIPE    NO sweep. PubCredit calls setdhires
*                                       ; AFTER unpacksplash, so the expand runs with the DHR
*                                       ; page not yet displayed and setdhires reveals it whole.
*                                       ; The oracle's own motion log says the same thing: one
*                                       ; frame at f306 with the entire screen changing.
                fdb     BUNDLE_PRESENTS ; BEAT_PATCH   "Broderbund Software Presents"
                fdb     99              ; BEAT_PRE
                fdb     281             ; BEAT_HOLD
                fcb     S_PRESENTS      ; BEAT_SONG    its song [MASTER.S:753-755, jsr PlaySongI, X=80]

                fcb     0               ; BEAT_TRACK   none — inherit beat 1's picture
                fcb       0               ; BEAT_WIPE    no track — a caption over the picture already up
                fdb     BUNDLE_BYLINE   ; BEAT_PATCH   "A Game by Jordan Mechner"
                fdb     96              ; BEAT_PRE
                fdb     283             ; BEAT_HOLD
                fcb     S_BYLINE        ; BEAT_SONG    its song [MASTER.S:795-797, jsr, X=80]

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
                fcb     S_TITLE         ; BEAT_SONG    its song [MASTER.S:832-834, jsr, X=140]

                fcb     DISK_PROLOG1_TRK ; BEAT_TRACK  its OWN picture — first beat to
                fcb     101               ; BEAT_WIPE    measured: the oracle's edge runs x=32..524 in 81 frames
                fdb     0                ; BEAT_PATCH   none: the picture IS the beat
                fdb     101              ; BEAT_PRE     the oracle spends these wiping
*                                        ;              the picture in over the splash
                fdb     760              ; BEAT_HOLD    f1822 - f2582
                fcb     S_PROLOG        ; BEAT_SONG    its song [MASTER.S:850-852, jmp -- a TAIL CALL, X=250]

                fcb     DISK_PROLOG2_TRK ; BEAT_TRACK   the second prologue picture
                fcb       0               ; BEAT_WIPE    NO sweep, and no invented duration:
*                                       ; Prolog2 also calls setdhires AFTER its DblExpand
                fdb     0                ; BEAT_PATCH   none
                fdb     0                ; BEAT_PRE     back-to-back: the oracle's gap
*                                        ;              here is the PrincessScene
*                                        ;              cutscene, which is not built
                fdb     1564             ; BEAT_HOLD    f5753 - f7317
                fcb     0               ; BEAT_SONG    NO SONG -- the oracle's gap here is the PrincessScene cutscene, not built

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
                fcb     S_SUMUP         ; BEAT_SONG    its song [MASTER.S:882-884, jmp -- a TAIL CALL, X=250]

                ifdef   OBJTARGET
                endsection
                else
                end     intro_seq_entry
                endc
