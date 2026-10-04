* chtab5_044_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #44 (5x17 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_044_src:
        fcb     17,8  ; height=17 rows, coco3_width=8 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$00,$00,$00,$01  ; row 0
        fcb     $00,$00,$00,$00,$FF,$00,$00,$01  ; row 1
        fcb     $00,$00,$00,$03,$FF,$EF,$00,$01  ; row 2
        fcb     $00,$00,$00,$03,$FF,$EF,$C0,$10  ; row 3
        fcb     $00,$00,$00,$03,$FF,$F0,$80,$10  ; row 4
        fcb     $00,$00,$0F,$FE,$FF,$FC,$00,$10  ; row 5
        fcb     $00,$00,$0F,$FE,$FF,$FC,$01,$50  ; row 6
        fcb     $00,$00,$0F,$FC,$3F,$FF,$C1,$00  ; row 7
        fcb     $00,$00,$03,$FF,$FF,$FF,$55,$00  ; row 8
        fcb     $00,$00,$00,$FF,$7F,$FF,$55,$00  ; row 9
        fcb     $00,$00,$00,$F5,$55,$7F,$50,$00  ; row 10
        fcb     $00,$00,$00,$F5,$7F,$EF,$00,$00  ; row 11
        fcb     $00,$00,$03,$C3,$FF,$F7,$C0,$00  ; row 12
        fcb     $00,$01,$57,$FF,$FF,$F7,$C0,$00  ; row 13
        fcb     $01,$55,$57,$FF,$FF,$F0,$00,$00  ; row 14
        fcb     $01,$55,$57,$FF,$FF,$F0,$00,$00  ; row 15
        fcb     $00,$00,$00,$3F,$FF,$00,$00,$00  ; row 16
