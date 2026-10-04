* chtab4gd_032_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.GD
*         POP cel: #32 (6x11 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4gd_032_src:
        fcb     11,11  ; height=11 rows, coco3_width=11 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$00,$00,$3F,$FC,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$00,$01,$57,$FF,$FF,$00,$00,$00  ; row 1
        fcb     $00,$00,$00,$00,$15,$55,$7F,$FF,$C3,$F0,$00  ; row 2
        fcb     $00,$00,$00,$00,$15,$55,$7F,$FF,$FF,$FF,$00  ; row 3
        fcb     $00,$00,$00,$01,$55,$57,$FF,$FF,$FF,$FF,$00  ; row 4
        fcb     $00,$00,$15,$55,$55,$7F,$FF,$FE,$FF,$FF,$C0  ; row 5
        fcb     $00,$3F,$55,$55,$55,$7F,$FF,$FE,$FF,$FF,$C0  ; row 6
        fcb     $00,$3F,$C0,$00,$10,$3F,$FF,$FE,$AF,$FF,$C0  ; row 7
        fcb     $03,$FF,$55,$50,$A8,$3F,$FF,$F0,$AF,$FF,$C0  ; row 8
        fcb     $03,$FF,$55,$50,$A8,$10,$FF,$F0,$AF,$FF,$00  ; row 9
        fcb     $01,$01,$55,$55,$55,$57,$FF,$FC,$03,$FC,$00  ; row 10
