* chtab4gd_009_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.GD
*         POP cel: #9 (6x35 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4gd_009_src:
        fcb     35,11  ; height=35 rows, coco3_width=11 bytes/row (4px/byte)
        fcb     $00,$00,$00,$03,$FF,$00,$00,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$3F,$FF,$FC,$00,$00,$00,$00,$00  ; row 1
        fcb     $00,$00,$00,$3F,$FF,$FF,$00,$00,$00,$00,$00  ; row 2
        fcb     $00,$00,$00,$0F,$FF,$FF,$00,$00,$00,$00,$00  ; row 3
        fcb     $00,$00,$00,$17,$FF,$FF,$00,$00,$00,$00,$00  ; row 4
        fcb     $00,$00,$00,$00,$FF,$FC,$00,$00,$00,$00,$00  ; row 5
        fcb     $00,$00,$00,$0A,$AF,$F0,$00,$00,$00,$00,$00  ; row 6
        fcb     $00,$00,$00,$0A,$AF,$FC,$00,$00,$00,$00,$00  ; row 7
        fcb     $00,$00,$00,$00,$FF,$FF,$C0,$00,$00,$00,$00  ; row 8
        fcb     $00,$A8,$00,$0F,$FF,$FF,$FC,$00,$00,$00,$00  ; row 9
        fcb     $00,$AA,$F5,$7F,$FF,$FF,$FC,$00,$00,$00,$00  ; row 10
        fcb     $00,$08,$15,$57,$FF,$FF,$F5,$00,$00,$00,$00  ; row 11
        fcb     $00,$00,$00,$17,$FF,$FF,$F5,$00,$00,$00,$00  ; row 12
        fcb     $00,$00,$00,$00,$17,$FF,$C1,$00,$00,$00,$00  ; row 13
        fcb     $00,$00,$00,$00,$0F,$EA,$81,$00,$00,$00,$00  ; row 14
        fcb     $00,$00,$00,$00,$00,$AA,$81,$00,$00,$00,$00  ; row 15
        fcb     $00,$00,$00,$00,$00,$AF,$FF,$00,$00,$00,$00  ; row 16
        fcb     $00,$00,$00,$00,$01,$57,$FF,$C0,$00,$00,$00  ; row 17
        fcb     $00,$00,$00,$00,$01,$57,$FF,$C0,$00,$00,$00  ; row 18
        fcb     $00,$00,$00,$00,$01,$57,$FF,$F0,$00,$00,$00  ; row 19
        fcb     $00,$00,$00,$00,$15,$57,$FF,$F0,$00,$00,$00  ; row 20
        fcb     $00,$00,$00,$01,$55,$57,$FF,$F0,$00,$00,$00  ; row 21
        fcb     $00,$00,$00,$15,$55,$57,$FF,$F0,$00,$00,$00  ; row 22
        fcb     $00,$00,$01,$55,$55,$57,$FF,$F0,$00,$00,$00  ; row 23
        fcb     $00,$00,$01,$55,$55,$0F,$FF,$F0,$00,$00,$00  ; row 24
        fcb     $00,$00,$01,$55,$55,$0F,$FF,$F0,$00,$00,$00  ; row 25
        fcb     $00,$00,$15,$55,$7F,$EF,$FF,$F0,$00,$00,$00  ; row 26
        fcb     $00,$00,$15,$57,$FF,$EF,$FF,$F5,$50,$00,$00  ; row 27
        fcb     $00,$00,$15,$57,$FF,$0F,$FF,$F5,$55,$00,$00  ; row 28
        fcb     $00,$00,$15,$57,$FF,$7F,$FF,$F5,$55,$7C,$00  ; row 29
        fcb     $00,$00,$15,$57,$FF,$0F,$FF,$F5,$55,$0F,$C0  ; row 30
        fcb     $00,$00,$15,$7F,$FF,$00,$FF,$01,$50,$0F,$C0  ; row 31
        fcb     $00,$00,$3F,$00,$00,$00,$00,$00,$00,$0F,$00  ; row 32
        fcb     $00,$03,$FF,$00,$00,$00,$00,$00,$00,$3F,$00  ; row 33
        fcb     $00,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00  ; row 34
