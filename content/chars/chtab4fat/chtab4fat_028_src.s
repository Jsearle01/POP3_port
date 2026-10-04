* chtab4fat_028_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.FAT
*         POP cel: #28 (3x35 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4fat_028_src:
        fcb     35,5  ; height=35 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$FF,$C0,$00,$00  ; row 0
        fcb     $0F,$FF,$FF,$00,$00  ; row 1
        fcb     $0F,$FF,$FF,$C0,$00  ; row 2
        fcb     $03,$FF,$FF,$C0,$00  ; row 3
        fcb     $0A,$FF,$FF,$C0,$00  ; row 4
        fcb     $00,$3F,$FF,$00,$00  ; row 5
        fcb     $01,$7F,$FC,$00,$00  ; row 6
        fcb     $01,$57,$F0,$00,$00  ; row 7
        fcb     $0F,$FF,$F0,$00,$00  ; row 8
        fcb     $00,$FF,$FC,$00,$00  ; row 9
        fcb     $03,$FF,$FF,$00,$00  ; row 10
        fcb     $0F,$FF,$FF,$00,$00  ; row 11
        fcb     $0F,$FF,$FF,$C0,$00  ; row 12
        fcb     $7F,$FF,$FF,$F0,$00  ; row 13
        fcb     $7F,$EA,$83,$F0,$00  ; row 14
        fcb     $7F,$EA,$AF,$FC,$00  ; row 15
        fcb     $FF,$EA,$AF,$FC,$00  ; row 16
        fcb     $FF,$EA,$AF,$50,$00  ; row 17
        fcb     $15,$0A,$81,$55,$00  ; row 18
        fcb     $15,$08,$17,$FF,$00  ; row 19
        fcb     $AF,$0A,$FF,$FF,$00  ; row 20
        fcb     $A8,$15,$0F,$FF,$00  ; row 21
        fcb     $A8,$15,$0A,$FF,$00  ; row 22
        fcb     $A8,$15,$0A,$FF,$00  ; row 23
        fcb     $AA,$AA,$A8,$3C,$00  ; row 24
        fcb     $AA,$AA,$AA,$FC,$00  ; row 25
        fcb     $AA,$AA,$83,$FF,$00  ; row 26
        fcb     $AA,$AA,$AF,$FF,$F0  ; row 27
        fcb     $AA,$AA,$83,$FF,$C0  ; row 28
        fcb     $AA,$AA,$80,$3F,$00  ; row 29
        fcb     $0A,$AA,$A8,$00,$00  ; row 30
        fcb     $0A,$AA,$A8,$00,$00  ; row 31
        fcb     $00,$0A,$FC,$00,$00  ; row 32
        fcb     $00,$3F,$FF,$00,$00  ; row 33
        fcb     $00,$FF,$FF,$00,$00  ; row 34
