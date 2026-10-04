* chtab2_041_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #41 (2x57 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_041_src:
        fcb     57,3  ; height=57 rows, coco3_width=3 bytes/row (4px/byte)
        fcb     $00,$00,$00  ; row 0
        fcb     $00,$08,$00  ; row 1
        fcb     $00,$08,$00  ; row 2
        fcb     $00,$08,$00  ; row 3
        fcb     $00,$08,$00  ; row 4
        fcb     $00,$08,$00  ; row 5
        fcb     $00,$08,$00  ; row 6
        fcb     $00,$08,$00  ; row 7
        fcb     $00,$08,$00  ; row 8
        fcb     $00,$08,$00  ; row 9
        fcb     $00,$08,$00  ; row 10
        fcb     $00,$08,$00  ; row 11
        fcb     $00,$0A,$F0  ; row 12
        fcb     $00,$0A,$FC  ; row 13
        fcb     $00,$AA,$FF  ; row 14
        fcb     $00,$AA,$FF  ; row 15
        fcb     $00,$AA,$FF  ; row 16
        fcb     $00,$AA,$FC  ; row 17
        fcb     $00,$0A,$80  ; row 18
        fcb     $00,$0A,$A8  ; row 19
        fcb     $00,$FE,$AF  ; row 20
        fcb     $03,$FE,$AF  ; row 21
        fcb     $03,$FF,$FF  ; row 22
        fcb     $0F,$FF,$FF  ; row 23
        fcb     $0F,$FF,$FC  ; row 24
        fcb     $0F,$FF,$F0  ; row 25
        fcb     $0F,$FF,$F0  ; row 26
        fcb     $0F,$FF,$F0  ; row 27
        fcb     $0F,$FF,$F0  ; row 28
        fcb     $0F,$FF,$FC  ; row 29
        fcb     $0F,$FF,$FC  ; row 30
        fcb     $0F,$FF,$FC  ; row 31
        fcb     $0F,$FF,$F0  ; row 32
        fcb     $7F,$FF,$F0  ; row 33
        fcb     $7F,$FF,$F0  ; row 34
        fcb     $7F,$FF,$F0  ; row 35
        fcb     $7F,$FF,$F0  ; row 36
        fcb     $7F,$FF,$F0  ; row 37
        fcb     $7F,$FF,$F0  ; row 38
        fcb     $7F,$FF,$F0  ; row 39
        fcb     $7F,$FF,$F0  ; row 40
        fcb     $7F,$FF,$F0  ; row 41
        fcb     $0F,$FF,$C0  ; row 42
        fcb     $0F,$FF,$C0  ; row 43
        fcb     $0F,$FF,$C0  ; row 44
        fcb     $0F,$FF,$C0  ; row 45
        fcb     $0F,$FF,$C0  ; row 46
        fcb     $03,$FF,$C0  ; row 47
        fcb     $03,$FF,$C0  ; row 48
        fcb     $03,$FF,$00  ; row 49
        fcb     $00,$FF,$00  ; row 50
        fcb     $00,$FF,$C0  ; row 51
        fcb     $00,$FF,$C0  ; row 52
        fcb     $00,$FF,$00  ; row 53
        fcb     $03,$FC,$00  ; row 54
        fcb     $03,$F0,$00  ; row 55
        fcb     $03,$C0,$00  ; row 56
