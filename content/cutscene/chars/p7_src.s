* p7_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #31 (4x43 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=128  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

p7_src:
        fcb     43,7  ; height=43 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$00,$0F,$C0,$00,$00  ; row 0
        fcb     $00,$00,$00,$F0,$08,$00,$00  ; row 1
        fcb     $00,$00,$03,$F0,$00,$00,$00  ; row 2
        fcb     $00,$00,$0F,$00,$10,$00,$00  ; row 3
        fcb     $00,$00,$08,$01,$50,$00,$00  ; row 4
        fcb     $00,$00,$80,$01,$50,$00,$00  ; row 5
        fcb     $00,$0F,$00,$00,$10,$00,$00  ; row 6
        fcb     $0F,$F0,$00,$00,$00,$00,$00  ; row 7
        fcb     $7F,$00,$00,$00,$00,$00,$00  ; row 8
        fcb     $0F,$C0,$00,$10,$00,$00,$00  ; row 9
        fcb     $7F,$FF,$FC,$17,$C0,$00,$00  ; row 10
        fcb     $00,$3F,$F0,$17,$F0,$00,$00  ; row 11
        fcb     $00,$00,$00,$17,$FC,$00,$00  ; row 12
        fcb     $00,$00,$00,$17,$FC,$00,$00  ; row 13
        fcb     $00,$00,$00,$17,$F0,$00,$00  ; row 14
        fcb     $00,$00,$00,$17,$C1,$00,$00  ; row 15
        fcb     $00,$00,$00,$15,$55,$00,$00  ; row 16
        fcb     $00,$00,$00,$FF,$C0,$00,$00  ; row 17
        fcb     $00,$00,$00,$FF,$C0,$00,$00  ; row 18
        fcb     $00,$00,$03,$FF,$C0,$00,$00  ; row 19
        fcb     $00,$00,$03,$FF,$F0,$00,$00  ; row 20
        fcb     $00,$00,$0F,$FF,$F0,$00,$00  ; row 21
        fcb     $00,$00,$3F,$FF,$FC,$00,$00  ; row 22
        fcb     $00,$00,$FC,$3F,$FC,$00,$00  ; row 23
        fcb     $00,$03,$F0,$0F,$FF,$00,$00  ; row 24
        fcb     $00,$0F,$0A,$80,$FF,$00,$00  ; row 25
        fcb     $00,$3C,$0A,$AA,$AF,$C0,$00  ; row 26
        fcb     $00,$80,$0A,$AA,$AF,$C0,$00  ; row 27
        fcb     $01,$00,$0A,$AA,$AA,$F0,$00  ; row 28
        fcb     $00,$00,$0A,$AA,$AA,$80,$00  ; row 29
        fcb     $00,$00,$0A,$AA,$AA,$80,$00  ; row 30
        fcb     $00,$00,$0A,$AA,$AA,$A8,$00  ; row 31
        fcb     $00,$00,$0A,$AA,$AA,$A8,$00  ; row 32
        fcb     $00,$00,$0A,$AA,$AA,$A8,$00  ; row 33
        fcb     $00,$00,$0A,$AA,$AA,$AA,$80  ; row 34
        fcb     $00,$00,$0A,$AA,$AA,$AA,$80  ; row 35
        fcb     $00,$00,$0A,$AA,$AA,$80,$00  ; row 36
        fcb     $00,$00,$0A,$A8,$00,$00,$00  ; row 37
        fcb     $00,$00,$00,$00,$3C,$00,$00  ; row 38
        fcb     $00,$00,$03,$C0,$3C,$00,$00  ; row 39
        fcb     $00,$00,$03,$C0,$FF,$00,$00  ; row 40
        fcb     $00,$00,$0F,$F0,$FF,$F0,$00  ; row 41
        fcb     $00,$00,$0F,$FF,$00,$00,$00  ; row 42
