* src/engine/flame_cels.s
*
* POP CoCo3 — the torch flames, as a DISK-RESIDENT code bundle.
*
* WHY THIS IS NOT PART OF THE ROOM PROGRAM. A LOADM'd engine must stay inside
* $2000-$25FF: above that is BASIC's program and variable area, which is DECB's own
* workspace, and a load that runs through it clobbers the loader mid-flight.
* [link/pop_engine.link — "below the graphics pages' end at $25FF"]
*
* That is measured, not theoretical. With the nine compiled flames inside the program
* image, ROOM.BIN's prog section ran $2000-$2C5A and LOADM never returned: the text
* screen showed the command with no "OK" after it, the first segment was in memory and
* the second was not. Trimmed back under $25FF the identical code loads and runs.
*
* So the flames follow the intro's pattern instead: assets live on raw tracks and the
* program reads them at run time. INTROSEQ.BIN is 2,005 B for exactly this reason --
* every screen and caption it uses is read from disk, not carried.
*
* THE TABLES COME FIRST, deliberately. This bundle is loaded at a fixed address and
* indexed from there, so it has to describe itself: three 9-entry pointer tables at a
* known offset, then the code they point at. The room needs one constant, not a link
* map. (Same reasoning as the intro bundle's fixed slots -- an index would be a third
* place to get the layout wrong.)
*
* The layout is the LABEL ORDER BELOW and nothing else — no addresses are restated here.
* They were, as $0A00.., which was two bundle relocations out of date ($4200, then $3000)
* and still called the streams "the compiled cels" a dispatch after the compiled sprites
* were retired. Anything that needs the numbers reads build/obj/flames.map.
*
* The compiled routines are position-dependent only through these tables: each is
* straight-line code addressing the framebuffer through U and the peel buffer through
* Y, with no absolute references of its own, so linking the bundle at $0A00 is all
* that placement requires.
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                import  chars_frame
                import  chars_due
                import  blit_cel_full
                import  blit_save_full
                import  blit_erase_full
                import  cel_load_startup
                import  cel_service_read
                export  torch0_cels     ; only so lwlink has an exec address to
                endc                    ; resolve; this bundle is data, never EXEC'd

* THE THREE COMPILED TABLES ARE NOW TWO CEL-DATA TABLES, ONE PER TORCH (P3.54).
*
* The flames were the LAST COMPILED SPRITES in the tree. P3.18 measured that
* representation at 8.2x the RAM of packed bitmaps -- "the same 49 cels are 11.9 KB as
* raw packed bitmaps and 100.8 KB as compiled code" -- and it is what put the cutscene
* outside 128 KB. The characters moved to segment streams; these never did. Retiring
* them frees 532 B and removes the mechanism that caused the whole memory arc.
*
* THERE IS NO save/erase TABLE ANY MORE. A compiled sprite needed a routine per cel per
* operation; a segment stream needs data for the DRAW only, because the peel is a plain
* rectangle copy that does not care what is in it -- blit_save/blit_erase are already
* resident here for the characters and serve the torches unchanged.
*
* TWO TABLES BECAUSE THE TWO TORCHES SIT ON DIFFERENT SUB-BYTE PHASES. ptorchoff is
* db 0,6 [SUBS.S:307]; Apple hires is 7 px/byte against CoCo3's 4, and 7 does not divide
* into 4, so the two torches land on DIFFERENT phases. One set could only place both on
* the same phase, which is exactly why the right torch sat a pixel left of true and why
* correcting it used to drag the left one with it.
*
* ★ THE PHASES ARE 3 AND 1, NOT 0 AND 1 (corrected P3.83). P3.56 moved torch 0 from byte
* 28 to byte 27, where byte 27 + phase 3 = px 111 exactly. build.bat is the authority and
* builds them `--phase 3` and `--phase 1`.
*
* ★ AND THE OFFSETS BELOW ARE STALE TOO: blit_tab is at +40 and chars_tab at +46, not the
* +58/+64 this said — P3.54 retired the third dispatch table and shifted everything after
* it up by 18. The live numbers are checked on every build by bundle_offsets_check.py
* against the link map, which is why the drift was harmless here and would not have been
* if anyone had trusted the comment. +0 and +18 for the two cel tables are still right.
* ★ CORRECTED AT P3.83 TO THE MEASURED TRUTH. This said "phase 0, 13x2B, px 112", which
* was right until P3.56 moved torch 0 from byte 28 to byte 27 and put it on phase 3
* (byte 27 + phase 3 = px 111 exactly, where rounding up to byte 28 gave px 112). The
* room's own `equ` was updated then and this line was not. Authorities, in order:
* build.bat builds these `--phase 3`, and the machine reports width 3 — a blit_cel tap
* at P3.82 logged `rows=13 width=3` for both torches.
torch0_cels     fdb     flseg0_1,flseg0_2,flseg0_3      ; phase 3, 13x3B, px 111
                fdb     flseg0_4,flseg0_5,flseg0_6
                fdb     flseg0_7,flseg0_8,flseg0_9
