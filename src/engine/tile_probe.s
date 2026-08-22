* src/engine/tile_probe.s
*
* POP CoCo3 - THE FIRST GAMEPLAY PIXELS (P5.5).
*
* ---------------------------------------------------------------
* WHAT THIS IS, AND WHAT IT DELIBERATELY IS NOT
* ---------------------------------------------------------------
* It draws LEVEL0 screen 1's static background - the dungeon room the demo starts in -
* from a baked page, on the real GIME, off a real disk. No characters, no motion, no
* input, no room change, no second screen. That is the whole of P5.5's scope.
*
* ★ PLANE ORDERING IS NOT TESTED BY THIS PROGRAM AND MUST NOT BE QUOTED AS IF IT WERE.
* `DRAWALL` has a FOREGROUND plane that is drawn AFTER the characters, and it matters only
* RELATIVE to them [P5.0 §3B]. There are no characters here, so a renderer that draws back
* and fore in one undifferentiated pass - which is exactly what this one does - looks
* identical to a correct one.
*
* ---------------------------------------------------------------
* THE PAGE, AND WHY THE RENDERER IS THIS SMALL
* ---------------------------------------------------------------
* harness/tools/bake_screen.py bakes the screen into one 8,192 B GIME block: a magic, two
* counts, a variant table, a display list, and the variant pixels. Every display-list entry
* is an OPAQUE RECTANGLE of the FINISHED page's pixels, so:
*
*   * there is no transparency to honour - an `ora` entry's unpainted pixels already hold
*     the finished value;
*   * there is no draw ORDER to preserve - overlapping rectangles write identical bytes;
*   * the four AND/mask entries need no code at all - the finished page already reflects
*     what they cleared.
*
* So the renderer is a table walk and a rectangle copy, and the bake proves it byte-exact
* against hgr_screen_convert before a single byte reaches the disk.
*
* ---------------------------------------------------------------
* THE MAP, AND THE ONE ORDERING THAT IS LOAD-BEARING
* ---------------------------------------------------------------
* HAL_gfx_set_mode ends in gfx_map_blocks, which writes ALL FOUR window registers
* unconditionally [gfx.s]. So the page's block CANNOT be mapped before set_mode - it would
* be overwritten. Map it AFTER, exactly as cutscene_room.s's cel_bank_map does after every
* swap, and for the same reason.
*
* HAL_gfx_mirror then takes $FFA6/$FFA7 for the FRONT buffer, which destroys the page
* mapping - and that is fine, because by then the drawing is done. Nothing after the mirror
* touches $C000.
*
* ---------------------------------------------------------------
* ★ THE PAGE ARRIVES PACKED, AND THAT IS A DELIVERY CONSTRAINT, NOT AN OPTIMISATION
* ---------------------------------------------------------------
* The baked page is 7,280 B. A track is 18 x 256 = 4,608 B, so the raw page needs TWO, and
* the image has exactly ONE free track left (34). The uncompressed form is therefore not
* deliverable at all on this disk - not "bigger than we would like", undeliverable. lz_pack
* takes it to 1,390 B, under a third of one track.
*
* The blob is staged in MAIN RAM at LZ_STAGE and expanded into $C000, so source and
* destination DO NOT OVERLAP and lz_pack.py's in-place high-water argument is not load-
* bearing here. lz_unpack takes the output base in X and the blob in U and has no opinion
* about either, which is exactly why it was lifted out of intro_seq.s at P3.17.
*
* $FFA7 IS NEVER WRITTEN BY THIS PROGRAM. cel_pg_sig is 0 in the gated design: one pinned
* page, zero rotations. The rotating register keeps whatever set_mode left in it.
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                export  tile_entry
                import  disk_read_init
                import  disk_read_range
                import  lz_unpack
                endc

                include "src/hal.inc"

* --- the page ---------------------------------------------------
TILE_BLOCK      equ     $0C             ; the same physical block the cutscene pins
CEL_MMU         equ     $FFA6           ; $C000-$DFFF
PAGE_BASE       equ     $C000
PAGE_MAGIC      equ     $7B1E           ; bake_screen.py's; NOT the cutscene's $C35A
TILE_TAB        equ     PAGE_BASE+4     ; variant table: fdb data / fcb w / fcb h
                ifndef  TILE_TRK
TILE_TRK        equ     34
                endc
SECS_TRACK      equ     18
* Where the PACKED page is staged before it is expanded. Main RAM, clear of everything this
* program's link map names: prog ends well below $3000, the kernel is at $7900, the disk
* driver's block at $6A00 and the stack top at $7F00. One whole track lands here (4,608 B,
* $3000-$41FF) even though the blob is a third of that -- the read is track-granular.
LZ_STAGE        equ     $3000

* --- disk_read.s's parameter block, from the same -DDR_VARBASE the kernel gets ---
                ifndef  DR_VARBASE
DR_VARBASE      equ     $1F00
                endc
dr_dest         equ     DR_VARBASE+2
dr_r_track      equ     DR_VARBASE+5
dr_r_count      equ     DR_VARBASE+6

SAM_SLOW        equ     $FFD8           ; the FDC needs normal speed (CLAUDE.md §2G)
STACK_TOP       equ     $7F00           ; below the $8000 draw window
FB_STRIDE       equ     80

