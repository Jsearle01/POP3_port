* chtab3_072_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #72 (2x7 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_072_src:
        fcb     7,4  ; height=7 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $7F,$00,$00,$00  ; row 0
        fcb     $03,$F0,$00,$00  ; row 1
        fcb     $00,$3F,$00,$00  ; row 2
        fcb     $00,$03,$FC,$00  ; row 3
        fcb     $00,$00,$3F,$C0  ; row 4
        fcb     $00,$00,$00,$80  ; row 5
        fcb     $00,$00,$00,$00  ; row 6