torch1_cels     fdb     flseg1_1,flseg1_2,flseg1_3      ; phase 1, 13x3B, px 201
                fdb     flseg1_4,flseg1_5,flseg1_6
                fdb     flseg1_7,flseg1_8,flseg1_9

* --- P3.20: the CHARACTER cels ride the same track --------------------------
* Piece D's baked cels are 1.17 KB and this track has ~2.2 KB spare, so they land
* here rather than in ROOM.BIN. That is not tidiness: putting them in the program
* pushed `prog` to ~$2E70 and LOADM broke exactly as this file's header describes
* -- the first segment landed, $7900 stayed $FF, the kernel never loaded. Same
* failure, same cause, one dispatch later.
*
* A fourth table at a FIXED offset ($0A36) so the room can find them without
* knowing how big the flame cels are.
* char_tab RETIRED at P3.22: it existed so the room could patch cel pointers into
* its descriptors at run time. The slot records and the cel data now live in the same
* object (char_draw.s), so the linker resolves them and nothing needs patching.
                fdb     0,0                     ; was char_tab — offsets below depend on it

* --- P3.20: the BLIT CORE rides here too, and for the same reason -----------
* blit_core is ~500 bytes of code. In ROOM.BIN it pushed `prog` to ~$2660, past
* the $25FF ceiling this file's header describes, and the room hung with status 1
* and no disk reads. The bundle is already executable -- the flames' compiled cels
* are JSR'd out of it -- so the blitter belongs here alongside the cels it draws.
* The room reaches it through this table rather than by link-time symbol.
* ★ THE UNCLIPPED ENTRIES (P3.78d). The room draws the torches through this table and
* never sets the character clip window, so it must not inherit one. See blit_core.
blit_tab        fdb     blit_cel_full,blit_save_full,blit_erase_full

* --- P3.22: piece D's character draw, same track, same reason ---------------
* Third time the LOADM ceiling has pushed something out of ROOM.BIN. P3.22 proved
* it is size alone (175 bytes of dead filler reproduces the failure), and measured
* the real ceiling ~174 bytes BELOW the documented $25FF.
* P3.51 adds chars_due as a SECOND word here (CHARS_TAB+2). The room must ask whether an
* animation step is due BEFORE it draws anything, because flicker runs first and would
* otherwise have advanced the torch already.
*
* ★ THIS COMMENT USED TO NAME THE OFFSETS — "BLIT_TAB +58, CHARS_TAB +64" — and P3.54
* moved them to +40 and +46 without updating the prose, so the file that DEFINES the
* layout was describing it wrongly. That is a third home for the same fact, in the worst
* possible material: a comment cannot be checked and is believed anyway. The numbers are
* deliberately not repeated here now. The layout is what the labels below say it is; the
* room's copy is verified against the link map by harness/tools/bundle_offsets_check.py,
* which build.bat runs immediately after this bundle links.
chars_tab       fdb     chars_frame,chars_due

