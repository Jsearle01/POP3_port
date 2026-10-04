* chtab3_025_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #25 (4x28 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_025_src:
        fcb     28,7  ; height=28 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $0F,$FC,$00,$00,$00,$00,$00  ; row 0
        fcb     $FF,$FF,$00,$3F,$FF,$FF,$00  ; row 1
        fcb     $FF,$FF,$7F,$FF,$FF,$FF,$C0  ; row 2
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$F0  ; row 3
        fcb     $FE,$AF,$EA,$FF,$FF,$FF,$F0  ; row 4
        fcb     $FE,$AF,$EA,$FF,$FF,$FF,$FC  ; row 5
        fcb     $80,$00,$AA,$FF,$FF,$FF,$F0  ; row 6
        fcb     $00,$00,$A8,$3F,$F7,$FF,$F0  ; row 7
        fcb     $00,$00,$A8,$00,$17,$FF,$F0  ; row 8
        fcb     $00,$00,$A8,$00,$3F,$FF,$C0  ; row 9
        fcb     $00,$00,$AA,$80,$FF,$FF,$C0  ; row 10
        fcb     $00,$00,$AA,$80,$FF,$FF,$00  ; row 11
        fcb     $00,$00,$AA,$80,$FF,$FF,$00  ; row 12
        fcb     $00,$00,$AA,$83,$FF,$FC,$00  ; row 13
        fcb     $00,$00,$80,$83,$FF,$FC,$00  ; row 14
        fcb     $00,$00,$80,$83,$FF,$FC,$00  ; row 15
        fcb     $00,$00,$80,$83,$FF,$FC,$00  ; row 16
        fcb     $00,$00,$80,$83,$FF,$FC,$00  ; row 17
        fcb     $00,$00,$80,$03,$FF,$FF,$00  ; row 18
        fcb     $00,$00,$80,$03,$FF,$FF,$00  ; row 19
        fcb     $00,$00,$80,$00,$FF,$FF,$C0  ; row 20
        fcb     $00,$00,$80,$00,$3F,$FF,$C0  ; row 21
        fcb     $00,$00,$00,$00,$3F,$FF,$C0  ; row 22
        fcb     $00,$00,$00,$00,$3F,$FF,$F0  ; row 23
        fcb     $00,$00,$00,$00,$3F,$FF,$F0  ; row 24
        fcb     $00,$00,$00,$00,$FF,$FF,$F0  ; row 25
        fcb     $00,$00,$00,$03,$FF,$00,$00  ; row 26
        fcb     $00,$00,$00,$3F,$F0,$00,$00  ; row 27
