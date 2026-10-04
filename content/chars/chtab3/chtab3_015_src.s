* chtab3_015_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #15 (2x44 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_015_src:
        fcb     44,3  ; height=44 rows, coco3_width=3 bytes/row (4px/byte)
        fcb     $00,$0F,$FC  ; row 0
        fcb     $00,$FF,$FF  ; row 1
        fcb     $00,$FF,$FF  ; row 2
        fcb     $0A,$AA,$FF  ; row 3
        fcb     $AA,$AA,$FC  ; row 4
        fcb     $A8,$10,$FC  ; row 5
        fcb     $00,$10,$FC  ; row 6
        fcb     $00,$3F,$FF  ; row 7
        fcb     $00,$3F,$FF  ; row 8
        fcb     $00,$3F,$FF  ; row 9
        fcb     $00,$3F,$FF  ; row 10
        fcb     $00,$3F,$FF  ; row 11
        fcb     $00,$3F,$FF  ; row 12
        fcb     $00,$3F,$FF  ; row 13
        fcb     $00,$FF,$FF  ; row 14
        fcb     $00,$FF,$FF  ; row 15
        fcb     $00,$FF,$FF  ; row 16
        fcb     $00,$FF,$FF  ; row 17
        fcb     $00,$3F,$FF  ; row 18
        fcb     $00,$3F,$FF  ; row 19
        fcb     $00,$3F,$FF  ; row 20
        fcb     $00,$3F,$FC  ; row 21
        fcb     $00,$0F,$FC  ; row 22
        fcb     $00,$0F,$FC  ; row 23
        fcb     $00,$3F,$FC  ; row 24
        fcb     $00,$3F,$FC  ; row 25
        fcb     $00,$3F,$FC  ; row 26
        fcb     $00,$3F,$FC  ; row 27
        fcb     $00,$3F,$FC  ; row 28
        fcb     $00,$3F,$FC  ; row 29
        fcb     $00,$3F,$FC  ; row 30
        fcb     $00,$3F,$FF  ; row 31
        fcb     $00,$3F,$FF  ; row 32
        fcb     $00,$3F,$FF  ; row 33
        fcb     $00,$0F,$FF  ; row 34
        fcb     $00,$0F,$FF  ; row 35
        fcb     $00,$03,$FC  ; row 36
        fcb     $00,$03,$FC  ; row 37
        fcb     $00,$00,$A8  ; row 38
        fcb     $00,$00,$AF  ; row 39
        fcb     $00,$03,$FC  ; row 40
        fcb     $00,$03,$F0  ; row 41
        fcb     $00,$0F,$C0  ; row 42
        fcb     $00,$0F,$00  ; row 43
