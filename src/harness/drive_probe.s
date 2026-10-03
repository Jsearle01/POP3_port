* src/harness/drive_probe.s
*
* POP CoCo3 — P5.22 (Jay's two-situation ruling): CAN THE GAME TELL WHETHER DRIVE 1 HOLDS SIDE B,
* WITHOUT HANGING WHEN IT DOES NOT?
*
* Jay, 2026-10-03: "we should be designing for two situations. two drives two disks and a single
* drive with a flippy disk. the game should check for a second drive and if a disk with the
* appropriate file exists. if no second drive, no disk, or wrong disk, then prompt for user flip
* on the single drive."
*
* ★★ THE HAZARD THIS MEASURES. disk_read.s arms HALT for every transfer (DSKREG b7): the CPU is
* held until the WD1773 raises DRQ or ends the command. On an EMPTY or ABSENT drive there may be
* no index pulses, so a Type II command may never end -- and a halted CPU cannot time out. So
* this probe NEVER arms HALT: everything is polled, every wait is bounded, and what the
* controller does in each case is recorded rather than assumed.
*
* Not shipped; not in build.bat; touches no HAL file (drive select is hard-coded to drive 0 in the
* shared disk_read.s -- changing that is a cross-repo HAL task, named in the P5.22 report).
* FDC registers $FF40-$FF4B are outside the register ratchet's $FF80-$FFDF scope.
*
* For each drive in dp_drives: select it with the motor on, spin up ~0.5 s, Restore, then for
* ~1.2 s count index-pulse edges (Type I status b1) and note Busy/Track00; then a polled single-
* sector read of track 0 sector 1, keeping what arrives. Results per drive, 32 bytes at dp_res.

DSKREG          equ     $FF40
FDC_CMD         equ     $FF48
FDC_TRK         equ     $FF49
FDC_SEC         equ     $FF4A
FDC_DAT         equ     $FF4B
NMI_SEC         equ     $FEFD           ; DECB's secondary NMI vector: a JMP lives here

                org     $3000
dp_entry        jmp     dp_start        ; +0
dp_status       fcb     0               ; +3  1 = finished
dp_ndrv         fcb     2               ; +4
dp_drives       fcb     $2A,$29         ; +5  DSKREG values: drive 1, then drive 0 (control)
*                                          b0/b1 drive select, b3 motor, b5 double density
dp_res          rmb     64              ; +7  per drive: see dp_one

dp_start
                orcc    #$50
                lds     #$2F00
* NMI -> RTI, so an INTRQ-generated NMI cannot drop into DECB's handler mid-probe.
                lda     #$7E
                sta     NMI_SEC
                ldx     #dp_rti
                stx     NMI_SEC+1
                ldy     #dp_res
                ldu     #dp_drives
                lda     dp_ndrv
                sta     dp_cnt
dp_loop         lda     ,u+
                pshs    u
                bsr     dp_one
                puls    u
                leay    32,y
                dec     dp_cnt
                bne     dp_loop
                clr     DSKREG                  ; motors off, no drive
                lda     #1
                sta     dp_status
dp_halt         bra     dp_halt
dp_rti          rti

dp_cnt          fcb     0
dp_last         fcb     0
dp_tmpb         fcb     0

* ---------------------------------------------------------------
* dp_one -- A = DSKREG value, Y = 32-byte result record:
*   +0  DSKREG value used
*   +1  Type I status after Restore (or $FF if Busy never cleared)
*   +2  Restore: 0 = completed, 1 = TIMED OUT (Busy stuck)
*   +3,+4  index-pulse EDGES seen in the ~1.2 s window (b1 changes)
*   +5  Type II status at the end of the read
*   +6  read: 0 = Busy cleared, 1 = TIMED OUT (forced)
*   +7,+8  bytes received
*   +9..+24  the first 16 bytes received (side B's signature is "POPB")
* ---------------------------------------------------------------
dp_one
                sta     ,y
                sta     DSKREG                  ; select + motor, no HALT (b7 = 0)
                ldx     #0
dp_spin         leax    1,x                     ; ~0.5 s at 0.894 MHz (8 cy x 65536)
                bne     dp_spin
                lda     #$D0
                sta     FDC_CMD                 ; Force Interrupt: a clean Type I status
                lbsr    dp_short
                lda     #$00
                sta     FDC_CMD                 ; Restore
                lbsr    dp_short
* wait for Busy to clear, bounded (~1.3 s)
                ldx     #0
dp_rw           lda     FDC_CMD
                bita    #$01
                beq     dp_rdone
                leax    1,x
                cmpx    #$9000
                bne     dp_rw
                lda     #$D0
                sta     FDC_CMD
                lbsr    dp_short
                lda     #1
                sta     2,y
                lda     #$FF
                sta     1,y
                bra     dp_idx
dp_rdone        sta     1,y
                clr     2,y
* index-pulse edges over ~1.2 s, from Type I status b1
dp_idx          lda     FDC_CMD
                anda    #$02
                sta     dp_last
                ldd     #0
                std     3,y
                ldx     #0
dp_il           lda     FDC_CMD
                anda    #$02
                cmpa    dp_last
                beq     dp_inext
                sta     dp_last
                ldd     3,y
                addd    #1
                std     3,y
dp_inext        leax    1,x
                cmpx    #$6000
                bne     dp_il
* ★ MEASURED (first run): a POLLED read cannot keep up at 0.894 MHz -- Lost Data after one byte on
* a good disk -- and on an empty or absent drive it never ends at all. So the read that identifies
* the disk must be HALT-paced, like disk_read.s, and that is only safe once the index pulses have
* proved a disk is turning. STAGE 2 runs only on >= 2 edges; otherwise the record says so.
                ldd     3,y
                cmpd    #2
                bhs     dp_halt_read
                lda     #$EE                    ; "no index pulses: not attempted"
                sta     5,y
                lda     #2
                sta     6,y
                rts
dp_halt_read
                clr     FDC_TRK
                lda     #1
                sta     FDC_SEC
                leax    9,y
                lda     #$80
                sta     FDC_CMD                 ; Read Sector, single
                lda     ,y
                ora     #$80                    ; arm HALT: DRQ paces each byte (disk_read.s)
                sta     DSKREG
                ldu     #256
dp_hl           lda     FDC_DAT                 ; HALT holds here until DRQ; INTRQ->NMI frees it
                cmpu    #256-16
                bls     dp_hskip
                sta     ,x+                     ; keep the first 16
dp_hskip        leau    -1,u
                bne     dp_hl
                lda     ,y
                sta     DSKREG                  ; disarm HALT
                lbsr    dp_short
                lda     FDC_CMD
                sta     5,y
                clr     6,y
                ldd     #256
                std     7,y
                rts

* (the polled read, kept for the record of WHY it is not used)
                clr     FDC_TRK
                lda     #1
                sta     FDC_SEC
                ldd     #0
                std     7,y
                leax    9,y                     ; first 16 bytes land here
                lda     #$80
                sta     FDC_CMD                 ; Read Sector, single
                lbsr    dp_short
                ldu     #0                      ; timeout counter
dp_rd           lda     FDC_CMD
                bita    #$02                    ; DRQ
                bne     dp_byte
                bita    #$01                    ; Busy
                beq     dp_rend
                leau    1,u
                cmpu    #$C000
                bne     dp_rd
                lda     #$D0                    ; never finished: force it, and say so
                sta     FDC_CMD
                lbsr    dp_short
                lda     #1
                sta     6,y
                lda     FDC_CMD
                sta     5,y
                rts
dp_byte         ldb     FDC_DAT
                stb     dp_tmpb
                ldd     7,y
                addd    #1
                std     7,y
                cmpd    #16
                bhi     dp_rd
                ldb     dp_tmpb
                stb     ,x+
                bra     dp_rd
dp_rend         sta     5,y
                clr     6,y
                rts

* let a command register write settle before the status is meaningful
dp_short        pshs    b
                ldb     #40
dp_sl           decb
                bne     dp_sl
                puls    b,pc

                end     dp_entry
