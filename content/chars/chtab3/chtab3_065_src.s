* chtab3_065_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #65 (2x18 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_065_src:
        fcb     18,4  ; height=18 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $00,$08,$00,$00  ; row 0
        fcb     $00,$08,$00,$00  ; row 1
        fcb     $00,$0F,$00,$00  ; row 2
        fcb     $00,$01,$00,$00  ; row 3
        fcb     $00,$03,$C0,$00  ; row 4
        fcb     $00,$03,$C0,$00  ; row 5
        fcb     $00,$00,$80,$00  ; row 6
        fcb     $00,$00,$F0,$00  ; row 7
        fcb     $00,$00,$F0,$00  ; row 8
        fcb     $00,$00,$10,$00  ; row 9
        fcb     $00,$00,$3C,$00  ; row 10
        fcb     $00,$00,$3C,$00  ; row 11
        fcb     $00,$00,$0F,$00  ; row 12
        fcb     $00,$00,$0F,$00  ; row 13
        fcb     $00,$00,$0F,$C0  ; row 14
        fcb     $00,$00,$01,$50  ; row 15
        fcb     $00,$00,$01,$50  ; row 16
        fcb     $00,$00,$01,$00  ; row 17
