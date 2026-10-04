* chtab4viz_027_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.VIZ
*         POP cel: #27 (2x38 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4viz_027_src:
        fcb     38,4  ; height=38 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $0F,$FF,$00,$00  ; row 0
        fcb     $FF,$FF,$F0,$00  ; row 1
        fcb     $FF,$FF,$FC,$00  ; row 2
        fcb     $0F,$FF,$FF,$00  ; row 3
        fcb     $00,$3F,$FF,$00  ; row 4
        fcb     $01,$7F,$FC,$00  ; row 5
        fcb     $0F,$7F,$00,$00  ; row 6
        fcb     $0F,$FF,$C0,$00  ; row 7
        fcb     $FF,$FF,$F0,$00  ; row 8
        fcb     $7F,$FF,$F0,$00  ; row 9
        fcb     $7F,$FF,$F0,$00  ; row 10
        fcb     $7F,$FF,$FC,$00  ; row 11
        fcb     $7F,$FF,$FC,$00  ; row 12
        fcb     $0A,$AF,$FC,$00  ; row 13
        fcb     $0A,$83,$FF,$00  ; row 14
        fcb     $0A,$83,$FF,$00  ; row 15
        fcb     $0A,$83,$FF,$00  ; row 16
        fcb     $0A,$AF,$FF,$00  ; row 17
        fcb     $0A,$AA,$FF,$00  ; row 18
        fcb     $0A,$AA,$FF,$00  ; row 19
        fcb     $01,$7E,$FF,$C0  ; row 20
        fcb     $01,$7E,$FF,$C0  ; row 21
        fcb     $01,$7E,$FF,$C0  ; row 22
        fcb     $00,$AA,$FF,$C0  ; row 23
        fcb     $00,$AA,$FF,$C0  ; row 24
        fcb     $00,$AA,$FF,$C0  ; row 25
        fcb     $00,$AA,$FF,$C0  ; row 26
        fcb     $00,$AA,$FF,$00  ; row 27
        fcb     $0A,$AA,$FF,$00  ; row 28
        fcb     $0A,$AA,$FF,$00  ; row 29
        fcb     $0A,$AA,$FF,$00  ; row 30
        fcb     $0A,$AA,$AF,$C0  ; row 31
        fcb     $00,$AA,$AF,$C0  ; row 32
        fcb     $00,$AA,$AF,$C0  ; row 33
        fcb     $00,$0A,$A8,$00  ; row 34
        fcb     $00,$03,$FC,$00  ; row 35
        fcb     $00,$3F,$FF,$00  ; row 36
        fcb     $00,$0F,$FF,$00  ; row 37
