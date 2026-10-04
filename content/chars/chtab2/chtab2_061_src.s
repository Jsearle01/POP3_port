* chtab2_061_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #61 (4x26 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_061_src:
        fcb     26,6  ; height=26 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $0F,$FF,$00,$00,$00,$00  ; row 0
        fcb     $FF,$FF,$C0,$00,$00,$00  ; row 1
        fcb     $FF,$FE,$80,$00,$00,$00  ; row 2
        fcb     $0F,$C0,$FF,$00,$00,$00  ; row 3
        fcb     $0A,$AF,$FF,$FC,$00,$00  ; row 4
        fcb     $08,$3F,$FF,$FF,$F0,$00  ; row 5
        fcb     $08,$3E,$FF,$FF,$FF,$00  ; row 6
        fcb     $00,$0A,$FF,$FF,$FF,$C0  ; row 7
        fcb     $00,$0A,$AF,$FF,$FF,$F0  ; row 8
        fcb     $00,$0A,$83,$FF,$FF,$FC  ; row 9
        fcb     $00,$00,$80,$FF,$FF,$FC  ; row 10
        fcb     $00,$00,$80,$FF,$FF,$FC  ; row 11
        fcb     $00,$00,$80,$FF,$FF,$F0  ; row 12
        fcb     $00,$00,$83,$FF,$FF,$F0  ; row 13
        fcb     $00,$00,$AF,$FF,$FF,$C0  ; row 14
        fcb     $00,$00,$AF,$FF,$FF,$00  ; row 15
        fcb     $00,$00,$AF,$FF,$FF,$C0  ; row 16
        fcb     $00,$00,$AF,$FF,$FF,$C0  ; row 17
        fcb     $00,$00,$AF,$FF,$FF,$C0  ; row 18
        fcb     $00,$00,$AF,$FF,$FF,$F0  ; row 19
        fcb     $00,$00,$83,$FF,$FF,$FC  ; row 20
        fcb     $00,$00,$00,$FF,$FF,$FC  ; row 21
        fcb     $00,$00,$00,$10,$0F,$FC  ; row 22
        fcb     $00,$00,$00,$00,$0F,$F0  ; row 23
        fcb     $00,$00,$00,$00,$0F,$C0  ; row 24
        fcb     $00,$00,$00,$00,$0F,$00  ; row 25
