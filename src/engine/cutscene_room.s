* src/engine/cutscene_room.s
*
* POP CoCo3 — THE PRINCESS'S ROOM, static (P3.17 phase A).
*
* The first thing in this port to run in FOUR-COLOUR mode. Everything up to here —
* the whole static intro — is 16-colour; the cutscene is where the port crosses into
* gameplay's mode, and this program is that crossing with nothing else in it.
*
* ---------------------------------------------------------------
* WHERE THE ROOM COMES FROM, AND WHY IT IS ONE PICTURE
* ---------------------------------------------------------------
* The oracle does not build this room from tiles. cutprincess1 is three lines:
*
*     jsr LoadStage2          ; displaces bgtab1-2, chtab4
*     lda #pacProom
*     jsr SngExpand           ; SINGLE-hires expand
*     ...then copy page 1 to page 2
*
* -- one packed picture, expanded once and copied to both pages. That is the same
* shape as the intro's screens, and it is why the room never redraws: nothing after
* the expand touches it. (It is also why an early attempt to find a "block layout"
* found nothing: there isn't one.)
*
* So the asset is a captured, converted framebuffer, acquired the way P3.2 acquired
* its reference: dumped from the running oracle rather than unpacked out of the game's
* crunch format. CLAUDE.md §2 ranks the execution trace above the source, and it means
* SngExpand never has to be ported.
*
* THE ONE TRAP, AND IT COST A ROUND OF THIS DISPATCH. `mem:read_u8` in MAME reads
* through the CPU program space, which honours the RAMRD soft switch -- and POP sets
* RAMRDaux constantly, so a dump at $2000 returns AUX, where LoadStage2 parks
* bgtab1-2/chtab4. Image tables rendered as a picture look exactly like a broken
* converter. Two objective tests tell them apart and are now in the tooling: row-to-row
* coherence (26.8 for the real page vs 101.5 for the tables) and hires screen-hole
* occupancy (the display never reads those bytes, so they are near-empty on a real
* page). [harness/tools/oracle_ram_dump.lua]
*
* ---------------------------------------------------------------
* THE ASSET
* ---------------------------------------------------------------
* 4-colour is 80 bytes/row x 192 = 15,360 B, half the 16-colour framebuffer. LZ-packed
* it is 4,598 B -- ONE track, against the intro screens' two. That is what forced
* lz_unpack out of intro_seq.s and into a shared module: its old entry derived the
* blob address from a constant sized for 2-track screens. The caller passes the
* pointer now. [src/engine/lz_unpack.s]
* ---------------------------------------------------------------

                include "src/hal.inc"

                ifdef   OBJTARGET
                section prog
                export  room_entry
                import  disk_read_init
                import  disk_read_range
        import  disk_read_motor_off
                import  lz_unpack
                else
                org     $0200
                endc

* --- disk_read.s's parameter block, derived from the SAME -DDR_VARBASE the kernel
* --- is assembled with (see intro_seq.s for why this is not an import).
                ifndef  DR_VARBASE
DR_VARBASE      equ     $1F00
                endc
dr_track        equ     DR_VARBASE+0
dr_sector       equ     DR_VARBASE+1
dr_dest         equ     DR_VARBASE+2
dr_status       equ     DR_VARBASE+4
dr_r_track      equ     DR_VARBASE+5
dr_r_count      equ     DR_VARBASE+6

STACK_TOP       equ     $7F00           ; below the $8000 draw window
SECS_PER_TRACK  equ     18
DISK_ROOM_TRK   equ     29              ; clear of the intro's spans and the directory
ROOM_TRACKS     equ     1
DISK_ROOM_SEC   equ     ROOM_TRACKS*SECS_PER_TRACK

* ---------------------------------------------------------------
* THE CEL BANK (P3.71) — 16 KB of GIME RAM mapped where 4-colour leaves a hole.
*
* The scene's cel pixels are their own link unit at $C000 (link/pop_cels.link), read off
* disk into two GIME blocks mapped at CPU $C000-$FFFF through $FFA6/$FFA7. char_draw.s
* indexes them there and reads the image's own first two bytes for its bounds.
*
* WHY $C000 IS FREE. The draw window is $8000-$FFFF (gfx.s GFX_DB_WINDOW, four registers
* $FFA4-$FFA7), but a 4-colour framebuffer is only 15,360 B and reaches $BBFF. The upper
* half of the window is the reserved tail of a 32 KB-per-buffer allocation that this mode
* never uses. In 16-colour it would not be free — a 30,720 B framebuffer needs all four
* blocks, which is the same fact HAL_gfx_mirror's guard tests before borrowing $C000.
*
* WHY BLOCKS $0E/$0F AND NOT $3E/$3F. The GIME masks a block number to the RAM actually
* installed, so on 128 KB only $00-$0F exist and everything aliases mod 16. $0E/$0F alias
* to themselves there, and on 512 KB they sit below both framebuffers ($10-$17) and below
* the default CPU map ($38-$3F). The same two numbers are therefore free in BOTH sizes —
* where $3E/$3F would be the CPU's own map at 512 KB. This is the P3.10 lesson that put
* buffer B at $14 instead of $18, applied one register along.
* ★★ AND AT P3.78 THE IMAGE NO LONGER FITS THE BANK, so it is SPLIT.
*
* The complete scene is 39,682 B of cel image against a bank that is 31,744 B addressable
* (two mappings, each losing its top 512 B to MC3 and I/O — P3.75 §3A). So the cels are
* packed into a PINNED page at $C000 and five ROTATING pages that all live at $E000 and
* take turns in $FFA7, one per group of beats. Three are in RAM at once; the other two
* arrive off disk during the two song holds, over pages whose content the residency table
* proves finished.
*
* WHICH page is showing is decided by the beat schedule in the bundle (char_draw.s's
* vm_beat_tick), because the beats are what the schedule is about. This file's job is the
* two mechanical halves: put the pages in RAM at startup, and service the mid-scene read
* the schedule asks for. Both talk to the bundle through three bytes in the constant page.
CEL_BASE        equ     $C000           ; the PINNED page
CEL_PAGE        equ     $E000           ; whichever rotating page is mapped
CEL_MMU         equ     $FFA6           ; the register covering $C000-$DFFF; +1 covers
*                                       ;   $E000-$FFFF, of which $E000-$FDFF is reachable

* --- the three bytes shared with the bundle. See char_draw.s for the full reason; the
* --- short of it is that these two files never link together, so a shared variable has
* --- to be an address both are told, and it has to be in the constant page because the
* --- thing it describes is the MMU remap that would otherwise take it away.
                ifndef  CEL_VARBASE
CEL_VARBASE     equ     $FE02
                endc
cel_pg_block    equ     CEL_VARBASE+0
cel_pg_sig      equ     CEL_VARBASE+1   ; 2 B
cel_rd_req      equ     CEL_VARBASE+3   ; page+1 the schedule wants read; 0 = none
cel_res_block   equ     CEL_VARBASE+4   ; the PINNED page's block. PUBLISHED BY THE
*                                       ;   BUNDLE'S LOADER rather than named here: the
*                                       ;   generated page table is its one home and that
*                                       ;   table moved out of this file with the loader,
*                                       ;   so the room learns the number instead of
*                                       ;   keeping a second copy of it.
* ★ cel_scene_done — SET BY THE BUNDLE'S terminal beat, READ BY room_loop (P3.107). The two
* live in different link units, so the address cannot be imported; both derive it from the
* SAME -DCEL_VARBASE build.bat passes to both assemblies, which is the one home. Only the
* `+5` is written twice, and bundle_offsets_check.py is the existing check for exactly that
* class of duplication — see the assertion added there.
cel_scene_done  equ     CEL_VARBASE+5   ; non-zero once the terminal beat is reached

* WHERE THE PACKED BLOB LIVES, and it is main RAM rather than the draw window.
*
* It used to load high in the window (offset 32256-4608) and expand down over itself,
* which is what the intro does and what lz_pack's in-place slack argument is about.
* That is fine for a screen shown once. It is wrong here, because the window is
* REMAPPED by every buffer swap: a blob sitting in it is unreachable the instant the
* pages flip, so filling the second buffer meant reading the same track off disk a
* second time -- 1.3 s of it, with the finished picture already on screen.
*
* At $3000 the blob survives the swap and expands twice from RAM. The map (see
* link/pop_engine.link) puts the engine at $2000, the trace ring at $7800 and the
* stack at $7F00, so $3000-$41FF is clear of all three with room to spare.
*
* The unpacker's `cmpu #LZ_SRC_END` guard is a window-runaway check and cannot fire
* on a blob this low. It is not what terminates the loop -- `lz_end`, the WRITER
* bound, is -- and the writer is the destructive direction, so the bound that matters
* still holds.
* MOVED UP at P3.20: piece D's blit core, the two baked cels and the four peel
* buffers pushed `prog` from ~$2760 to ~$2E70, leaving under 400 bytes before the
* blob at $3000. That is not a margin worth trusting to future edits, and an
* overlap would present as a corrupt room rather than as a link error. $4000 is
* clear of prog, of the trace ring at $7800 and of the stack at $7F00.
* Bundle entry points, at fixed offsets from FLAME_BASE. The room reaches everything
* disk-resident through these rather than by link-time symbol, because the bundle and
* the program are separate images.
* The cutscene bundle moved to $4200 and grew to TWO tracks at P3.25. It could not
* grow in place: two tracks from $0A00 reach $2E00 and this program starts at $2000,
* so the bundle would have loaded over the engine. See link/pop_flames.link.
* P3.31: $4200 -> $3000, and the base is ONE literal for the whole build, passed as
* -DFLAME_BASE by build.bat. P3.62: it now goes to THIS FILE ONLY. char_draw.s used to
* take it too and declare its own copies of the offsets below; it is linked inside the
* bundle, so it imports blit_cel/blit_save/blit_erase instead and no longer knows or
* needs the base. FLAME_BASE_TAB, a second name for the same address in this file alone,
* is retired with it.
                ifndef  FLAME_BASE
FLAME_BASE      equ     $3000
                endc
* ★ THE ONLY HOME FOR THE BUNDLE'S LAYOUT (P3.62), and it is here because this program is
* SEPARATE from the bundle: the room is LOADM'd to $2000 and reads the bundle to $3000 at
* run time, so it must reach in by arithmetic. Everything else that needs the blitter is
* linked with it and uses symbols.
*
* THESE TRACK flame_cels.s'S DECLARATION ORDER AND MUST MOVE WITH IT. P3.54 retired the
* third compiled table (flame_erase, 18 B) and everything after it shifted up by 18:
* blit_tab +58 -> +40, chars_tab +64 -> +46. The build LINKED CLEANLY with the old values,
* booted, read the disk twice, stepped the VM, and only then jumped into cel data.
*
* SO IT IS NO LONGER TRUSTED TO A COMMENT. build.bat runs bundle_offsets_check.py after
* the flames link: it reads these `equ`s out of this file, reads blit_tab/chars_tab out of
* build/obj/flames.map, and FAILS THE BUILD if they disagree. A clean link and a good boot
* were never the check — both passed while these were wrong.
* ★★ THE MUSIC PLAYER, reached at fixed offsets exactly as the bundle's own entry points
* are. Read to $0A00 by intro_seq.s at start-up; nothing in the scene's map touches that
* region (scene program $2500, bundle $3000, SAVE_BUF $5400, peels $6C00).
MSYS_BASE       equ     $0A00
msys_stop       equ     MSYS_BASE+6

BLIT_TAB        equ     FLAME_BASE+40           ; blit_cel / blit_save / blit_erase
CHARS_TAB       equ     FLAME_BASE+46           ; chars_frame (piece D), +2 = chars_due
CELS_TAB        equ     FLAME_BASE+50           ; cel_load_startup, +2 = cel_service_read

* ★ THE ROOM BLOB MOVED TO FLAME_LOAD AT P3.78b. It was $3000, which is where the
* expanded bundle lives — and the bundle is now expanded FIRST so that its cel loader
* exists before the picture is revealed (see room_start). FLAME_LOAD is free from the
* moment bundle_expand has run: it is where the PACKED bundle was read to, and nothing
* reads it again. 4,608 B from $5800 ends at $69FF, clear of the disk parameter block at
* $6A00 — the same bound the packed bundle already had to satisfy.
ROOM_BLOB       equ     FLAME_LOAD

SAM_SLOW        equ     $FFD8           ; the FDC needs normal speed (§2G disk rule)
SAM_FAST        equ     $FFD9
DSKREG          equ     $FF40

room_entry      jmp     room_start      ; +0   EXEC address (standalone: sets its own stack)

probe_status    fcb     0               ; +3   0=boot 1=mode set 2=room up 3=holding
probe_loads     fcb     0               ; +4   successful disk reads
probe_dskerr    fcb     0               ; +5   WD1773 status of the first failure
probe_magic     fdb     0               ; +6   set once the room is on screen
probe_frames    fcb     0               ; +8   frames of flicker completed
probe_cel0      fcb     0               ; +9   cel each torch is showing —
probe_cel1      fcb     0               ; +A   the pixel check composites these

* ---------------------------------------------------------------
* ★★★ room_call — THE INTEGRATED ENTRY (P3.107), AND IT EXISTS BECAUSE OF THE STACK.
*
* room_start opens `lds #STACK_TOP` and STACK_TOP is $7F00 — and intro_seq.s sets its
* stack to the very same $7F00 [intro_seq.s:104,233]. So a `jsr` from the intro into
* room_start would reset S on top of the caller's own frames and then push over them: the
* return address would be gone before the first subroutine call, and the symptom would be
* a wild `rts` many milliseconds later.
*
* ★★ THAT IS WHY THE ENTRY IS SEPARATE RATHER THAN A FLAG. The two paths want genuinely
* different stack behaviour — the standalone one MUST take the stack away from DECB (whose
* own stack sits near $7F2B with its string space above it), and the called one must NOT
* take it away from the intro. One entry with a mode byte would be one routine pretending
* to be two.
*
* IT SITS AFTER THE PROBE BLOCK ON PURPOSE. Every harness reads the probe bytes as offsets
* from `room_entry` (walk_test.lua's `rd8(ENGINE + 6)` is the magic), so a new entry ahead
* of them would move all seven and re-point five files to save three bytes.
* ---------------------------------------------------------------
room_call       jmp     room_called     ; +B   called entry — keeps the caller's stack

* ★ AND THE OFFSET IS ASSERTED, NOT DOCUMENTED. intro_seq.s calls SCENE_BASE+SCENE_CALL_OFF
* and cannot see this label — the two are separate link units and the intro is assembled
* before the scene is linked. Both take SCENE_CALL_OFF from the same -D, so the duplicated
* fact is one number, and this turns a drift in it into a build error instead of a jsr into
* the middle of probe_magic.
                ifndef  SCENE_CALL_OFF
SCENE_CALL_OFF  equ     11
                endc
                ifne    room_call-room_entry-SCENE_CALL_OFF
                fail    "room_call moved: intro_seq.s's SCENE_CALL_OFF no longer points at it"
                endc

ROOM_MAGIC      equ     $4B00


* room_called — entered by `jsr` from the intro. Keeps the caller's stack and remembers it,
* so the exit can put S back exactly where the `jsr` left it and `rts` to the beat loop.
* ★ `sts` runs AFTER the jsr has pushed the return address, so rs_saved_s captures a stack
* whose top IS that address — which is the whole of what makes the return work.
room_called
                sts     rs_saved_s
                lda     #1
                sta     rs_called       ; the exit path is chosen here, not guessed later
                bra     room_common

room_start
                clr     rs_called       ; standalone: nothing to return to
                orcc    #$50            ; mask while the machine comes up
                lds     #STACK_TOP
room_common
                orcc    #$50            ; mask while the machine comes up
                clra
                tfr     a,dp

                jsr     HAL_sys_init            ; PIAs, MMU, MC3=1
                jsr     HAL_mem_size_detect
                jsr     HAL_time_init
                andcc   #$EF                    ; opt in to real VBL waits

* THE MODE SWAP. GFX_MODE_320x192x4 is mode 0 and was the HAL's original reference
* mode -- the intro's 16-colour is the newer one. set_mode clears both buffers and
* maps the back one at HAL_gfx_draw_base, so nothing here needs to know block numbers.
                lda     #GFX_MODE_320x192x4
                jsr     HAL_gfx_set_mode
                lda     #1
                sta     probe_status

                jsr     disk_read_init

* EVERY DISK READ HAPPENS HERE, BEFORE THE PICTURE IS SHOWN.
*
* Jay: "it takes like 2 seconds between the static screen being rendered and the
* torches to be drawn and start animating." It did, and both seconds were disk: the
* room used to be swapped into view as soon as it unpacked, and only THEN did the
* engine read a second room track (for the other buffer) and the flame track. The
* delay was not slow flames -- it was a still picture being displayed during two
* track reads that had not happened yet.
*
* The second room read was pure waste. The blob is ONE track of 4,608 bytes and the
* unpacker only READS it (`lz_end`, the writer bound, is what terminates -- see
* lz_unpack.s), so the same blob expands twice. Landing it in main RAM at $3000
* instead of high in the draw window is what makes that possible: the window is
* remapped by the swap, so a blob living there is gone the moment the buffers flip,
* while $3000 stays put. One track read becomes one track read plus a memory
* decompress of a few frames.
* ★★ THE BUNDLE IS READ AND EXPANDED FIRST NOW (P3.78b), AND THE ORDER IS THE FIX.
*
* P3.78 moved the cel-page loader INTO the bundle, because the room could not carry it and
* stay under the LOADM ceiling. That made the cel read depend on bundle_expand — and
* bundle_expand had to follow HAL_gfx_mirror, because it lands on the room blob's ground.
* So the cel pages ended up after the mirror, and THE MIRROR IS THE REVEAL: it writes the
* finished room into the FRONT buffer, the displayed one. Eight tracks of disk then ran
* with the completed picture on screen and nothing moving.
*
* That is precisely the bug P3.72f removed, and the paragraph it left behind says so. I
* re-introduced it and then wrote "the load still happens BEFORE room_present, so it is
* still a black screen" three paragraphs underneath the text explaining that the reveal is
* at the mirror and NOT at room_present. Jay found it in one viewing: "the initial disk
* load is occurring with the static screen shown, it shouldn't appear until after the
* load."
*
* THE ORDER THAT WORKS, and it needs no new code — only the blob to move house:
*
*     bundle -> expand      the loader exists, and nothing is on screen
*     cel pages             eight tracks, still against black
*     room blob -> unpack   the picture is BUILT but not shown
*     mirror                ...and only now is it revealed, with every read finished
*
* The room blob moves from $3000 to FLAME_LOAD, because $3000 is where the expanded bundle
* now lives by the time the blob is read. FLAME_LOAD is free the instant bundle_expand has
* run — it is where the PACKED bundle sat — and the slow path's second unpack reads it
* from there too.
                ldx     #FLAME_LOAD
                lda     #DISK_FLAME_TRK
                ldb     #DISK_FLAME_SEC
                jsr     load_tracks
                lbne    room_failed
                jsr     bundle_expand           ; the bundle is live from here on

* THE CEL PAGES — eight tracks, and every one of them against a black screen.
                jsr     room_load_cels

* THE ROOM PICTURE, read LAST and into the space the packed bundle has just vacated.
                ldx     #ROOM_BLOB
                lda     #DISK_ROOM_TRK
                ldb     #DISK_ROOM_SEC
                jsr     load_tracks
                lbne    room_failed

* THE CEL IMAGE, AND IT BELONGS HERE WITH THE OTHER TWO — MOVED UP AT P3.72f.
*
* It was AFTER HAL_gfx_mirror, and that was wrong in exactly the way the paragraph below
* documents. The mirror writes the finished room into the FRONT buffer, which is the
* DISPLAYED one -- so the picture appears at the mirror, not at the swap -- and three
* whole tracks at ~3.3 s each then ran with the completed room sitting on screen and
* nothing moving. Jay, watching it live: "there is a long wait between the static
* background drawing and the torch flames and princess appearing." That is ten seconds
* of disk after the reveal, and it is the same bug P3.17 removed and this file already
* warns about: work done AFTER the reveal that the viewer has to wait through.
*
* MY REASON FOR PUTTING IT LATER WAS SIMPLY WRONG. The old comment claimed "reading the
* cels first would put them exactly where the mirror is about to write". It would not.
* The mirror maps the FRONT BUFFER's blocks at $FFA6/$FFA7 and writes there; the bank's
* physical blocks $0E/$0F are not mapped while it runs, so they are untouched. Same CPU
* addresses, different physical memory -- which is the entire point of the MMU, and
* exactly the confusion between the CPU's view and the machine's that gfx.s calls out at
* its own head.
* THE P3.72f LESSON IS KEPT BY THE ORDER ABOVE, not by a claim here: every disk read is
* finished before HAL_gfx_mirror runs, and the mirror is the reveal.

                ldx     HAL_gfx_draw_base       ; X -> the picture
                ldu     #ROOM_BLOB              ; U -> the blob, in main RAM
                jsr     lz_unpack

                jsr     ps_savebg               ; the room under each star, once

* MIRROR BEFORE THE REVEAL, so nothing is built while the viewer waits. Jay, on the
* first fix: "there's still a visible delay but not horrible" -- 15 frames of it,
* which is the second LZ expand almost exactly (15,360 B at ~30 cy/byte against a
* 29,859 cy frame). Copying the finished picture is cheaper than expanding it twice,
* and doing it here rather than after the swap means it happens against a black
* screen instead of against the finished room.
                jsr     HAL_gfx_mirror
                bcc     room_filled             ; 16-colour would refuse; this is not

* THE FALLBACK, and it is the OLD behaviour rather than a failure. If the mirror ever
* refuses -- it does so only in a mode whose framebuffer needs the whole window -- the
* second buffer still has to be filled, and expanding the blob again is exactly how this
* worked before. The scene stays correct; it just costs the 15 frames back.
*
* ★ IT REJOINS THE MAIN PATH NOW RATHER THAN DUPLICATING ITS TAIL (P3.78). It used to
* carry its own copy of bundle_expand + the reveal and fall into room_ready; both copies
* then had to grow when the cel load was added, and ROOM.BIN has ONE BYTE of headroom
* under the LOADM ceiling. Merging costs the slow path one extra buffer flip, which shows
* the buffer it has just filled — correct either way.
                jsr     room_present            ; reveal, then fill the other buffer
                ldx     HAL_gfx_draw_base
                ldu     #ROOM_BLOB
                jsr     lz_unpack
room_filled
* THE BANK MUST BE RE-MAPPED HERE. The mirror above rewrote $FFA6/$FFA7 to reach the
* front buffer and restored them to the BACK buffer's blocks, not to the bank — the same
* four-register ownership P3.68 established and P3.71 was bitten by. The cels are already
* in physical RAM; this only brings the window back onto them.
                jsr     cel_bank_map

                jsr     room_present            ; the room appears, ready to animate

room_ready
* No cel-pointer patching any more: the slot records and the cel data are in the
* same object now, so the linker resolves them and char_tab is vestigial.
* ch_ready is gone: it guarded the draw against running before the room was up, but
* room_loop is only reached from here anyway, so the flag was checking a condition
* the control flow already guaranteed.
                lda     #2
                sta     probe_status
                ldd     #ROOM_MAGIC
                std     probe_magic

* ---------------------------------------------------------------
* PHASE B — the torch flicker.
*
* The room is a still picture; the two torch flames are the only thing that moves,
* and they move EVERY frame. In the oracle `pburn` is called twice per frame and
* advances one torch each time, round-robin over a 2-entry table:
*
*     ptorchx     db 13,25,-1     ; byte columns, -1 ends the list
*     ptorchoff   db 0,6          ; SUB-BYTE offsets
*     ptorchy     db 113,113
*     ptorchstate db 1,6          ; initial flame frames
*
* Pixel X = ptorchx*7 + ptorchoff = 91 and 181, which under the 280->320 centring
* land at CoCo pixel 111 and 201 -- byte 27.75 and byte 50.25. MEASURED against the
* running oracle, the flames flicker in columns 27-29 and 50-51 and in rows 104-113,
* which confirms both the arithmetic and that ptorchy is the BASELINE: a 13-row cel
* ending at 113 starts at 101.
*
* SUB-BYTE IS ROUNDED, DELIBERATELY AND VISIBLY. A compiled sprite is byte-granular
* by construction, so torch 0 is placed at byte 28 (1 px right of true) and torch 1
* at byte 50 (1 px right). One pixel each. Doing better means pre-shifted phase
* variants, which is exactly what the parallel sub-byte recon exists to cost -- this
* does not pre-empt it.
* ---------------------------------------------------------------
room_hold
                lda     #3
                sta     probe_status
* DRAW, THEN WAIT, THEN FLIP. The order matters at this rate and did not at the
* intro's. HAL_gfx_swap writes VOFFSET ($FF9D); doing that mid-frame moves the
* display's base address while the GIME is part-way down the screen, so the top of
* the frame comes from one buffer and the bottom from the other. The intro swaps
* once per caption and never showed it; here it happened 60 times a second, which is
* a continuous tear — and a tear in 4-colour is not merely a shifted image, it lands
* the raster on different bit pairs and reads as colours that are in NEITHER buffer.
* That is the shape of what Jay reported: blue in flames whose cels contain no blue.
* ONE VBL WAIT PER FRAME, NOT TWO.
*
* This loop used to wait here AND inside HAL_gfx_swap, which opens with its own
* HAL_time_vbl_wait before moving VOFFSET. Two waits meant two frame boundaries per
* iteration, so the loop ran at 30 Hz and FLAME_DIV=3 stepped the flames every SIX
* video frames -- 10.0 Hz, measured, against the oracle's 22.8. The divider was chosen
* believing this loop ran at 60 Hz, so the rate was off by exactly the factor the
* extra wait introduced.
*
* Removing this wait does NOT reopen the tear that P3.17 fixed. That bug was ordering:
* VOFFSET moved mid-frame because the swap happened before any wait. The wait that
* prevents it is the one INSIDE swap, which is still there and still runs first. The
* order is unchanged -- draw, wait, move VOFFSET -- it is only counted once now.
* ---------------------------------------------------------------
* THE ANIMATION STEP IS THE UNIT OF DRAWING (P3.51), and it is the oracle's structure.
*
* This loop used to draw and flip EVERY video frame: flicker, chars_frame and
* HAL_gfx_swap all unconditional. The oracle does not. `play` -> `FrameAdv` -> `DoFast`
* draws the torches, stars, sand, hourglass and characters in ONE pass into the hidden
* page and flips ONCE, per ANIMATION STEP [SUBS.S:876-914, :967, :1002-1007].
*
* The cost of the difference was measured: the frame is 57,074 cy against a 29,673 budget
* -- 192% -- while the same work inside a 2.60-frame step has 77,150 cy to spend, which is
* 70%. Nothing had to get faster; the work had to stop happening five times as often as
* the content changes.
*
* ASK BEFORE DRAWING ANYTHING. chars_due reads the same vm_now/vm_due comparison
* vm_nextframe uses and reports whether a step is due, without advancing it. The test has
* to happen HERE, ahead of flicker, because flicker advances the torch: a gate inside
* chars_frame would fire after the torch had already stepped, and reordering the two would
* put the torches on top of the characters where they overlap.
*
* vm_nextframe STILL OWNS THE STEP. chars_due asks; cad_idx advances where it always did.
* Two things deciding one cadence is exactly the defect this change removes from flicker.
* ★★ THE LOOP RUNS AT THE FLAME RATE NOW, NOT THE CHARACTER RATE (P3.72k).
*
* The gate above was chars_due, so the flames advanced once per CHARACTER STEP. Measured
* on both machines off the same signal, with the room up and nothing else moving:
*
*     oracle   2.3 frames between torch changes = 26.2 Hz
*     port     6.0 frames                       = 10.0 Hz
*
* -- and it got worse when the step rate was re-anchored to the oracle's 6 frames at
* P3.72d, from 15.7 Hz to 10.0. The flames were never the oracle's; they were whatever
* the character cadence happened to be. In the oracle pburn runs from the play loop and
* does not answer to the animation cadence at all [SUBS.S:876 play / MOVEDATA.S torch].
*
* THE DECOUPLING NEEDS NO CHANGE TO char_draw, because chars_frame is ALREADY the two
* phases the oracle keeps distinct: vm_nextframe DECIDES and vm_frameadv DRAWS, and
* vm_nextframe's gate is `vm_now - vm_due` against the real frame count. That comparison
* is idempotent under being asked more often -- calling it every 2-3 frames instead of
* every 6 steps the characters on exactly the same frames and simply draws them more
* often. So the room stops asking chars_due and paces itself on the torch instead; the
* VM keeps owning its own cadence, which is the property the note above is protecting.
*
* WHY THE WHOLE LOOP AND NOT JUST flicker: the flames are drawn into the BACK buffer and
* only a swap makes them visible, so a 26 Hz flicker requires a 26 Hz swap. The character
* redraw comes along with it. That is affordable because the peel is the expensive half
* and ch_anymove already skips it when nothing moved -- between steps the characters are
* draw-only, which P3.21 measured as fitting in one frame.
FLM_LEN         equ     3
room_loop
* ★★★ THE EXIT, AND IT IS AT THE TOP FOR A REASON (P3.107). room_loop has TWO arms and
* both used to end `bra room_loop` — the idle path at rl_idle and the draw path at the foot
* of rl_draw. A terminal test bolted onto one of them would leave the scene returning only
* when the torch happened to be due, which is a 1-in-3 chance per pass and would have read
* as an intermittent hang. One test, above the branch that separates them, cannot do that.
*
* ★★ AND S IS A REAL STACK HERE. blit_core uses S as the blast destination and returns by
* a software return precisely because `jsr` would push onto it — so an exit taken from
* inside the blitter could not `rts` at all. This point is above every draw call: the only
* thing on the stack is what the caller pushed.
                lda     cel_scene_done          ; published by the terminal beat
                lbne    room_return
                jsr     HAL_time_frame_count    ; D = 16-bit frame count (race-safe)
                std     rl_now
                subd    flm_due
                bpl     rl_draw                 ; the torch is due
* IDLE: the torch has not moved on, so the displayed buffer is still correct -- do not
* redraw it and do not flip. The VBL wait is NOT optional: HAL_gfx_swap is what paces this
* loop, and skipping the draw without waiting would spin the CPU at full speed, burning
* the budget this change exists to reclaim while putting nothing new on screen.
                jsr     HAL_time_vbl_wait
                bra     room_loop

rl_draw
* SCHEDULE THE NEXT TORCH STEP, from the same table the oracle's histogram gave. Measured
* there: gaps of 1 x11, 2 x102, 3 x61 over 400 frames -- mean 2.3. `2,2,3` is 2.33, which
* is the closest a whole-frame cadence gets without inventing precision the measurement
* does not have.
                lda     flm_idx
                inca
                cmpa    #FLM_LEN
                blo     rl_fwrap
                clra
rl_fwrap
                sta     flm_idx
                ldx     #flm_cad
                lda     a,x
                tfr     a,b
                clra                            ; D = the frame count, zero-extended
                addd    rl_now
                std     flm_due

                jsr     flicker                 ; into the back buffer
* PIECE D lives in the disk-resident bundle, not in ROOM.BIN. Three dispatches have
* now hit the LOADM ceiling by growing this program (P3.20 twice, P3.22 once), and
* P3.22 proved it is SIZE alone: the green baseline plus 175 bytes of dead `rmb`
* reproduces the failure exactly (status $40, no disk reads). So the character code
* went the same way the blit core and the cels did.
*
* The two HAL values it needs are passed as ARGUMENTS rather than linked, which is
* what lets it live in a bundle that has no HAL: A = which buffer, X = its address.
* The VM paces off REAL VBLs, not off loop iterations — P3.25 measured the old
* iteration counter at 3.09 frames/step against a 2.60 table, because one iteration
* stopped equalling one frame the moment the VM added work. The bundle links without
* the HAL, so the frame counter is handed over like the other two HAL values.
                jsr     HAL_time_frame_count    ; D = 16-bit frame count (race-safe)
                tfr     d,u
                lda     HAL_gfx_cur_back
                anda    #1
                ldx     HAL_gfx_draw_base
                jsr     [CHARS_TAB]             ; chars_frame, in the bundle
* ★ THE STAGED READ (P3.78). The beat schedule raises cel_rd_req when a page is due, and
* it only ever does so in a beat it has ALREADY asserted draws nothing but pinned cels —
* so the block the track lands in is one nothing on screen is coming from.
*
* SERVICED HERE, AFTER THE DRAW AND BEFORE THE FLIP, for one reason: this is the point in
* the loop where the frame is complete. Reading before the draw would leave the half-built
* back buffer displayed across the whole transfer; reading after the flip would be the
* same thing one frame later. Neither is better than freezing on a finished frame.
*
* THE TORCHES FREEZE FOR THE TRANSFER AND IT IS SURFACED, NOT SMOOTHED. There is no DMA
* here: disk_read_range polls the FDC with interrupts masked and the CPU IS the transfer,
* so nothing else runs. Jay accepted 1.7 s at P3.75 §4A for one track plus a spin-up; a
* page is two tracks, so this is the number to check at the gate rather than the design.
                ldy     #load_tracks            ; the bundle has no HAL and no room —
                jsr     [CELS_TAB+2]            ;   the disk arrives as an argument
                jsr     room_present            ; waits for VBL, moves VOFFSET, re-maps
* The probes must name what is DISPLAYED, not what was last drawn. flicker draws into
* the back buffer; only the swap makes it the front. Publishing the cel numbers here
* -- after the swap -- is what makes them describe the buffer the test actually reads.
* Before this they were set during the draw, so a sample taken between the VBL wait
* and the swap compared the NEW cel numbers against the OLD picture.
                lda     pend_cel0
                sta     probe_cel0
                lda     pend_cel1
                sta     probe_cel1
                inc     probe_frames
                bra     room_loop

* ---------------------------------------------------------------
* ★★★ room_return — TERMINATE, RESTORE, RETURN (P3.107).
*
* THE RESTORE IS ENUMERATED HERE RATHER THAN DISCOVERED LATER, and each item says whether
* it is DONE here or ESTABLISHED as self-correcting, with the evidence:
*
*   $FFA6/$FFA7  the cel bank's window. RESTORED BY set_mode, and NOT by hand — see the
*                note at the store below for what happened when this list said otherwise.
*   ★★★ video mode  RESTORED, and the first version of this list said it did not need to be.
*                THAT WAS WRONG ON A FACT THIS FILE ALREADY STATED. Forty lines above,
*                the mode swap's own comment reads "the intro's 16-colour is the newer
*                one" — and the restore list said "that is the HAL's OTHER mode, which the
*                intro does not use." I read the sentence and wrote down its opposite.
*
*                The two modes are not cosmetic variants:
*                  GFX_MODE_320x192x4   $FF99=$15   80 B/row   15,360 B   4 palette regs
*                  GFX_MODE_320x192x16  $FF99=$1E  160 B/row   30,720 B  16 palette regs
*                Different STRIDE. Returning in 4-colour leaves the intro drawing 16-colour
*                screens through an 80-byte row, so every row after the first lands in the
*                wrong place — which is exactly what introseq's reprise check reported:
*                "19717 bytes differ; first at row 0 col 10".
*
*                ★ Jay caught it by eye before the suite's message was diagnosed: "it looks
*                like you are not properly switching back to DHRes after the vizier scene
*                completes."
*
*                THE ORACLE HAS THE SAME SEAM. MASTER.S runs PrincessScene, then
*                SetupDHires, then Prolog2 — the mode swap sits between the scene and the
*                next picture there too. ★ This is NOT that routine and does not claim to
*                be: SetupDHires establishes the game's display and is still absent. This
*                only puts back what the scene borrowed.
*   ★★ palette   NOT restored here, and NOT self-correcting — this list said it was and was
*                wrong a second time. It cited intro_seq.s's palette comment as though it
*                described load_screen; it describes the STARTUP path, which installs the
*                sixteen registers ONCE. load_screen never touches them. So the scene's two
*                set_mode calls leave the diagnostic palette behind and every later beat is
*                drawn in the wrong colours. ★ Jay: "you need to restore the DHRes palette."
*                THE CALLER DOES IT, and it has to: the palette's source is BUNDLE_PAL at
*                $3000, which the scene overwrote and which only the caller can reload.
*                intro_seq.s's run_scene calls set_dhr_palette after the caption read.
*   DP           NOT restored: both set it to 0 and never move it [intro_seq.s:235,
*                room_common above].
*   S            restored from rs_saved_s — see room_called.
*   interrupts   the scene runs with VBL IRQs enabled (andcc #$EF at entry) and the intro
*                wants the same; left as they are.
* ---------------------------------------------------------------
room_return
* ★★★ THE SONG DIES WITH THE SCENE (P4.23). The scene's beats START songs and never stop
* them -- a song outlives its own beat by design -- so this is the only place that knows
* the scene is over. A scene returning with a live FIRQ hands the intro an interrupt it
* does not know about, and the intro's next beat would then be sharing the GIME's timer
* with a song nobody is listening to.
* ★ Idempotent and safe when no song ever played, which is why it is unconditional. It is
* also correct on the STANDALONE path below: room_dead holds forever, and holding with the
* speaker live is worse than holding silent.
                jsr     msys_stop
                lda     rs_called
                beq     room_dead               ; standalone: nothing to return to, hold
* THE MODE, BACK TO THE INTRO'S. set_mode clears both buffers and re-maps the window, so it
* is done FIRST and the window fix-up below is what survives it.
                lda     #GFX_MODE_320x192x16
                jsr     HAL_gfx_set_mode
* ★★★ AND THE WINDOW NEEDS NOTHING FURTHER — THE FIRST VERSION OF THIS PUT IT BACK BY HAND
* AND THAT WAS THE DEFECT. It wrote $3E/$3F into $FFA6/$FFA7 after set_mode, on the
* reasoning that "set_mode owns $FFA4/$FFA5". It owns ALL FOUR: the 16-colour buffer is
* 30,720 B — four 8 KB blocks — so $FFA4-$FFA7 together ARE the framebuffer.
*
* Overwriting the top two put the boot map back under $C000-$FFFF, so everything the intro
* then drew above row ~115 went somewhere else. introseq caught it precisely:
* "9_prolog2 == its own converted picture: 12260 bytes differ; first at row 102 col 64".
* 12,260 of 30,720 is the top 40% of the screen, which is exactly the two blocks.
*
* ★ So the restore for the window is set_mode itself, and the correct action here is none.
* Recorded rather than deleted because the wrong version looked more careful than the right
* one — it named registers and cited an owner, and the owner was wrong.
                lds     rs_saved_s              ; the caller's stack, with its return on top
                rts

room_failed
                lda     dr_status
                sta     probe_dskerr
room_dead
                jsr     HAL_time_vbl_wait
                bra     room_dead

* ---------------------------------------------------------------
* flicker — advance and redraw both torches, once per frame.
*
* Unrolled rather than looped over a table. There are exactly two torches, at fixed
* positions, forever; a loop here buys nothing and costs index arithmetic on every
* access, which is precisely where a first draft of this went wrong.
*
* Per torch the order is ERASE(previous) -> SAVE(new) -> DRAW(new). The save cannot
* be hoisted out of the loop even though the background never changes, because each
* cel has its OWN footprint: erase_flameN restores exactly the bytes save_flameN
* captured, so a save taken for one cel does not serve another.
* ---------------------------------------------------------------
* ---------------------------------------------------------------
* THE RATE. Measured on the running oracle, its flames change every 2-3 video frames
* under SPEED 7 and every 6 under SPEED 12 -- mean 2.6 frames, 22.8 Hz.
*
* `play` is the reason: its loop is `pause SPEED` then NextFrame/FrameAdv, so ONE
* engine frame spans many video frames and everything the engine animates -- flames,
* stars, characters -- steps at that rate, not at the display's.
*
* THE DIVIDER IS DELETED, NOT RETUNED (P3.51). `FLAME_DIV equ 3` was a SECOND cadence,
* counted in LOOP ITERATIONS rather than video frames -- the identical unit error P3.25
* fixed for the VM and never fixed here. Measured, it gave a torch step every 3 iterations
* x 2.159 frames = 6.48 frames = 9.25 Hz, against the "~20 Hz" its own comment claimed. It
* was not merely mistuned: a second divider cannot be made to agree with the first, it can
* only be removed.
*
* Now room_loop runs this routine ONLY on an animation step, so the torch advances once
* per step and the state advance is unconditional. That is `pburn` in the oracle's
* `DoFast` -- one advance per drawn frame, in the same pass as the characters, and the
* flame rate IS the step rate rather than a number of its own [SUBS.S:967, :1002-1007].
* ---------------------------------------------------------------

flicker
                inc     fl_step         ; every call is a step now — see room_loop
* slot = buffer parity * 2 + torch. Each of the four slots owns a peel buffer and a
* "cel last drawn there", because a buffer is redrawn only every other frame and its
* erase must restore what was saved INTO IT, not into its twin.
*
* THE PARITY IS READ FROM THE HAL, NOT KEPT HERE (P3.50). It used to be a local `fl_buf`
* toggled at the foot of this routine -- and P3.17, moving HAL_gfx_swap out to room_loop,
* put the replacement `rts` ABOVE that toggle instead of below it. Three instructions went
* unreachable, `fl_buf` stayed 0 forever, and `fl_slot` was therefore ALWAYS 0: both
* buffers shared slots 0-1, slots 2-3 were never touched, and every erase restored into
* the twin of the buffer it was saved from -- exactly what the paragraph above forbids.
* Thirty dispatches passed without notice, because the room beneath the torches is static
* and identical in both buffers, so the wrong copy almost always wrote the right bytes.
*
* A SECOND COPY OF "WHICH BUFFER" IS WHAT MADE THAT SILENT. HAL_gfx_cur_back already holds
* it, and room_loop already passes it to chars_frame as the character side's slot index --
* so a local toggle was a parallel home for a fact that has an owner, and a parallel home
* can drift with nothing disagreeing out loud (P3.31: one home per fact). Derived here,
* the torch slots and the character slots cannot disagree about which buffer is being
* drawn, because they read the same byte.
*
* Measured after this change (P3.48, re-confirmed P3.49): `fl_slot` written 0:347 2:347
* where it had been 0 for every frame, parity agreeing with the HAL 694/694, and all four
* slots saving AND erasing at their own addresses.
                ldb     HAL_gfx_cur_back
                andb    #1                      ; the same mask room_loop applies
                lslb                            ; slot base for this buffer
                stb     fl_slot

                ldd     #TORCH0_OFF
                std     t_off
                ldd     #TORCH0_CELS            ; phase-3 cels — px 111 (P3.56; the "phase-0,
*                                               ;   px 112" this said was the pre-P3.56 siting)
                std     t_tab
                lda     fl_slot
                jsr     slot_peel
                std     t_peel
                lda     fl_slot
                ldx     #fl_prev
                lda     a,x
                sta     t_prev
                lda     fl_state0
                tst     fl_step
                beq     fl_keep0
                jsr     next_flame
                sta     fl_state0
fl_keep0
                jsr     torch_step
                sta     pend_cel0
                ldb     fl_slot
                ldx     #fl_prev
                abx
                sta     ,x

                ldd     #TORCH1_OFF
                std     t_off
                ldd     #TORCH1_CELS            ; phase-1 cels — px 201, the correction
                std     t_tab
                lda     fl_slot
                inca
                jsr     slot_peel
                std     t_peel
                lda     fl_slot
                inca
                ldx     #fl_prev
                lda     a,x
                sta     t_prev
                lda     fl_state1
                tst     fl_step
                beq     fl_keep1
                jsr     next_flame
                sta     fl_state1
fl_keep1
                jsr     torch_step
                sta     pend_cel1
                ldb     fl_slot
                incb
                ldx     #fl_prev
                abx
                sta     ,x

                jsr     pstars                  ; and the window
                clr     fl_step
                rts
* THE ORPHAN IS DELETED, NOT MADE REACHABLE (P3.50). Three instructions -- `lda fl_buf` /
* `eora #1` / `sta fl_buf` -- sat below this `rts` from P3.17 until now, unreachable and
* still carrying every appearance of live bookkeeping: valid syntax, assembled into the
* image, and described by a comment forty lines up. Restoring them would put the parity
* back in two places; it comes from HAL_gfx_cur_back at the point of use now, so there is
* nothing left to toggle.

* slot_peel — A = slot 0..3; returns D = that slot's peel buffer address.
slot_peel
                ldb     #PEEL_BYTES
                mul                             ; D = slot * PEEL_BYTES
                addd    #peel_base
                rts

* torch_step — A = the new STATE (0..17). Erases whatever is there, then draws the
* cel this state selects. Returns A = the cel number, for the caller to remember as
* the next frame's "previous".
torch_step
                pshs    a
                ldy     #ptorchflame
                lda     a,y                     ; state -> cel number 1..9
                sta     t_cel
                puls    a

* THE CEL'S OWN HEADER IS THE ONE HOME FOR ITS DIMENSIONS (P3.54). blit_save and
* blit_erase need rows and width; taking them from anywhere but the cel about to be
* drawn is how P3.25's stride bug worked -- a save at one extent and an erase at
* another. All nine cels of a torch happen to share dimensions, so this cannot bite
* today; reading them from the header anyway is what keeps that true if it changes.
                lda     t_cel
                deca                            ; cels are 1..9; the tables are 0-based
                lsla                            ; two bytes per entry
                ldx     t_tab                   ; this torch's cel table
                ldu     a,x                     ; U -> the segment stream
                stu     t_data
                lda     ,u                      ; rows
                sta     t_rows
                lda     1,u                     ; width in bytes
                sta     t_wide

                ldd     HAL_gfx_draw_base
                addd    t_off
                std     t_dest                  ; where this torch lands this frame

                lda     t_prev                  ; erase what the last frame drew
                beq     ts_nosave               ; 0 = nothing drawn yet
                ldx     t_dest
                ldy     t_peel
                lda     t_rows
                ldb     t_wide
                jsr     [BLIT_TAB+4]            ; blit_erase (preserves X,Y,U)
ts_nosave
                lda     t_cel
                sta     t_prev
                ldx     t_dest                  ; capture the background this cel covers
                ldy     t_peel
                lda     t_rows
                ldb     t_wide
                jsr     [BLIT_TAB+2]            ; blit_save (preserves X,Y,U)
* DRAW LAST, because blit_cel clobbers A,B,D,X,Y,U -- only the peel primitives preserve
* them, which is why the order is erase, save, draw and not any other.
                ldx     t_dest
                ldu     t_data
                jsr     [BLIT_TAB]              ; blit_cel
                lda     t_cel
                rts

* torch_call DELETED at P3.54 — it existed to tail-jump into a COMPILED sprite routine
* selected from one of three per-cel tables. With segment streams there is one generic
* blitter and one generic peel, so the dispatch has nothing left to dispatch.

* ---------------------------------------------------------------
* pstars — the four stars outside the princess's window. [SUBS.S:360 pstars]
*
* Each frame: count down any lit star and put it out when it expires, then roughly
* one frame in 25 light a RANDOM star for 5-8 frames. So the window is mostly dark
* with occasional single points -- the oracle's own rates, ported.
*
* NOT compiled sprites, and deliberately. A star is ONE PIXEL: cels $2A/$2B convert
* to a single byte $10, one pixel of colour 1. A compiled sprite would be three
* generated routines and a dispatch to write one byte. The flames earn that machinery
* (13 rows, 9 cels, mixed RMW throughout); a star does not.
*
* The background under each star never changes, so it is saved ONCE and the star is
* just a masked write over it -- which also makes "erase" exact by construction.
* Both buffers converge because every frame redraws all four into the back buffer.
* ---------------------------------------------------------------
* TWINKLE draws with OPACITY = eor, onto both pages [GAMEBG.S:794]. So a star is not
* a coloured pixel written over the window -- it is a BIT TOGGLE, and what it looks
* like depends on the art underneath. The window is not uniform there:
*
*   star 0 row  98 byte $03 -> [black,black,black,white]
*   star 1 row 101 byte $08 -> [black,black,BLUE, black]
*   star 2 row 109 byte $03 -> [black,black,black,white]
*   star 3 row 114 byte $00 -> [black,black,black,black]
*
* A fixed orange write gives all four the same appearance and lands on top of existing
* art; the EOR gives each its own, which is what the oracle shows.
*
* THE SUB-PIXEL WAS ALSO WRONG. starx=2 is an Apple BYTE column, so the cels light
* mono px 14+1=15 ($2B) and 14+5=19 ($2A); under the +20 centring those are CoCo px 35
* and 39, i.e. sub-pixel 3 of bytes 8 and 9 -- not sub-pixel 1. The mask is the low
* bit pair.
* AND EOR IS WRONG HERE, which Jay saw before I did: "its blue now instead of red".
* The oracle EORs in APPLE bit space, where toggling a bit lights a star. In our
* packed 4-colour space the same operation is arithmetic on a 2-bit colour index --
* and the art under two of the stars is white (3), so EOR $01 gives 2, which IS blue.
* The faithful result is "the star pixel takes the star's colour", so set it.
* AND THE POSITIONS ARE MEASURED, not derived. Deriving them from starx=2 plus the
* cel's lit bit gives only TWO distinct columns, because stari is 2a,2b,2b,2a. The
* running oracle shows FOUR: mono px 20, 14, 16, 19 on rows 98, 101, 109, 114
* [harness/tools/oracle_window_stars.lua]. Two of my four therefore landed on a white
* pixel that is already part of the window art, turning it orange instead of adding a
* star -- which reads as nothing happening, and is why Jay saw only one blink.
*
* Under the +20 centring those are CoCo px 40, 34, 36, 39 -> byte 10 sub-pixel 0,
* byte 8 sub-pixel 2, byte 9 sub-pixel 0, byte 9 sub-pixel 3. So the mask and value
* are PER STAR; a single pair cannot express four different sub-pixels.

* ps_savebg — capture the room byte under each star. Called once, after the room is
* up and before any star is drawn, so "erase" is exact rather than approximate.
ps_savebg
                ldx     #0
ps_sloop
                pshs    x
                tfr     x,d
                lslb
                ldy     #star_off
                ldd     b,y
                addd    HAL_gfx_draw_base
                tfr     d,y
                lda     ,y
                puls    x
                sta     star_bg,x
                leax    1,x
                cmpx    #4
                blo     ps_sloop
                rts

pstars
                tst     fl_step                 ; engine-paced, like the flames
                bne     ps_run
                jmp     ps_draw                 ; redraw, but do not age or light
ps_run
                ldx     #0
ps_age
                lda     star_cnt,x              ; age the lit ones
                beq     ps_agenext
                deca
                sta     star_cnt,x
ps_agenext
                leax    1,x
                cmpx    #4
                blo     ps_age

                jsr     rnd                     ; a new twinkle? ~1 frame in 25
                cmpa    #10
                bhs     ps_draw
                jsr     rnd
                anda    #3
                adda    #5                      ; lit for 5..8 frames
                sta     ps_dur
                jsr     rnd
                anda    #3                      ; which of the four
                tfr     a,b
                ldx     #star_cnt
                abx
                lda     ps_dur
                sta     ,x

ps_draw
                ldx     #0
ps_dloop
                lda     star_bg,x               ; the room, under this star
                ldb     star_cnt,x
                beq     ps_dark
                eora    star_eor,x              ; lit: TOGGLE this star's sub-pixel
ps_dark
                sta     ps_val
                pshs    x
                tfr     x,d                     ; B = star index 0..3
                lslb                            ; the offset table is 16-bit
                ldy     #star_off
                ldd     b,y
                addd    HAL_gfx_draw_base
                tfr     d,y                     ; Y -> this star's byte
                lda     ps_val
                sta     ,y
                puls    x
                leax    1,x
                cmpx    #4
                blo     ps_dloop
                rts

* ---------------------------------------------------------------
* next_flame — the oracle's GETFLAMEFRAME, ported. [MOVER.S:1084]
* A = current state; returns the next. A random draw below torchLast+1 JUMPS to that
* state (18 of 256 draws); otherwise it steps by one and wraps. So the flicker is
* mostly the designed 18-entry pattern with occasional jumps -- which is what makes
* it read as fire rather than as noise.
* ---------------------------------------------------------------
next_flame
                sta     fl_tmp
                jsr     rnd
                cmpa    fl_tmp
                beq     nf_step
                cmpa    #TORCHLAST+1
                blo     nf_done                 ; use the random state directly
                lda     fl_tmp
nf_step
                inca
                cmpa    #TORCHLAST+1
                blo     nf_done
                clra                            ; wrap
nf_done
                rts

* rnd — 8-bit xorshift. The oracle has its own generator and nothing here depends on
* matching its sequence, only on the jump happening at about the same RATE.
* AN 8-BIT LFSR IS NOT ENOUGH STATE HERE, and the failure was total rather than
* subtle: pstars draws THREE times per decision (gate, duration, which star), and in
* an 8-bit LFSR consecutive outputs share bits by construction -- bit0 of one output
* is bit7 of the previous, bit1 is bit0. After the `< 10` gate both are always zero,
* so `anda #3` returned 0 EVERY TIME and star 0 was the only one ever lit. Simulated
* over 20,000 engine frames: 496 lightings, 100% star 0, the other three never.
*
* That is exactly what Jay saw -- "the top most star is working, the three below are
* not" -- and why holding them all lit made all four appear: the DRAW was always
* correct, the SELECTION was not.
*
* Widening to 16 bits is not by itself the fix; a Galois-16 read from its low byte is
* just as skewed (star 3 never chosen). Taking the HIGH byte decorrelates the
rnd
                lsr     rnd_seed                ; 16-bit shift right; carry = old bit 0
                ror     rnd_seed+1
                bcc     rnd_no
                lda     rnd_seed
                eora    #$B4                    ; x^16+x^14+x^13+x^11+1
                sta     rnd_seed
rnd_no
                lda     rnd_seed                ; the HIGH byte is the output
                rts

* ---------------------------------------------------------------
* bundle_expand — expand the packed cutscene bundle down onto the room blob's ground.
*
* THE PACKING IS STRUCTURAL, NOT AN OPTIMISATION, and P3.30 proved that by breaking it.
* The bundle with the walk cels is 14,258 B unpacked. Three separate budgets bound it
* and they are NOT the same number:
*
*   disk bytes        2 tracks 9,216 / 3 tracks 13,824 / 4 tracks 18,432
*   resident bytes    14,258 -- packing does not move this one at all, because the
*                     blitter walks the segment stream in place
*   READ GRANULARITY  load_tracks reads WHOLE TRACKS. Four tracks from $3000 write
*                     through to $77FF -- straight across DR_VARBASE at $6A00, the disk
*                     driver's own parameter block, WHILE IT IS USING IT. The room hung
*                     at EXEC. So the room is not $3000-$77FF but $3000-$69FF = 14,848 B
*                     = 3.22 tracks, and 3 whole tracks is 13,824: the unpacked bundle
*                     cannot be loaded at ANY track count.
*
* Packed it is two tracks, and the expand is memory-to-memory, which has no track
* granularity at all. That is the whole reason this routine exists.
*
* WHY IT CANNOT OVERWRITE ITS OWN INPUT. Same argument as the intro screens (P3.12):
* the writer starts at FLAME_BASE and the reader starts high in the same window, and
* lz_pack places the stream so the writer never catches it -- then PROVES it by
* decoding the blob out of a single buffer exactly as lz_unpack does, rather than
* trusting the arithmetic. The measured slack for this blob is printed by the build.
*
* WHEN IT RUNS IS LOAD-BEARING. The destination IS the room blob, so this must not run
* until the blob has been read for the last time: after HAL_gfx_mirror on the fast path,
* and after the second lz_unpack on the slow one. It runs BEFORE the swap so the ~14
* frames it costs are spent against a black screen rather than in front of the finished
* room -- the same reason the mirror moved ahead of the reveal in P3.17.
* ---------------------------------------------------------------
bundle_expand
                ldx     #FLAME_BASE
                ldu     #FLAME_LOAD
                jmp     lz_unpack               ; tail call: nothing to preserve

* ---------------------------------------------------------------
* load_tracks — A = first track, B = sector count, X = destination.
* Returns Z set on success. Carried from intro_seq.s, including the two things that
* file learned the hard way: the FDC must run at NORMAL speed (double speed breaks
* it), and the drive must be RELEASED afterwards or it spins forever.
* ---------------------------------------------------------------
* ---------------------------------------------------------------
* cel_bank_map — bring the cel bank into the window at $C000.
*
* Two MMU writes under one interrupt mask. The mask is not ceremony: between the first
* write and the second the window is half bank and half framebuffer tail, and anything
* that ran in that gap would see a map that describes nothing. gfx_map_blocks documents
* the same hazard for its own four writes.
*
* Clobbers A only. Safe to call with the bank already mapped.
* ---------------------------------------------------------------
* ---------------------------------------------------------------
* room_load_cels — the split image's pages, through the bundle that now owns the loader.
*
* ★ IT CANNOT RUN BEFORE bundle_expand, which is what moved it out of the startup read
* block. The loader lives in the bundle (flame_cels.s cels_tab — the room could not carry
* it and stay under the LOADM ceiling), and the bundle does not exist until it is
* expanded. Everything else about the ordering is unchanged: on the main path this is
* still before room_present, so it is still a black screen the viewer waits at rather
* than a finished room with disk running under it (the P3.72f lesson, kept).
*
* ★★ AND IT LIVES HERE, WITH THE OTHER SUBROUTINES, RATHER THAN AT ITS CALL SITE. Written
* inline after the fallback path's `bsr`, the return FELL THROUGH INTO THE ROUTINE AGAIN
* and then RTS'd out of the room's startup entirely — the room stalled at status 1 with
* the read count climbing past twice what the schedule asks for (14 against 6), which
* reads exactly like a disk problem and is not one. A routine defined immediately below
* its own caller is a fall-through waiting for the first path that does not branch away.
* ---------------------------------------------------------------
room_load_cels
                ldy     #load_tracks            ; the bundle has no HAL and no room; the
                ldu     #disk_read_motor_off    ;   disk arrives as arguments
                jsr     [CELS_TAB]
                lbne    room_failed
* ★ THE DRIVE IS NOT RELEASED HERE ANY MORE (P3.84). It used to be, and each of the two
* mid-scene staged reads then found a stopped motor and paid dr_spinup's delay loop again
* — ~0.40 s apiece (P3.76's A/B measurement), inside a freeze the viewer is watching.
*
* The bundle holds it across the whole schedule and releases it the instant the LAST
* staged read completes, counting down from the pack's own CEL_N_READS. Releasing here
* was the right call while the cels were one startup load; it stopped being right when
* the schedule grew reads of its own.
*
* ★★ WHAT THIS DOES **NOT** DO, and the difference is worth stating: it does not HIDE the
* spin-up, it removes it from the second read only. Hiding it means starting the motor
* early and letting the flame loop run through it — and dr_spinup keys on the driver's own
* `dr_motor_on` flag, NOT on DSKREG ("that is why the flag is the driver's and not the
* caller's", disk_read.s). So poking DSKREG early would spin the motor and the driver would
* still burn the loop. That needs an exported disk_read_motor_on, which is a HAL change and
* a Karateka back-port under CLAUDE.md §2G — a separate task, not this one.
                rts

cel_bank_map
                pshs    cc
                orcc    #$50
                lda     cel_res_block
                sta     CEL_MMU                 ; $FFA6 -> the PINNED page at $C000
* ★ AND THE SECOND REGISTER IS NOT A CONSTANT ANY MORE (P3.78). It used to be
* `inca` — the bank was two adjacent blocks and the pair never changed. The rotating
* page changes per beat, so the block comes from the byte the beat schedule publishes.
* Reading it rather than knowing it is what keeps the schedule the ONE home for which
* page is live: this routine re-applies a decision, it does not make one.
                lda     cel_pg_block
                sta     CEL_MMU+1               ; $FFA7 -> $E000-$FDFF
                puls    cc
                rts


* ---------------------------------------------------------------
* room_present — swap the buffers, then put the cel bank back.
*
* ★ THE MAP CANNOT HAPPEN ONCE, and P3.68 established that as a measured hard stop
* rather than a preference: HAL_gfx_swap ends by calling gfx_map_blocks, which writes
* ALL FOUR window registers unconditionally to bring the new back buffer in. $FFA6 and
* $FFA7 are two of those four, so every flip destroys the bank mapping. There is no
* "map it at startup" version of this design.
*
* SO THE RE-MAP IS A PROPERTY OF ONE ROUTINE RATHER THAN A RULE EVERY CALL SITE HAS TO
* REMEMBER. That is the whole reason this wrapper exists: three call sites flip the
* buffers, and a rule of the form "always re-map after a swap" is the kind that holds
* until someone adds a fourth. Nothing in this file may call HAL_gfx_swap directly while
* the bank is live — call this instead.
*
* Preserves nothing HAL_gfx_swap does not already clobber; cel_bank_map touches only A,
* which HAL_gfx_swap has already spent.
* ---------------------------------------------------------------
room_present
                jsr     HAL_gfx_swap
                jsr     cel_bank_map
                rts

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
* THE DRIVE IS NOT RELEASED HERE ANY MORE (P3.76), AND THAT IS THE WHOLE SAVING.
*
* This released it after EVERY read, so the next call found a stopped motor and paid a
* fresh 0.60 s spin-up — three startup reads, 1.80 s of a 9.27 s startup, for a drive
* that had been turning the entire time. Making dr_spinup conditional in the HAL was
* necessary and NOT sufficient: with the release still here the flag was cleared between
* every read and the conditional never fired. Measured — the first build with the HAL
* change alone came back at 9.27 s, unchanged to the frame.
*
* The caller owns the drive's lifetime because only the caller knows when it has
* finished reading. room_release_drive is called once, after the last read.
                sta     SAM_FAST
                puls    cc
                tst     lt_err
                bne     lt_done
                inc     probe_loads
lt_done
                tst     lt_err
                rts

lt_err          fcb     0

* --- the torch's own cadence (P3.72k) ------------------------------------
* Measured on the oracle with the room up and nothing else moving, f3000-3400:
* gaps of 1 x11, 2 x102, 3 x61 between torch-box changes, mean 2.3 frames = 26.2 Hz.
* 2,2,3 is 2.33. This is the flames' clock and it is deliberately NOT cad_tab: tying the
* two together is what made the torches answer to the character step rate.
* AND THE PORT IS DRAW-BOUND BELOW THIS, MEASURED: asking 2,2,2 (mean 2.00) achieves
* 2.7 frames and asking 2,2,3 (mean 2.33) achieves 2.8, so the work per iteration is the
* floor at ~2.7 and the table barely moves it. 2,2,3 is kept anyway, because it is the
* ORACLE'S measured shape rather than a value chosen to compensate for today's overrun —
* and a minimum tuned to cancel an overrun becomes wrong the moment the overrun changes,
* which is precisely how cad_tab came to sit at 3.83 against a rate nobody had measured.
flm_cad         fcb     2,2,3
flm_idx         fcb     0
flm_due         fdb     0
rl_now          fdb     0               ; the frame count this iteration read
* P3.107 — the called-entry state. rs_called picks the exit path at ENTRY rather than
* letting room_return infer it, because "was I called?" is knowable once and guessable
* thereafter.
rs_called       fcb     0               ; 1 = entered through room_call
rs_saved_s      fdb     0               ; the caller's S, captured after its jsr

* ---------------------------------------------------------------
* Torch data and state
* ---------------------------------------------------------------
TORCHLAST       equ     17              ; states 0..17 [MOVEDATA.S:42 torchLast]
FB_STRIDE_4C    equ     80              ; 320 px at 4 px/byte
FLAME_TOP       equ     101             ; ptorchy 113 is the BASELINE; 13 rows up
* P3.56: byte 27 + phase 3 = px 111 EXACTLY, where this rounded UP to byte 28 (px 112)
* and sat a pixel right of true for the whole life of the port. Jay, on the live gate
* once the right torch was correct: "the left flame is one pixel to far right." The
* rounding is the one recorded in the old comment -- 27.75 -- and it was only
* correctable once P3.54 gave each torch its own sub-byte phase.
TORCH0_COL      equ     27              ; true px 111 = byte 27, phase 3
TORCH1_COL      equ     50              ; true px 201 -> byte 50.25, rounded
TORCH0_OFF      equ     FLAME_TOP*FB_STRIDE_4C+TORCH0_COL
TORCH1_OFF      equ     FLAME_TOP*FB_STRIDE_4C+TORCH1_COL
* SIZED TO THE WIDEST TORCH FOOTPRINT, not to one cel. Torch 1 sits on sub-byte phase 1,
* so its 8 px straddle THREE byte columns where torch 0's byte-aligned cel needs two.
* An undersized peel does not fail loudly -- the save writes past its slot into whatever
* follows and the erase restores garbage (P3.25 found exactly that on the character side).
PEEL_BYTES      equ     39              ; 13 rows x 3 bytes — torch 1's footprint

* The flames are a DISK-RESIDENT code bundle, not part of this program. A LOADM'd
* engine has to stay under $25FF -- above it is BASIC's program/variable area, which
* is DECB's own workspace -- and nine compiled cels put the image at $2C5A, at which
* point LOADM never returns. Measured: the text screen showed the command with no
* "OK", first segment in memory, second absent. So the flames go on a raw track and
* are read at run time, exactly as the intro reads every screen it shows.
* [src/engine/flame_cels.s, link/pop_flames.link]
* The bundle's cel tables. Same offsets the compiled draw/save tables used, so blit_tab
* (+58) and chars_tab (+64) do not move. +36 (the old erase table) is now free: a
* segment stream needs no per-cel erase routine.
TORCH0_CELS     equ     FLAME_BASE+0    ; 9 fdb, phase 3, 13x3B — px 111
TORCH1_CELS     equ     FLAME_BASE+18   ; 9 fdb, phase 1, 13x3B — px 201
DISK_FLAME_TRK  equ     30
* FLAME_LOAD, FLAME_TRACKS and FLAME_RAW are GENERATED by lz_pack.py from the bundle it
* actually packed (build/obj/flame_load.inc). They are not editable constants: the load
* address is `FLAME_BASE + window - blob`, so it MOVES when the packed size crosses a
* track, and a hand-kept copy would be right until the day the bundle grew.
                include "build/obj/flame_load.inc"
DISK_FLAME_SEC  equ     FLAME_TRACKS*SECS_PER_TRACK

* The oracle's flame pattern, verbatim. 18 states over 9 cels; the repeats and the
* out-of-order tail are what give the flicker its rhythm. [GAMEBG.S:150 ptorchflame]
ptorchflame     fcb     1,2,3,4,5,6,7,8,9,3,5,7,1,4,9,2,8,6

* Initial states are the oracle's too [SUBS.S:309 ptorchstate db 1,6] — the two
* torches start out of phase, which is why they never flicker in lockstep.
fl_state0       fcb     1
fl_state1       fcb     6
* fl_buf DELETED at P3.50 -- a second home for "which buffer is being drawn", which
* HAL_gfx_cur_back owns. Its only write had been unreachable since P3.17, so it read 0
* forever and pinned fl_slot to 0. The declaration goes with the dead store on purpose: a
* leftover variable invites the toggle being put back.
fl_slot         fcb     0
fl_prev         fcb     0,0,0,0         ; cel last drawn, per (buffer, torch) slot
fl_tmp          fcb     0
rnd_seed        fdb     $ACE1           ; 16-bit; any non-zero seed (0 is a fixed point)

* The stars. starx=2 is an Apple BYTE column, so mono px 14 -> CoCo px 34; cel $2A
* trims one leading byte and $2B does not, which puts them at framebuffer bytes 9 and
* 8. stari 2a,2b,2b,2a and stary $62,$65,$6D,$72. [GAMEBG.S:113-115]
* BACK TO THE ORACLE, and the EOR was right all along. Measured across six captures,
* the oracle's star 0 at row 98 px 40 reads WHITE unlit and BLUE lit -- so its twinkle
* really does toggle the colour of an already-painted star rather than lighting a dot
* in empty sky. Jay's "its blue now instead of red" was describing correct behaviour,
* and removing the EOR in response made this LESS faithful, not more.
*
* But a UNIFORM single-bit toggle is not the rule -- that was a guess that happened to
* fit star 0. Measured on the running oracle (oracle_star_colors.lua, f2750-4400, the
* only nine positions in the window that change at all):
*
*     r 98  white -> pale violet     -> blue in our palette
*     r101  black/blue -> WHITE
*     r109  white -> magenta / black -> blue
*     r114  black/blue -> WHITE      <-- NOT red; a 1-bit toggle would have said red
*
* The oracle toggles 2-3 adjacent MONO pixels per star, so what a single CoCo pixel
* becomes is an artifact-colour question and has to be measured per star, not derived.
* The EOR values below are those measurements, which is why star 3's is $03 (black ->
* white) rather than the $01 the uniform rule predicted.
*
* The interim version -- moved onto black and written rather than toggled -- made all
* four obvious, which is how the RNG bug was cornered. It was a diagnostic that earned
* its keep, not a design.
star_off        fdb     98*80+10,101*80+8,109*80+9,114*80+9
star_eor        fcb     $40,$04,$40,$03 ; per-star, MEASURED off the oracle (see above)
star_cnt        fcb     0,0,0,0         ; frames left lit
star_bg         fcb     0,0,0,0         ; the room byte under each, saved once
ps_dur          fcb     0
ps_val          fcb     0
pend_cel0       fcb     0
pend_cel1       fcb     0
* fl_div DELETED with FLAME_DIV at P3.51 — the second cadence. Its label fl_nostep went
* too: nothing branches there now, and an unreferenced label below a deleted test is how
* the fl_buf orphan started (P3.17 -> P3.50).
fl_step         fcb     0

t_off           fdb     0               ; the torch being stepped: framebuffer offset,
t_peel          fdb     0               ;   peel slot,
t_cel           fcb     0               ;   cel to draw,
t_prev          fcb     0
t_tab           fdb     0               ; which torch's cel table (P3.54)
t_data          fdb     0               ; the segment stream for this cel
t_dest          fdb     0               ; its framebuffer origin this frame
t_rows          fcb     0               ; from the cel's own header —
t_wide          fcb     0               ;   one home for the dimensions               ;   cel to erase

peel_base       rmb     PEEL_BYTES*4    ; one per (buffer, torch) slot



