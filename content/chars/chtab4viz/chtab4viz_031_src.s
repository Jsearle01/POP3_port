* chtab4viz_031_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.VIZ
*         POP cel: #31 (5x19 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4viz_031_src:
        fcb     19,9  ; height=19 rows, coco3_width=9 bytes/row (4px/byte)
        fcb     $00,$00,$00,$15,$00,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$15,$00,$00,$00,$00,$00  ; row 1
        fcb     $00,$00,$00,$17,$E8,$00,$00,$00,$00  ; row 2
        fcb     $00,$00,$00,$03,$E8,$00,$00,$00,$00  ; row 3
        fcb     $00,$00,$00,$00,$AA,$80,$00,$00,$00  ; row 4
        fcb     $00,$00,$00,$00,$AA,$A8,$00,$00,$00  ; row 5
        fcb     $00,$00,$00,$00,$0A,$A8,$3F,$C0,$00  ; row 6
        fcb     $00,$00,$00,$00,$00,$F7,$FF,$FC,$00  ; row 7
        fcb     $0F,$C0,$00,$00,$0F,$FF,$7F,$FF,$00  ; row 8
        fcb     $0F,$FF,$FC,$00,$03,$F5,$7F,$FF,$C0  ; row 9
        fcb     $0F,$FF,$FF,$FC,$3F,$F5,$7F,$FF,$C0  ; row 10
        fcb     $0A,$FF,$FF,$FF,$FF,$F5,$7F,$FF,$C0  ; row 11
        fcb     $0A,$FF,$FE,$AA,$AF,$F5,$7F,$FF,$00  ; row 12
        fcb     $AA,$AA,$AA,$AA,$AF,$FF,$7F,$FF,$00  ; row 13
        fcb     $AA,$AA,$AA,$AA,$AA,$FF,$FF,$FC,$00  ; row 14
        fcb     $AA,$AA,$AA,$AA,$AA,$FF,$FF,$F0,$00  ; row 15
        fcb     $AA,$F0,$AA,$AA,$AA,$FF,$FF,$FC,$00  ; row 16
        fcb     $AA,$F5,$0A,$AA,$AA,$AF,$FF,$F0,$00  ; row 17
        fcb     $0A,$F5,$0A,$AA,$AA,$83,$FF,$00,$00  ; row 18
