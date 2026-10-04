* chtab2_056_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #56 (3x23 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_056_src:
        fcb     23,5  ; height=23 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$FF,$00,$00,$00  ; row 0
        fcb     $0F,$FF,$C0,$00,$00  ; row 1
        fcb     $7F,$FF,$F0,$00,$00  ; row 2
        fcb     $0F,$FF,$F0,$00,$00  ; row 3
        fcb     $00,$FF,$F0,$00,$00  ; row 4
        fcb     $00,$AA,$FF,$C0,$00  ; row 5
        fcb     $00,$AF,$FF,$FC,$00  ; row 6
        fcb     $00,$0A,$FF,$FF,$C0  ; row 7
        fcb     $00,$0A,$FF,$FF,$F0  ; row 8
        fcb     $00,$0A,$FF,$FF,$FC  ; row 9
        fcb     $00,$0A,$FF,$FF,$FC  ; row 10
        fcb     $00,$0A,$FF,$FF,$FC  ; row 11
        fcb     $00,$0A,$FF,$FF,$FC  ; row 12
        fcb     $00,$AA,$FF,$FF,$FC  ; row 13
        fcb     $00,$AF,$FF,$FF,$F0  ; row 14
        fcb     $00,$AF,$FF,$FF,$C0  ; row 15
        fcb     $00,$AF,$FF,$00,$00  ; row 16
        fcb     $0A,$AF,$FF,$F0,$00  ; row 17
        fcb     $0A,$AF,$C3,$FF,$00  ; row 18
        fcb     $0A,$80,$03,$FF,$00  ; row 19
        fcb     $00,$00,$03,$FC,$00  ; row 20
        fcb     $00,$00,$03,$F0,$00  ; row 21
        fcb     $00,$00,$0F,$C0,$00  ; row 22
