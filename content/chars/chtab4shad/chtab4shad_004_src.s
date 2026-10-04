* chtab4shad_004_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.SHAD
*         POP cel: #4 (7x31 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4shad_004_src:
        fcb     31,13  ; height=31 rows, coco3_width=13 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$FF,$C0,$00,$00,$00,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$0F,$FF,$F0,$00,$00,$00,$00,$00,$00,$00  ; row 1
        fcb     $00,$00,$00,$0F,$FF,$F0,$00,$00,$00,$00,$00,$00,$00  ; row 2
        fcb     $00,$00,$00,$00,$FF,$FF,$C0,$00,$00,$00,$00,$00,$00  ; row 3
        fcb     $01,$50,$00,$15,$55,$7F,$F5,$00,$00,$00,$00,$00,$00  ; row 4
        fcb     $01,$55,$55,$55,$55,$7F,$FF,$55,$00,$00,$00,$00,$00  ; row 5
        fcb     $00,$00,$00,$15,$55,$7F,$FF,$55,$50,$00,$00,$00,$00  ; row 6
        fcb     $00,$00,$00,$00,$0F,$FF,$FF,$F5,$55,$50,$00,$00,$00  ; row 7
        fcb     $00,$00,$00,$00,$03,$FF,$FF,$F0,$01,$55,$00,$00,$00  ; row 8
        fcb     $00,$00,$00,$00,$00,$3F,$FF,$FC,$00,$15,$00,$00,$00  ; row 9
        fcb     $00,$00,$00,$00,$00,$0F,$FF,$FF,$00,$00,$00,$00,$00  ; row 10
        fcb     $00,$00,$00,$00,$00,$03,$FF,$FF,$C0,$00,$00,$00,$00  ; row 11
        fcb     $00,$00,$00,$00,$00,$00,$FF,$FF,$F0,$00,$00,$00,$00  ; row 12
        fcb     $00,$00,$00,$00,$00,$00,$3F,$FF,$FC,$00,$00,$00,$00  ; row 13
        fcb     $00,$00,$00,$00,$00,$00,$3F,$FF,$FC,$00,$00,$00,$00  ; row 14
        fcb     $00,$00,$00,$00,$00,$3F,$FF,$FF,$FC,$00,$00,$00,$00  ; row 15
        fcb     $00,$00,$00,$00,$0F,$FF,$FF,$FF,$F0,$00,$00,$00,$00  ; row 16
        fcb     $00,$00,$00,$00,$3F,$FF,$FF,$FF,$0F,$00,$00,$00,$00  ; row 17
        fcb     $00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$C0,$00,$00,$00  ; row 18
        fcb     $00,$00,$00,$00,$FF,$FF,$F0,$03,$FF,$C0,$00,$00,$00  ; row 19
        fcb     $00,$00,$00,$00,$FF,$C0,$00,$03,$FF,$F0,$00,$00,$00  ; row 20
        fcb     $00,$00,$00,$00,$FF,$C0,$00,$00,$FF,$FC,$00,$00,$00  ; row 21
        fcb     $00,$00,$00,$00,$FF,$C0,$00,$00,$3F,$FF,$F0,$00,$00  ; row 22
        fcb     $00,$00,$00,$03,$FF,$C0,$00,$00,$0F,$FF,$FF,$00,$00  ; row 23
        fcb     $00,$00,$00,$03,$FF,$00,$00,$00,$03,$FF,$FF,$F0,$00  ; row 24
        fcb     $00,$00,$00,$03,$FC,$00,$00,$00,$00,$03,$FF,$FF,$C0  ; row 25
        fcb     $00,$00,$00,$0F,$FC,$00,$00,$00,$00,$00,$0F,$FF,$C0  ; row 26
        fcb     $00,$00,$00,$3F,$F0,$00,$00,$00,$00,$00,$00,$3F,$C0  ; row 27
        fcb     $00,$00,$00,$FF,$F0,$00,$00,$00,$00,$00,$00,$3F,$00  ; row 28
        fcb     $00,$00,$03,$FF,$FC,$00,$00,$00,$00,$00,$00,$3C,$00  ; row 29
        fcb     $00,$00,$3F,$FF,$FC,$00,$00,$00,$00,$00,$00,$00,$00  ; row 30
