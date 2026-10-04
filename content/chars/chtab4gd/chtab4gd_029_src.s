* chtab4gd_029_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.GD
*         POP cel: #29 (3x32 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4gd_029_src:
        fcb     32,6  ; height=32 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $00,$FF,$C0,$00,$00,$00  ; row 0
        fcb     $0F,$FF,$FF,$00,$00,$00  ; row 1
        fcb     $0F,$FF,$FF,$C0,$00,$00  ; row 2
        fcb     $03,$FF,$FF,$C0,$00,$00  ; row 3
        fcb     $0A,$FF,$FF,$C0,$00,$00  ; row 4
        fcb     $00,$3F,$FF,$00,$00,$00  ; row 5
        fcb     $01,$57,$FC,$00,$00,$00  ; row 6
        fcb     $01,$57,$C0,$00,$00,$00  ; row 7
        fcb     $01,$55,$00,$00,$00,$00  ; row 8
        fcb     $00,$FF,$FC,$00,$00,$00  ; row 9
        fcb     $00,$FF,$FF,$00,$00,$00  ; row 10
        fcb     $03,$FF,$FF,$C0,$00,$00  ; row 11
        fcb     $00,$AA,$FF,$F0,$00,$00  ; row 12
        fcb     $00,$AA,$FF,$F0,$00,$00  ; row 13
        fcb     $00,$AA,$FF,$F0,$00,$00  ; row 14
        fcb     $00,$AA,$FF,$50,$00,$00  ; row 15
        fcb     $00,$A8,$15,$50,$00,$00  ; row 16
        fcb     $03,$EA,$81,$50,$00,$00  ; row 17
        fcb     $17,$EA,$AF,$FC,$00,$00  ; row 18
        fcb     $10,$0A,$AF,$FF,$C0,$00  ; row 19
        fcb     $00,$0A,$AF,$FF,$C0,$00  ; row 20
        fcb     $00,$0A,$AF,$FF,$FC,$00  ; row 21
        fcb     $00,$0A,$AF,$FF,$FF,$C0  ; row 22
        fcb     $00,$01,$7F,$FF,$FF,$C0  ; row 23
        fcb     $00,$01,$7E,$FF,$FF,$00  ; row 24
        fcb     $00,$81,$7E,$FF,$F0,$00  ; row 25
        fcb     $00,$81,$7E,$FF,$C0,$00  ; row 26
        fcb     $00,$AA,$AA,$A8,$00,$00  ; row 27
        fcb     $00,$AA,$AA,$80,$00,$00  ; row 28
        fcb     $00,$AA,$AA,$80,$00,$00  ; row 29
        fcb     $00,$AA,$AA,$F0,$00,$00  ; row 30
        fcb     $00,$0A,$80,$00,$00,$00  ; row 31
