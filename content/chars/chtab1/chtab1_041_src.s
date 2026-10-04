* chtab1_041_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB1
*         POP cel: #41 (8x30 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab1_041_src:
        fcb     30,13  ; height=30 rows, coco3_width=13 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$3F,$F0,$00,$00,$00,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$03,$FF,$FF,$FC,$00,$00,$00,$00,$00,$00  ; row 1
        fcb     $00,$00,$00,$03,$FF,$FF,$FF,$C0,$00,$00,$00,$00,$00  ; row 2
        fcb     $00,$00,$00,$03,$FE,$AF,$FE,$F0,$00,$00,$00,$00,$00  ; row 3
        fcb     $00,$00,$00,$03,$FE,$AF,$EA,$FC,$00,$00,$00,$00,$00  ; row 4
        fcb     $00,$00,$00,$03,$EA,$AF,$EA,$FF,$00,$00,$00,$00,$00  ; row 5
        fcb     $00,$00,$00,$00,$00,$0A,$AA,$FF,$C0,$00,$00,$00,$00  ; row 6
        fcb     $00,$00,$00,$00,$00,$0A,$AF,$FF,$C0,$00,$00,$00,$00  ; row 7
        fcb     $00,$00,$00,$00,$00,$AA,$FF,$FF,$C0,$00,$00,$00,$00  ; row 8
        fcb     $00,$00,$00,$00,$0A,$80,$FF,$FF,$F0,$00,$00,$00,$00  ; row 9
        fcb     $00,$00,$00,$00,$00,$00,$FF,$FF,$F0,$00,$00,$00,$00  ; row 10
        fcb     $00,$00,$00,$00,$00,$00,$FF,$FF,$FC,$00,$00,$00,$00  ; row 11
        fcb     $00,$00,$00,$00,$00,$00,$3F,$FF,$FC,$00,$00,$00,$00  ; row 12
        fcb     $00,$00,$00,$0F,$FF,$FF,$FF,$FF,$FC,$00,$00,$00,$00  ; row 13
        fcb     $00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FC,$00,$00,$00,$00  ; row 14
        fcb     $00,$00,$03,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00  ; row 15
        fcb     $00,$00,$0F,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00  ; row 16
        fcb     $00,$00,$0F,$FF,$00,$0F,$FF,$FF,$FF,$00,$00,$00,$00  ; row 17
        fcb     $00,$00,$3F,$C0,$00,$00,$3F,$FF,$FF,$00,$00,$00,$00  ; row 18
        fcb     $FC,$03,$FC,$00,$00,$00,$0F,$FF,$FF,$00,$00,$00,$00  ; row 19
        fcb     $7F,$FF,$C0,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00  ; row 20
        fcb     $0F,$FC,$00,$00,$00,$00,$00,$3F,$FF,$C0,$00,$00,$00  ; row 21
        fcb     $03,$C0,$00,$00,$00,$00,$00,$0F,$FF,$F0,$00,$00,$00  ; row 22
        fcb     $00,$00,$00,$00,$00,$00,$00,$03,$FF,$FF,$C0,$3C,$00  ; row 23
        fcb     $00,$00,$00,$00,$00,$00,$00,$00,$3F,$FF,$F7,$FF,$00  ; row 24
        fcb     $00,$00,$00,$00,$00,$00,$00,$00,$0F,$FF,$FF,$FF,$C0  ; row 25
        fcb     $00,$00,$00,$00,$00,$00,$00,$00,$03,$FF,$C0,$3F,$F0  ; row 26
        fcb     $00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$00,$00,$FC  ; row 27
        fcb     $00,$00,$00,$00,$00,$00,$00,$00,$00,$08,$00,$00,$3C  ; row 28
        fcb     $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$08  ; row 29
