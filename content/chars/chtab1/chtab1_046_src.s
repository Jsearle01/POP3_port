* chtab1_046_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB1
*         POP cel: #46 (2x39 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab1_046_src:
        fcb     39,4  ; height=39 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $00,$03,$FF,$00  ; row 0
        fcb     $00,$3F,$FF,$C0  ; row 1
        fcb     $00,$3F,$FF,$C0  ; row 2
        fcb     $00,$00,$0F,$C0  ; row 3
        fcb     $00,$0A,$AF,$C0  ; row 4
        fcb     $00,$0A,$AF,$C0  ; row 5
        fcb     $00,$0A,$AF,$00  ; row 6
        fcb     $03,$FF,$E8,$00  ; row 7
        fcb     $00,$FF,$EF,$C0  ; row 8
        fcb     $0A,$FF,$EF,$F0  ; row 9
        fcb     $0A,$FF,$FF,$C0  ; row 10
        fcb     $0A,$FF,$FF,$C0  ; row 11
        fcb     $0A,$FF,$FF,$00  ; row 12
        fcb     $0A,$FF,$FF,$00  ; row 13
        fcb     $0A,$AF,$FF,$00  ; row 14
        fcb     $0A,$AF,$FF,$C0  ; row 15
        fcb     $00,$AA,$FF,$C0  ; row 16
        fcb     $0F,$EA,$FF,$C0  ; row 17
        fcb     $0F,$FE,$AA,$80  ; row 18
        fcb     $0F,$FF,$EA,$80  ; row 19
        fcb     $0F,$FF,$EA,$80  ; row 20
        fcb     $03,$FF,$FF,$00  ; row 21
        fcb     $03,$FF,$FF,$00  ; row 22
        fcb     $03,$FF,$FF,$00  ; row 23
        fcb     $00,$FF,$FF,$00  ; row 24
        fcb     $00,$FF,$FF,$00  ; row 25
        fcb     $00,$3F,$FF,$C0  ; row 26
        fcb     $00,$0F,$FF,$C0  ; row 27
        fcb     $00,$0F,$FF,$C0  ; row 28
        fcb     $00,$0F,$FF,$00  ; row 29
        fcb     $00,$3F,$FF,$00  ; row 30
        fcb     $00,$3F,$FF,$00  ; row 31
        fcb     $00,$3F,$FF,$00  ; row 32
        fcb     $00,$3F,$00,$00  ; row 33
        fcb     $00,$FF,$00,$00  ; row 34
        fcb     $00,$FF,$00,$00  ; row 35
        fcb     $03,$FF,$00,$00  ; row 36
        fcb     $03,$FF,$C0,$00  ; row 37
        fcb     $00,$FF,$F0,$00  ; row 38
