* chtab4fat_031_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.FAT
*         POP cel: #31 (5x17 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4fat_031_src:
        fcb     17,8  ; height=17 rows, coco3_width=8 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$00,$00,$00,$15  ; row 0
        fcb     $00,$00,$00,$00,$00,$00,$00,$15  ; row 1
        fcb     $00,$00,$00,$00,$00,$00,$00,$3F  ; row 2
        fcb     $00,$00,$00,$0F,$FF,$C0,$00,$A8  ; row 3
        fcb     $00,$00,$00,$FF,$FF,$FF,$00,$A8  ; row 4
        fcb     $00,$00,$0F,$FF,$FF,$FF,$C0,$A8  ; row 5
        fcb     $00,$00,$0F,$FF,$FF,$FF,$C0,$A8  ; row 6
        fcb     $00,$00,$3F,$FF,$FF,$FF,$FE,$A8  ; row 7
        fcb     $00,$00,$3F,$FF,$FF,$FF,$FE,$A8  ; row 8
        fcb     $00,$00,$3F,$FF,$57,$FF,$FF,$E8  ; row 9
        fcb     $00,$00,$3F,$F5,$08,$03,$FF,$FC  ; row 10
        fcb     $00,$17,$FC,$17,$FF,$F0,$FF,$F0  ; row 11
        fcb     $0A,$AF,$FE,$FF,$FF,$FE,$FF,$F0  ; row 12
        fcb     $0A,$AF,$F7,$FF,$FF,$FE,$FF,$C0  ; row 13
        fcb     $0A,$AF,$F7,$FF,$FF,$FE,$FC,$00  ; row 14
        fcb     $00,$AF,$F7,$FF,$FF,$F7,$C0,$00  ; row 15
        fcb     $00,$00,$3E,$FF,$FF,$00,$00,$00  ; row 16
