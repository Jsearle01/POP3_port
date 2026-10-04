* chtab4gd_022_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.GD
*         POP cel: #22 (4x37 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4gd_022_src:
        fcb     37,7  ; height=37 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$0F,$FF,$C0,$00,$00  ; row 0
        fcb     $00,$00,$FF,$FF,$F0,$00,$00  ; row 1
        fcb     $00,$03,$FF,$FF,$F0,$00,$00  ; row 2
        fcb     $00,$03,$FF,$FF,$F0,$00,$00  ; row 3
        fcb     $00,$03,$FF,$FF,$C0,$00,$00  ; row 4
        fcb     $00,$00,$AF,$FF,$C0,$00,$00  ; row 5
        fcb     $00,$00,$15,$7F,$00,$00,$00  ; row 6
        fcb     $00,$00,$17,$FF,$F0,$00,$00  ; row 7
        fcb     $00,$00,$0F,$FF,$FC,$00,$00  ; row 8
        fcb     $00,$00,$AF,$FF,$FF,$00,$00  ; row 9
        fcb     $00,$AA,$AF,$FF,$FF,$00,$00  ; row 10
        fcb     $17,$EA,$AA,$FF,$FF,$00,$00  ; row 11
        fcb     $17,$E8,$00,$FF,$FF,$00,$00  ; row 12
        fcb     $00,$00,$00,$3F,$F5,$00,$00  ; row 13
        fcb     $00,$00,$00,$01,$57,$C0,$00  ; row 14
        fcb     $00,$00,$00,$01,$7F,$F0,$00  ; row 15
        fcb     $00,$00,$00,$03,$FF,$F0,$00  ; row 16
        fcb     $00,$00,$00,$03,$FF,$FC,$00  ; row 17
        fcb     $00,$00,$00,$0A,$FF,$FC,$00  ; row 18
        fcb     $00,$00,$00,$0A,$FF,$FC,$00  ; row 19
        fcb     $00,$00,$00,$0A,$FF,$FC,$00  ; row 20
        fcb     $00,$00,$00,$AA,$AF,$F0,$00  ; row 21
        fcb     $00,$00,$00,$AA,$AF,$F0,$00  ; row 22
        fcb     $00,$00,$00,$AA,$AF,$C0,$00  ; row 23
        fcb     $00,$00,$00,$AA,$AF,$00,$00  ; row 24
        fcb     $00,$00,$0A,$AA,$A8,$00,$00  ; row 25
        fcb     $00,$00,$0A,$AA,$AA,$80,$00  ; row 26
        fcb     $00,$00,$0A,$AA,$AA,$AF,$00  ; row 27
        fcb     $00,$00,$0A,$AA,$AA,$AF,$F0  ; row 28
        fcb     $00,$00,$0A,$AA,$AA,$AF,$FF  ; row 29
        fcb     $00,$00,$0A,$A8,$00,$03,$FF  ; row 30
        fcb     $00,$00,$00,$A8,$00,$00,$FF  ; row 31
        fcb     $00,$00,$00,$0F,$C0,$00,$FC  ; row 32
        fcb     $00,$00,$00,$3F,$F0,$00,$3C  ; row 33
        fcb     $00,$00,$00,$FF,$C0,$00,$10  ; row 34
        fcb     $00,$00,$00,$FF,$00,$00,$00  ; row 35
        fcb     $00,$00,$03,$F0,$00,$00,$00  ; row 36
