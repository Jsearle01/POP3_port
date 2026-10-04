* chtab4gd_031_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.GD
*         POP cel: #31 (5x19 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4gd_031_src:
        fcb     19,8  ; height=19 rows, coco3_width=8 bytes/row (4px/byte)
        fcb     $00,$00,$01,$50,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$01,$50,$00,$00,$00,$00  ; row 1
        fcb     $00,$00,$01,$7E,$80,$00,$00,$00  ; row 2
        fcb     $00,$00,$00,$0A,$80,$00,$00,$00  ; row 3
        fcb     $00,$00,$00,$0A,$A8,$00,$00,$00  ; row 4
        fcb     $00,$00,$00,$0A,$AA,$80,$00,$00  ; row 5
        fcb     $00,$00,$00,$00,$AA,$80,$00,$00  ; row 6
        fcb     $00,$00,$00,$00,$0F,$57,$FC,$00  ; row 7
        fcb     $00,$00,$00,$00,$FF,$57,$FF,$F0  ; row 8
        fcb     $00,$00,$00,$00,$FF,$57,$FF,$FC  ; row 9
        fcb     $00,$00,$00,$03,$FF,$57,$FF,$FC  ; row 10
        fcb     $00,$00,$00,$3F,$F5,$57,$FF,$FC  ; row 11
        fcb     $FC,$00,$08,$3F,$F5,$57,$FF,$F0  ; row 12
        fcb     $FF,$C0,$A8,$3F,$C0,$0F,$FF,$C0  ; row 13
        fcb     $00,$AA,$AA,$FF,$FF,$0F,$FC,$00  ; row 14
        fcb     $0A,$AA,$AA,$FF,$0F,$FF,$FF,$00  ; row 15
        fcb     $AA,$AA,$AA,$AA,$AF,$FF,$FF,$00  ; row 16
        fcb     $FE,$F5,$0A,$AA,$AA,$FF,$FF,$00  ; row 17
        fcb     $0A,$F5,$7E,$AA,$A8,$3F,$F0,$00  ; row 18