* --- P3.78: the SPLIT CEL IMAGE's loader, and it is the fourth time the LOADM ceiling
* --- has pushed something out of ROOM.BIN. The measurement is on file this time rather
* --- than inferred: HEAD's room ended at $2475, eleven bytes under the $2480 practical
* --- limit, and the page table plus the two load routines took it to $24E4 — into the
* --- measured-corrupt band ($2488..$2535). The symptom was the exact signature
* --- link/pop_engine.link records: "status 0 and the disk-read count is ZERO."
*
* So the page table and both loaders live here, where the cel data they load already
* does, and the room calls them through this table with Y = its own load_tracks. That
* argument is the same shape as the two HAL values the room already hands chars_frame:
* the bundle links without the HAL and without the room, so anything it needs from
* either arrives in a register.
cels_tab        fdb     cel_load_startup,cel_service_read

* The compiled cels — straight-line draw/save/erase per flame, generated by
* harness/tools/sprite_compiler.py from the oracle's chtable6 cels 1-9.
* The flame cels as SEGMENT STREAMS, generated by harness/tools/cel_blit_prep.py from
* content/cutscene/flames/*/converted.s at each torch's own phase (build.bat). The
* tool REPLAYS the blit over a background and verifies reconstruction before it
* emits, so a cel that does not rebuild is never written.
                include "build/flames_seg/t0_1.s"
                include "build/flames_seg/t0_2.s"
                include "build/flames_seg/t0_3.s"
                include "build/flames_seg/t0_4.s"
                include "build/flames_seg/t0_5.s"
                include "build/flames_seg/t0_6.s"
                include "build/flames_seg/t0_7.s"
                include "build/flames_seg/t0_8.s"
                include "build/flames_seg/t0_9.s"
                include "build/flames_seg/t1_1.s"
                include "build/flames_seg/t1_2.s"
                include "build/flames_seg/t1_3.s"
                include "build/flames_seg/t1_4.s"
                include "build/flames_seg/t1_5.s"
                include "build/flames_seg/t1_6.s"
                include "build/flames_seg/t1_7.s"
                include "build/flames_seg/t1_8.s"
                include "build/flames_seg/t1_9.s"

* ── THE HOURGLASS (P3.85) ────────────────────────────────────────────────────────────
*
* It lives HERE, in the bundle, and not in the paged cel image — which is the whole
* reason it fits at all. From the beat it appears it is drawn every frame to the end of
* the scene, spanning beats that map two different rotating blocks, and a cel that
* straddles a mapping change is the one thing cel_pack refuses. Six dispatches costed it
* against the pinned page and deferred it; the question was never the size (994 B against
* 4,330 B spare) but the RESIDENCY, and the bundle is already resident for exactly this
* kind of thing. The torches, the stars and the sand are one class of object in the
* oracle too [SUBS.S:360 pstars, GAMEBG.S DRAWGLASS] and now in one class of storage.
*
* NO FIXED OFFSET, unlike the torch tables at the head. Those are reached by the ROOM,
* which is a separate program and must index the bundle by arithmetic; these are reached
* by char_draw.s, which is linked INTO the bundle and can import the symbol. An import
* cannot drift where an offset can.
                ifdef   OBJTARGET
                export  glass_cels
                export  flow_cels
                endc
glass_cels      fdb     glseg_g0,glseg_g1       ; addglass1 X=0 / X=1  [SUBS.S:722,745]
flow_cels       fdb     glseg_f0,glseg_f1,glseg_f2      ; psandcount 0,1,2
                include "build/glass_seg/g0.s"
                include "build/glass_seg/g1.s"
                include "build/glass_seg/f0.s"
                include "build/glass_seg/f1.s"
                include "build/glass_seg/f2.s"

* The character cels moved to char_draw.s at P3.22, next to the slot records that
* point at them, so the linker resolves the pointers instead of the room patching
* them at run time.
