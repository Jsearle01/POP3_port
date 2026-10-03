* src/harness/side_check_probe.s
*
* POP CoCo3 — P5.24: JAY'S FOUR CASES, ONE MECHANISM, AND THE SIGNATURE'S CONDITION TESTED.
*
* Jay: "two drives two disks and a single drive with a flippy disk ... if no second drive, no
* disk, or wrong disk, then prompt for user flip" -- and, on identification, "raw signature if
* it's unique and valid".
*
* side_check is the POLICY, and it is POP's, not the HAL's: select the drive, ask the HAL's
* presence gate (HALT OFF, every wait bounded), and only if a disk is turning do the HALT-paced
* read of that side's signature sector and compare it. The order is the requirement (P5.22
* §3H): a HALT read on an empty or absent drive never ends.
*
* Not shipped, not in build.bat. Links against a HAL object assembled WITH
* -DHAL_DISK_DRIVE_SELECT (harness/smoke/run_side_check.sh); the shipped hal_build.o is not it.
*
* The step table runs the same eight checks in every MAME configuration -- cold, warm,
* re-read and cold-Restore on drive 1, side A's location, then drive 0 -- so AC7's
* "spin-up, cold Restore, re-read, on both drives" is the same table everywhere.

                ifdef   OBJTARGET
                section prog
                export  sc_entry
                import  disk_read_init
                import  disk_read
                import  disk_read_motor_off
                import  disk_select_drive
                import  disk_present
                endc

                include "src/hal.inc"

                ifndef  DR_VARBASE
DR_VARBASE      equ     $6A00
                endc
dr_track        equ     DR_VARBASE+0
dr_sector       equ     DR_VARBASE+1
dr_dest         equ     DR_VARBASE+2
dr_status       equ     DR_VARBASE+4

SC_BUF          equ     $3000           ; one sector
STACK_TOP       equ     $7F00
SIG_LEN         equ     17              ; 16 bytes of text + the format-version byte

sc_entry        jmp     sc_start        ; +0
sc_flag         fcb     0               ; +3  2 = a step is running, 1 = step done, 4 = all done
sc_go           fcb     0               ; +4
sc_step         fcb     0               ; +5
sc_rec          rmb     24              ; +6  reason, edges, status, then SIG_LEN+3 bytes read
*   reason: 0 = MATCH   1 = no disk turning (empty/absent)   2 = wrong signature
*           3 = the read failed (status in +2)   4 = no such drive number

* where each side's signature lives, and what it must say
sig_b           fcb     0,1             ; SIDE B (raw): track 0 sector 1, head of its directory
                fcc     "POP COCO3 SIDE B"
                fcb     1
sig_a           fcb     17,18           ; SIDE A (DECB): track 17 sector 18 -- DECB writes 2..11 only
                fcc     "POP COCO3 SIDE A"
                fcb     1

* steps: flags (b0 = motor off first: a COLD check), drive, signature descriptor
sc_steps        fcb     1,1
                fdb     sig_b           ; S0 drive 1, side B, cold
                fcb     0,1
                fdb     sig_b           ; S1 drive 1, side B, warm re-read
                fcb     0,1
                fdb     sig_b           ; S2 drive 1, side B, re-read
                fcb     1,1
                fdb     sig_b           ; S3 drive 1, side B, cold Restore again
                fcb     0,1
                fdb     sig_a           ; S4 drive 1, side A's location
                fcb     0,0
                fdb     sig_b           ; S5 drive 0, side B (the flipped single drive)
                fcb     0,0
                fdb     sig_a           ; S6 drive 0, side A (the flip-back check)
                fcb     1,0
                fdb     sig_a           ; S7 drive 0, side A, cold
                fcb     $FF

sc_start
                orcc    #$50
                lds     #STACK_TOP
                clra
                tfr     a,dp
                jsr     HAL_sys_init            ; MC3=1: the NMI vector lives at $FExx
                jsr     disk_read_init
                ldu     #sc_steps
sc_loop         lda     ,u
                cmpa    #$FF
                beq     sc_all
                bita    #1
                beq     sc_warm
                jsr     disk_read_motor_off     ; a COLD check: the motor stopped, the flag clear
sc_warm         lda     #2
                sta     sc_flag
                lda     1,u                     ; drive
                ldx     2,u                     ; signature descriptor
                pshs    u
                bsr     side_check
                puls    u
                lda     #1
                sta     sc_flag
sc_wait         lda     sc_go
                beq     sc_wait
                clr     sc_go
                inc     sc_step
                leau    4,u
                bra     sc_loop
sc_all          jsr     disk_read_motor_off
                lda     #4
                sta     sc_flag
sc_halt         bra     sc_halt

* ---------------------------------------------------------------
* side_check -- A = drive, X -> {track, sector, SIG_LEN bytes}. Result in sc_rec.
* Out: CC.C clear = this drive holds that side; set = it does not (reason in sc_rec+0).
* ★ disk_read runs ONLY after disk_present has passed. That ordering is the whole point.
* ---------------------------------------------------------------
side_check
                stx     sc_desc
                ldx     #sc_rec
                ldb     #24
sc_clr          clr     ,x+
                decb
                bne     sc_clr
                jsr     disk_select_drive
                bcc     sc_sel
                lda     #4
                bra     sc_fail
sc_sel          jsr     disk_present            ; HALT OFF, bounded -- the gate
                sta     sc_rec+1                ; edges
                bcc     sc_turning
                lda     #1
                bra     sc_fail
sc_turning      ldx     sc_desc
                lda     ,x
                sta     dr_track
                lda     1,x
                sta     dr_sector
                ldd     #SC_BUF
                std     dr_dest
                jsr     disk_read               ; HALT-paced: safe now a disk is turning
                lda     dr_status
                sta     sc_rec+2
                bcc     sc_got
                lda     #3
                bra     sc_fail
sc_got          ldx     sc_desc                 ; keep what was read, for the report
                leax    2,x
                ldy     #SC_BUF
                ldu     #sc_rec+3
                ldb     #SIG_LEN+3
sc_keep         lda     ,y+
                sta     ,u+
                decb
                bne     sc_keep
                ldy     #SC_BUF
                ldb     #SIG_LEN
sc_cmp          lda     ,y+
                cmpa    ,x+
                bne     sc_wrong
                decb
                bne     sc_cmp
                clr     sc_rec
                andcc   #$FE
                rts
sc_wrong        lda     #2
sc_fail         sta     sc_rec
                orcc    #$01
                rts

sc_desc         fdb     0
