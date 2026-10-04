* chtab4skel_025_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.SKEL
*         POP cel: #25 (5x24 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4skel_025_src:
        fcb     24,8  ; height=24 rows, coco3_width=8 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$0F,$FC,$00,$00  ; row 0
        fcb     $00,$00,$00,$00,$FF,$FF,$00,$00  ; row 1
        fcb     $00,$00,$00,$00,$08,$3F,$00,$00  ; row 2
        fcb     $00,$00,$00,$00,$3C,$3F,$00,$00  ; row 3
        fcb     $00,$00,$00,$00,$83,$F0,$00,$00  ; row 4
        fcb     $00,$00,$00,$00,$FF,$C0,$00,$00  ; row 5
        fcb     $00,$00,$00,$00,$03,$C0,$00,$00  ; row 6
        fcb     $00,$00,$00,$00,$00,$80,$00,$00  ; row 7
        fcb     $00,$00,$00,$00,$0F,$C0,$00,$00  ; row 8
        fcb     $00,$00,$00,$03,$F0,$FE,$F0,$00  ; row 9
        fcb     $00,$00,$00,$03,$FF,$F0,$F0,$00  ; row 10
        fcb     $00,$00,$00,$00,$80,$0F,$F0,$00  ; row 11
        fcb     $00,$00,$F0,$00,$FF,$F0,$3C,$00  ; row 12
        fcb     $00,$03,$F0,$01,$00,$10,$3C,$00  ; row 13
        fcb     $00,$03,$FC,$03,$FF,$F0,$3F,$00  ; row 14
        fcb     $00,$0F,$C0,$00,$FC,$3F,$03,$C0  ; row 15
        fcb     $00,$3F,$7F,$FC,$0F,$50,$03,$C0  ; row 16
        fcb     $00,$3E,$FC,$0F,$EF,$F0,$03,$C0  ; row 17
        fcb     $00,$FC,$0F,$FF,$7F,$00,$01,$00  ; row 18
        fcb     $0F,$C0,$0F,$FF,$0F,$C0,$00,$00  ; row 19
        fcb     $0F,$00,$00,$00,$03,$F5,$00,$00  ; row 20
        fcb     $7C,$00,$00,$00,$00,$FF,$00,$00  ; row 21
        fcb     $00,$00,$00,$00,$00,$3F,$00,$00  ; row 22
        fcb     $10,$00,$00,$00,$00,$00,$00,$00  ; row 23
