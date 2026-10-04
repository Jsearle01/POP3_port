* chtab3_049_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #49 (3x2 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_049_src:
        fcb     2,6  ; height=2 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$03,$C0  ; row 0
        fcb     $0F,$FF,$FF,$FF,$FF,$C0  ; row 1
