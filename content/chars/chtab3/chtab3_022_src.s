* chtab3_022_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #22 (5x24 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_022_src:
        fcb     24,8  ; height=24 rows, coco3_width=8 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$FF,$FF,$00,$00  ; row 0
        fcb     $00,$00,$00,$3F,$FF,$FF,$C0,$00  ; row 1
        fcb     $00,$00,$03,$FF,$F7,$FF,$C0,$00  ; row 2
        fcb     $00,$00,$0F,$FF,$FF,$FF,$C0,$00  ; row 3
        fcb     $00,$00,$FF,$FE,$FF,$FF,$C0,$00  ; row 4
        fcb     $7F,$FF,$EA,$83,$FF,$FF,$00,$00  ; row 5
        fcb     $7F,$FF,$EA,$AF,$FF,$FC,$00,$00  ; row 6
        fcb     $FF,$EA,$AA,$FF,$FF,$C0,$00,$00  ; row 7
        fcb     $FF,$E8,$0A,$FF,$FC,$00,$00,$00  ; row 8
        fcb     $FE,$A8,$0A,$AF,$FC,$00,$00,$00  ; row 9
        fcb     $FC,$00,$0A,$AF,$FF,$00,$00,$00  ; row 10
        fcb     $80,$00,$0A,$83,$FF,$C0,$00,$00  ; row 11
        fcb     $00,$00,$08,$0A,$FF,$F0,$00,$00  ; row 12
        fcb     $00,$00,$08,$08,$3F,$F0,$00,$00  ; row 13
        fcb     $00,$00,$08,$08,$0F,$C0,$00,$00  ; row 14
        fcb     $00,$00,$08,$08,$00,$AF,$00,$00  ; row 15
        fcb     $00,$00,$08,$00,$80,$FF,$C0,$00  ; row 16
        fcb     $00,$00,$08,$00,$83,$FC,$3F,$00  ; row 17
        fcb     $00,$00,$A8,$00,$AF,$C0,$FF,$FC  ; row 18
        fcb     $00,$00,$00,$00,$00,$00,$3E,$FC  ; row 19
        fcb     $00,$00,$00,$00,$00,$00,$03,$FC  ; row 20
        fcb     $00,$00,$00,$00,$00,$00,$03,$F0  ; row 21
        fcb     $00,$00,$00,$00,$00,$00,$03,$F0  ; row 22
        fcb     $00,$00,$00,$00,$00,$00,$03,$F0  ; row 23
