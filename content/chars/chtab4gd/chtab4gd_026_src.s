* chtab4gd_026_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.GD
*         POP cel: #26 (8x14 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4gd_026_src:
        fcb     14,14  ; height=14 rows, coco3_width=14 bytes/row (4px/byte)
        fcb     $00,$00,$00,$03,$FF,$F0,$00,$00,$00,$00,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$3F,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00  ; row 1
        fcb     $00,$00,$00,$03,$EA,$FF,$00,$00,$00,$00,$00,$00,$00,$00  ; row 2
        fcb     $00,$00,$03,$FF,$EA,$FC,$00,$3F,$FC,$00,$00,$00,$00,$00  ; row 3
        fcb     $00,$00,$0F,$FF,$FE,$A8,$00,$FF,$55,$00,$00,$00,$00,$00  ; row 4
        fcb     $00,$00,$3F,$FF,$FE,$A8,$0F,$F5,$55,$50,$00,$00,$00,$00  ; row 5
        fcb     $00,$01,$7F,$FF,$FE,$A8,$0F,$55,$55,$55,$00,$00,$00,$00  ; row 6
        fcb     $00,$01,$7F,$FF,$EF,$EF,$0F,$55,$55,$55,$55,$00,$00,$00  ; row 7
        fcb     $00,$15,$0F,$FF,$EF,$FF,$01,$55,$55,$55,$55,$50,$00,$00  ; row 8
        fcb     $00,$15,$57,$FF,$EF,$FC,$01,$55,$55,$55,$55,$55,$7F,$00  ; row 9
        fcb     $00,$15,$55,$55,$7F,$FE,$A8,$15,$55,$55,$55,$57,$FF,$C0  ; row 10
        fcb     $00,$15,$55,$55,$57,$FE,$AA,$A8,$15,$55,$55,$57,$FF,$C0  ; row 11
        fcb     $00,$01,$55,$55,$03,$EA,$AA,$AA,$A8,$01,$55,$50,$03,$C0  ; row 12
        fcb     $00,$00,$00,$00,$AA,$AA,$AA,$A8,$00,$00,$00,$00,$00,$00  ; row 13
