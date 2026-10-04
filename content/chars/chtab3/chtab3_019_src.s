* chtab3_019_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #19 (4x28 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_019_src:
        fcb     28,6  ; height=28 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $00,$00,$3F,$FF,$FC,$00  ; row 0
        fcb     $7F,$F7,$FF,$FF,$FF,$C0  ; row 1
        fcb     $7F,$FF,$FF,$FF,$FF,$F0  ; row 2
        fcb     $FF,$FF,$F7,$FF,$FF,$FC  ; row 3
        fcb     $FF,$50,$F5,$7F,$FF,$FC  ; row 4
        fcb     $F5,$50,$15,$7F,$FF,$FC  ; row 5
        fcb     $80,$00,$01,$7F,$FF,$FC  ; row 6
        fcb     $00,$00,$01,$7F,$FF,$F0  ; row 7
        fcb     $00,$00,$01,$03,$FF,$F0  ; row 8
        fcb     $00,$00,$15,$03,$FF,$C0  ; row 9
        fcb     $01,$55,$55,$03,$FF,$C0  ; row 10
        fcb     $01,$50,$00,$03,$FF,$C0  ; row 11
        fcb     $00,$00,$00,$03,$FF,$C0  ; row 12
        fcb     $00,$00,$00,$03,$FF,$00  ; row 13
        fcb     $00,$00,$00,$03,$FF,$00  ; row 14
        fcb     $00,$00,$00,$00,$FF,$00  ; row 15
        fcb     $00,$00,$00,$00,$FF,$00  ; row 16
        fcb     $00,$00,$00,$00,$FF,$00  ; row 17
        fcb     $00,$00,$00,$00,$FF,$00  ; row 18
        fcb     $00,$00,$00,$00,$FF,$C0  ; row 19
        fcb     $00,$00,$00,$00,$FF,$C0  ; row 20
        fcb     $00,$00,$00,$00,$3F,$C0  ; row 21
        fcb     $00,$00,$00,$00,$0F,$F0  ; row 22
        fcb     $00,$00,$00,$00,$03,$F0  ; row 23
        fcb     $00,$00,$00,$00,$03,$F0  ; row 24
        fcb     $00,$00,$00,$00,$0F,$F0  ; row 25
        fcb     $00,$00,$00,$00,$3F,$C0  ; row 26
        fcb     $00,$00,$00,$00,$FF,$00  ; row 27
