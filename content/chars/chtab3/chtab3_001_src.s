* chtab3_001_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #1 (2x40 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_001_src:
        fcb     40,3  ; height=40 rows, coco3_width=3 bytes/row (4px/byte)
        fcb     $03,$FC,$00  ; row 0
        fcb     $7F,$FF,$00  ; row 1
        fcb     $FF,$FF,$C0  ; row 2
        fcb     $FF,$FF,$C0  ; row 3
        fcb     $01,$7F,$C0  ; row 4
        fcb     $01,$55,$00  ; row 5
        fcb     $01,$55,$00  ; row 6
        fcb     $00,$03,$C0  ; row 7
        fcb     $00,$3F,$F0  ; row 8
        fcb     $00,$3F,$50  ; row 9
        fcb     $00,$3F,$50  ; row 10
        fcb     $00,$FF,$50  ; row 11
        fcb     $00,$FF,$50  ; row 12
        fcb     $00,$FF,$50  ; row 13
        fcb     $00,$F5,$50  ; row 14
        fcb     $00,$F5,$7C  ; row 15
        fcb     $00,$F5,$7C  ; row 16
        fcb     $00,$F5,$7C  ; row 17
        fcb     $00,$F7,$FC  ; row 18
        fcb     $00,$F7,$FC  ; row 19
        fcb     $00,$F7,$FC  ; row 20
        fcb     $01,$57,$FC  ; row 21
        fcb     $01,$7F,$FC  ; row 22
        fcb     $01,$7F,$F0  ; row 23
        fcb     $00,$3F,$F0  ; row 24
        fcb     $00,$3F,$F0  ; row 25
        fcb     $00,$3F,$F0  ; row 26
        fcb     $00,$3F,$FC  ; row 27
        fcb     $00,$3F,$FC  ; row 28
        fcb     $00,$3F,$FC  ; row 29
        fcb     $00,$0F,$FC  ; row 30
        fcb     $00,$0F,$FC  ; row 31
        fcb     $00,$0F,$FC  ; row 32
        fcb     $00,$03,$FC  ; row 33
        fcb     $00,$03,$FF  ; row 34
        fcb     $00,$00,$3F  ; row 35
        fcb     $00,$00,$FF  ; row 36
        fcb     $00,$03,$FF  ; row 37
        fcb     $00,$3F,$FF  ; row 38
        fcb     $00,$3F,$FF  ; row 39
