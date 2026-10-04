* chtab2_057_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #57 (3x19 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_057_src:
        fcb     19,5  ; height=19 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$FF,$C0,$00,$00  ; row 0
        fcb     $0F,$FF,$F0,$00,$00  ; row 1
        fcb     $0F,$FF,$F0,$00,$00  ; row 2
        fcb     $00,$FF,$F0,$00,$00  ; row 3
        fcb     $01,$7F,$F0,$00,$00  ; row 4
        fcb     $01,$57,$FF,$FC,$00  ; row 5
        fcb     $01,$57,$FF,$FF,$C0  ; row 6
        fcb     $00,$15,$7F,$FF,$FC  ; row 7
        fcb     $00,$15,$7F,$FF,$FF  ; row 8
        fcb     $00,$15,$7F,$FF,$FF  ; row 9
        fcb     $00,$15,$7F,$FF,$FF  ; row 10
        fcb     $00,$17,$FF,$FF,$FF  ; row 11
        fcb     $00,$17,$FF,$FF,$FC  ; row 12
        fcb     $00,$17,$FF,$FF,$F0  ; row 13
        fcb     $00,$17,$FF,$FF,$C0  ; row 14
        fcb     $01,$57,$F0,$3F,$F0  ; row 15
        fcb     $01,$50,$00,$3F,$F0  ; row 16
        fcb     $01,$00,$00,$FF,$C0  ; row 17
        fcb     $15,$00,$03,$FC,$00  ; row 18
