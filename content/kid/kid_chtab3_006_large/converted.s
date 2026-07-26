* converted.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #6 (5x38 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

kid_chtab3_006_large:
        fcb     38,8  ; height=38 rows, coco3_width=8 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$00,$FF,$C0,$00  ; row 0
        fcb     $00,$00,$00,$00,$03,$FF,$FC,$00  ; row 1
        fcb     $00,$00,$00,$00,$0F,$FF,$FC,$00  ; row 2
        fcb     $00,$00,$00,$00,$0F,$FF,$FC,$00  ; row 3
        fcb     $00,$00,$00,$00,$00,$AF,$FC,$00  ; row 4
        fcb     $00,$00,$00,$00,$00,$AA,$80,$00  ; row 5
        fcb     $00,$00,$00,$00,$00,$0A,$80,$00  ; row 6
        fcb     $00,$00,$00,$00,$00,$03,$FC,$00  ; row 7
        fcb     $00,$00,$00,$00,$00,$0F,$FF,$00  ; row 8
        fcb     $00,$00,$00,$00,$00,$0F,$E8,$00  ; row 9
        fcb     $00,$00,$00,$00,$00,$3F,$E8,$00  ; row 10
        fcb     $00,$00,$00,$00,$00,$3F,$E8,$00  ; row 11
        fcb     $00,$00,$00,$00,$00,$3F,$E8,$00  ; row 12
        fcb     $00,$00,$00,$00,$0A,$AA,$A8,$00  ; row 13
        fcb     $00,$00,$00,$00,$0A,$AA,$A8,$00  ; row 14
        fcb     $00,$00,$00,$00,$00,$FE,$A8,$00  ; row 15
        fcb     $00,$00,$00,$00,$03,$FF,$FC,$00  ; row 16
        fcb     $00,$00,$00,$00,$03,$FF,$FC,$00  ; row 17
        fcb     $00,$00,$00,$00,$0F,$FF,$FC,$00  ; row 18
        fcb     $00,$00,$00,$00,$0F,$FF,$FC,$00  ; row 19
        fcb     $00,$00,$00,$00,$3F,$FF,$FC,$00  ; row 20
        fcb     $00,$00,$00,$00,$3F,$FF,$FC,$00  ; row 21
        fcb     $00,$00,$00,$00,$FF,$FF,$F0,$00  ; row 22
        fcb     $00,$00,$00,$03,$FF,$FF,$C0,$00  ; row 23
        fcb     $00,$00,$00,$0F,$FF,$FF,$00,$00  ; row 24
        fcb     $00,$00,$00,$3F,$FF,$FC,$00,$00  ; row 25
        fcb     $00,$00,$00,$FF,$FF,$C1,$00,$00  ; row 26
        fcb     $00,$00,$03,$FF,$FC,$3F,$00,$00  ; row 27
        fcb     $00,$00,$0F,$FF,$C0,$FF,$C0,$00  ; row 28
        fcb     $00,$00,$3F,$FF,$00,$3F,$F0,$00  ; row 29
        fcb     $00,$00,$FF,$FF,$00,$3F,$FC,$00  ; row 30
        fcb     $00,$00,$FF,$FC,$00,$0F,$FC,$00  ; row 31
        fcb     $00,$00,$FF,$F0,$00,$03,$FF,$C0  ; row 32
        fcb     $0F,$C0,$FF,$00,$00,$00,$FE,$80  ; row 33
        fcb     $03,$FE,$80,$00,$00,$00,$00,$FC  ; row 34
        fcb     $00,$FF,$C0,$00,$00,$00,$03,$FF  ; row 35
        fcb     $00,$3F,$C0,$00,$00,$00,$3F,$FF  ; row 36
        fcb     $00,$00,$00,$00,$00,$00,$00,$00  ; row 37