* ---------------------------------------------------------------
* THE PROBE BLOCK. Byte offsets from tile_entry, read by tile_test.lua.
* ---------------------------------------------------------------
tile_entry      jmp     tile_start      ; +0   EXEC address
probe_status    fcb     0               ; +3   0=boot 1=mode 2=page in 3=drawn 4=shown
probe_dskerr    fcb     0               ; +4   non-zero: the track read failed
probe_magic     fdb     0               ; +5   the page's own magic, once verified
probe_ents      fcb     0               ; +7   display-list entries drawn

* ---------------------------------------------------------------
tile_start
                orcc    #$50            ; mask while the machine comes up
                lds     #STACK_TOP
                clra
                tfr     a,dp

                jsr     HAL_sys_init            ; PIAs, MMU, MC3=1
                jsr     HAL_mem_size_detect
                jsr     HAL_time_init
                andcc   #$EF                    ; opt in to real VBL waits

                lda     #GFX_MODE_320x192x4
                jsr     HAL_gfx_set_mode
* set_mode clears BOTH buffers, so there is no separate clear here: every pixel no
* rectangle covers is already index 0, which is what the composited page holds there.
                lda     #1
                sta     probe_status

                jsr     disk_read_init

* --- the page's block at $FFA6, AFTER set_mode (see the header) -----
                jsr     tile_bank_map

* --- read the PACKED page off its whole track, then expand into the block ------
                lda     #TILE_TRK
                ldb     #SECS_TRACK
                ldx     #LZ_STAGE
                jsr     load_track
                tst     probe_dskerr
                bne     tp_hold                 ; the harness reads the byte

                ldx     #PAGE_BASE              ; X = output
                ldu     #LZ_STAGE               ; U = the blob
                jsr     lz_unpack

* --- the page says who it is, or nothing is drawn -------------------
* The same shape of check char_draw.s makes: the image's own content, not a flag.
                ldd     PAGE_BASE
                cmpd    #PAGE_MAGIC
                bne     tp_hold
                std     probe_magic
                lda     #2
                sta     probe_status

                jsr     tile_draw
                lda     #3
                sta     probe_status

                jsr     HAL_gfx_mirror          ; both buffers hold it before anything shows
                jsr     HAL_gfx_swap
                lda     #4
                sta     probe_status
tp_hold         bra     tp_hold

* ---------------------------------------------------------------
* tile_bank_map - ONE register, so no interrupt mask is needed.
*
* char_draw.s:2178 states the rule and cutscene_room.s's cel_bank_map is the counterexample:
* THAT routine writes two registers and must mask, because between them the window is half
* one page and half another. This writes one, so every instant before and after it is a
* complete, valid map.
* ---------------------------------------------------------------
tile_bank_map
                lda     #TILE_BLOCK
                sta     CEL_MMU
                rts

* ---------------------------------------------------------------
* load_track - A = track, B = sectors, X = destination.
* Normal SAM speed for the whole transfer: double speed breaks the FDC (CLAUDE.md §2G).
* ---------------------------------------------------------------
load_track
                pshs    cc
                orcc    #$50
                sta     dr_r_track
                stb     dr_r_count
                stx     dr_dest
                sta     SAM_SLOW        ; value irrelevant - the SAM latches on the write
                jsr     disk_read_range
                bcc     lt_ok
                com     probe_dskerr
lt_ok
                puls    cc
                rts

* ---------------------------------------------------------------
* tile_draw - walk the display list, copy each variant's rectangle.
*
* U walks the 3-byte entries: variant id, x byte, y top.
* Y is the destination; X the source; the row stride correction is 80-width.
* ---------------------------------------------------------------
td_w            fcb     0
td_h            fcb     0

tile_draw
                clr     probe_ents
* U = the display list = TILE_TAB + 4 * n_variants
                lda     PAGE_BASE+2             ; n_variants
                ldb     #4
                mul
                addd    #TILE_TAB
                tfr     d,u

                lda     PAGE_BASE+3             ; n_entries
                beq     td_done
                sta     td_n
td_entry
* --- resolve the variant: Y -> its 4-byte table row ---
                lda     ,u                      ; variant id
                ldb     #4
                mul
                addd    #TILE_TAB
                tfr     d,y
                ldx     ,y                      ; X = the pixel data
                lda     2,y
                sta     td_w
                lda     3,y
                sta     td_h

* --- Y = draw base + y_top * 80 + x_byte ---
                ldy     HAL_gfx_draw_base
                lda     2,u                     ; y top
                ldb     #FB_STRIDE
                mul
                leay    d,y
                clra
                ldb     1,u                     ; x byte
                leay    d,y

td_row
                ldb     td_w
td_byte
                lda     ,x+
                sta     ,y+
                decb
                bne     td_byte
* next row: Y is at dest+width, and the row is 80 wide
                ldb     td_w
                negb
                sex
                addd    #FB_STRIDE
                leay    d,y
                dec     td_h
                bne     td_row

                inc     probe_ents
                leau    3,u
                dec     td_n
                bne     td_entry
td_done
                rts

td_n            fcb     0

                ifndef  OBJTARGET
                end     tile_entry
                endc
