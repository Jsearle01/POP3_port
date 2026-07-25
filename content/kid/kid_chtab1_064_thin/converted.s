* converted.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB1
*         POP cel: #64 (1x24 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

kid_chtab1_064_thin:
        fcb     24,2  ; height=24 rows, coco3_width=2 bytes/row (4px/byte)
        fcb     $03,$C0  ; row 0
        fcb     $7F,$C0  ; row 1
        fcb     $0F,$00  ; row 2
        fcb     $0F,$C0  ; row 3
        fcb     $0F,$C0  ; row 4
        fcb     $0F,$C0  ; row 5
        fcb     $0F,$C0  ; row 6
        fcb     $0F,$C0  ; row 7
        fcb     $03,$C0  ; row 8
        fcb     $03,$C0  ; row 9
        fcb     $03,$C0  ; row 10
        fcb     $03,$C0  ; row 11
        fcb     $0F,$C0  ; row 12
        fcb     $0F,$C0  ; row 13
        fcb     $0F,$C0  ; row 14
        fcb     $0F,$C0  ; row 15
        fcb     $0F,$C0  ; row 16
        fcb     $0F,$C0  ; row 17
        fcb     $0F,$C0  ; row 18
        fcb     $0F,$C0  ; row 19
        fcb     $17,$C0  ; row 20
        fcb     $17,$C0  ; row 21
        fcb     $17,$C0  ; row 22
        fcb     $03,$C0  ; row 23
