* chtab2_015_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #15 (6x27 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_015_src:
        fcb     27,11  ; height=27 rows, coco3_width=11 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$00,$03,$FF,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$00,$00,$FF,$EA,$80,$00,$00,$00  ; row 1
        fcb     $00,$00,$00,$00,$3F,$EF,$EA,$F0,$00,$00,$00  ; row 2
        fcb     $00,$00,$00,$00,$FF,$FE,$AA,$FC,$00,$00,$00  ; row 3
        fcb     $00,$00,$00,$03,$FF,$FE,$AA,$FC,$00,$00,$00  ; row 4
        fcb     $00,$00,$00,$03,$FF,$FE,$AA,$FC,$00,$00,$00  ; row 5
        fcb     $00,$00,$00,$03,$FF,$FE,$AA,$FF,$00,$00,$00  ; row 6
        fcb     $00,$00,$00,$00,$FF,$F7,$EA,$FF,$00,$00,$00  ; row 7
        fcb     $00,$00,$00,$00,$3F,$EF,$EA,$FF,$C0,$00,$00  ; row 8
        fcb     $00,$00,$00,$00,$0A,$AF,$EA,$FF,$C0,$00,$00  ; row 9
        fcb     $00,$00,$00,$00,$0A,$83,$EA,$FF,$C0,$00,$00  ; row 10
        fcb     $00,$00,$00,$00,$0A,$83,$EA,$FF,$C0,$00,$00  ; row 11
        fcb     $00,$00,$00,$00,$0A,$FF,$EA,$FF,$F0,$00,$00  ; row 12
        fcb     $00,$00,$00,$00,$3F,$FF,$EA,$FF,$F0,$00,$00  ; row 13
        fcb     $00,$00,$00,$0F,$FF,$FF,$EA,$FF,$F0,$00,$00  ; row 14
        fcb     $00,$00,$00,$3F,$FF,$FF,$EA,$FF,$F0,$00,$00  ; row 15
        fcb     $00,$00,$03,$FF,$FF,$FF,$EA,$FF,$F0,$10,$00  ; row 16
        fcb     $00,$00,$03,$FF,$FF,$C0,$AA,$FF,$F0,$FC,$00  ; row 17
        fcb     $00,$00,$03,$FF,$E8,$00,$0A,$FF,$F0,$FF,$C0  ; row 18
        fcb     $00,$00,$0A,$FC,$08,$00,$0A,$FF,$F0,$80,$80  ; row 19
        fcb     $01,$00,$A8,$00,$08,$00,$0A,$FF,$FF,$C0,$00  ; row 20
        fcb     $03,$FF,$F0,$00,$08,$00,$03,$FF,$FF,$C0,$00  ; row 21
        fcb     $00,$FF,$C0,$00,$00,$00,$00,$FF,$FF,$C0,$00  ; row 22
        fcb     $00,$3F,$C0,$00,$00,$00,$00,$FF,$FF,$C0,$00  ; row 23
        fcb     $00,$00,$00,$00,$00,$00,$00,$3F,$FF,$00,$00  ; row 24
        fcb     $00,$00,$00,$00,$00,$00,$00,$0F,$FC,$00,$00  ; row 25
        fcb     $00,$00,$00,$00,$00,$00,$00,$03,$F0,$00,$00  ; row 26
