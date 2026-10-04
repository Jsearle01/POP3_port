* chtab4viz_030_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.VIZ
*         POP cel: #30 (3x22 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4viz_030_src:
        fcb     22,6  ; height=22 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $15,$00,$00,$00,$00,$00  ; row 0
        fcb     $15,$0F,$FF,$00,$00,$00  ; row 1
        fcb     $03,$FF,$FF,$F0,$00,$00  ; row 2
        fcb     $03,$FF,$FF,$FC,$00,$00  ; row 3
        fcb     $00,$3F,$FF,$FC,$00,$00  ; row 4
        fcb     $00,$00,$FF,$F0,$00,$00  ; row 5
        fcb     $00,$17,$FF,$00,$00,$00  ; row 6
        fcb     $00,$F7,$FF,$FC,$00,$00  ; row 7
        fcb     $00,$FF,$FF,$FF,$00,$00  ; row 8
        fcb     $03,$C0,$3F,$FF,$C0,$00  ; row 9
        fcb     $00,$00,$FF,$FF,$F0,$00  ; row 10
        fcb     $00,$03,$FF,$FF,$F0,$00  ; row 11
        fcb     $00,$03,$FF,$FF,$FC,$00  ; row 12
        fcb     $00,$03,$FF,$FF,$FF,$00  ; row 13
        fcb     $00,$03,$EA,$FF,$FF,$00  ; row 14
        fcb     $00,$00,$0A,$AF,$FF,$C0  ; row 15
        fcb     $00,$00,$AA,$AF,$FF,$C0  ; row 16
        fcb     $00,$AA,$FE,$AA,$FF,$C0  ; row 17
        fcb     $0A,$AA,$FE,$AA,$FF,$00  ; row 18
        fcb     $0A,$AA,$AA,$AA,$FF,$00  ; row 19
        fcb     $0A,$F5,$0A,$AF,$FC,$00  ; row 20
        fcb     $0A,$F5,$7E,$AF,$00,$00  ; row 21
