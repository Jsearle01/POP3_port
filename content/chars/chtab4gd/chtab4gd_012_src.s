* chtab4gd_012_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.GD
*         POP cel: #12 (5x37 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4gd_012_src:
        fcb     37,9  ; height=37 rows, coco3_width=9 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$03,$FC,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$00,$AA,$FF,$C0,$00,$00  ; row 1
        fcb     $00,$00,$00,$0A,$AA,$FF,$F0,$00,$00  ; row 2
        fcb     $00,$00,$00,$AA,$AA,$FF,$F0,$00,$00  ; row 3
        fcb     $00,$00,$03,$EA,$AF,$FF,$F0,$00,$00  ; row 4
        fcb     $00,$00,$01,$7E,$AF,$FF,$C0,$00,$00  ; row 5
        fcb     $00,$00,$01,$50,$3F,$FF,$C0,$00,$00  ; row 6
        fcb     $00,$00,$03,$F0,$0F,$FF,$C0,$00,$00  ; row 7
        fcb     $00,$00,$00,$3C,$08,$3F,$F0,$00,$00  ; row 8
        fcb     $00,$00,$00,$3C,$3E,$FF,$FC,$00,$00  ; row 9
        fcb     $00,$00,$00,$0F,$7F,$FF,$FC,$00,$00  ; row 10
        fcb     $00,$00,$00,$0F,$7F,$FF,$FF,$00,$00  ; row 11
        fcb     $00,$00,$00,$01,$55,$7F,$FF,$00,$00  ; row 12
        fcb     $00,$00,$00,$00,$F5,$57,$EA,$80,$00  ; row 13
        fcb     $00,$00,$00,$00,$FF,$F5,$0A,$80,$00  ; row 14
        fcb     $00,$00,$00,$00,$FF,$FF,$00,$00,$00  ; row 15
        fcb     $00,$00,$00,$00,$AF,$FF,$C0,$00,$00  ; row 16
        fcb     $00,$00,$00,$00,$AF,$FF,$C0,$00,$00  ; row 17
        fcb     $00,$00,$00,$0A,$AF,$FF,$C0,$00,$00  ; row 18
        fcb     $00,$00,$00,$0A,$AF,$FF,$C0,$00,$00  ; row 19
        fcb     $00,$00,$00,$AA,$AF,$FF,$F0,$00,$00  ; row 20
        fcb     $00,$00,$00,$AA,$AF,$FF,$F0,$00,$00  ; row 21
        fcb     $00,$00,$0A,$AA,$AF,$FF,$F0,$00,$00  ; row 22
        fcb     $00,$00,$0A,$AA,$83,$FF,$F0,$00,$00  ; row 23
        fcb     $00,$00,$AA,$AA,$83,$FF,$F0,$00,$00  ; row 24
        fcb     $00,$00,$AA,$A8,$03,$FF,$F0,$00,$00  ; row 25
        fcb     $00,$00,$AA,$80,$03,$FF,$FC,$00,$00  ; row 26
        fcb     $00,$00,$AA,$80,$3E,$FF,$EA,$80,$00  ; row 27
        fcb     $00,$00,$AA,$AF,$FE,$FF,$EA,$80,$00  ; row 28
        fcb     $00,$3E,$AA,$AF,$FE,$FE,$AA,$A8,$00  ; row 29
        fcb     $00,$FE,$AA,$AF,$00,$80,$AA,$A8,$00  ; row 30
        fcb     $00,$00,$AA,$80,$00,$00,$0A,$A8,$00  ; row 31
        fcb     $00,$00,$08,$00,$00,$00,$0A,$AA,$80  ; row 32
        fcb     $00,$00,$0F,$C0,$00,$00,$00,$03,$F0  ; row 33
        fcb     $00,$00,$3F,$C0,$00,$00,$00,$03,$F0  ; row 34
        fcb     $00,$03,$FF,$C0,$00,$00,$00,$3F,$FC  ; row 35
        fcb     $00,$3F,$F0,$00,$00,$00,$00,$00,$00  ; row 36
