* v85_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB7
*         POP cel: #8 (3x48 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=156  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v85_src:
        fcb     48,5  ; height=48 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$0F,$C0,$00,$00  ; row 0
        fcb     $00,$FF,$FF,$00,$00  ; row 1
        fcb     $03,$FF,$FF,$F0,$00  ; row 2
        fcb     $03,$FF,$FF,$FC,$00  ; row 3
        fcb     $00,$3F,$FF,$FC,$00  ; row 4
        fcb     $00,$03,$FF,$FC,$00  ; row 5
        fcb     $00,$15,$7F,$F0,$00  ; row 6
        fcb     $00,$15,$7F,$00,$00  ; row 7
        fcb     $00,$F7,$FF,$00,$00  ; row 8
        fcb     $00,$80,$FF,$C0,$00  ; row 9
        fcb     $00,$0F,$FF,$F0,$00  ; row 10
        fcb     $00,$0F,$FF,$F0,$00  ; row 11
        fcb     $00,$3F,$FF,$F0,$00  ; row 12
        fcb     $00,$3F,$FF,$FC,$00  ; row 13
        fcb     $00,$3F,$FF,$FC,$00  ; row 14
        fcb     $00,$3F,$FF,$FC,$00  ; row 15
        fcb     $00,$0F,$FF,$FC,$00  ; row 16
        fcb     $00,$AF,$FF,$FC,$00  ; row 17
        fcb     $00,$AF,$FF,$FC,$00  ; row 18
        fcb     $00,$AF,$FF,$FC,$00  ; row 19
        fcb     $00,$AF,$FF,$FF,$00  ; row 20
        fcb     $00,$AF,$FF,$FF,$00  ; row 21
        fcb     $03,$EA,$FF,$FF,$00  ; row 22
        fcb     $03,$EA,$FF,$FF,$00  ; row 23
        fcb     $15,$0A,$FF,$FF,$00  ; row 24
        fcb     $15,$0A,$FF,$FF,$00  ; row 25
        fcb     $10,$0A,$FF,$FF,$00  ; row 26
        fcb     $00,$0A,$FF,$FF,$00  ; row 27
        fcb     $00,$0A,$FF,$FF,$00  ; row 28
        fcb     $00,$0A,$FF,$FF,$00  ; row 29
        fcb     $00,$0A,$FF,$FF,$C0  ; row 30
        fcb     $00,$0A,$FF,$FF,$C0  ; row 31
        fcb     $00,$0A,$AF,$FF,$C0  ; row 32
        fcb     $00,$0A,$AF,$FF,$C0  ; row 33
        fcb     $00,$0A,$AF,$FF,$C0  ; row 34
        fcb     $00,$0A,$AF,$FF,$C0  ; row 35
        fcb     $00,$00,$AF,$FF,$C0  ; row 36
        fcb     $00,$00,$AF,$FF,$C0  ; row 37
        fcb     $00,$00,$AF,$FF,$C0  ; row 38
        fcb     $00,$00,$AF,$FF,$C0  ; row 39
        fcb     $00,$00,$AA,$FF,$C0  ; row 40
        fcb     $00,$00,$0A,$FF,$C0  ; row 41
        fcb     $00,$00,$0A,$FF,$C0  ; row 42
        fcb     $00,$00,$0A,$FF,$C0  ; row 43
        fcb     $00,$00,$0A,$FF,$C0  ; row 44
        fcb     $00,$00,$3F,$EF,$C0  ; row 45
        fcb     $00,$03,$FF,$EF,$F0  ; row 46
        fcb     $00,$3F,$FF,$FC,$00  ; row 47
