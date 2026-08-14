* glass0_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #21 (3x25 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=133  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

glass0_src:
        fcb     25,6  ; height=25 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $FF,$FF,$FF,$FF,$FC,$00  ; row 0
        fcb     $BD,$FD,$FD,$FD,$F0,$00  ; row 1
        fcb     $BF,$FF,$FF,$FF,$F0,$00  ; row 2
        fcb     $BF,$00,$00,$03,$F0,$00  ; row 3
        fcb     $BF,$AA,$AA,$AB,$F0,$00  ; row 4
        fcb     $BF,$AA,$AA,$AB,$F0,$00  ; row 5
        fcb     $BF,$AA,$AA,$AB,$F0,$00  ; row 6
        fcb     $BF,$AA,$AA,$AB,$F0,$00  ; row 7
        fcb     $BD,$FA,$AA,$BD,$F0,$00  ; row 8
        fcb     $BC,$2A,$AA,$A0,$F0,$00  ; row 9
        fcb     $BC,$0F,$AB,$C0,$F0,$00  ; row 10
        fcb     $BC,$03,$DF,$00,$F0,$40  ; row 11
        fcb     $FF,$00,$54,$03,$FC,$00  ; row 12
        fcb     $BC,$03,$DF,$00,$F0,$40  ; row 13
        fcb     $BC,$04,$00,$40,$F0,$40  ; row 14
        fcb     $BC,$20,$00,$20,$F0,$00  ; row 15
        fcb     $BD,$40,$00,$05,$F0,$00  ; row 16
        fcb     $BD,$40,$00,$05,$F0,$40  ; row 17
        fcb     $BF,$00,$00,$03,$F0,$00  ; row 18
        fcb     $BF,$00,$00,$03,$F0,$40  ; row 19
        fcb     $BC,$00,$00,$00,$F0,$00  ; row 20
        fcb     $BC,$00,$00,$00,$F0,$40  ; row 21
        fcb     $FC,$00,$00,$00,$FC,$00  ; row 22
        fcb     $FF,$C0,$00,$0F,$FD,$40  ; row 23
        fcb     $03,$FF,$FF,$FF,$00,$00  ; row 24
