* chtab4viz_029_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.VIZ
*         POP cel: #29 (4x31 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4viz_029_src:
        fcb     31,6  ; height=31 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $03,$FF,$C0,$00,$00,$00  ; row 0
        fcb     $7F,$FF,$FC,$00,$00,$00  ; row 1
        fcb     $7F,$FF,$FF,$00,$00,$00  ; row 2
        fcb     $03,$FF,$FF,$C0,$00,$00  ; row 3
        fcb     $00,$0F,$FF,$C0,$00,$00  ; row 4
        fcb     $01,$7F,$FF,$00,$00,$00  ; row 5
        fcb     $0F,$7F,$C0,$00,$00,$00  ; row 6
        fcb     $0F,$FF,$C0,$00,$00,$00  ; row 7
        fcb     $7F,$7F,$FC,$00,$00,$00  ; row 8
        fcb     $00,$FF,$FF,$00,$00,$00  ; row 9
        fcb     $03,$FF,$FF,$C0,$00,$00  ; row 10
        fcb     $00,$AA,$FF,$F0,$00,$00  ; row 11
        fcb     $00,$AA,$FF,$F0,$00,$00  ; row 12
        fcb     $00,$AA,$FF,$F0,$00,$00  ; row 13
        fcb     $00,$AA,$FF,$F0,$00,$00  ; row 14
        fcb     $00,$A8,$3F,$F0,$00,$00  ; row 15
        fcb     $03,$EA,$AF,$F0,$00,$00  ; row 16
        fcb     $17,$EA,$AF,$FC,$00,$00  ; row 17
        fcb     $10,$0A,$AF,$FF,$C0,$00  ; row 18
        fcb     $00,$0A,$AF,$FF,$C0,$00  ; row 19
        fcb     $00,$0A,$AF,$FF,$FC,$00  ; row 20
        fcb     $00,$0A,$AF,$FF,$FF,$F0  ; row 21
        fcb     $00,$01,$7F,$FF,$FF,$C0  ; row 22
        fcb     $00,$01,$7E,$FF,$FF,$00  ; row 23
        fcb     $00,$81,$7E,$FF,$F0,$00  ; row 24
        fcb     $00,$81,$7E,$FF,$C0,$00  ; row 25
        fcb     $00,$AA,$AA,$A8,$00,$00  ; row 26
        fcb     $00,$AA,$AA,$80,$00,$00  ; row 27
        fcb     $00,$AA,$AA,$80,$00,$00  ; row 28
        fcb     $00,$AA,$AA,$F0,$00,$00  ; row 29
        fcb     $00,$0A,$80,$00,$00,$00  ; row 30
