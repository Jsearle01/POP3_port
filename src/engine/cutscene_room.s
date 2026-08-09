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
* P3.31: $4200 -> $3000, and the base is now ONE literal for the whole build, passed
* as -DFLAME_BASE by build.bat to this file and to char_draw.s together. It was three
* independent copies of $4200; see char_draw.s for what moving one without the others
* does. FLAME_BASE_TAB was a second name for the same address in this file alone.
                ifndef  FLAME_BASE
FLAME_BASE      equ     $3000
                endc
FLAME_BASE_TAB  equ     FLAME_BASE
* ★ THESE TRACK flame_cels.s'S DECLARATION ORDER AND MUST MOVE WITH IT. P3.54 retired
* the third compiled table (flame_erase, 18 B) -- a segment stream needs no per-cel erase
* routine -- and everything after it shifted up by 18: blit_tab +58 -> +40, chars_tab
* +64 -> +46. The build LINKED CLEANLY with the old values and would have jumped into the
* middle of a cel table at run time. Verified by symbol after every change:
*   blit_tab  $3028 = FLAME_BASE+40      chars_tab $302E = FLAME_BASE+46
* This is a second home for flame_cels.s's layout (P3.31) and the only thing keeping the
* two honest is that a mismatch takes the room down instantly rather than subtly.
BLIT_TAB        equ     FLAME_BASE_TAB+40       ; blit_cel / blit_save / blit_erase
CHARS_TAB       equ     FLAME_BASE_TAB+46       ; chars_frame (piece D), +2 = chars_due

ROOM_BLOB       equ     $3000

SAM_SLOW        equ     $FFD8           ; the FDC needs normal speed (§2G disk rule)
SAM_FAST        equ     $FFD9
DSKREG          equ     $FF40

room_entry      jmp     room_start      ; $0200 — EXEC address

probe_status    fcb     0               ; $0203  0=boot 1=mode set 2=room up 3=holding
probe_loads     fcb     0               ; $0204  successful disk reads
probe_dskerr    fcb     0               ; $0205  WD1773 status of the first failure
probe_magic     fdb     0               ; $0206  set once the room is on screen
probe_frames    fcb     0               ; $0208  frames of flicker completed
probe_cel0      fcb     0               ; $0209  cel each torch is showing —
probe_cel1      fcb     0               ; $020A  the pixel check composites these

ROOM_MAGIC      equ     $4B00

room_start
                orcc    #$50            ; mask while the machine comes up
                lds     #STACK_TOP
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
                ldx     #ROOM_BLOB
                lda     #DISK_ROOM_TRK
                ldb     #DISK_ROOM_SEC
                jsr     load_tracks
                bne     room_failed

* THE BUNDLE ARRIVES PACKED, AND IT LANDS ABOVE WHERE IT WILL LIVE.
*
* Both reads still happen here, before the picture, so this is still two reads and no
* disk between the room appearing and the flames moving. What changed is WHERE: the
* packed blob is read to FLAME_LOAD, high in the window, and expanded down to
* FLAME_BASE later -- see bundle_expand. Reading it here is safe because the packed
* blob does not overlap the room blob it will eventually overwrite.
                ldx     #FLAME_LOAD
                lda     #DISK_FLAME_TRK
                ldb     #DISK_FLAME_SEC
                jsr     load_tracks
                bne     room_failed

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
                bcs     room_mirror_slow        ; 16-colour would refuse; this is not

                jsr     bundle_expand           ; the blob is spent — expand over it
                jsr     HAL_gfx_swap            ; the room appears, ready to animate

* AND AGAIN INTO THE OTHER BUFFER. The flames are drawn per frame and the page is
* flipped per frame, so BOTH buffers have to hold the room -- otherwise every other
* frame shows a cleared screen. The oracle avoids this by drawing its flames straight
* onto the displayed page (`lay`, a direct hires call) and never flipping for them;
* our HAL maps only the back buffer, so the port flips instead. This second expand is
* now the ONLY thing between the picture appearing and the flames moving, and it is
* CPU-bound rather than disk-bound.
                bra     room_ready

* THE FALLBACK, and it is the OLD behaviour rather than a failure. If the mirror ever
* refuses -- it does so only in a mode whose framebuffer needs the whole window -- the
* second buffer still has to be filled, and expanding the blob again is exactly how
* this worked before. The scene stays correct; it just costs the 15 frames back.
room_mirror_slow
                jsr     HAL_gfx_swap
                ldx     HAL_gfx_draw_base
                ldu     #ROOM_BLOB
                jsr     lz_unpack
                jsr     bundle_expand           ; only now is the blob finished with

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
room_loop
                jsr     HAL_time_frame_count    ; D = 16-bit frame count (race-safe)
                tfr     d,u
                jsr     [CHARS_TAB+2]           ; chars_due — A = 1 if a step is due
                tsta
                bne     rl_draw
* IDLE: nothing changes this frame, so the displayed buffer is already correct -- do not
* redraw it and do not flip. The VBL wait is NOT optional: HAL_gfx_swap is what paces this
* loop, and skipping the draw without waiting would spin the CPU at full speed, burning
* the budget this change exists to reclaim while putting nothing new on screen.
                jsr     HAL_time_vbl_wait
                bra     room_loop

rl_draw
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
                jsr     HAL_gfx_swap            ; waits for VBL, THEN moves VOFFSET
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
                ldd     #TORCH0_CELS            ; phase-0 cels — px 112, unchanged
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
                clr     DSKREG          ; motor off, no drive selected
                sta     SAM_FAST
                puls    cc
                tst     lt_err
                bne     lt_done
                inc     probe_loads
lt_done
                tst     lt_err
                rts

lt_err          fcb     0

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



