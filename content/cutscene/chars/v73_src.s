* v73_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #99 (5x49 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=164  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v73_src:
        fcb     49,8  ; height=49 rows, coco3_width=8 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$3F,$F0,$00,$00  ; row 0
        fcb     $00,$00,$00,$0F,$FF,$FF,$00,$00  ; row 1
        fcb     $00,$00,$00,$3F,$FF,$FF,$F0,$00  ; row 2
        fcb     $10,$00,$00,$FF,$FF,$FF,$F0,$00  ; row 3
        fcb     $15,$00,$00,$FF,$FF,$FF,$F0,$00  ; row 4
        fcb     $15,$00,$00,$00,$FF,$FF,$C0,$00  ; row 5
        fcb     $17,$E8,$00,$01,$57,$FC,$00,$00  ; row 6
        fcb     $03,$E8,$00,$01,$57,$F0,$00,$00  ; row 7
        fcb     $00,$A8,$00,$03,$EF,$F0,$00,$00  ; row 8
        fcb     $00,$AA,$80,$0F,$7F,$FC,$00,$00  ; row 9
        fcb     $00,$0A,$A8,$03,$FF,$FC,$00,$00  ; row 10
        fcb     $00,$0A,$AA,$FF,$FF,$FC,$00,$00  ; row 11
        fcb     $00,$00,$AA,$AF,$FF,$FC,$00,$00  ; row 12
        fcb     $00,$00,$0A,$AF,$FF,$F0,$00,$00  ; row 13
        fcb     $00,$00,$00,$AA,$FF,$F0,$00,$00  ; row 14
        fcb     $00,$00,$00,$AA,$FF,$F0,$00,$00  ; row 15
        fcb     $00,$00,$00,$AA,$FF,$FC,$00,$00  ; row 16
        fcb     $00,$00,$00,$AA,$FF,$FC,$00,$00  ; row 17
        fcb     $00,$00,$0A,$AA,$AF,$FC,$00,$00  ; row 18
        fcb     $00,$00,$0A,$AA,$AF,$FC,$00,$00  ; row 19
        fcb     $00,$00,$0A,$AA,$AF,$FC,$00,$00  ; row 20
        fcb     $00,$00,$0A,$AA,$AF,$FC,$00,$00  ; row 21
        fcb     $00,$00,$0A,$AA,$AF,$FC,$00,$00  ; row 22
        fcb     $00,$00,$0A,$AA,$AF,$FC,$00,$00  ; row 23
        fcb     $00,$00,$0A,$AA,$AF,$FC,$00,$00  ; row 24
        fcb     $00,$00,$0A,$AA,$AF,$FF,$00,$00  ; row 25
        fcb     $00,$00,$0A,$AA,$AF,$FF,$00,$00  ; row 26
        fcb     $00,$00,$0A,$AA,$AF,$FF,$00,$00  ; row 27
        fcb     $00,$00,$0A,$AA,$AA,$FF,$00,$00  ; row 28
        fcb     $00,$00,$0A,$AA,$AA,$FF,$C0,$00  ; row 29
        fcb     $00,$00,$00,$AA,$AA,$FF,$C0,$00  ; row 30
        fcb     $00,$00,$00,$AA,$AA,$FF,$C0,$00  ; row 31
        fcb     $00,$00,$00,$AA,$AA,$FF,$F0,$00  ; row 32
        fcb     $00,$00,$00,$AA,$AA,$FF,$F0,$00  ; row 33
        fcb     $00,$00,$00,$AA,$AA,$FF,$F0,$00  ; row 34
        fcb     $00,$00,$00,$AA,$AA,$AF,$FC,$00  ; row 35
        fcb     $00,$00,$00,$0A,$AA,$AF,$FF,$00  ; row 36
        fcb     $00,$00,$00,$0A,$AA,$AF,$FF,$00  ; row 37
        fcb     $00,$00,$00,$0A,$AA,$AF,$FF,$00  ; row 38
        fcb     $00,$00,$00,$0A,$AA,$83,$FF,$C0  ; row 39
        fcb     $00,$00,$00,$00,$AA,$80,$FF,$F0  ; row 40
        fcb     $00,$00,$00,$00,$AA,$A8,$3F,$C0  ; row 41
        fcb     $00,$00,$00,$00,$AA,$A8,$0F,$C0  ; row 42
        fcb     $00,$00,$00,$00,$AA,$A8,$0F,$00  ; row 43
        fcb     $00,$00,$00,$00,$0A,$A8,$00,$00  ; row 44
        fcb     $00,$00,$00,$00,$0A,$A8,$00,$00  ; row 45
        fcb     $00,$00,$00,$00,$3F,$F0,$00,$00  ; row 46
        fcb     $00,$00,$00,$00,$FF,$F0,$00,$00  ; row 47
        fcb     $00,$00,$00,$0F,$FF,$C0,$00,$00  ; row 48
