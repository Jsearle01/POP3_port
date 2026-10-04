* chtab5_037_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #37 (3x38 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_037_src:
        fcb     38,4  ; height=38 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $00,$3F,$F0,$00  ; row 0
        fcb     $03,$FF,$FC,$00  ; row 1
        fcb     $03,$FF,$FC,$00  ; row 2
        fcb     $00,$0F,$FC,$00  ; row 3
        fcb     $00,$AA,$FC,$00  ; row 4
        fcb     $00,$AA,$F0,$00  ; row 5
        fcb     $00,$AA,$80,$00  ; row 6
        fcb     $00,$3E,$AF,$C0  ; row 7
        fcb     $00,$FE,$AF,$E8  ; row 8
        fcb     $0A,$FF,$FF,$E8  ; row 9
        fcb     $0A,$FF,$FF,$E8  ; row 10
        fcb     $AA,$FF,$FF,$E8  ; row 11
        fcb     $AA,$AA,$FF,$E8  ; row 12
        fcb     $00,$AA,$FF,$E8  ; row 13
        fcb     $00,$3E,$AA,$A8  ; row 14
        fcb     $00,$3F,$EA,$A8  ; row 15
        fcb     $00,$0F,$FF,$F0  ; row 16
        fcb     $00,$0F,$FF,$F0  ; row 17
        fcb     $00,$0F,$FF,$FC  ; row 18
        fcb     $00,$0F,$FF,$FC  ; row 19
        fcb     $00,$0F,$FF,$FC  ; row 20
        fcb     $00,$0F,$FF,$F0  ; row 21
        fcb     $00,$0F,$FF,$F0  ; row 22
        fcb     $00,$3F,$FF,$F0  ; row 23
        fcb     $00,$3F,$FF,$F0  ; row 24
        fcb     $00,$3F,$FF,$C0  ; row 25
        fcb     $00,$3F,$FF,$C0  ; row 26
        fcb     $00,$3F,$FF,$C0  ; row 27
        fcb     $00,$FF,$FF,$C0  ; row 28
        fcb     $00,$3F,$FF,$F0  ; row 29
        fcb     $00,$0F,$FF,$F0  ; row 30
        fcb     $00,$03,$FF,$FC  ; row 31
        fcb     $00,$00,$FF,$FF  ; row 32
        fcb     $00,$00,$3F,$FF  ; row 33
        fcb     $00,$00,$0F,$FF  ; row 34
        fcb     $00,$00,$3F,$FF  ; row 35
        fcb     $00,$00,$3F,$FF  ; row 36
        fcb     $00,$00,$0F,$F0  ; row 37
