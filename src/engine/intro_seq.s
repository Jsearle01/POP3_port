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
BEAT_SIZE       equ     10      ; +1 for BEAT_SONG (P3.52), +1 for BEAT_KEEP (P4.47)
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

* ═══ THE RAM TRACK CACHE (P5.16) ══════════════════════════════════════════════════
*
* ★★★ THE POINT IS THE ORACLE'S CADENCE, AND THIS FILE ALREADY NAMED IT TWICE. The batch
* at seq_boot says "The oracle's cadence, matched: one burst of I/O up front, then
* silence" -- and then four beats read from disk anyway. sq_flip_in's comment names the
* same standard from the other side: "the prologue beats were once reading their picture
* twice and stalling on the previous screen for 18 seconds where the oracle (which
* batch-loads the whole stage up front) takes none at all."
*
* Measured at P5.15, after the cutscene's own read was removed: SIXTEEN AND A HALF SECONDS
* of drive time still happen after the loading screen is gone --
*
*     beat 4   7.81 s   the scene's program, its preload, and prolog1's picture
*     beat 5   6.00 s   prolog2's picture and the post-scene caption reload
*     beat 6   3.00 s   the splash, READ A SECOND TIME
*
* Jay named all three from the screen without being told where to look, which is the
* definition of visible. [Jay, 2026-08-22: "there is a delay between the first tilte
* screen and prolog1, between the princess scene and prolog2, and between prolog2 and the
* silent title screen."]
*
* ★★ WHY A CACHE AND NOT FIVE SEPARATE PRELOADS. Every one of those readers already takes
* a TRACK NUMBER, because load_tracks' contract is (X = destination, A = track, B =
* sectors). So the tracks are the natural key, and one routine with load_tracks' own
* signature replaces the read at every site without changing a single caller's shape:
* `jsr load_tracks` becomes `jsr tc_fetch`. A miss falls through to the disk, so a track
* nobody cached still works and the change cannot break a path it did not anticipate.
*
* ★★ AND THE DESTINATIONS ARE WHY IT MUST BE A COPY RATHER THAN A MAPPING. A packed screen
* is expanded from draw_base+LZ_LOAD_OFF, the captions live at $3000 and the scene program
* at $2600 -- three different homes, none of them block-aligned, and during a draw all four
* MMU slots are the framebuffer. There is no window to reveal a cached track IN. So the
* cache borrows $FFA4/$FFA5, whose contents at that moment are the back buffer the caller
* is about to overwrite entirely, and copies. 9,216 B costs ~0.05 s against the 3.00 s read
* it replaces.
*
* ★ THE BORROW IS INVISIBLE TO THE SCREEN, and that is a GIME fact rather than a hope: the
* video fetch runs from VOFFSET against PHYSICAL blocks and does not go through the MMU at
* all, so remapping a CPU window cannot disturb what is displayed. cel_preload borrows
* $FFA6/$FFA7 the same way and its header sets out the same argument.
*
* ★★★ 512 KB IS WHAT PAYS FOR IT, and at 128 KB it is not merely tight but impossible --
* every one of the sixteen blocks is spoken for (cel_pack.py's header has the census). Nine
* blocks out of the 56 free at 512 KB, which P5.12 costed.
* ★★ THE SCENE'S OWN TWO ASSETS, AND NEITHER NUMBER IS WRITTEN HERE. The tracks arrive as
* -D from build.bat, which is now their single home and the same place the raw_tracks call
* that PUTS them on the disk takes them from — so the disk, the scene that reads them and
* the cache that holds them cannot disagree. The alternative was a duplicated literal in a
* second link unit, which is exactly the drift link/pop_scene.link cost a dispatch to find.
                ifndef  DISK_FLAME_TRK
                fail    "DISK_FLAME_TRK must come from build.bat"
                endc
                ifndef  DISK_ROOM_TRK
                fail    "DISK_ROOM_TRK must come from build.bat"
                endc
* ★ AND THE SIZE COMES FROM THE PACKER, not from a guess: lz_pack.py emits FLAME_TRACKS with
* the bundle it actually produced. It is 1 today; if the flames grow past a track it becomes
* 2 and this follows, where a hand-written 18 would have cached half a bundle in silence.
                include "build/obj/flame_load.inc"
DISK_FLAME_SEC  equ     FLAME_TRACKS*SECS_PER_TRACK
ROOM_TRACKS     equ     1               ; princess_room.lz — build.bat asserts it still fits
DISK_ROOM_SEC   equ     ROOM_TRACKS*SECS_PER_TRACK
TC_BLOCK0       equ     $19             ; $19..$23 — eleven blocks, above the cel bank's $18
TC_MMU          equ     $FFA4           ; the borrowed pair: $8000-$9FFF and $A000-$BFFF
TC_WIN          equ     $8000           ; where a cached track appears while borrowed
* Every entry starts at a block boundary, so one entry never needs a third block and the
* fetch is "map N and N+1, copy from $8000". Two blocks per two-track entry wastes 6,976 B
* apiece; against 56 free blocks that is the cheaper thing to spend than the arithmetic.

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
SCENE_BASE      equ     $2600           ; P4.47: was $2500 -- see build.bat
                endc
                ifndef  SCENE_CALL_OFF
SCENE_CALL_OFF  equ     11
                endc
* ★ THE FETCH-ONLY ENTRY (P4.25b). cutscene_room.s asserts this offset against its own
* label at build time — the two units never link together, so the shared number is checked
* rather than trusted. See run_scene and sq_pre below.
                ifndef  SCENE_PRELOAD_OFF
SCENE_PRELOAD_OFF equ   14
                endc
SCENE_SIG       equ     $7E             ; SCENE_BASE opens `jmp room_start`, like MSYS_SIG
SAVE_MAX        equ     6144            ; the TITLE patch is 5,361 pixel bytes --
*                                       ; 7x the captions', and this buffer has to
*                                       ; hold the largest of them, not the last.

* --- SAM speed latches. The FDC cannot keep up at 1.78 MHz and HAL_gfx_init has
* --- already set it, so every transfer is bracketed slow/fast (idiom §8:
* --- force-slow -> do-I/O -> restore-speed, owned at the I/O-CALLER layer, not
* --- inside the primitive). CLAUDE.md §2G calls this rule PROVISIONAL, carried
* --- from karateka; POP is the first project to exercise it for real.
DSKREG          equ     $FF40           ; FDC control latch (write-only)
* --- THE $FFA2 SCRATCH SLOT --------------------------------------
* ★★★ THIS WAS THE SPLASH BANK (P3.11) UNTIL P4.25, AND THE BANK IS GONE. It cached the
* Broderbund splash in GIME blocks $3C-$3F so that beat 1's second base copy — a caption
* beat needs its picture in BOTH buffers — cost 95 ms instead of a 2.6 s re-read.
*
* ★★ IT HAD TO GO BECAUSE ITS BLOCKS ARE THE CUTSCENE'S CEL BANK AT 128 KB, and P4.25
* moved the cel pages into the opening batch. run_scene's own comment already recorded the
* aliasing in the other direction ("BANK_BLOCK is $3C ... on a STOCK 128 KB machine those
* are $0C,$0D,$0E,$0F — and those are precisely the scene's cel bank"); once the cel pages
* are read BEFORE the first beat, beat 1's bank fill would land on top of them. P3.105
* measured all four free blocks at 128 KB as the scene's, so there is no second home: the
* bank and an early cel load are mutually exclusive on the target machine.
*
* ★★★ AND THE REPLACEMENT IS CHEAPER THAN EITHER, WHICH IS WHY THIS IS NOT A SACRIFICE.
* The bank existed to avoid re-READING a picture the machine already had — in the FRONT
* buffer. `fb_copy_front` copies front -> back directly through this same $FFA2 window, so
* the second base costs one 95 ms memory copy and NO disk read and NO 32 KB of storage.
* It is also more general than the bank was: the bank only ever held DISK_SCREEN_TRK, so
* beat 4's and beat 5's second base would have been re-read had they carried captions.
* (HAL_gfx_mirror does exactly this job and REFUSES here — it needs both buffers mapped at
* once and a 16-colour framebuffer is 30,720 B, which takes the whole window. gfx.s:600.)
*
* The slot is $FFA2 (CPU $4000-$5FFF), ONE block at a time. That slot normally holds part
* of the asset bundle and the patch save buffer -- but remapping does not destroy anything,
* it only changes what is addressable, and a base copy touches neither. $FFA0/$FFA1/$FFA3
* are untouched, so the DP band, this code, the kernel and the stack all stay put.
*
* NOT the HAL's $FFA4-$FFA7: those are HAL-private (gfx.s says callers must never
* learn a buffer address) and this needs no knowledge of them -- it copies to and
* from HAL_gfx_draw_base like any other drawing code.
BANK_MMU        equ     $FFA2           ; the borrowed slot
BANK_MMU_HOME   equ     $3A             ; what sys.s left in it ($FFA0-$FFA7 = $38-$3F)
BANK_WINDOW     equ     $4000           ; CPU address a bank block appears at
BANK_CHUNK      equ     $2000           ; 8 KB per block
BANK_TAIL       equ     30720-3*BANK_CHUNK   ; the 4th block is only part used

* --- THE CUTSCENE'S CEL PAGES, READ HERE (P4.25) ------------------
* ★★★ THE SCENE'S EIGHT CEL TRACKS ARE READ IN THE OPENING BATCH, NOT AT SCENE START.
* Measured at P4.23/P4.24: the scene's opening reads put its first musical cue 12.4 s late,
* and 10.1 s of that is these eight tracks. Jay: "I already watched it and it is not synced
* well enough." The reads have to happen; the only question is WHERE, and the opening batch
* is the one window in the whole intro that is already black and already silent.
*
* ★★ THE LOADER CANNOT MOVE, SO THE READS MOVE WITHOUT IT. P4.24 §3C found the blocker:
* `cel_load_startup` lives IN THE FLAME BUNDLE, which expands to $3000 over the captions —
* so the code that performs the reads cannot run until the captions are finished, which is
* the very thing moving the reads was meant to escape. What moves here is the RAW READS.
* `cel_load_startup` keeps the state initialisation, sees the pages already in place (it
* tests the pinned page's magic) and skips its own reads. Two units, one fact each.
*
* ★ THE TABLE IS THE SAME GENERATED FILE THE BUNDLE READS — included at the tail of this
* source, not copied. CEL_VARBASE's note in build.bat covers the shape: two objects that
* never link together share a constant by including the same generated text.
CEL_MMU         equ     $FFA6           ; $C000-$DFFF; +1 is $E000-$FDFF. HAL-private
*                                       ; while the intro draws, borrowed here between
*                                       ; beats — saved and restored around the batch.

SAM_SLOW        equ     $FFD8
SAM_FAST        equ     $FFD9

* Beat descriptor — 8 bytes. The intro is DATA in this table, not code.
BEAT_TRACK      equ     0               ; raw track of this beat's screen, 0 = inherit
BEAT_WIPE       equ     1               ; frames the picture SWEEPS in over (0 = flip)
BEAT_PATCH      equ     2               ; sparse caption patch, in the bundle
BEAT_PRE        equ     4               ; frames the clean base is held first
BEAT_HOLD       equ     6               ; frames the caption stays up
BEAT_SONG       equ     8               ; the SONG whose length this beat's hold is (0 = none)
* ★★★ BEAT_KEEP — this beat's caption STAYS UP when its hold ends (P4.47, Jay).
* Both beats that set it are settled from the oracle's own source, and they are settled
* differently, which is why this is a per-beat field and not a rule:
*
*   beat 5, the reprise — `SilentTitle` [MASTER.S:808-822] ends
*       `lda #delTitle / jsr DeltaExpPop / lda #160 / jmp tpause`
*     and RETURNS to `jmp Demo`. There is no `CleanScreen`. The oracle simply never takes
*     this one down, so clearing it was the port's own invention. Straight fidelity.
*
*   beat 2, the first title — `TitleScreen` [MASTER.S:823-838] DOES end `jmp CleanScreen`
*     ("Credit line disappears"), so the port's clear was faithful to the instruction and
*     wrong about the result. The oracle batch-loads its stage, so its cleared splash is
*     visible for an instant; the port pays beat 3's scene preload AND prolog1's read there,
*     and Jay watched a bare splash for the length of both. ★ CLAUDE.md §2I governs: the
*     mandate is that it LOOKS right, not that it works the way the oracle works — and here
*     reproducing the oracle's ACTION reproduces the opposite of the oracle's APPEARANCE.
*     Beat 3 wipes prolog1 in over the held title, which is what DblExpand does anyway.
BEAT_KEEP       equ     9               ; non-zero: no vanish-swap, no repair

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
* ★★★ intro_seq_boot — THE ENTRY THE STAGE-1 LOADER USES (P4.46).
*
* The loader has already drawn the "loading" screen, and `seq_start`'s `HAL_gfx_set_mode`
* CLEARS BOTH BUFFERS — so entering there would wipe it at the hand-off and leave the
* ~27 s of batch reads black, which is the whole thing the screen exists to cover.
*
* ★★ SO THE MACHINE IS ALREADY UP WHEN THIS IS ENTERED. The loader owns the canonical boot
* prefix, the video mode and the palette; this resumes at the disk reader, with the screen
* on display and both stacks already the same $7F00.
*
* ★ IT SITS AFTER THE PROBE BLOCK, NOT BEFORE IT. Every harness reads those bytes as
* offsets from `intro_seq_entry` — probe_status at +3, probe_magic at +6 — so an entry
* ahead of them would move all seven and re-point five files to save nothing. Same
* reasoning, same placement, as the scene's `room_call` at +B.
*
* AND THE OFFSET IS ASSERTED RATHER THAN DOCUMENTED: the loader jumps to
* INTRO_BASE+INTRO_BOOT_OFF and cannot see this label — the two are separate link units.
* Both take the number from the same -D, so a drift becomes a build error instead of a jump
* into the middle of probe_magic.
* ---------------------------------------------------------------
intro_seq_boot  jmp     seq_after_mode  ; +B   the loader's entry — machine already up
                ifndef  INTRO_BOOT_OFF
INTRO_BOOT_OFF  equ     11
                endc
                ifne    intro_seq_boot-intro_seq_entry-INTRO_BOOT_OFF
                fail    "intro_seq_boot moved: the loader's INTRO_BOOT_OFF no longer points at it"
                endc
* ---------------------------------------------------------------
* (probe_wipes' own note, kept with the byte it describes:)
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

* ★ THE STAGE-1 LOADER RESUMES HERE (P4.46), past the boot prefix and past the set_mode
* whose buffer-clear would erase the "loading" screen it has just put up. Everything above
* this label the loader has already done.
seq_after_mode

* --- the disk reader ---------------------------------------------
* AFTER HAL_sys_init, which is what puts the GIME in MC3=1 and so makes
* $FE00-$FEFF constant — the primitive lands its NMI handler and completion flag
* there precisely because that page survives every MMU remap the draw window does.
                jsr     disk_read_init

* --- everything the beats will need, in one batch, before the first beat -------
* The oracle's cadence, matched: one burst of I/O up front, then silence.
*
* ★★★ AND SINCE P5.16 THAT SECOND CLAUSE IS TRUE. It was written at P3.3 as the intent and
* four beats went on reading from disk anyway; the cache is what makes the sentence
* describe the program. tc_preload runs FIRST, before the captions below, because the
* captions are themselves one of the cached runs — read once here, copied at every later
* use, including the post-scene restore that used to be a second read of the same tracks.
                jsr     tc_preload
                bne     seq_disk_fail
                ldx     #BUNDLE
                lda     #DISK_BUNDLE_TRK
                ldb     #DISK_BUNDLE_SEC
                jsr     tc_fetch
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

* --- the CUTSCENE's cel pages, in the SAME burst ------------------
* ★★★ EIGHT TRACKS, AND EVERY ONE OF THEM AGAINST BLACK. This is the 10.1 s that used to
* run between the cutscene's first frame and its first musical cue. Nothing is on screen
* yet (set_mode cleared both buffers), no song is playing, and the batch already exists —
* so the reads add no second pause anywhere the oracle has none. They land in GIME blocks
* $0C-$0F, which nothing else in the intro touches now that the splash bank is gone.
* LAST IN THE BATCH on purpose: the bundle and the player are what a failure here should
* not have wasted, and the MMU borrow is over before anything else runs.
                jsr     cel_preload
                bne     seq_disk_fail

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
*
* ★★★ AND BEAT_KEEP IS A THIRD CASE (P4.47). A beat with BEAT_KEEP set leaves its CAPTION
* on the front page and the clean base on the hidden one -- so it satisfies neither "both
* buffers clean" nor "both buffers hold the picture". Only two beats set it and each is
* followed by something that does not care:
*   beat 2 (title) is followed by beat 3, which reads its own picture into the hidden page
*     and WIPES, and wipe_in leaves both buffers holding prolog1 -- the invariant is
*     restored one beat later, by the sweep rather than by a repair.
*   beat 5 (reprise) is the LAST beat. Nothing follows it to inherit anything.
* ★ So the rule is not "a keep beat is safe"; it is that a keep beat must be followed by a
* beat that rebuilds both pages, or by nothing. Both are checked above, not assumed.
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
                lda     BEAT_KEEP,x
                sta     beat_keep

* -- this beat's screen, if it brings one --------------------------
* Read into the back buffer, show it, read again into the other one, so both pages
* hold it. The oracle's copy1to2 is a memory copy; here it is a second read,
* because only ONE buffer is CPU-addressable at a time — the $8000 window maps
* four 8 KB blocks and a 30,720-byte framebuffer needs all four. A chunked
* front-to-back copy through the spare MMU slots would be faster, and is the
* obvious move if this ever happens in front of the player. It does not: both
* reads finish before the first beat is visible.
* -- ★★★ THE SCENE'S ASSETS, FETCHED AT THE TOP OF THE BEAT BEFORE IT (P4.25b) ------
* The scene runs at the END of this beat. Everything it used to read at its own start is
* read HERE instead, in the same stall beat 4's own picture read already occupies, against
* beat 3's cleared title screen and before beat 4's music begins.
*
* WHY THIS BEAT AND NOT EARLIER: beat 3 was the last user of the captions at $3000, and the
* scene's fetch expands its bundle straight over them. Before beat 3's repair, both this
* read (which overruns $2600..$37FF — a whole track for a 1,196-byte program) and the
* expand would destroy a caption the intro still has to show. After it, nothing needs them
* until beat 6, which gets a fresh copy from run_scene's post-scene reload.
*
* NEITHER FAILURE IS CHECKED HERE, AND THAT IS DELIBERATE. run_scene tests SCENE_BASE for
* its `jmp` before calling, and the scene's own room_start re-reads its assets when the
* fetch left no receipt. Both degrade to exactly the pre-P4.25b behaviour, so an error path
* here would add bytes to a routine with 25 of them to buy nothing.
                lda     probe_beat
                cmpa    #SCENE_AFTER_BEAT
                bne     sq_pre_done
                ldx     #SCENE_BASE
                lda     #DISK_SCENE_TRK
                ldb     #SECS_PER_TRACK
                jsr     tc_fetch
                bne     sq_pre_done     ; no program -> no fetch; run_scene will decline
* ★★★ AND THE SCENE'S OWN TWO FETCHES COME FROM THE CACHE TOO (P5.16b). room_preloaded
* takes Y = the reader; tc_fetch has load_tracks' contract and clobber set, so the scene's
* flame bundle and room blob are copied rather than read. That is the 3.40 s Jay saw:
* "there is still a long delay between the first title and prolog 1."
                ldy     #tc_fetch
                jsr     SCENE_BASE+SCENE_PRELOAD_OFF
* ★★★ AND RELEASE THE DRIVE, BECAUSE NOTHING ELSE WILL ANY MORE (P5.16). room_preloaded
* deliberately does not release it — P3.84 made the scene hold the drive across its whole
* staged schedule — and until now that was harmless, because the very next thing the intro
* did was load_screen, whose load_tracks ends every read with disk_read_motor_off. The
* cache turned that read into a RAM copy, so the release went with it: measured, the drive
* stayed engaged for 18.37 s to transfer 9,216 B, spinning for the last fifteen of them
* until the scene finally started and cel_load_startup let it go.
*
* This is the same shape as the bug P5.15 fixed one layer down, and the same lesson: a
* release that happens as a SIDE EFFECT of the next operation survives exactly until that
* operation changes. The intro owns this beat, so the intro asks for it here.
                jsr     disk_read_motor_off
sq_pre_done

                lda     beat_track
                beq     sq_nobase
                jsr     load_screen
                lbne    seq_disk_fail   ; LONG: the beat-4 fetch above pushed this past
*                                       ;   8-bit range, the same way the sweep pushed the
*                                       ;   second-base branch at P3.9
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
* The SECOND base exists only so the caption machinery has a clean copy on the hidden
* page to repair from. A beat with no caption never repairs anything, so it pays nothing
* here -- which matters a great deal: the prologue beats were once reading their picture
* twice and stalling on the previous screen for 18 seconds where the oracle (which
* batch-loads the whole stage up front) takes none at all.
* ★★★ IT IS A COPY, NOT A READ, AND NOT A CACHE (P4.25). The swap above has just put this
* beat's picture in the FRONT buffer; fb_copy_front brings it back into the hidden one for
* 95 ms. The splash bank did the same job for beat 1 only, out of 32 KB of GIME blocks the
* cutscene now needs — see the constants block. Copying from the buffer that is already
* showing the picture needs no storage at all, and works for any beat rather than for the
* one track the bank happened to hold.
                ldd     beat_patch
                beq     sq_nobase
                jsr     fb_copy_front
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
* ★ A KEEP BEAT SKIPS BOTH HALVES, and it has to be both: the swap is the disappearance
* and the repair is what makes the hidden page clean again. Skipping only the swap would
* leave the caption up and then quietly erase it from the page behind it, so the next
* swap-in from any source would show it vanishing for no reason.
                lda     beat_keep
                bne     sq_keep_caption
                jsr     HAL_gfx_swap    ; the caption VANISHES, in one frame
* ★★★ probe_phase IS SET HERE, BETWEEN THE SWAP AND THE REPAIR, AND IT MUST BE.
* P4.47 briefly moved it below patch_blit to share one copy with the keep path and save
* six bytes. That is six bytes for a race: the repair is the slow part of the beat, so
* setting the phase after it leaves phase 2 alive for only the handful of frames before
* the next beat overwrites probe_status -- and the suite caught it at once, with beat 0
* going `status=2 phase=1` straight to `status=3 phase=2`. Phase 2 was never observable.
* ★ The comment 30 lines up already said so ("P3.3 got lucky and P3.4 did not"); the
* saving was only wanted because the prog was over SCENE_BASE, and raising SCENE_BASE
* removed the reason rather than the symptom.
                lda     #2
                sta     probe_phase
                lda     #1
                sta     seq_restore
                jsr     patch_blit      ; same runs, from the saved bytes
                bra     sq_beat_end
sq_keep_caption
* The keep path skips BOTH halves -- the swap is the disappearance, the repair is what
* makes the hidden page clean again -- but still advances the phase, because phase 2
* means "this beat's hold is over" and that is true either way. The FRAMEBUFFER is what
* differs, and the offline comparison now asserts it against ttl_fb rather than base_fb.
                lda     #2
                sta     probe_phase
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
* shown"), so the destinations are stated: $2600 is the scene's program region and $3000
* is the caption bundle. NEITHER IS A FRAMEBUFFER. What is on screen throughout is the
* scene's own finished last frame, which is a completed picture and not a partial one —
* the same relationship the intro's own beats already have, where load_screen reads into
* the BACK buffer while the previous beat's picture is displayed.
*
* The scene's program is re-read on every pass rather than kept: it is 1,196 B and the
* intro reaches this point exactly once, so caching it would be state to get wrong for no
* gain.
* ---------------------------------------------------------------
* ★★★ THE READ THAT USED TO OPEN THIS ROUTINE IS GONE — IT HAPPENS AT THE TOP OF BEAT 4
* NOW (P4.25b), together with the scene's own two asset reads. Jay, on P4.25's build:
* *"still too late"*. He was right against a number that said +2.4 s, because the number
* started inside the stall: the interval he sits through is the SCENE PROGRAM read, then
* the FLAME BUNDLE read, then the ROOM BLOB read, and `cue_times.lua` only opens its window
* at the second of those. Measured end to end it was 6.4 s of static prolog1 with the music
* already finished. All three reads moved; what is left here is the call.
*
* ★★ AND THE CHECK IS THE IMAGE'S OWN FIRST BYTE, NOT A FLAG THE READ SET. `SCENE_BASE`
* opens with `jmp room_start`, so a $7E there means a scene program arrived — the same test
* the opening batch already makes on the music player (`cmpa #MSYS_SIG`). A failed read
* therefore still leaves the intro running rather than calling into whatever is at $2600,
* which is what the old `bne rs_out` bought and this keeps without a byte of state.
run_scene
                lda     SCENE_BASE
                cmpa    #SCENE_SIG
                bne     rs_out          ; no scene program — leave the intro running
* ★★★ BLACK OUT BEFORE THE CUTSCENE, AND IT IS THE ORACLE'S OWN FIRST INSTRUCTION.
* PrincessScene [MASTER.S:859-861] opens `jsr blackout` before it reloads or reads anything;
* the port went straight from prolog1's picture to the room's first frame. Jay, twice: "the
* prolog1 transition to the cutscene is a bit to abrupt" — and then, after a second was
* added to the hold, "still too abrupt", which is the useful half of the report. It was
* never a DURATION problem. A hard cut does not get softer by lasting longer.
*
* ★★ AND THE FIRST DIAGNOSIS WAS WRONG, WHICH IS WHY THIS IS MEASURED AND NOT ARGUED. The
* obvious suspect was play_song's `jsr msys_stop` chopping s_Prolog mid-phrase. Lifting the
* beat's ceiling to 3000 frames grew it by THIRTEEN — the song was already ending on its own
* at ~833 frames, so the cut was 0.22 s early and inaudible. The music was never the problem.
*
* Both pages are cleared, not one: the swap shows the cleared page and the second clear takes
* the picture off the page that is now hidden, so nothing can flash back if the scene swaps
* before it draws.
                jsr     HAL_gfx_clear   ; the hidden page goes black
                jsr     HAL_gfx_swap    ; ...and is shown
                jsr     HAL_gfx_clear   ; the other one too — see above
* ★ THE PAUSE ON BLACK IS AN INVENTED NUMBER, and it is flagged as one. The oracle spends
* this interval on `ReloadStuff` and `cutprincess1` — real work with real duration — and the
* port has nothing to do here because P5.16 made every one of the scene's assets resident.
* So the beat that separates the two pictures has to be asked for explicitly. Half a second
* is a starting point for Jay to rule on, not a measurement of anything.
BLACKOUT_FRAMES equ     30              ; 0.50 s at 59.92 Hz — Jay's to change
                ldd     #BLACKOUT_FRAMES
                jsr     hold_frames
                jsr     SCENE_BASE+SCENE_CALL_OFF
* ---------------------------------------------------------------
* ★★★ THERE IS NO SPLASH CACHE TO INVALIDATE ANY MORE, AND THE REASON IS THE OLD ONE.
*
* This is where `clr bank_valid` lived. The bank was four GIME blocks $3C-$3F; the GIME
* masks a block number to the RAM actually installed [gfx.s:406], so on a STOCK 128 KB
* machine those are $0C,$0D,$0E,$0F — precisely the scene's cel bank (CEL_RES_BLOCK $0C
* pinned plus $0D/$0E/$0F rotating; P3.105 §3B measured that all four free blocks are the
* scene's). The scene overwrote every one of them, so beat 6 had to be told to go to disk.
*
* ★★ P4.25 RESOLVED THE COLLISION BY REMOVING ONE SIDE OF IT RATHER THAN SEQUENCING IT.
* The cel pages are now read in the opening batch and must survive the whole intro, so the
* bank cannot exist at all — and it did not need to: fb_copy_front gets the second base
* from the front buffer for 95 ms and no storage. Nothing here is stale, so nothing here
* is cleared.
*
* ★ 512 KB WOULD NOT HAVE CAUGHT THE ORIGINAL EITHER. There, $3C-$3F and $0C-$0F are
* different physical blocks and the cache survives. CLAUDE.md §2K: "512 KB can pass while a
* masking assumption is wrong; the reverse does not happen." introseq's reprise check found
* it at 128 KB — "19717 bytes differ; first at row 0 col 10" — which is the whole reason
* the suites run on the target machine first.
* ---------------------------------------------------------------
* THE CAPTIONS, BACK. The scene expanded its bundle over all three of them.
* ★ AND SINCE P5.16 THIS IS A COPY, NOT A SECOND READ OF TRACKS 25-26. It is the clearest
* statement of what the cache is for: the bytes were already fetched before the first
* beat, and the only reason this was a disk operation is that nothing kept them.
                ldx     #BUNDLE
                lda     #DISK_BUNDLE_TRK
                ldb     #DISK_BUNDLE_SEC
                jsr     tc_fetch
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
* ★ EVERY PICTURE COMES FROM THE DISK NOW (P4.25). The bank's shortcut is gone with the
* bank; what replaced it is fb_copy_front at the ONE call site that wanted a second copy,
* which is a better place for it — this routine's job is "put track A on the hidden page",
* and it no longer carries a special case for one particular track.
                pshs    a               ; the track, kept across the read
                ldx     HAL_gfx_draw_base
                leax    LZ_LOAD_OFF,x   ; the packed blob lands high in the window,
                ldb     #DISK_SCREEN_SEC ; above the picture it is about to become
* ★ ALL THREE SCREENS ARE CACHED (P5.16), so this is a copy for every beat that has a
* picture — including beat 6, whose track is the SAME splash beat 1 already used. That
* one was the clearest case in the whole intro: the comment on beat 6's row explains that
* the splash "is not resident anywhere" and so must be read back, and the cache is exactly
* the residence it was missing.
                jsr     tc_fetch
                bne     ls_failed
                ldx     HAL_gfx_draw_base
                leau    LZ_LOAD_OFF,x   ; U -> the blob; the module has no constant
                jsr     lz_unpack       ; and expands down over itself
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
* THE RAM TRACK CACHE — see the constants block for why it exists.
*
* tc_tab: one row per cached run, `track, sectors, first block`. The KEY IS BOTH THE
* TRACK AND THE COUNT, because a caller asking for a different span of the same track is
* asking for something this cache does not hold, and answering it from here would hand
* back the wrong length. A row is matched only if both agree.
* ---------------------------------------------------------------
tc_tab
                fcb     DISK_PROLOG1_TRK,DISK_SCREEN_SEC,TC_BLOCK0+0    ; $19,$1A
                fcb     DISK_PROLOG2_TRK,DISK_SCREEN_SEC,TC_BLOCK0+2    ; $1B,$1C
* ★★★ THE SCENE'S PROGRAM IS NOT CACHED, AND THIS IS A MEASURED EXCLUSION RATHER THAN AN
* OVERSIGHT. Its row belongs here — track 24, one track, into TC_BLOCK0+4 — and caching it
* BREAKS THE CUTSCENE. Bisected at P5.16, with the link address finally correct so the test
* meant something: every other row cached and this one absent, integ PASSES and
* cel_scene_done sets at frame 9255; add this row back and the scene is entered, fails
* inside room_load_cels, and never even CLEARS that flag.
*
* ★★ WHAT IT IS NOT. The copy itself is correct — a write tap on SCENE_BASE caught it
* landing $7E 27 1C, a valid `jmp`, at the right beat. Nor is it spin-up: disk_read_range
* calls dr_spinup itself and dr_spinup is self-checking. Nor is it the motor: load_tracks
* releases the drive after every read, so it is off either way.
*
* ★ WHAT IS STILL UNKNOWN is why, and the honest form of that is to leave the row out and
* say so here. The difference this fetch made and the copy does not is that load_tracks
* brackets its read with SAM_SLOW/SAM_FAST and holds interrupts masked throughout — it is
* the only operation at beat 4 that does, immediately before the scene's own two reads.
* That is a hypothesis, not a finding, and it is written as one.
*
* The cost of leaving it out is 1.8 s of disk at beat 4, under a title beat 3 already holds
* up for exactly this reason (BEAT_KEEP, P4.47). The cost of guessing wrong is the cutscene.
*               fcb     DISK_SCENE_TRK,SECS_PER_TRACK,TC_BLOCK0+4       ; $1D
                fcb     DISK_BUNDLE_TRK,DISK_BUNDLE_SEC,TC_BLOCK0+5     ; $1E,$1F
                fcb     DISK_SCREEN_TRK,DISK_SCREEN_SEC,TC_BLOCK0+7     ; $20,$21
* ★★ THE SCENE'S OWN TWO ASSETS (P5.16b). They are not the intro's — they belong to the
* cutscene bundle, which has its own load_tracks and cannot see this table — so they are
* cached HERE and handed over as a reader argument at beat 4. One track each; the second
* block of each pair is mapped but never written.
                fcb     DISK_FLAME_TRK,DISK_FLAME_SEC,TC_BLOCK0+9       ; $22
                fcb     DISK_ROOM_TRK,DISK_ROOM_SEC,TC_BLOCK0+10        ; $23
                fcb     0               ; end. Track 0 is DECB's own and is never an asset.

* ---------------------------------------------------------------
* tc_preload — fill the cache. Called ONCE, inside the opening batch, before any other
* asset read, so that a track which is both cached and wanted immediately (the captions,
* the splash) is read from the disk exactly ONCE in the whole run and copied thereafter.
*
* Returns Z set on success, as load_tracks does. Clobbers: A, B, X, Y, U.
* ---------------------------------------------------------------
tc_preload
                ldy     #tc_tab
tc_p_next
                lda     ,y
                beq     tc_p_ok
                sta     tc_trk
                ldb     1,y
                stb     tc_sec
                lda     2,y
                sta     tc_blk
                leay    3,y
                sty     tc_cur          ; load_tracks is free to clobber Y
                jsr     tc_map
                ldx     #TC_WIN
                lda     tc_trk
                ldb     tc_sec
                jsr     load_tracks
                pshs    cc              ; keep load_tracks' answer across the restore
                jsr     tc_unmap
                puls    cc
                bne     tc_p_fail
                ldy     tc_cur
                bra     tc_p_next
tc_p_ok
                clra                    ; Z set = success
                rts
tc_p_fail
                lda     #1              ; Z clear, and the caller stops the intro
                tsta
                rts

* ---------------------------------------------------------------
* tc_fetch — load_tracks' contract, answered from RAM when the run is cached.
*
*   Entry: X = destination, A = track, B = sectors
*   Exit:  Z set = success. Clobbers: A, B, X, Y, U — exactly what load_tracks clobbers,
*          which is what lets every call site change by one word.
*
* ★★ A DESTINATION INSIDE THE BORROWED WINDOW FALLS BACK TO THE DISK. No caller does this
* today — the three destinations are $DA00, $3000 and $2600 — but the borrow would destroy
* such a destination silently and the failure would look like a corrupt asset rather than
* like a wrong window. Two comparisons make it impossible instead of unlikely.
* ---------------------------------------------------------------
tc_fetch
                sta     tc_trk
                stb     tc_sec
                stx     tc_dst
                cmpx    #TC_WIN
                blo     tc_f_look
                cmpx    #TC_WIN+$4000
                blo     tc_f_disk       ; destination is the window the borrow needs
tc_f_look
                ldy     #tc_tab
tc_f_scan
                lda     ,y
                beq     tc_f_disk       ; not cached — the disk still answers
                cmpa    tc_trk
                bne     tc_f_step
                lda     1,y
                cmpa    tc_sec
                beq     tc_f_hit
tc_f_step
                leay    3,y
                bra     tc_f_scan
tc_f_disk
                lda     tc_trk
                ldb     tc_sec
                ldx     tc_dst
                jmp     load_tracks     ; TAIL CALL: its Z is the answer, unmodified
tc_f_hit
                lda     2,y
                sta     tc_blk          ; ...before Y becomes the copy's scratch
                jsr     tc_map
                ldu     #TC_WIN
                ldx     tc_dst
                ldb     tc_sec
tc_f_page
                pshs    b
                ldb     #128            ; 128 x 2 bytes = one 256-byte sector
tc_f_byte
                ldy     ,u++
                sty     ,x++
                decb
                bne     tc_f_byte
                puls    b
                decb
                bne     tc_f_page
                jsr     tc_unmap
                clra                    ; Z set = success
                rts

* tc_map / tc_unmap — the borrow. Both halves are written under a masked CC because
* between the two stores the window is half cache and half framebuffer, which is the
* multi-register update idiom (§22) cel_preload observes for the same pair.
* The readback is masked to 6 bits: the MMU latches 8 and returns 6.
tc_map
                lda     TC_MMU
                anda    #$3F
                sta     tc_sav4
                lda     TC_MMU+1
                anda    #$3F
                sta     tc_sav5
                pshs    cc
                orcc    #$50
                lda     tc_blk
                sta     TC_MMU
                inca
                sta     TC_MMU+1
                puls    cc
                rts
tc_unmap
                pshs    cc
                orcc    #$50
                lda     tc_sav4
                sta     TC_MMU
                lda     tc_sav5
                sta     TC_MMU+1
                puls    cc
                rts

tc_trk          fcb     0
tc_sec          fcb     0
tc_blk          fcb     0
tc_sav4         fcb     0
tc_sav5         fcb     0
tc_dst          fdb     0
tc_cur          fdb     0

* ---------------------------------------------------------------
* cel_preload — the cutscene's cel pages, read here instead of at scene start (P4.25).
*
* Returns Z set on success, as load_tracks does. Clobbers: A, B, X, U.
*
* ★★★ WHAT IT DOES AND WHAT IT DELIBERATELY DOES NOT. It performs the eight track reads
* `cel_load_startup` used to perform and NOTHING ELSE — no state, no publication, no
* window left anywhere in particular. The state (`cel_rd_left`, `cel_pg_sig`,
* `cel_scene_done`, `cel_res_block`) stays in the bundle, where the scene reads it, and
* runs when the scene starts. Two units, one fact each; splitting the state out to here
* would put the scene's own bookkeeping in the intro, 90 seconds before the scene exists.
*
* ★★ THE MMU BORROW IS SAVED AND RESTORED, AND IT IS TWO BYTES. $FFA6/$FFA7 are the HAL's
* while the intro draws — set_mode has just pointed them at the back buffer, and
* load_screen reads a packed screen to draw_base+$5A00, i.e. $DA00, straight through both.
* This routine points them at the cel bank for the duration of the batch and puts them back
* before returning. Nothing runs in between that reads $C000-$FDFF: load_tracks writes only
* the destination it is given, the VBL handler lives in the DP band and the kernel, and the
* disk driver's own NMI vector and flags are at $FE00-$FEFF, which MC3=1 holds CONSTANT
* through every remap — that is the property they were put there for.
*
* ★ THE READS ARE ALL-OR-NOTHING, WHICH IS WHAT MAKES THE BUNDLE'S GUARD ONE TEST. A
* failure anywhere returns Z clear and seq_start stops on it, so the scene can never meet a
* partial preload: either the pinned page's magic is at $C000 and all eight tracks landed,
* or the intro never got past the batch.
*
* ★ TWO CALLS PER PAGE, THE SECOND SKEWED, exactly as cel_read_page does it in the bundle
* — a page is up to 7,680 B and a whole-track read is 4,608, so track B is laid out on disk
* to END where the window ends ($EC00 + 4,608 = $FE00) and the two overlap by 1,536 bytes
* carrying identical data. A plain two-track read to $E000 would write through the constant
* page and then through the GIME. char_draw.s's cel_read_page carries the full argument.
* ---------------------------------------------------------------
cel_preload
* ★★ THE MMU REGISTERS ARE READABLE, AND THE TOP TWO BITS ARE NOT PART OF THE ANSWER.
* [SockmasterGime.md:243 — "like the MMU registers, the upper 2 bits must be masked out";
* $FFA0-$FFA7 are the Task-0 bank registers and a block number is six bits.] Masking is not
* required for the write-back — the GIME ignores those bits on write — but an unmasked
* value is not a block number, and this one is stored in a variable another reader could
* believe. Save what the register MEANS, not what the bus happened to return.
                lda     CEL_MMU
                anda    #$3F
                sta     cp_sav6
                lda     CEL_MMU+1
                anda    #$3F
                sta     cp_sav7
                clr     cp_err
                lda     #CEL_RES_BLOCK
                sta     CEL_MMU                 ; $FFA6 -> the pinned page
                ldx     #CEL_RES_LO
                lda     #CEL_RES_TRK
                ldb     #CEL_SECS
                jsr     load_tracks
                bne     cp_failed
                ldx     #CEL_RES_HI
                lda     #CEL_RES_TRK+1
                ldb     #CEL_SECS
                jsr     load_tracks
                bne     cp_failed
                clr     cp_n
cp_next
                lda     cp_n
                cmpa    #CEL_N_STARTUP
                bhs     cp_out
                inc     cp_n
                ldx     #cel_startup_tab
                lda     a,x                     ; the page number this slot names
                lsla                            ; -> its row in cel_page_tab (2 B each)
                tfr     a,b
                clra                            ; ★ D, NOT A: `leax a,x` is SIGNED
                ldx     #cel_page_tab           ;   -128..+127 (idiom §20e, trap P3.65).
                leax    d,x                     ;   Four pages cannot reach it today; a
*                                               ;   grown table would, silently. Two bytes.
                lda     1,x                     ; the block this page belongs in
                sta     CEL_MMU+1               ; ...and bring it in, BEFORE the read
                lda     ,x                      ; track A
                sta     cp_trk
                ldb     #CEL_SECS
                ldx     #CEL_PAGE_LO
                jsr     load_tracks
                bne     cp_failed
                lda     cp_trk
                inca                            ; track B, the skewed one
                ldb     #CEL_SECS
                ldx     #CEL_PAGE_HI
                jsr     load_tracks
                beq     cp_next
cp_failed
                com     cp_err
cp_out
* PUT THE WINDOW BACK, and mask it: between the two writes the window is half cel bank and
* half framebuffer, which is the multi-register update idiom §22 names.
                pshs    cc
                orcc    #$50
                lda     cp_sav6
                sta     CEL_MMU
                lda     cp_sav7
                sta     CEL_MMU+1
                puls    cc
                tst     cp_err                  ; Z set = every track landed
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
* The front buffer is the one HAL_gfx_cur_back does NOT name — derived in front_block,
* which fb_copy_front needs as well.
                jsr     front_block
                sta     wp_front
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
* fb_copy_front — copy the DISPLAYED buffer into the hidden one. 30,720 bytes, four
* blocks through $FFA2, ~95 ms.
*
* ★★★ THIS IS THE SPLASH BANK'S JOB WITHOUT THE SPLASH BANK (P4.25). The bank held a
* private 32 KB copy of one picture; this reads the copy the machine already has, in the
* front buffer, and needs no storage at all. It also has no cache to invalidate — which is
* the whole of what run_scene used to do about it — and no track it is specific to.
*
* ~95 ms against a 2.6 s disk read: 27x, and the difference between an intro that stalls
* after every caption beat's reveal and one that does not.
*
* THE SOURCE BLOCK IS DERIVED, NOT STORED: the front buffer is the one HAL_gfx_cur_back
* does not name, exactly as wipe_in derives it, so this cannot go stale across a swap.
* HAL_gfx_mirror is the HAL's version of this and REFUSES in 16-colour, where a 30,720 B
* framebuffer needs the whole window; going one block at a time is what makes it possible
* here [gfx.s:595-604].
*
* Interrupts are masked only around the MMU writes themselves (idiom §22 — a
* multi-register hardware update is a critical section), not across the copy: the
* VBL handler lives in the DP band and the kernel, neither of which is remapped
* here, so it is free to run.
* Clobbers: everything
* ---------------------------------------------------------------
fb_copy_front
                bsr     front_block
                sta     bk_blk
                ldd     HAL_gfx_draw_base
                std     bk_fb
                lda     #4
                sta     bk_n
bk_block
                pshs    cc
                orcc    #$50
                lda     bk_blk
                sta     BANK_MMU        ; this FRONT-buffer block now answers at $4000
                puls    cc

                ldy     #BANK_CHUNK
                lda     bk_n
                cmpa    #1
                bne     bk_len_ok
                ldy     #BANK_TAIL      ; the 4th block is only 6,144 bytes of screen
bk_len_ok
                ldx     #BANK_WINDOW
                ldu     bk_fb
bk_to_fb
                ldd     ,x++            ; front -> back
                std     ,u++
                leay    -2,y
                bne     bk_to_fb
                stu     bk_fb           ; U advanced over the framebuffer

                pshs    cc
                orcc    #$50
                lda     #BANK_MMU_HOME
                sta     BANK_MMU        ; give the slot back before anything reads it
                puls    cc

                inc     bk_blk
                dec     bk_n
                bne     bk_block
                rts

* front_block — A = the DISPLAYED buffer's first GIME block.
* ONE HOME for the derivation: wipe_in wants it too, and two copies of "the front buffer is
* the one HAL_gfx_cur_back does not name" is one copy too many.
front_block
                lda     HAL_gfx_cur_back
                bne     fb_front_a
                lda     #FB_B_BLOCK
                rts
fb_front_a      lda     #FB_A_BLOCK
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
* ★★★ AND NOW THE INTERVAL REALLY IS THE SONG (P5.16c). This routine's own header has said
* since P3.41 what should happen here — "the duration is a CONSEQUENCE of the song, not a
* designed hold… WHEN SOUND ARRIVES IT REPLACES THIS BODY" — and sound arrived, and the body
* went on spending a fixed frame count anyway.
*
* Measured, and Jay heard it before it was measured: "prolog2 seems to be displayed for a
* long time after the song ends. longer than needed." Beat 5 holds 1564 frames (26.10 s,
* taken from the ORACLE's frame numbers, f5753..f7317) and the port's rendition of s_Sumup
* stops sounding at 18.57 s. SEVEN AND A HALF SECONDS of prolog2 in silence.
*
* The frame count stays as a CEILING, not as the duration: it is the oracle's interval and a
* song that runs longer than the oracle's must not stretch the intro past it. So the hold is
* min(song, oracle) — which for every beat whose song already fits is exactly what it was.
                tfr     x,d
                bsr     hold_song
                jsr     msys_stop       ; ★ tear down, always
                rts
ps_hold
                tfr     x,d             ; the beat's frame count, unchanged
                bsr     hold_frames
                jsr     msys_stop       ; ★ tear down, always
                rts

* hold_song — wait D frames, but stop early once the song has sounded AND fallen silent.
*
* ★★ IT WAITS FOR THE SONG TO START BEFORE IT WATCHES FOR THE END, and that is the whole
* subtlety. msys_play returns AT ONCE and the FIRQ does the sounding, so msys_playing reads
* 0 for the first frames — testing it naively would end every beat on its first tick and
* collapse the intro to nothing. ps_started latches the first non-zero reading; only after
* that does a zero mean "finished" rather than "not begun".
hold_song
                pshs    y
                clr     ps_started
                tfr     d,y
hs_lp           cmpy    #0
                beq     hs_done
                jsr     HAL_time_vbl_wait
                jsr     msys_playing    ; A != 0 while sounding [msys_player.s:290]
                tsta
                beq     hs_quiet
                sta     ps_started      ; A is non-zero — the song is under way
                bra     hs_next
hs_quiet        tst     ps_started
                bne     hs_done         ; it sounded, and it has stopped: the interval is over
hs_next         leay    -1,y
                bra     hs_lp
hs_done         puls    y,pc

ps_started      fcb     0               ; has this beat's song been heard yet?

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
beat_keep       fcb     0               ; non-zero: this beat's caption stays up (P4.47)
seq_beat        fdb     0               ; the beat under way. Held in a variable
*                                       ; rather than re-read from 1,S after every
*                                       ; call: the stack offset was correct but it
*                                       ; made every routine in between part of the
*                                       ; contract, and debugging that cost more
*                                       ; than the two bytes this costs.
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
cp_sav6         fcb     0               ; the HAL's $FFA6/$FFA7, across the cel preload
cp_sav7         fcb     0
cp_err          fcb     0
cp_n            fcb     0
cp_trk          fcb     0

* ---------------------------------------------------------------
* THE CEL PAGES' DISK MANIFEST — the SAME generated file the flame bundle includes.
*
* ★ NOT A COPY. bake_scene.py writes it once from cel_pack.json and build.bat places the
* very same tracks, so the disk, the bundle's loader and this preload cannot disagree
* without the build being re-run. char_draw.s includes it for cel_read_page; this object
* includes it for cel_preload; the two never link together, so the labels do not collide.
* ---------------------------------------------------------------
                include "content/cutscene/chars/cel_pages.s"

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
                fcb     0               ; BEAT_KEEP    PubCredit ends `jmp CleanScreen`

                fcb     0               ; BEAT_TRACK   none — inherit beat 1's picture
                fcb       0               ; BEAT_WIPE    no track — a caption over the picture already up
                fdb     BUNDLE_BYLINE   ; BEAT_PATCH   "A Game by Jordan Mechner"
                fdb     96              ; BEAT_PRE
                fdb     283             ; BEAT_HOLD
                fcb     S_BYLINE        ; BEAT_SONG    its song [MASTER.S:795-797, jsr, X=80]
                fcb     0               ; BEAT_KEEP    AuthorCredit ends `jmp CleanScreen`

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
* ★★★ KEEP, AND THIS IS THE ONE THAT DIVERGES FROM THE ORACLE'S INSTRUCTION (§2I).
* TitleScreen really does `jmp CleanScreen`. But the next thing the PORT does is beat 3's
* scene preload plus prolog1's own read, and the oracle pays neither -- so the faithful
* clear bought a bare splash held for the length of two disk reads. Jay: "the first title
* screen clears the title while the disk loads, i'd rather keep the title up until the
* disk reads are done." Beat 3 wipes prolog1 in over it, which is DblExpand's own shape.
                fcb     1               ; BEAT_KEEP    the title holds through beat 3's reads

                fcb     DISK_PROLOG1_TRK ; BEAT_TRACK  its OWN picture — first beat to
                fcb     101               ; BEAT_WIPE    measured: the oracle's edge runs x=32..524 in 81 frames
                fdb     0                ; BEAT_PATCH   none: the picture IS the beat
                fdb     101              ; BEAT_PRE     the oracle spends these wiping
*                                        ;              the picture in over the splash
* ★★★ 760 -> 820 AT P5.16c, AND IT IS A JAY RULING, NOT A MEASUREMENT. 760 is the oracle's
* own interval (f1822..f2582) and every other number in this table is faithful to one like
* it. Jay, on the live run: "prolog1 transition to the cutscene is a bit to abrupt, may
* extend prologs for a sec?" — so this beat now outlasts the oracle's by 60 frames, 1.00 s
* at 59.92 Hz, and §2I is why that is allowed to stand: the mandate is that the port LOOKS
* and FEELS right, and the oracle's timing is evidence toward that rather than the thing
* itself. Recorded as a deliberate divergence so nobody "corrects" it back to 760.
*
* ★ AND IT ONLY WORKS BECAUSE THIS BEAT'S HOLD IS FRAME-GOVERNED. play_song now ends a hold
* early when the song falls silent, so extending a beat whose song is the shorter of the two
* would change nothing. Beat 4 measured frame-identical either side of that change, which
* is what proves s_Prolog outlasts its interval — and therefore that this number is the one
* that decides when the cutscene starts.
                fdb     820              ; BEAT_HOLD    the oracle's f1822 - f2582 is 760
                fcb     S_PROLOG        ; BEAT_SONG    its song [MASTER.S:850-852, jmp -- a TAIL CALL, X=250]
                fcb     0               ; BEAT_KEEP    no caption on a picture beat

                fcb     DISK_PROLOG2_TRK ; BEAT_TRACK   the second prologue picture
                fcb       0               ; BEAT_WIPE    NO sweep, and no invented duration:
*                                       ; Prolog2 also calls setdhires AFTER its DblExpand
                fdb     0                ; BEAT_PATCH   none
                fdb     0                ; BEAT_PRE     back-to-back: the oracle's gap
*                                        ;              here is the PrincessScene
*                                        ;              cutscene, which is not built
                fdb     1564             ; BEAT_HOLD    f5753 - f7317
* ★★★ S_SUMUP BELONGS HERE, AND IT WAS ON BEAT 6 UNTIL P4.23. Jay heard it: "something is
* wrong at prolog 2, there is no music for a long time and then it move to the second
* title screen and then plays music."
* ★★ THE ORACLE'S OWN ORDER SETTLES IT [MASTER.S:690-707]:
*       jsr Prolog1        -> s_Prolog
*       jsr PrincessScene  -> the cutscene
*       jsr SetupDHires
*       jsr Prolog2        -> s_Sumup      <- MASTER.S:882-884, INSIDE Prolog2
*       jsr SilentTitle    -> nothing      <- and its NAME says so
* ★ The old comment reasoned that beat 5's gap WAS the unbuilt cutscene, and concluded it
*   must therefore be silent. The cutscene is a SEPARATE call between Prolog1 and Prolog2;
*   beat 5 IS Prolog2, and Prolog2 plays. Beat 6's row even cited MASTER.S:882-884 — the
*   citation was right and the assignment was one beat off.
                fcb     S_SUMUP         ; BEAT_SONG    its song [MASTER.S:882-884, jmp -- a TAIL CALL, X=250]
                fcb     0               ; BEAT_KEEP    no caption on a picture beat

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
* ★★ SILENT, AND THE ORACLE NAMED IT: the routine is `SilentTitle` [MASTER.S:705]. It
*    carried S_SUMUP until P4.23, which put Prolog2's song one beat late — audible as a
*    long silence over the prologue and then music over the title reprise.
                fcb     0               ; BEAT_SONG    NO SONG -- SilentTitle plays nothing
* ★★★ KEEP, AND HERE THE ORACLE SETTLES IT OUTRIGHT. SilentTitle [MASTER.S:808-822] is
* `unpacksplash / copy1to2 / tpause 20 / DeltaExpPop delTitle / jmp tpause 160` and then
* RETURNS -- into `jmp Demo` [MASTER.S:709]. No CleanScreen anywhere in it, where both
* PubCredit and TitleScreen end with one. The title is still on screen when Demo starts.
* Jay: "the final title screen clears the title, the oracle doesn't." The port's clear was
* its own addition; this removes it.
                fcb     1               ; BEAT_KEEP    the title is still up when the intro ends

                ifdef   OBJTARGET
                endsection
                else
                end     intro_seq_entry
                endc
