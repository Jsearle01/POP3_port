* chtab2_016_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #16 (5x16 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_016_src:
        fcb     16,9  ; height=16 rows, coco3_width=9 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$00,$3F,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$03,$F0,$3F,$C0,$00,$00  ; row 1
        fcb     $00,$00,$00,$0F,$F0,$3F,$C0,$00,$00  ; row 2
        fcb     $00,$00,$00,$0F,$F0,$01,$00,$00,$00  ; row 3
        fcb     $00,$00,$FF,$F7,$F0,$3F,$00,$00,$00  ; row 4
        fcb     $00,$00,$FF,$FF,$00,$FF,$C0,$00,$00  ; row 5
        fcb     $00,$00,$3F,$FC,$00,$FF,$C0,$00,$00  ; row 6
        fcb     $00,$00,$3F,$FF,$03,$FF,$C0,$00,$00  ; row 7
        fcb     $00,$00,$0F,$F7,$FF,$FC,$00,$00,$00  ; row 8
        fcb     $00,$15,$0F,$55,$7F,$FC,$00,$01,$50  ; row 9
        fcb     $00,$15,$0F,$55,$7F,$FC,$00,$01,$50  ; row 10
        fcb     $01,$50,$3C,$15,$0F,$FC,$00,$15,$00  ; row 11
        fcb     $15,$55,$7F,$FF,$FF,$7C,$15,$50,$00  ; row 12
        fcb     $15,$57,$FF,$FF,$FF,$55,$55,$00,$00  ; row 13
        fcb     $01,$57,$FF,$FF,$EF,$55,$50,$00,$00  ; row 14
        fcb     $00,$00,$03,$FF,$F0,$00,$00,$00,$00  ; row 15
