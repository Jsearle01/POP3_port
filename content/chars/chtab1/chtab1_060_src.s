* chtab1_060_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB1
*         POP cel: #60 (3x31 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab1_060_src:
        fcb     31,4  ; height=31 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $00,$00,$0F,$FC  ; row 0
        fcb     $00,$00,$3F,$FC  ; row 1
        fcb     $00,$00,$3F,$F0  ; row 2
        fcb     $00,$00,$3F,$50  ; row 3
        fcb     $00,$00,$3F,$50  ; row 4
        fcb     $00,$00,$FF,$00  ; row 5
        fcb     $00,$0F,$FF,$C0  ; row 6
        fcb     $00,$3F,$FF,$F0  ; row 7
        fcb     $00,$3F,$FF,$50  ; row 8
        fcb     $01,$7F,$FF,$50  ; row 9
        fcb     $01,$7F,$F5,$00  ; row 10
        fcb     $03,$FF,$F5,$00  ; row 11
        fcb     $03,$FF,$F5,$00  ; row 12
        fcb     $03,$FF,$F5,$50  ; row 13
        fcb     $0F,$FF,$FF,$50  ; row 14
        fcb     $0F,$FF,$FC,$15  ; row 15
        fcb     $0F,$FF,$FC,$10  ; row 16
        fcb     $03,$FF,$FF,$00  ; row 17
        fcb     $03,$FF,$FF,$00  ; row 18
        fcb     $00,$FF,$FF,$C0  ; row 19
        fcb     $00,$FF,$FF,$C0  ; row 20
        fcb     $00,$FF,$FF,$F0  ; row 21
        fcb     $00,$FF,$FF,$C0  ; row 22
        fcb     $03,$FF,$FF,$C0  ; row 23
        fcb     $03,$FE,$FF,$C0  ; row 24
        fcb     $7F,$F7,$FF,$00  ; row 25
        fcb     $FF,$00,$FF,$00  ; row 26
        fcb     $FF,$00,$FC,$00  ; row 27
        fcb     $7F,$00,$FF,$C0  ; row 28
        fcb     $7C,$00,$FF,$00  ; row 29
        fcb     $08,$00,$00,$00  ; row 30
