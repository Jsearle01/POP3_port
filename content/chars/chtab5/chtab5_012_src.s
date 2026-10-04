* chtab5_012_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #12 (4x39 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_012_src:
        fcb     39,7  ; height=39 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$0A,$80,$00,$00,$00,$00  ; row 0
        fcb     $00,$0A,$80,$03,$FF,$00,$00  ; row 1
        fcb     $00,$00,$A8,$3F,$FF,$C0,$00  ; row 2
        fcb     $00,$00,$A8,$3F,$FF,$C0,$00  ; row 3
        fcb     $00,$00,$AA,$83,$FF,$C0,$00  ; row 4
        fcb     $00,$00,$0A,$AA,$AF,$00,$00  ; row 5
        fcb     $00,$00,$0A,$AA,$AF,$F0,$00  ; row 6
        fcb     $00,$00,$03,$EA,$AA,$80,$00  ; row 7
        fcb     $00,$00,$00,$FF,$FE,$80,$00  ; row 8
        fcb     $00,$00,$00,$FF,$EA,$80,$00  ; row 9
        fcb     $00,$00,$0A,$FF,$EA,$80,$00  ; row 10
        fcb     $00,$00,$0A,$AA,$AA,$F0,$00  ; row 11
        fcb     $00,$00,$00,$AA,$AF,$C0,$00  ; row 12
        fcb     $00,$00,$00,$AA,$FF,$C0,$00  ; row 13
        fcb     $00,$00,$03,$FF,$FF,$00,$00  ; row 14
        fcb     $00,$00,$03,$FF,$FF,$00,$00  ; row 15
        fcb     $00,$00,$03,$FF,$FF,$00,$00  ; row 16
        fcb     $00,$00,$0F,$FF,$FF,$C0,$00  ; row 17
        fcb     $00,$00,$FF,$FF,$FF,$C0,$00  ; row 18
        fcb     $00,$0F,$FF,$FF,$FF,$C0,$00  ; row 19
        fcb     $00,$FF,$FF,$FF,$FF,$C0,$00  ; row 20
        fcb     $0F,$FF,$FF,$FF,$FF,$C0,$00  ; row 21
        fcb     $FF,$FF,$FF,$FF,$FF,$C0,$00  ; row 22
        fcb     $FF,$FF,$F0,$03,$FF,$F0,$00  ; row 23
        fcb     $7F,$FF,$00,$03,$FF,$F0,$00  ; row 24
        fcb     $7F,$FF,$00,$00,$FF,$F0,$00  ; row 25
        fcb     $0F,$FF,$00,$00,$FF,$F0,$00  ; row 26
        fcb     $0F,$FF,$C0,$00,$FF,$FC,$00  ; row 27
        fcb     $03,$FF,$C0,$00,$3F,$FF,$00  ; row 28
        fcb     $03,$FF,$C0,$00,$3F,$FF,$00  ; row 29
        fcb     $00,$FF,$C0,$00,$0F,$FF,$C0  ; row 30
        fcb     $00,$3F,$C0,$00,$03,$FF,$C0  ; row 31
        fcb     $00,$08,$00,$00,$00,$FF,$C0  ; row 32
        fcb     $00,$0A,$FC,$00,$00,$3F,$C0  ; row 33
        fcb     $00,$0F,$FC,$00,$00,$00,$AF  ; row 34
        fcb     $00,$3F,$F0,$00,$00,$00,$FF  ; row 35
        fcb     $00,$FF,$00,$00,$00,$00,$FF  ; row 36
        fcb     $00,$00,$00,$00,$00,$00,$FC  ; row 37
        fcb     $00,$00,$00,$00,$00,$03,$F0  ; row 38
