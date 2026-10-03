* src/harness/side_read_probe.s
*
* POP CoCo3 — P5.22: READ AN AUTHORED SIDE BACK THROUGH THE SHIPPED PRIMITIVE, AND TIME IT.
*
* Not shipped, not on probe.dmk, not in build.bat. harness/smoke/run_side_read.sh links it against
* the same hal_build.o the port uses and pokes it into a machine whose drive 0 holds an image
* make_side_dmk.py authored. It exists to show that a side laid by `writesector` at an explicit
* track map reads back byte-exact through disk_read_range's own geometry -- m=1 whole tracks,
* Seek-advance, HALT-paced -- and how long a track takes, measured rather than carried.
*
* THE READ LIST (sr_reads): every track 0..34 on its own, so every byte of the side is compared
* (track 17 included -- a RAW side carries payload there); then 1-track and 3-track ranges at
* three positions, so the per-track MARGINAL time separates from the per-call cost (Restore to
* track 0, then a Seek) by subtraction rather than by assumption.
*
* SPEED: HAL_sys_init leaves the SAM at 0.894 MHz unless HAL_SYS_FAST_CLOCK is defined, and POP's
* hal_build.o does not define it, so the FDC sees normal speed (CLAUDE.md §2G) without this file
* writing $FFD8 -- which would also have made it a new owner under the register ratchet.
*
* HANDSHAKE with harness/tools/side_read.lua: sr_status 2 = reading, 1 = done OK, 3 = done with
* the carry set, 4 = list finished; the Lua dumps the buffer, then sets sr_go.

                ifdef   OBJTARGET
                section prog
                export  side_entry
                import  disk_read_init
                import  disk_read_range
                endc

                include "src/hal.inc"

                ifndef  DR_VARBASE
DR_VARBASE      equ     $6A00
                endc
dr_dest         equ     DR_VARBASE+2
dr_r_track      equ     DR_VARBASE+5
dr_r_count      equ     DR_VARBASE+6

SR_BUF          equ     $2400           ; three tracks, $2400..$59FF, clear of $6A00 and $7900
STACK_TOP       equ     $7F00
SECS_TRACK      equ     18

side_entry      jmp     side_start      ; +0
sr_status       fcb     0               ; +3
sr_go           fcb     0               ; +4
sr_idx          fcb     0               ; +5  index into sr_reads of the read in hand
sr_ptr          fdb     0

* (start track, track count), terminated by $FF
sr_reads
                fcb     0,1,1,1,2,1,3,1,4,1,5,1,6,1,7,1,8,1,9,1
                fcb     10,1,11,1,12,1,13,1,14,1,15,1,16,1,17,1,18,1,19,1
                fcb     20,1,21,1,22,1,23,1,24,1,25,1,26,1,27,1,28,1,29,1
                fcb     30,1,31,1,32,1,33,1,34,1
                fcb     2,1,2,3,15,1,15,3,28,1,28,3
                fcb     $FF

side_start
                orcc    #$50
                lds     #STACK_TOP
                clra
                tfr     a,dp
                jsr     HAL_sys_init            ; PIAs, MMU, MC3=1 (the NMI vector lives at $FExx)
                jsr     disk_read_init
                ldx     #sr_reads
sr_next
                stx     sr_ptr
                lda     ,x
                cmpa    #$FF
                beq     sr_done
                sta     dr_r_track
                ldb     1,x
                lda     #SECS_TRACK
                mul                             ; B = sectors (<= 54)
                stb     dr_r_count
                ldx     #SR_BUF
                stx     dr_dest
                lda     #2
                sta     sr_status               ; the Lua's START mark (a write tap)
                jsr     disk_read_range
                lda     #1
                bcc     sr_ok
                lda     #3
sr_ok           sta     sr_status               ; the Lua's END mark
sr_wait         lda     sr_go
                beq     sr_wait
                clr     sr_go
                inc     sr_idx
                ldx     sr_ptr
                leax    2,x
                bra     sr_next
sr_done         lda     #4
                sta     sr_status
sr_halt         bra     sr_halt
