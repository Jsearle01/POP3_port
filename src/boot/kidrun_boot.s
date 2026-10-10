* src/boot/kidrun_boot.s
*
* POP CoCo3 - THE KID-RUN PROBE'S LOADER (P5.31b). KIDRUN.BIN is this, not the probe.
*
* ---------------------------------------------------------------
* WHY A LOADER (Jay, 2026-10-10: "it does not take 53 sec to load" ... "i thought we were
* doing both. that is the way karateka works already.")
* ---------------------------------------------------------------
* P5.31 shipped the probe as one 18,460 B DECB file, so Disk BASIC's LOADM read every byte of
* it -- one sector per command, which on this project's interleave-0 disks costs about a
* revolution per sector: 1,206 frames (20.1 s), measured. The disks are interleave 0 because the
* port's own driver reads a WHOLE TRACK per command and wants sequential sectors (idiom 29).
* karateka's answer, and the intro's (src/boot/loader.s), is to let Disk BASIC load only a small
* file and have the driver fetch the bulk off raw tracks. This is that, for the kid-run probe.
*
* ---------------------------------------------------------------
* THE TWO READS -- whole tracks only (disk_read_range), so each one's END matters
* ---------------------------------------------------------------
*   A  KR_TRK_A, 2 tracks -> $0E00-$31FF   prog ($0E00-) and kd2 ($2000-$2FFF); the tail
*                                         $3000-$31FF is the staging area, unused until
*                                         tile_probe stages its page there
*   B  KR_TRK_B, 3 tracks -> $3400-$69FF   xftab ($4200-) and kd1 ($6000-$69FF); it ENDS at
*                                         $69FF because $6A00 is the driver's own parameter
*                                         block, which a read must never cover
*   C  KR_TRK_C, 1 track  -> $3400 FIRST, then copied to $6B00-$77FF: kd3, the guard's streams
*                                         (P5.32). Read before B, which then overwrites $3400.
*   this loader sits between them, $3200-$33FF, and the kernel at $7900 is its own segment --
*   the SAME hal_build.o the probe links at the same address (kernel_identical_check.py), so
*   the probe's kernel segment is dropped from both images rather than read over the running
*   driver.
*
* ★ wk_stop. The harness pokes "stop after step N" before EXEC; the probe's own word is inside
*   image A and would be overwritten by the read, so the harness pokes kr_stop here instead and
*   this copies it across after the reads. 0 = run forever, the probe's own default.
* ---------------------------------------------------------------

                include "src/hal.inc"

                ifdef   OBJTARGET
                section prog
                export  kr_entry
                export  kr_stop,kr_nact
                import  disk_read_init
                import  disk_read_range
                import  disk_read_motor_off
                endc

                ifndef  DR_VARBASE
DR_VARBASE      equ     $6A00
                endc
* ★ disk_read.s:77-82, the FULL block (loader.s:72-77 records why a partial list went wrong)
dr_track        equ     DR_VARBASE+0
dr_sector       equ     DR_VARBASE+1
dr_dest         equ     DR_VARBASE+2
dr_status       equ     DR_VARBASE+4
dr_r_track      equ     DR_VARBASE+5
dr_r_count      equ     DR_VARBASE+6

STACK_TOP       equ     $7F00
SAM_SLOW        equ     $FFD8
SAM_FAST        equ     $FFD9
SECS_TRACK      equ     18

* passed in by build.bat from the same variables raw_tracks.py places the images with, and
* from build/obj/kidrun.map (the probe is linked first)
                ifndef  KR_TRK_A
KR_TRK_A        equ     2
                endc
                ifndef  KR_TRK_B
KR_TRK_B        equ     4
                endc
KR_BASE_A       equ     $0E00
KR_NTRK_A       equ     2
KR_BASE_B       equ     $3400
KR_NTRK_B       equ     3
                ifndef  KR_TRK_C
KR_TRK_C        equ     7
                endc
KR_KD3          equ     $6B00           ; P5.32: the guard's streams (link/pop_kidrun.link kd3)
KR_KD3_END      equ     $7800
* KR_GO, not KR_ENTRY: lwasm symbols are case-insensitive and kr_entry is this file's label
                ifndef  KR_GO
KR_GO           equ     $0E00
                endc
                ifndef  KR_WKSTOP
                error   "KR_WKSTOP (wk_stop in build/obj/kidrun.map) must be passed in"
                endc
                ifndef  KR_WKNACT
                error   "KR_WKNACT (wk_nact in build/obj/kidrun.map) must be passed in"
                endc

* ---------------------------------------------------------------
kr_entry
                orcc    #$50
                lds     #STACK_TOP
                clra
                tfr     a,dp

* the canonical prefix, as loader.s runs it before ITS reads [idioms §21a]. tile_entry runs it
* again; nothing in it depends on running once.
                jsr     HAL_sys_init
                jsr     HAL_mem_size_detect
                jsr     HAL_time_init

                jsr     disk_read_init
* --- P5.32: read C FIRST -- kd3, one track, into $3400 (where read B will land later), then up to
* $6B00. No whole-track read can land at $6B00 itself: 4,608 B from there covers the kernel at $7900.
* $3400-$45FF is overwritten by read B afterwards; this loader ($3200-$33FF) is never covered.
                ldx     #KR_BASE_B
                lda     #KR_TRK_C
                ldb     #SECS_TRACK
                bsr     load_tracks
                bne     kr_dead
                ldx     #KR_BASE_B
                ldu     #KR_KD3
kr_cp           ldd     ,x++
                std     ,u++
                cmpu    #KR_KD3_END
                blo     kr_cp
                ldx     #KR_BASE_A
                lda     #KR_TRK_A
                ldb     #KR_NTRK_A*SECS_TRACK
                bsr     load_tracks
                bne     kr_dead
                ldx     #KR_BASE_B
                lda     #KR_TRK_B
                ldb     #KR_NTRK_B*SECS_TRACK
                bsr     load_tracks
                bne     kr_dead

* ★ CHECK WHAT LANDED (loader.s's reason: a whole-track read ends on RNF by design, so "no
* error" is a weak claim). tile_entry opens with a JMP.
                lda     KR_GO
                cmpa    #$7E
                bne     kr_dead
                ldd     kr_stop
                std     KR_WKSTOP
                lda     kr_nact
                sta     KR_WKNACT
                jmp     KR_GO

kr_dead         bra     kr_dead

kr_stop         fdb     0               ; the harness pokes this before EXEC
kr_nact         fcb     2               ; P5.32: actors; the harness pokes 1 for the one-actor control

* ---------------------------------------------------------------
* load_tracks - A = first track, B = sector count, X = destination. Z set on success.
* loader.s's wrapper verbatim: SAM slow for the FDC, IRQ+FIRQ masked, carry kept across the
* speed restore.
* ---------------------------------------------------------------
load_tracks
                pshs    cc
                orcc    #$50
                sta     dr_r_track
                stb     dr_r_count
                stx     dr_dest
                clr     lt_err
                sta     SAM_SLOW
                jsr     disk_read_range
                bcc     lt_ok
                com     lt_err
lt_ok
                jsr     disk_read_motor_off
                sta     SAM_FAST
                puls    cc
                tst     lt_err
                rts
lt_err          fcb     0

                ifdef   OBJTARGET
                endsection
                else
                end     kr_entry
                endc
