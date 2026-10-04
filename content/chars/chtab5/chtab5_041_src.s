* chtab5_041_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #41 (2x33 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_041_src:
        fcb     33,4  ; height=33 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $0F,$F0,$00,$00  ; row 0
        fcb     $FF,$FC,$00,$00  ; row 1
        fcb     $FF,$FF,$00,$00  ; row 2
        fcb     $03,$FF,$00,$00  ; row 3
        fcb     $15,$7F,$00,$00  ; row 4
        fcb     $15,$7F,$00,$00  ; row 5
        fcb     $17,$FF,$00,$00  ; row 6
        fcb     $01,$7F,$F0,$00  ; row 7
        fcb     $01,$7F,$F0,$00  ; row 8
        fcb     $01,$7F,$FC,$00  ; row 9
        fcb     $01,$7F,$FC,$00  ; row 10
        fcb     $01,$7F,$FF,$00  ; row 11
        fcb     $01,$7F,$FF,$00  ; row 12
        fcb     $01,$7F,$FF,$00  ; row 13
        fcb     $01,$7F,$FF,$C0  ; row 14
        fcb     $01,$7F,$FF,$F0  ; row 15
        fcb     $01,$7F,$FF,$C0  ; row 16
        fcb     $01,$7F,$FF,$C0  ; row 17
        fcb     $01,$7F,$FF,$F0  ; row 18
        fcb     $01,$7F,$FF,$F0  ; row 19
        fcb     $01,$7F,$FF,$C0  ; row 20
        fcb     $01,$7F,$FF,$C0  ; row 21
        fcb     $03,$FF,$FF,$00  ; row 22
        fcb     $0F,$FF,$FC,$00  ; row 23
        fcb     $0F,$FF,$F0,$00  ; row 24
        fcb     $7F,$FF,$C0,$00  ; row 25
        fcb     $7F,$FF,$C0,$00  ; row 26
        fcb     $FF,$FF,$F0,$00  ; row 27
        fcb     $7F,$FF,$FC,$00  ; row 28
        fcb     $03,$FF,$FC,$00  ; row 29
        fcb     $00,$3F,$FC,$00  ; row 30
        fcb     $00,$3F,$FF,$00  ; row 31
        fcb     $00,$FF,$FF,$00  ; row 32
