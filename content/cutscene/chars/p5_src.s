* p5_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #29 (3x42 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=122  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

p5_src:
        fcb     42,6  ; height=42 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $00,$3F,$00,$00,$00,$00  ; row 0
        fcb     $00,$FF,$C0,$00,$00,$00  ; row 1
        fcb     $7F,$F0,$10,$00,$00,$00  ; row 2
        fcb     $80,$00,$FE,$80,$00,$00  ; row 3
        fcb     $00,$00,$00,$00,$00,$00  ; row 4
        fcb     $00,$00,$F0,$00,$00,$00  ; row 5
        fcb     $80,$00,$10,$00,$00,$00  ; row 6
        fcb     $00,$00,$10,$00,$00,$00  ; row 7
        fcb     $00,$00,$15,$00,$00,$00  ; row 8
        fcb     $00,$01,$55,$00,$00,$00  ; row 9
        fcb     $80,$01,$55,$00,$00,$00  ; row 10
        fcb     $15,$55,$55,$00,$00,$00  ; row 11
        fcb     $17,$FF,$F5,$00,$00,$00  ; row 12
        fcb     $17,$FF,$F5,$00,$00,$00  ; row 13
        fcb     $17,$FF,$F5,$00,$00,$00  ; row 14
        fcb     $17,$FF,$F5,$00,$00,$00  ; row 15
        fcb     $10,$FF,$F5,$00,$00,$00  ; row 16
        fcb     $00,$FF,$FC,$00,$00,$00  ; row 17
        fcb     $00,$FF,$FC,$00,$00,$00  ; row 18
        fcb     $03,$FF,$FF,$00,$00,$00  ; row 19
        fcb     $03,$FF,$FF,$C0,$00,$00  ; row 20
        fcb     $03,$FF,$FF,$C0,$00,$00  ; row 21
        fcb     $03,$FF,$FF,$F0,$00,$00  ; row 22
        fcb     $00,$83,$FF,$FC,$00,$00  ; row 23
        fcb     $00,$AA,$83,$FC,$00,$00  ; row 24
        fcb     $00,$AA,$AA,$AA,$80,$00  ; row 25
        fcb     $00,$0A,$AA,$AA,$80,$00  ; row 26
        fcb     $00,$0A,$AA,$AA,$A8,$00  ; row 27
        fcb     $00,$0A,$AA,$AA,$A8,$00  ; row 28
        fcb     $00,$AA,$AA,$AA,$AA,$80  ; row 29
        fcb     $00,$AA,$AA,$AA,$AA,$80  ; row 30
        fcb     $00,$AA,$AA,$AA,$AA,$80  ; row 31
        fcb     $0A,$AA,$AA,$AA,$AA,$80  ; row 32
        fcb     $0A,$AA,$AA,$AA,$A8,$00  ; row 33
        fcb     $0A,$AA,$AA,$AA,$A8,$00  ; row 34
        fcb     $AA,$AA,$AA,$AA,$80,$00  ; row 35
        fcb     $AA,$AA,$A8,$00,$00,$00  ; row 36
        fcb     $0F,$00,$00,$F0,$00,$00  ; row 37
        fcb     $0F,$00,$00,$F0,$00,$00  ; row 38
        fcb     $7F,$00,$00,$F0,$00,$00  ; row 39
        fcb     $7F,$C0,$03,$F0,$00,$00  ; row 40
        fcb     $03,$F0,$00,$00,$00,$00  ; row 41
