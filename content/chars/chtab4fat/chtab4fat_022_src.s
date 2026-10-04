* chtab4fat_022_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.FAT
*         POP cel: #22 (4x39 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4fat_022_src:
        fcb     39,7  ; height=39 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$0F,$FC,$00,$00,$00  ; row 0
        fcb     $00,$00,$FF,$FF,$F0,$00,$00  ; row 1
        fcb     $00,$00,$FF,$FF,$FC,$00,$00  ; row 2
        fcb     $00,$00,$3F,$FF,$FC,$00,$00  ; row 3
        fcb     $00,$00,$AF,$FF,$FC,$00,$00  ; row 4
        fcb     $00,$00,$03,$FF,$F0,$00,$00  ; row 5
        fcb     $00,$00,$17,$FF,$C0,$00,$00  ; row 6
        fcb     $00,$00,$15,$7F,$C0,$00,$00  ; row 7
        fcb     $00,$00,$FF,$FF,$C0,$00,$00  ; row 8
        fcb     $00,$00,$3F,$FF,$FC,$00,$00  ; row 9
        fcb     $00,$03,$FF,$FF,$FF,$00,$00  ; row 10
        fcb     $00,$0F,$EF,$FF,$FF,$00,$00  ; row 11
        fcb     $00,$AA,$AF,$FF,$FF,$C0,$00  ; row 12
        fcb     $17,$EA,$AA,$FF,$FF,$C0,$00  ; row 13
        fcb     $17,$EA,$AA,$FF,$FF,$00,$00  ; row 14
        fcb     $00,$0A,$AF,$FF,$F5,$00,$00  ; row 15
        fcb     $00,$3F,$FF,$F5,$57,$F0,$00  ; row 16
        fcb     $00,$3F,$F5,$57,$FF,$F0,$00  ; row 17
        fcb     $00,$15,$57,$FF,$FF,$F0,$00  ; row 18
        fcb     $00,$10,$AA,$AF,$FF,$F0,$00  ; row 19
        fcb     $00,$0A,$AA,$AA,$FF,$F0,$00  ; row 20
        fcb     $00,$0A,$AA,$AA,$FF,$F0,$00  ; row 21
        fcb     $00,$0A,$AA,$AA,$FF,$F0,$00  ; row 22
        fcb     $00,$0A,$AA,$AA,$AF,$C0,$00  ; row 23
        fcb     $00,$0A,$AA,$AA,$AF,$C0,$00  ; row 24
        fcb     $00,$00,$AA,$AA,$AF,$C0,$00  ; row 25
        fcb     $00,$00,$AA,$AA,$AF,$00,$00  ; row 26
        fcb     $00,$00,$AA,$AA,$A8,$00,$00  ; row 27
        fcb     $00,$00,$AA,$AA,$AA,$80,$00  ; row 28
        fcb     $00,$00,$AA,$AA,$AA,$AF,$00  ; row 29
        fcb     $00,$00,$0A,$AA,$AA,$AF,$F0  ; row 30
        fcb     $00,$00,$0A,$AA,$AA,$AF,$FF  ; row 31
        fcb     $00,$00,$0A,$AA,$AA,$83,$FF  ; row 32
        fcb     $00,$00,$00,$AA,$A8,$00,$FF  ; row 33
        fcb     $00,$00,$00,$0F,$C0,$00,$FC  ; row 34
        fcb     $00,$00,$00,$3F,$F0,$00,$3C  ; row 35
        fcb     $00,$00,$00,$FF,$C0,$00,$10  ; row 36
        fcb     $00,$00,$00,$FF,$00,$00,$00  ; row 37
        fcb     $00,$00,$03,$F0,$00,$00,$00  ; row 38
