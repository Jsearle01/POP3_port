* v78_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB7
*         POP cel: #1 (2x50 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=156  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v78_src:
        fcb     50,4  ; height=50 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $15,$00,$00,$00  ; row 0
        fcb     $15,$00,$00,$00  ; row 1
        fcb     $08,$3C,$00,$00  ; row 2
        fcb     $08,$3F,$F0,$00  ; row 3
        fcb     $0A,$AF,$FF,$00  ; row 4
        fcb     $0A,$AF,$FF,$C0  ; row 5
        fcb     $0A,$AF,$FF,$C0  ; row 6
        fcb     $0A,$AF,$FF,$C0  ; row 7
        fcb     $0A,$83,$FF,$00  ; row 8
        fcb     $0A,$83,$F0,$00  ; row 9
        fcb     $0A,$AF,$F0,$00  ; row 10
        fcb     $0A,$AF,$FC,$00  ; row 11
        fcb     $00,$AF,$FF,$00  ; row 12
        fcb     $00,$AF,$FF,$00  ; row 13
        fcb     $00,$AA,$FF,$00  ; row 14
        fcb     $00,$AA,$FF,$C0  ; row 15
        fcb     $00,$AA,$FF,$C0  ; row 16
        fcb     $00,$AA,$FF,$C0  ; row 17
        fcb     $00,$AA,$FF,$C0  ; row 18
        fcb     $00,$AA,$FF,$C0  ; row 19
        fcb     $00,$AA,$AF,$C0  ; row 20
        fcb     $00,$AA,$AF,$C0  ; row 21
        fcb     $00,$AA,$AF,$C0  ; row 22
        fcb     $00,$AA,$AF,$C0  ; row 23
        fcb     $00,$AA,$AF,$C0  ; row 24
        fcb     $00,$AA,$AF,$C0  ; row 25
        fcb     $00,$AA,$AF,$C0  ; row 26
        fcb     $00,$AA,$AF,$C0  ; row 27
        fcb     $00,$AA,$AF,$C0  ; row 28
        fcb     $00,$AA,$AF,$C0  ; row 29
        fcb     $00,$0A,$AF,$C0  ; row 30
        fcb     $00,$0A,$AF,$C0  ; row 31
        fcb     $00,$0A,$AF,$C0  ; row 32
        fcb     $00,$0A,$AF,$C0  ; row 33
        fcb     $00,$0A,$AF,$F0  ; row 34
        fcb     $00,$0A,$AF,$F0  ; row 35
        fcb     $00,$0A,$AF,$F0  ; row 36
        fcb     $00,$0A,$AF,$F0  ; row 37
        fcb     $00,$0A,$AF,$F0  ; row 38
        fcb     $00,$0A,$AF,$F0  ; row 39
        fcb     $00,$0A,$AF,$F0  ; row 40
        fcb     $00,$0A,$AF,$F0  ; row 41
        fcb     $00,$0A,$AF,$F0  ; row 42
        fcb     $00,$00,$AF,$F0  ; row 43
        fcb     $00,$00,$AF,$F0  ; row 44
        fcb     $00,$00,$AF,$F0  ; row 45
        fcb     $00,$00,$AA,$80  ; row 46
        fcb     $00,$00,$FC,$00  ; row 47
        fcb     $00,$0F,$FF,$00  ; row 48
        fcb     $00,$FF,$FF,$00  ; row 49
