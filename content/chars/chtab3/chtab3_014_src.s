* chtab3_014_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #14 (2x44 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_014_src:
        fcb     44,3  ; height=44 rows, coco3_width=3 bytes/row (4px/byte)
        fcb     $15,$00,$00  ; row 0
        fcb     $01,$7F,$C0  ; row 1
        fcb     $01,$7F,$F0  ; row 2
        fcb     $01,$7F,$F0  ; row 3
        fcb     $01,$7F,$F0  ; row 4
        fcb     $01,$7F,$C0  ; row 5
        fcb     $01,$01,$00  ; row 6
        fcb     $01,$55,$7C  ; row 7
        fcb     $01,$55,$7F  ; row 8
        fcb     $01,$55,$7F  ; row 9
        fcb     $01,$57,$FF  ; row 10
        fcb     $01,$57,$FF  ; row 11
        fcb     $00,$FF,$FF  ; row 12
        fcb     $00,$FF,$FC  ; row 13
        fcb     $00,$FF,$FC  ; row 14
        fcb     $00,$FF,$FC  ; row 15
        fcb     $03,$FF,$FC  ; row 16
        fcb     $03,$FF,$F0  ; row 17
        fcb     $03,$FF,$F0  ; row 18
        fcb     $03,$FF,$F0  ; row 19
        fcb     $03,$FF,$F0  ; row 20
        fcb     $03,$FF,$F0  ; row 21
        fcb     $03,$FF,$C0  ; row 22
        fcb     $03,$FF,$C0  ; row 23
        fcb     $03,$FF,$C0  ; row 24
        fcb     $03,$FF,$C0  ; row 25
        fcb     $0F,$FF,$C0  ; row 26
        fcb     $0F,$FF,$C0  ; row 27
        fcb     $0F,$FF,$F0  ; row 28
        fcb     $0F,$FF,$F0  ; row 29
        fcb     $0F,$FF,$F0  ; row 30
        fcb     $0F,$FF,$F0  ; row 31
        fcb     $03,$FF,$F0  ; row 32
        fcb     $03,$FF,$F0  ; row 33
        fcb     $03,$FF,$F0  ; row 34
        fcb     $03,$FF,$C0  ; row 35
        fcb     $00,$FF,$00  ; row 36
        fcb     $00,$15,$00  ; row 37
        fcb     $00,$17,$C0  ; row 38
        fcb     $00,$17,$F0  ; row 39
        fcb     $00,$3F,$F0  ; row 40
        fcb     $00,$3F,$C0  ; row 41
        fcb     $00,$FF,$00  ; row 42
        fcb     $00,$F0,$00  ; row 43
