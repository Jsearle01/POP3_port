* chtab3_028_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #28 (2x51 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_028_src:
        fcb     51,3  ; height=51 rows, coco3_width=3 bytes/row (4px/byte)
        fcb     $15,$00,$00  ; row 0
        fcb     $01,$00,$00  ; row 1
        fcb     $01,$00,$00  ; row 2
        fcb     $01,$00,$00  ; row 3
        fcb     $01,$00,$00  ; row 4
        fcb     $01,$00,$00  ; row 5
        fcb     $01,$7F,$C0  ; row 6
        fcb     $01,$7F,$F0  ; row 7
        fcb     $01,$7F,$F0  ; row 8
        fcb     $01,$7F,$F0  ; row 9
        fcb     $01,$57,$F0  ; row 10
        fcb     $01,$57,$C0  ; row 11
        fcb     $01,$55,$00  ; row 12
        fcb     $00,$15,$7C  ; row 13
        fcb     $00,$15,$7F  ; row 14
        fcb     $00,$15,$7F  ; row 15
        fcb     $00,$17,$FF  ; row 16
        fcb     $00,$FF,$FF  ; row 17
        fcb     $00,$FF,$FF  ; row 18
        fcb     $00,$FF,$FC  ; row 19
        fcb     $00,$FF,$FC  ; row 20
        fcb     $00,$FF,$FC  ; row 21
        fcb     $00,$FF,$FC  ; row 22
        fcb     $00,$FF,$FC  ; row 23
        fcb     $03,$FF,$F0  ; row 24
        fcb     $03,$FF,$F0  ; row 25
        fcb     $03,$FF,$F0  ; row 26
        fcb     $03,$FF,$F0  ; row 27
        fcb     $03,$FF,$F0  ; row 28
        fcb     $03,$FF,$F0  ; row 29
        fcb     $03,$FF,$F0  ; row 30
        fcb     $03,$FF,$F0  ; row 31
        fcb     $0F,$FF,$F0  ; row 32
        fcb     $0F,$FF,$F0  ; row 33
        fcb     $0F,$FF,$F0  ; row 34
        fcb     $0F,$FF,$F0  ; row 35
        fcb     $0F,$FF,$F0  ; row 36
        fcb     $0F,$FF,$C0  ; row 37
        fcb     $0F,$FF,$C0  ; row 38
        fcb     $0F,$FF,$C0  ; row 39
        fcb     $0F,$FF,$C0  ; row 40
        fcb     $0F,$FF,$C0  ; row 41
        fcb     $00,$FF,$00  ; row 42
        fcb     $00,$15,$00  ; row 43
        fcb     $00,$17,$C0  ; row 44
        fcb     $00,$17,$F0  ; row 45
        fcb     $00,$3F,$F0  ; row 46
        fcb     $00,$3F,$C0  ; row 47
        fcb     $00,$FF,$00  ; row 48
        fcb     $00,$F0,$00  ; row 49
        fcb     $00,$10,$00  ; row 50
