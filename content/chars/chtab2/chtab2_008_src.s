* chtab2_008_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #8 (4x33 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_008_src:
        fcb     33,7  ; height=33 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$00,$03,$FC  ; row 0
        fcb     $00,$00,$00,$00,$00,$3F,$FF  ; row 1
        fcb     $00,$00,$00,$00,$80,$3F,$FF  ; row 2
        fcb     $00,$00,$00,$00,$AF,$EF,$FF  ; row 3
        fcb     $00,$00,$00,$0A,$AF,$EA,$FC  ; row 4
        fcb     $00,$00,$00,$A8,$0A,$AA,$80  ; row 5
        fcb     $00,$00,$0A,$80,$FE,$A8,$00  ; row 6
        fcb     $00,$00,$08,$03,$FE,$AF,$C0  ; row 7
        fcb     $00,$00,$A8,$3F,$FF,$EA,$80  ; row 8
        fcb     $00,$00,$80,$FF,$FF,$EA,$80  ; row 9
        fcb     $00,$00,$03,$FF,$FF,$C0,$80  ; row 10
        fcb     $00,$00,$0F,$FF,$FF,$00,$00  ; row 11
        fcb     $00,$00,$3F,$FF,$FC,$00,$00  ; row 12
        fcb     $00,$00,$3F,$FF,$F0,$00,$00  ; row 13
        fcb     $00,$00,$FF,$FF,$FC,$00,$00  ; row 14
        fcb     $00,$00,$FF,$FF,$FF,$00,$00  ; row 15
        fcb     $00,$03,$FF,$FF,$FF,$C0,$00  ; row 16
        fcb     $00,$03,$FF,$FF,$FF,$F0,$00  ; row 17
        fcb     $00,$0F,$FF,$FF,$FF,$F0,$00  ; row 18
        fcb     $00,$0F,$FF,$FF,$FF,$FC,$00  ; row 19
        fcb     $00,$3F,$FF,$C3,$FF,$FC,$00  ; row 20
        fcb     $00,$3F,$FF,$00,$FF,$FC,$00  ; row 21
        fcb     $00,$FF,$FC,$00,$3F,$FC,$00  ; row 22
        fcb     $03,$FF,$F0,$00,$3F,$FC,$00  ; row 23
        fcb     $03,$FF,$00,$00,$3F,$F0,$00  ; row 24
        fcb     $0F,$FC,$00,$00,$FF,$F0,$00  ; row 25
        fcb     $7F,$F0,$00,$00,$FF,$C0,$00  ; row 26
        fcb     $7F,$C0,$00,$00,$FF,$00,$00  ; row 27
        fcb     $7F,$00,$00,$00,$08,$00,$00  ; row 28
        fcb     $FC,$00,$00,$00,$0F,$00,$00  ; row 29
        fcb     $FC,$00,$00,$00,$3F,$C0,$00  ; row 30
        fcb     $F0,$00,$00,$00,$0F,$F0,$00  ; row 31
        fcb     $00,$00,$00,$00,$00,$FC,$00  ; row 32
