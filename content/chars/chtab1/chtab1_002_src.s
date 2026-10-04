* chtab1_002_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB1
*         POP cel: #2 (3x41 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab1_002_src:
        fcb     41,4  ; height=41 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $0F,$FC,$00,$00  ; row 0
        fcb     $FF,$FF,$00,$00  ; row 1
        fcb     $FF,$FF,$00,$00  ; row 2
        fcb     $0F,$FF,$00,$00  ; row 3
        fcb     $15,$7F,$00,$00  ; row 4
        fcb     $15,$7C,$00,$00  ; row 5
        fcb     $15,$50,$00,$00  ; row 6
        fcb     $01,$50,$00,$00  ; row 7
        fcb     $01,$7F,$00,$00  ; row 8
        fcb     $03,$FF,$C0,$00  ; row 9
        fcb     $0F,$F5,$00,$00  ; row 10
        fcb     $0F,$F5,$00,$00  ; row 11
        fcb     $0F,$F5,$00,$00  ; row 12
        fcb     $0F,$F5,$50,$00  ; row 13
        fcb     $0F,$FF,$50,$00  ; row 14
        fcb     $03,$FF,$50,$00  ; row 15
        fcb     $03,$FF,$50,$00  ; row 16
        fcb     $03,$FF,$50,$00  ; row 17
        fcb     $03,$F5,$7F,$00  ; row 18
        fcb     $01,$57,$FF,$00  ; row 19
        fcb     $01,$57,$FF,$00  ; row 20
        fcb     $01,$7F,$FF,$C0  ; row 21
        fcb     $00,$3F,$FF,$C0  ; row 22
        fcb     $00,$3F,$FF,$C0  ; row 23
        fcb     $00,$FF,$FF,$C0  ; row 24
        fcb     $00,$FF,$FF,$C0  ; row 25
        fcb     $03,$F7,$FF,$00  ; row 26
        fcb     $03,$F7,$FF,$00  ; row 27
        fcb     $03,$F7,$FF,$00  ; row 28
        fcb     $03,$F7,$FF,$00  ; row 29
        fcb     $03,$F7,$FF,$C0  ; row 30
        fcb     $03,$F7,$FF,$C0  ; row 31
        fcb     $00,$FE,$FF,$F0  ; row 32
        fcb     $00,$3E,$FF,$F0  ; row 33
        fcb     $00,$0A,$FF,$F0  ; row 34
        fcb     $00,$00,$3F,$F0  ; row 35
        fcb     $00,$00,$03,$C0  ; row 36
        fcb     $00,$00,$01,$50  ; row 37
        fcb     $00,$00,$0F,$F0  ; row 38
        fcb     $00,$00,$3F,$FC  ; row 39
        fcb     $00,$03,$FF,$FC  ; row 40
