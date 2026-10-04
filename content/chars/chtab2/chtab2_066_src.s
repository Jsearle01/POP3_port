* chtab2_066_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #66 (3x38 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_066_src:
        fcb     38,4  ; height=38 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $03,$FF,$00,$00  ; row 0
        fcb     $7F,$FF,$C0,$00  ; row 1
        fcb     $7F,$FF,$C0,$00  ; row 2
        fcb     $03,$FF,$C0,$00  ; row 3
        fcb     $0A,$FF,$C0,$00  ; row 4
        fcb     $0A,$AF,$00,$00  ; row 5
        fcb     $0A,$AF,$C0,$00  ; row 6
        fcb     $00,$3F,$FC,$00  ; row 7
        fcb     $00,$3E,$FF,$00  ; row 8
        fcb     $00,$FE,$AF,$00  ; row 9
        fcb     $00,$FE,$AF,$00  ; row 10
        fcb     $00,$3F,$EF,$C0  ; row 11
        fcb     $00,$3F,$EF,$C0  ; row 12
        fcb     $00,$3F,$EA,$F0  ; row 13
        fcb     $00,$0F,$EA,$FC  ; row 14
        fcb     $00,$03,$FE,$FC  ; row 15
        fcb     $00,$03,$FE,$FF  ; row 16
        fcb     $00,$00,$FE,$FF  ; row 17
        fcb     $00,$00,$FE,$FF  ; row 18
        fcb     $00,$00,$FE,$FC  ; row 19
        fcb     $00,$00,$AA,$F0  ; row 20
        fcb     $00,$00,$AF,$F0  ; row 21
        fcb     $00,$00,$AF,$F0  ; row 22
        fcb     $00,$03,$FF,$F0  ; row 23
        fcb     $00,$03,$FF,$F0  ; row 24
        fcb     $00,$03,$FF,$F0  ; row 25
        fcb     $00,$03,$FF,$F0  ; row 26
        fcb     $00,$00,$FF,$F0  ; row 27
        fcb     $00,$00,$FF,$F0  ; row 28
        fcb     $00,$00,$FF,$F0  ; row 29
        fcb     $00,$00,$FF,$F0  ; row 30
        fcb     $00,$00,$FF,$F0  ; row 31
        fcb     $00,$00,$3F,$F0  ; row 32
        fcb     $00,$00,$3F,$C0  ; row 33
        fcb     $00,$00,$3F,$C0  ; row 34
        fcb     $00,$00,$FE,$80  ; row 35
        fcb     $00,$03,$FC,$00  ; row 36
        fcb     $00,$3F,$FC,$00  ; row 37
