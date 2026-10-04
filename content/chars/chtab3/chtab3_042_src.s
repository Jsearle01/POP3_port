* chtab3_042_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #42 (4x4 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_042_src:
        fcb     4,6  ; height=4 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $03,$FF,$FC,$00,$00,$00  ; row 0
        fcb     $00,$00,$3F,$FF,$C0,$0F  ; row 1
        fcb     $00,$00,$00,$03,$FF,$FF  ; row 2
        fcb     $00,$00,$00,$00,$00,$3C  ; row 3
