* v80_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB7
*         POP cel: #3 (3x48 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=160  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v80_src:
        fcb     48,5  ; height=48 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$00,$0F,$C0,$00  ; row 0
        fcb     $00,$00,$FF,$FF,$00  ; row 1
        fcb     $00,$03,$FF,$FF,$F0  ; row 2
        fcb     $00,$03,$FF,$FF,$FC  ; row 3
        fcb     $00,$00,$3F,$FF,$FC  ; row 4
        fcb     $00,$00,$03,$FF,$FC  ; row 5
        fcb     $00,$00,$15,$7F,$F0  ; row 6
        fcb     $00,$00,$15,$7F,$00  ; row 7
        fcb     $00,$00,$F7,$FF,$00  ; row 8
        fcb     $00,$00,$80,$FF,$F0  ; row 9
        fcb     $15,$00,$03,$FF,$F0  ; row 10
        fcb     $15,$00,$03,$FF,$FC  ; row 11
        fcb     $0F,$E8,$0F,$FF,$FC  ; row 12
        fcb     $0A,$A8,$0F,$FF,$FC  ; row 13
        fcb     $00,$AA,$AF,$FF,$FC  ; row 14
        fcb     $00,$0A,$AA,$FF,$FC  ; row 15
        fcb     $00,$0A,$AA,$FF,$FC  ; row 16
        fcb     $00,$00,$AA,$FF,$FC  ; row 17
        fcb     $00,$00,$0A,$FF,$FF  ; row 18
        fcb     $00,$00,$0A,$FF,$FF  ; row 19
        fcb     $00,$00,$0A,$FF,$FF  ; row 20
        fcb     $00,$00,$0A,$FF,$FF  ; row 21
        fcb     $00,$00,$0A,$AF,$FF  ; row 22
        fcb     $00,$00,$0A,$AF,$FF  ; row 23
        fcb     $00,$00,$0A,$AF,$FF  ; row 24
        fcb     $00,$00,$0A,$AF,$FF  ; row 25
        fcb     $00,$00,$0A,$AF,$FF  ; row 26
        fcb     $00,$00,$0A,$AF,$FF  ; row 27
        fcb     $00,$00,$0A,$AF,$FF  ; row 28
        fcb     $00,$00,$0A,$AF,$FF  ; row 29
        fcb     $00,$00,$0A,$AF,$FF  ; row 30
        fcb     $00,$00,$0A,$AF,$FF  ; row 31
        fcb     $00,$00,$0A,$AF,$FF  ; row 32
        fcb     $00,$00,$0A,$AA,$FF  ; row 33
        fcb     $00,$00,$0A,$AA,$FF  ; row 34
        fcb     $00,$00,$0A,$AA,$FF  ; row 35
        fcb     $00,$00,$0A,$AA,$FF  ; row 36
        fcb     $00,$00,$0A,$AA,$FC  ; row 37
        fcb     $00,$00,$0A,$AA,$FC  ; row 38
        fcb     $00,$00,$0A,$AA,$FC  ; row 39
        fcb     $00,$00,$00,$AA,$FC  ; row 40
        fcb     $00,$00,$00,$AA,$FC  ; row 41
        fcb     $00,$00,$00,$AA,$FC  ; row 42
        fcb     $00,$00,$00,$AA,$FC  ; row 43
        fcb     $00,$00,$00,$AA,$FC  ; row 44
        fcb     $00,$00,$00,$FE,$FC  ; row 45
        fcb     $00,$00,$0F,$FE,$FF  ; row 46
        fcb     $00,$00,$FF,$FF,$C0  ; row 47
