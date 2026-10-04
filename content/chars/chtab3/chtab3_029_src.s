* chtab3_029_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #29 (1x9 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_029_src:
        fcb     9,2  ; height=9 rows, coco3_width=2 bytes/row (4px/byte)
        fcb     $03,$C0  ; row 0
        fcb     $03,$C0  ; row 1
        fcb     $0F,$00  ; row 2
        fcb     $0F,$00  ; row 3
        fcb     $7C,$00  ; row 4
        fcb     $10,$00  ; row 5
        fcb     $F0,$00  ; row 6
        fcb     $80,$00  ; row 7
        fcb     $80,$00  ; row 8
