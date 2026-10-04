* chtab5_043_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #43 (3x22 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_043_src:
        fcb     22,6  ; height=22 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $01,$7F,$F0,$00,$00,$00  ; row 0
        fcb     $03,$FF,$FC,$00,$00,$00  ; row 1
        fcb     $03,$FF,$FF,$00,$00,$00  ; row 2
        fcb     $03,$FF,$FF,$00,$00,$00  ; row 3
        fcb     $00,$3F,$FF,$00,$00,$00  ; row 4
        fcb     $00,$03,$FF,$00,$00,$00  ; row 5
        fcb     $00,$15,$7F,$F0,$00,$00  ; row 6
        fcb     $00,$15,$57,$FC,$00,$00  ; row 7
        fcb     $00,$15,$57,$FF,$00,$00  ; row 8
        fcb     $00,$00,$17,$FF,$C0,$00  ; row 9
        fcb     $00,$00,$FF,$FF,$C0,$00  ; row 10
        fcb     $00,$03,$FF,$FF,$F0,$00  ; row 11
        fcb     $00,$01,$57,$FF,$FC,$00  ; row 12
        fcb     $00,$01,$57,$FF,$FC,$00  ; row 13
        fcb     $00,$00,$15,$7F,$FF,$00  ; row 14
        fcb     $00,$00,$15,$7F,$FF,$00  ; row 15
        fcb     $00,$00,$F5,$7F,$FF,$C0  ; row 16
        fcb     $00,$0F,$F5,$7F,$FF,$C0  ; row 17
        fcb     $00,$3F,$F5,$57,$FF,$00  ; row 18
        fcb     $00,$FF,$F5,$57,$FF,$00  ; row 19
        fcb     $03,$F5,$55,$7F,$FC,$00  ; row 20
        fcb     $00,$F5,$7F,$FF,$00,$00  ; row 21
