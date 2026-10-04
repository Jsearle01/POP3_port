* chtab2_018_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #18 (2x41 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_018_src:
        fcb     41,3  ; height=41 rows, coco3_width=3 bytes/row (4px/byte)
        fcb     $0F,$FC,$00  ; row 0
        fcb     $0F,$FF,$00  ; row 1
        fcb     $03,$FF,$C0  ; row 2
        fcb     $17,$FF,$C0  ; row 3
        fcb     $15,$7F,$C0  ; row 4
        fcb     $15,$7F,$00  ; row 5
        fcb     $01,$7C,$00  ; row 6
        fcb     $01,$50,$00  ; row 7
        fcb     $03,$FC,$00  ; row 8
        fcb     $03,$FF,$00  ; row 9
        fcb     $0F,$7F,$C0  ; row 10
        fcb     $0F,$57,$C0  ; row 11
        fcb     $0F,$57,$F0  ; row 12
        fcb     $0F,$F7,$F0  ; row 13
        fcb     $0F,$F7,$F0  ; row 14
        fcb     $0F,$F7,$F0  ; row 15
        fcb     $0F,$F7,$FC  ; row 16
        fcb     $0F,$F7,$FC  ; row 17
        fcb     $0F,$57,$FC  ; row 18
        fcb     $0F,$57,$FC  ; row 19
        fcb     $0F,$7F,$FC  ; row 20
        fcb     $0F,$7F,$FC  ; row 21
        fcb     $01,$7F,$FC  ; row 22
        fcb     $01,$7F,$FC  ; row 23
        fcb     $03,$FF,$F0  ; row 24
        fcb     $03,$FF,$F0  ; row 25
        fcb     $03,$FF,$F0  ; row 26
        fcb     $03,$FF,$F0  ; row 27
        fcb     $0F,$FF,$F0  ; row 28
        fcb     $0F,$FF,$F0  ; row 29
        fcb     $0F,$FF,$C0  ; row 30
        fcb     $0F,$FF,$F0  ; row 31
        fcb     $0F,$FF,$F0  ; row 32
        fcb     $03,$FF,$F0  ; row 33
        fcb     $03,$FF,$F0  ; row 34
        fcb     $00,$FF,$F0  ; row 35
        fcb     $00,$FF,$F0  ; row 36
        fcb     $00,$FF,$FC  ; row 37
        fcb     $03,$FF,$FC  ; row 38
        fcb     $7F,$FF,$FC  ; row 39
        fcb     $FF,$C0,$00  ; row 40
