* chtab3_021_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #21 (5x20 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_021_src:
        fcb     20,8  ; height=20 rows, coco3_width=8 bytes/row (4px/byte)
        fcb     $00,$00,$00,$3F,$FF,$FF,$00,$00  ; row 0
        fcb     $00,$FF,$EF,$FF,$FE,$FF,$C0,$00  ; row 1
        fcb     $03,$FF,$FE,$AF,$F7,$FF,$F0,$00  ; row 2
        fcb     $0F,$FF,$FE,$AA,$AF,$FF,$F0,$00  ; row 3
        fcb     $0F,$FE,$AA,$AA,$AF,$FF,$C0,$00  ; row 4
        fcb     $0F,$EA,$AF,$EA,$83,$FF,$C0,$00  ; row 5
        fcb     $0F,$EA,$80,$3E,$AA,$FF,$C0,$00  ; row 6
        fcb     $0F,$00,$00,$0A,$A8,$3F,$F0,$00  ; row 7
        fcb     $08,$00,$00,$0A,$81,$03,$F0,$00  ; row 8
        fcb     $00,$00,$00,$0A,$AF,$C0,$FC,$00  ; row 9
        fcb     $00,$00,$00,$08,$3F,$F0,$FF,$00  ; row 10
        fcb     $00,$00,$00,$AA,$FF,$C0,$3F,$00  ; row 11
        fcb     $00,$00,$00,$AA,$FF,$C0,$FC,$00  ; row 12
        fcb     $00,$00,$0A,$83,$FF,$FF,$F7,$C0  ; row 13
        fcb     $00,$00,$08,$03,$FF,$FF,$EF,$C0  ; row 14
        fcb     $00,$00,$A8,$00,$00,$00,$3F,$FC  ; row 15
        fcb     $00,$00,$80,$00,$00,$00,$00,$FC  ; row 16
        fcb     $00,$00,$00,$00,$00,$00,$00,$FC  ; row 17
        fcb     $00,$00,$00,$00,$00,$00,$00,$3C  ; row 18
        fcb     $00,$00,$00,$00,$00,$00,$00,$3C  ; row 19
