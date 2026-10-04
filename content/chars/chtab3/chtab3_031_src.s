* chtab3_031_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #31 (3x3 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_031_src:
        fcb     3,5  ; height=3 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $7F,$FC,$00,$00,$00  ; row 0
        fcb     $00,$0F,$FF,$F0,$00  ; row 1
        fcb     $00,$00,$00,$FF,$FC  ; row 2
