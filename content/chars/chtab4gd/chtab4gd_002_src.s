* chtab4gd_002_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.GD
*         POP cel: #2 (6x37 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4gd_002_src:
        fcb     37,10  ; height=37 rows, coco3_width=10 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$0F,$FC,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$00,$FF,$FF,$F0,$00,$00,$00  ; row 1
        fcb     $00,$00,$00,$00,$FF,$FF,$FC,$00,$00,$00  ; row 2
        fcb     $00,$00,$00,$00,$3F,$FF,$FC,$00,$00,$00  ; row 3
        fcb     $00,$00,$00,$00,$AF,$FF,$FC,$00,$00,$00  ; row 4
        fcb     $00,$00,$00,$00,$03,$FF,$F0,$00,$00,$00  ; row 5
        fcb     $00,$00,$00,$00,$15,$7F,$C0,$00,$00,$00  ; row 6
        fcb     $00,$00,$00,$00,$15,$7C,$00,$00,$00,$00  ; row 7
        fcb     $00,$01,$7E,$A8,$3F,$FF,$C0,$00,$00,$00  ; row 8
        fcb     $00,$01,$7E,$AA,$83,$FF,$C0,$00,$00,$00  ; row 9
        fcb     $00,$00,$00,$AA,$83,$FF,$C0,$00,$00,$00  ; row 10
        fcb     $00,$00,$00,$00,$0A,$FF,$C0,$00,$00,$00  ; row 11
        fcb     $00,$00,$00,$00,$0A,$FF,$F0,$00,$00,$00  ; row 12
        fcb     $00,$00,$00,$00,$0F,$FF,$F0,$00,$00,$00  ; row 13
        fcb     $00,$00,$00,$10,$0F,$FF,$F0,$00,$00,$00  ; row 14
        fcb     $00,$00,$00,$17,$F5,$55,$00,$00,$00,$00  ; row 15
        fcb     $00,$00,$00,$17,$F5,$55,$00,$00,$00,$00  ; row 16
        fcb     $00,$00,$00,$00,$3F,$FF,$F0,$00,$00,$00  ; row 17
        fcb     $00,$00,$00,$00,$AA,$FF,$FC,$00,$00,$00  ; row 18
        fcb     $00,$00,$00,$00,$AA,$FF,$FC,$00,$00,$00  ; row 19
        fcb     $00,$00,$00,$0A,$AA,$FF,$FC,$00,$00,$00  ; row 20
        fcb     $00,$00,$00,$0A,$AA,$AF,$FC,$00,$00,$00  ; row 21
        fcb     $00,$00,$00,$AA,$AA,$AF,$FC,$00,$00,$00  ; row 22
        fcb     $00,$00,$0A,$AA,$AA,$AF,$FF,$00,$00,$00  ; row 23
        fcb     $00,$00,$0A,$AA,$AA,$F7,$FF,$00,$00,$00  ; row 24
        fcb     $00,$00,$0A,$AA,$AF,$F7,$FF,$C0,$00,$00  ; row 25
        fcb     $00,$00,$0A,$A8,$0F,$FE,$FF,$C0,$00,$00  ; row 26
        fcb     $00,$00,$AA,$80,$3F,$FE,$FF,$F0,$00,$00  ; row 27
        fcb     $00,$00,$AA,$80,$3F,$FE,$FF,$FC,$00,$00  ; row 28
        fcb     $00,$00,$AA,$80,$3F,$FF,$7F,$FF,$C0,$00  ; row 29
        fcb     $00,$00,$AA,$80,$00,$3F,$0F,$FF,$F0,$00  ; row 30
        fcb     $00,$00,$AA,$80,$00,$00,$0F,$FF,$E8,$00  ; row 31
        fcb     $00,$00,$08,$00,$00,$00,$00,$0A,$80,$00  ; row 32
        fcb     $00,$00,$F0,$00,$00,$00,$00,$00,$0F,$F0  ; row 33
        fcb     $0F,$FF,$FC,$00,$00,$00,$00,$00,$3F,$F0  ; row 34
        fcb     $00,$FF,$FC,$00,$00,$00,$00,$00,$FF,$C0  ; row 35
        fcb     $00,$03,$FC,$00,$00,$00,$00,$00,$00,$00  ; row 36
