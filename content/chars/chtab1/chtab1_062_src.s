* chtab1_062_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB1
*         POP cel: #62 (2x30 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab1_062_src:
        fcb     30,3  ; height=30 rows, coco3_width=3 bytes/row (4px/byte)
        fcb     $00,$03,$F0  ; row 0
        fcb     $00,$0F,$FC  ; row 1
        fcb     $00,$FF,$FC  ; row 2
        fcb     $03,$FF,$FC  ; row 3
        fcb     $03,$FF,$FC  ; row 4
        fcb     $17,$FF,$FC  ; row 5
        fcb     $17,$FF,$FC  ; row 6
        fcb     $17,$FF,$FC  ; row 7
        fcb     $03,$FF,$FC  ; row 8
        fcb     $0F,$FF,$FC  ; row 9
        fcb     $0F,$FF,$FC  ; row 10
        fcb     $0F,$FF,$FC  ; row 11
        fcb     $0F,$FF,$F0  ; row 12
        fcb     $0F,$FF,$F0  ; row 13
        fcb     $03,$FF,$F0  ; row 14
        fcb     $03,$FF,$F0  ; row 15
        fcb     $03,$FF,$F0  ; row 16
        fcb     $00,$FF,$F0  ; row 17
        fcb     $00,$FF,$F0  ; row 18
        fcb     $00,$FF,$F0  ; row 19
        fcb     $00,$FF,$F0  ; row 20
        fcb     $00,$FF,$C0  ; row 21
        fcb     $03,$FF,$FC  ; row 22
        fcb     $0F,$FF,$FC  ; row 23
        fcb     $0F,$FC,$00  ; row 24
        fcb     $0F,$F0,$00  ; row 25
        fcb     $0F,$C0,$00  ; row 26
        fcb     $7F,$C0,$00  ; row 27
        fcb     $0F,$C0,$00  ; row 28
        fcb     $03,$F0,$00  ; row 29
