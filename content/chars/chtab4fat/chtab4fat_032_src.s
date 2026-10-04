* chtab4fat_032_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.FAT
*         POP cel: #32 (5x14 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4fat_032_src:
        fcb     14,9  ; height=14 rows, coco3_width=9 bytes/row (4px/byte)
        fcb     $00,$00,$00,$0F,$FF,$C0,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$FF,$FF,$FC,$00,$00,$00  ; row 1
        fcb     $00,$00,$0F,$FF,$FF,$FF,$00,$00,$00  ; row 2
        fcb     $00,$00,$3F,$FF,$FF,$FF,$C0,$00,$00  ; row 3
        fcb     $00,$00,$FF,$FF,$FF,$FF,$C0,$00,$00  ; row 4
        fcb     $00,$03,$FF,$FF,$FF,$FF,$F0,$00,$00  ; row 5
        fcb     $00,$03,$FF,$FE,$FF,$FF,$F0,$0A,$80  ; row 6
        fcb     $01,$57,$FF,$EA,$AF,$FF,$F0,$0A,$80  ; row 7
        fcb     $15,$7F,$FE,$AA,$AA,$FF,$F5,$57,$C0  ; row 8
        fcb     $10,$FF,$C1,$0A,$81,$7F,$FF,$55,$00  ; row 9
        fcb     $17,$FF,$7F,$FF,$FF,$F7,$FF,$55,$00  ; row 10
        fcb     $17,$FF,$7F,$FF,$FF,$F7,$FF,$00,$00  ; row 11
        fcb     $00,$FF,$7F,$FF,$FF,$F7,$FC,$00,$00  ; row 12
        fcb     $00,$0F,$03,$FF,$FF,$00,$00,$00,$00  ; row 13
