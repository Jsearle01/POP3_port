* chtab2_068_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #68 (3x4 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_068_src:
        fcb     4,5  ; height=4 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$F7,$FC,$00,$00  ; row 0
        fcb     $00,$FF,$FF,$C0,$00  ; row 1
        fcb     $03,$FF,$FF,$C0,$00  ; row 2
        fcb     $0F,$FE,$FE,$FF,$F0  ; row 3
