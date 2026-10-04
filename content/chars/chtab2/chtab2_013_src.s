* chtab2_013_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #13 (4x37 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_013_src:
        fcb     37,7  ; height=37 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$03,$FF,$00  ; row 0
        fcb     $00,$00,$00,$00,$0F,$FF,$F0  ; row 1
        fcb     $00,$00,$00,$00,$0F,$FF,$F0  ; row 2
        fcb     $00,$00,$00,$00,$0F,$FF,$00  ; row 3
        fcb     $00,$00,$00,$00,$0F,$EA,$80  ; row 4
        fcb     $00,$00,$00,$00,$03,$EA,$80  ; row 5
        fcb     $00,$00,$00,$00,$00,$AA,$80  ; row 6
        fcb     $00,$00,$00,$03,$FF,$E8,$00  ; row 7
        fcb     $00,$00,$00,$0A,$AF,$EF,$C0  ; row 8
        fcb     $00,$00,$00,$3E,$AF,$FF,$00  ; row 9
        fcb     $00,$00,$00,$FE,$AF,$FC,$00  ; row 10
        fcb     $00,$00,$03,$FE,$AA,$80,$A8  ; row 11
        fcb     $00,$00,$0F,$FF,$EA,$AA,$A8  ; row 12
        fcb     $00,$00,$3F,$FF,$EA,$80,$00  ; row 13
        fcb     $00,$00,$FF,$FF,$00,$80,$00  ; row 14
        fcb     $00,$00,$FF,$FF,$C0,$80,$00  ; row 15
        fcb     $00,$00,$FF,$FF,$C0,$80,$00  ; row 16
        fcb     $00,$03,$FF,$FF,$F0,$80,$00  ; row 17
        fcb     $00,$03,$FF,$FF,$FE,$80,$00  ; row 18
        fcb     $00,$03,$FF,$FF,$FE,$80,$00  ; row 19
        fcb     $00,$0F,$FF,$FF,$FF,$00,$00  ; row 20
        fcb     $00,$0F,$FF,$FF,$FF,$00,$00  ; row 21
        fcb     $00,$3F,$FF,$0F,$FF,$C0,$00  ; row 22
        fcb     $00,$3F,$FF,$0F,$FF,$C0,$00  ; row 23
        fcb     $00,$FF,$FC,$3F,$FF,$00,$00  ; row 24
        fcb     $00,$FF,$F0,$FF,$FC,$00,$00  ; row 25
        fcb     $03,$FF,$F0,$FF,$F0,$00,$00  ; row 26
        fcb     $0F,$FF,$EF,$C3,$C0,$00,$00  ; row 27
        fcb     $0F,$FF,$7F,$C0,$00,$00,$00  ; row 28
        fcb     $0F,$FC,$0F,$C0,$00,$00,$00  ; row 29
        fcb     $0F,$F0,$0F,$C0,$00,$00,$00  ; row 30
        fcb     $0F,$00,$03,$C0,$00,$00,$00  ; row 31
        fcb     $FC,$00,$00,$80,$00,$00,$00  ; row 32
        fcb     $FF,$00,$00,$00,$00,$00,$00  ; row 33
        fcb     $FF,$00,$00,$00,$00,$00,$00  ; row 34
        fcb     $FF,$00,$00,$00,$00,$00,$00  ; row 35
        fcb     $0F,$C0,$00,$00,$00,$00,$00  ; row 36
