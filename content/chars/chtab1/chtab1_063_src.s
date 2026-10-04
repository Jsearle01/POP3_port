* chtab1_063_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB1
*         POP cel: #63 (2x24 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab1_063_src:
        fcb     24,2  ; height=24 rows, coco3_width=2 bytes/row (4px/byte)
        fcb     $00,$01  ; row 0
        fcb     $00,$3F  ; row 1
        fcb     $00,$FF  ; row 2
        fcb     $0A,$FF  ; row 3
        fcb     $0A,$FF  ; row 4
        fcb     $0A,$FF  ; row 5
        fcb     $0A,$FF  ; row 6
        fcb     $0A,$FF  ; row 7
        fcb     $03,$FF  ; row 8
        fcb     $03,$FF  ; row 9
        fcb     $03,$FF  ; row 10
        fcb     $03,$FF  ; row 11
        fcb     $03,$FF  ; row 12
        fcb     $00,$FF  ; row 13
        fcb     $00,$0F  ; row 14
        fcb     $00,$01  ; row 15
        fcb     $00,$01  ; row 16
        fcb     $00,$0F  ; row 17
        fcb     $00,$3F  ; row 18
        fcb     $00,$FF  ; row 19
        fcb     $03,$FF  ; row 20
        fcb     $00,$FC  ; row 21
        fcb     $00,$3F  ; row 22
        fcb     $00,$0F  ; row 23
