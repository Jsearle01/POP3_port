* chtab2_070_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #70 (2x10 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_070_src:
        fcb     10,3  ; height=10 rows, coco3_width=3 bytes/row (4px/byte)
        fcb     $10,$F0,$00  ; row 0
        fcb     $7F,$FC,$00  ; row 1
        fcb     $0F,$F0,$00  ; row 2
        fcb     $0F,$F0,$00  ; row 3
        fcb     $17,$FC,$00  ; row 4
        fcb     $03,$FC,$00  ; row 5
        fcb     $03,$FF,$00  ; row 6
        fcb     $0F,$F7,$FC  ; row 7
        fcb     $00,$00,$0F  ; row 8
        fcb     $00,$00,$3C  ; row 9
