* chtab3_068_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #68 (4x8 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_068_src:
        fcb     8,7  ; height=8 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $03,$F0,$00,$00,$00,$00,$00  ; row 0
        fcb     $00,$3F,$00,$00,$00,$00,$00  ; row 1
        fcb     $00,$03,$FC,$00,$00,$00,$00  ; row 2
        fcb     $00,$00,$0F,$F0,$00,$00,$00  ; row 3
        fcb     $00,$00,$00,$FF,$00,$00,$00  ; row 4
        fcb     $00,$00,$00,$03,$FE,$AA,$A8  ; row 5
        fcb     $00,$00,$00,$00,$0A,$A8,$00  ; row 6
        fcb     $00,$00,$00,$00,$00,$3C,$00  ; row 7
