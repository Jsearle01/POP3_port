* chtab5_024_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #24 (3x36 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_024_src:
        fcb     36,6  ; height=36 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $00,$FF,$C0,$00,$00,$00  ; row 0
        fcb     $03,$FF,$FC,$00,$00,$00  ; row 1
        fcb     $0F,$FF,$FF,$00,$00,$00  ; row 2
        fcb     $0F,$55,$7F,$00,$00,$00  ; row 3
        fcb     $00,$15,$57,$FC,$00,$00  ; row 4
        fcb     $00,$15,$7F,$55,$00,$00  ; row 5
        fcb     $0F,$F5,$7F,$57,$C0,$00  ; row 6
        fcb     $0F,$55,$7F,$57,$F0,$00  ; row 7
        fcb     $7F,$50,$0F,$55,$7C,$00  ; row 8
        fcb     $FF,$C0,$0F,$F5,$7C,$00  ; row 9
        fcb     $FF,$00,$03,$F5,$7F,$00  ; row 10
        fcb     $7F,$00,$03,$F5,$7F,$C0  ; row 11
        fcb     $00,$00,$00,$F5,$7F,$C0  ; row 12
        fcb     $00,$00,$00,$15,$7F,$C0  ; row 13
        fcb     $00,$00,$00,$15,$7F,$C0  ; row 14
        fcb     $00,$00,$00,$17,$FF,$C0  ; row 15
        fcb     $00,$00,$00,$17,$FF,$C0  ; row 16
        fcb     $00,$00,$00,$17,$FF,$C0  ; row 17
        fcb     $00,$00,$01,$7F,$FF,$00  ; row 18
        fcb     $00,$00,$01,$7F,$FC,$00  ; row 19
        fcb     $00,$00,$00,$FF,$F0,$00  ; row 20
        fcb     $00,$00,$0F,$FF,$C0,$00  ; row 21
        fcb     $00,$00,$3F,$FF,$00,$00  ; row 22
        fcb     $00,$00,$3F,$FF,$00,$00  ; row 23
        fcb     $00,$00,$3F,$FF,$00,$00  ; row 24
        fcb     $00,$00,$3F,$FF,$00,$00  ; row 25
        fcb     $00,$00,$0F,$FF,$C0,$00  ; row 26
        fcb     $00,$00,$0F,$FF,$C0,$00  ; row 27
        fcb     $00,$00,$0F,$FF,$F0,$00  ; row 28
        fcb     $00,$00,$03,$FF,$F0,$00  ; row 29
        fcb     $00,$00,$00,$FF,$FC,$00  ; row 30
        fcb     $00,$00,$00,$FF,$FC,$00  ; row 31
        fcb     $00,$00,$00,$FF,$FC,$00  ; row 32
        fcb     $00,$00,$0F,$FF,$FC,$00  ; row 33
        fcb     $00,$00,$00,$03,$FF,$00  ; row 34
        fcb     $00,$00,$00,$3F,$F0,$00  ; row 35
