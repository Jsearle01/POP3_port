* converted.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #3 (1x13 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=91  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

flame3:
        fcb     13,2  ; height=13 rows, coco3_width=2 bytes/row (4px/byte)
        fcb     $00,$00  ; row 0
        fcb     $00,$00  ; row 1
        fcb     $00,$00  ; row 2
        fcb     $00,$04  ; row 3
        fcb     $00,$04  ; row 4
        fcb     $00,$54  ; row 5
        fcb     $40,$40  ; row 6
        fcb     $40,$40  ; row 7
        fcb     $05,$40  ; row 8
        fcb     $05,$40  ; row 9
        fcb     $05,$54  ; row 10
        fcb     $00,$54  ; row 11
        fcb     $00,$40  ; row 12
