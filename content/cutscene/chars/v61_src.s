* v61_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #87 (4x47 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=152  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v61_src:
        fcb     47,7  ; height=47 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$0F,$FF,$00  ; row 0
        fcb     $00,$00,$00,$00,$FF,$FF,$F0  ; row 1
        fcb     $00,$00,$00,$03,$FF,$FF,$FC  ; row 2
        fcb     $00,$00,$00,$03,$FF,$FF,$FC  ; row 3
        fcb     $00,$00,$00,$03,$FF,$FF,$FC  ; row 4
        fcb     $00,$00,$00,$00,$FF,$FF,$FC  ; row 5
        fcb     $00,$00,$00,$00,$0F,$FF,$C0  ; row 6
        fcb     $00,$00,$00,$0F,$FF,$F0,$00  ; row 7
        fcb     $00,$00,$00,$3F,$FF,$FC,$00  ; row 8
        fcb     $00,$00,$00,$3F,$FF,$FF,$F0  ; row 9
        fcb     $00,$00,$00,$FF,$FF,$FF,$FC  ; row 10
        fcb     $00,$00,$03,$FF,$FF,$FF,$FC  ; row 11
        fcb     $00,$00,$03,$FF,$FF,$FF,$FC  ; row 12
        fcb     $00,$00,$0F,$FF,$FF,$FF,$FC  ; row 13
        fcb     $00,$00,$0F,$FF,$FF,$FF,$FC  ; row 14
        fcb     $00,$00,$3F,$FF,$FF,$FF,$FC  ; row 15
        fcb     $00,$00,$FF,$FF,$FF,$FF,$FC  ; row 16
        fcb     $00,$00,$FF,$FF,$FF,$FF,$FC  ; row 17
        fcb     $00,$03,$FF,$FF,$FF,$FF,$FC  ; row 18
        fcb     $00,$03,$FF,$FF,$FF,$FF,$FF  ; row 19
        fcb     $00,$0F,$FF,$FF,$FF,$FF,$FF  ; row 20
        fcb     $00,$0F,$FF,$FF,$FF,$FF,$FF  ; row 21
        fcb     $00,$3F,$FF,$FF,$FF,$FF,$FF  ; row 22
        fcb     $00,$3F,$FF,$FF,$FF,$FF,$FF  ; row 23
        fcb     $00,$3F,$FF,$FF,$FF,$FF,$FF  ; row 24
        fcb     $00,$FF,$FF,$FF,$FF,$FF,$FF  ; row 25
        fcb     $03,$FF,$FF,$FF,$FF,$FF,$FF  ; row 26
        fcb     $03,$FF,$FF,$FF,$FF,$FF,$FC  ; row 27
        fcb     $0F,$FF,$FF,$FF,$FF,$FF,$F0  ; row 28
        fcb     $0F,$FF,$FF,$FF,$FF,$FF,$F0  ; row 29
        fcb     $0F,$FF,$FF,$FF,$FF,$FF,$C0  ; row 30
        fcb     $0F,$FF,$FF,$FF,$FF,$FF,$C0  ; row 31
        fcb     $0F,$FF,$FF,$FF,$FF,$FF,$C0  ; row 32
        fcb     $7F,$FF,$FF,$FF,$FF,$FF,$00  ; row 33
        fcb     $7F,$FF,$FF,$FF,$FF,$FF,$00  ; row 34
        fcb     $7F,$FF,$FF,$FF,$FF,$FF,$00  ; row 35
        fcb     $0F,$FF,$FF,$FF,$FF,$FF,$00  ; row 36
        fcb     $7F,$FF,$FF,$FF,$FF,$FC,$00  ; row 37
        fcb     $7F,$FF,$FF,$FF,$FF,$FC,$00  ; row 38
        fcb     $00,$00,$AF,$FF,$FF,$FC,$00  ; row 39
        fcb     $00,$00,$AA,$FF,$FF,$FC,$00  ; row 40
        fcb     $00,$00,$FE,$83,$FF,$FC,$00  ; row 41
        fcb     $00,$00,$FC,$00,$0F,$F0,$00  ; row 42
        fcb     $00,$03,$FC,$00,$03,$F0,$00  ; row 43
        fcb     $00,$03,$FC,$00,$03,$F0,$00  ; row 44
        fcb     $00,$00,$00,$00,$0F,$F0,$00  ; row 45
        fcb     $00,$00,$00,$00,$0F,$F0,$00  ; row 46
