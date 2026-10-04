* chtab2_014_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #14 (7x12 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_014_src:
        fcb     12,12  ; height=12 rows, coco3_width=12 bytes/row (4px/byte)
        fcb     $00,$00,$00,$0A,$80,$00,$00,$00,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$03,$EA,$80,$00,$00,$00,$00,$00,$00,$00  ; row 1
        fcb     $00,$00,$03,$FE,$A8,$00,$00,$3F,$00,$00,$00,$00  ; row 2
        fcb     $00,$00,$0F,$FF,$EA,$80,$00,$3F,$F0,$00,$00,$00  ; row 3
        fcb     $03,$FF,$FF,$FF,$EA,$80,$03,$FF,$FC,$00,$00,$00  ; row 4
        fcb     $0F,$FE,$AF,$FF,$EA,$80,$0F,$FF,$FC,$00,$00,$00  ; row 5
        fcb     $FF,$FE,$AF,$FE,$AA,$80,$0F,$FF,$FF,$C0,$00,$00  ; row 6
        fcb     $FF,$EA,$AA,$FE,$AA,$AA,$AF,$FF,$FF,$EA,$FF,$00  ; row 7
        fcb     $FF,$EA,$AF,$FE,$AA,$AA,$AF,$FF,$FF,$EA,$FF,$00  ; row 8
        fcb     $7F,$EA,$AF,$FE,$AA,$AA,$AF,$FF,$FF,$FE,$AF,$FC  ; row 9
        fcb     $00,$00,$00,$0A,$AF,$FE,$A8,$0F,$FF,$FE,$AF,$FC  ; row 10
        fcb     $00,$00,$0A,$AA,$AA,$80,$AA,$80,$00,$00,$00,$00  ; row 11
