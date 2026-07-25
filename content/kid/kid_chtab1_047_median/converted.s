* converted.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB1
*         POP cel: #47 (3x40 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

kid_chtab1_047_median:
        fcb     40,5  ; height=40 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$FF,$C0,$00,$00  ; row 0
        fcb     $00,$FF,$C0,$00,$00  ; row 1
        fcb     $00,$FF,$00,$00,$00  ; row 2
        fcb     $00,$3F,$00,$00,$00  ; row 3
        fcb     $00,$3F,$00,$00,$00  ; row 4
        fcb     $00,$0F,$50,$00,$00  ; row 5
        fcb     $00,$0F,$FC,$00,$00  ; row 6
        fcb     $00,$3F,$FF,$00,$00  ; row 7
        fcb     $00,$FF,$FF,$C0,$00  ; row 8
        fcb     $00,$FF,$FF,$C0,$00  ; row 9
        fcb     $00,$FF,$FF,$F0,$00  ; row 10
        fcb     $00,$FF,$FF,$F0,$00  ; row 11
        fcb     $03,$FF,$FF,$F0,$00  ; row 12
        fcb     $03,$FF,$FF,$F0,$00  ; row 13
        fcb     $03,$FF,$FF,$F0,$00  ; row 14
        fcb     $03,$FF,$FF,$F0,$00  ; row 15
        fcb     $03,$FF,$FF,$F0,$00  ; row 16
        fcb     $03,$FF,$FF,$F0,$00  ; row 17
        fcb     $03,$FF,$FF,$F0,$00  ; row 18
        fcb     $03,$FF,$FF,$F0,$00  ; row 19
        fcb     $03,$FF,$FF,$F0,$00  ; row 20
        fcb     $03,$FF,$FE,$80,$00  ; row 21
        fcb     $00,$FF,$FE,$A8,$00  ; row 22
        fcb     $00,$FE,$AF,$EA,$80  ; row 23
        fcb     $00,$AA,$AF,$FE,$80  ; row 24
        fcb     $00,$AA,$FF,$F0,$80  ; row 25
        fcb     $0A,$AF,$FF,$F0,$80  ; row 26
        fcb     $0A,$FF,$FF,$F0,$80  ; row 27
        fcb     $0A,$FF,$FF,$FE,$80  ; row 28
        fcb     $0A,$FF,$FF,$FE,$80  ; row 29
        fcb     $0A,$FF,$FF,$FE,$80  ; row 30
        fcb     $00,$FF,$EF,$FC,$00  ; row 31
        fcb     $00,$FF,$EF,$FC,$00  ; row 32
        fcb     $00,$0A,$A8,$00,$00  ; row 33
        fcb     $00,$0A,$AF,$00,$00  ; row 34
        fcb     $00,$0A,$AF,$C0,$00  ; row 35
        fcb     $00,$03,$FF,$C0,$00  ; row 36
        fcb     $00,$3F,$FF,$C0,$00  ; row 37
        fcb     $00,$3F,$FF,$C0,$00  ; row 38
        fcb     $00,$03,$FF,$00,$00  ; row 39
