* chtab4viz_007_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.VIZ
*         POP cel: #7 (4x39 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4viz_007_src:
        fcb     39,7  ; height=39 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$0F,$FF,$00,$00,$00,$00  ; row 0
        fcb     $00,$FF,$FF,$F0,$00,$00,$00  ; row 1
        fcb     $00,$FF,$FF,$FC,$00,$00,$00  ; row 2
        fcb     $00,$0F,$FF,$FF,$00,$00,$00  ; row 3
        fcb     $00,$00,$3F,$FF,$00,$00,$00  ; row 4
        fcb     $00,$0A,$FF,$FC,$00,$00,$00  ; row 5
        fcb     $00,$3E,$FF,$00,$00,$00,$00  ; row 6
        fcb     $00,$3F,$FF,$00,$00,$00,$00  ; row 7
        fcb     $00,$FC,$3F,$FC,$00,$00,$00  ; row 8
        fcb     $01,$01,$57,$FF,$00,$00,$00  ; row 9
        fcb     $00,$01,$57,$FF,$F0,$00,$00  ; row 10
        fcb     $00,$01,$55,$7F,$F0,$00,$00  ; row 11
        fcb     $00,$01,$55,$7F,$FF,$00,$00  ; row 12
        fcb     $00,$01,$55,$7F,$FF,$00,$00  ; row 13
        fcb     $00,$01,$55,$7F,$FF,$00,$00  ; row 14
        fcb     $00,$00,$15,$7F,$FF,$00,$00  ; row 15
        fcb     $00,$00,$15,$0F,$FC,$00,$00  ; row 16
        fcb     $00,$0F,$55,$0F,$FC,$00,$00  ; row 17
        fcb     $00,$FF,$F5,$7F,$FC,$00,$00  ; row 18
        fcb     $0A,$FF,$55,$7F,$FC,$00,$00  ; row 19
        fcb     $0A,$80,$15,$7F,$FC,$00,$00  ; row 20
        fcb     $00,$01,$57,$FF,$FC,$00,$00  ; row 21
        fcb     $00,$15,$57,$FF,$FC,$00,$00  ; row 22
        fcb     $00,$15,$57,$FF,$FC,$00,$00  ; row 23
        fcb     $01,$55,$57,$FF,$FC,$00,$00  ; row 24
        fcb     $01,$55,$7F,$FF,$FC,$00,$00  ; row 25
        fcb     $15,$55,$7F,$FF,$FC,$00,$00  ; row 26
        fcb     $F5,$50,$FF,$FF,$F5,$00,$00  ; row 27
        fcb     $F5,$55,$7F,$FF,$55,$50,$00  ; row 28
        fcb     $15,$55,$7F,$FF,$55,$50,$00  ; row 29
        fcb     $01,$55,$7F,$F0,$15,$55,$00  ; row 30
        fcb     $01,$55,$7F,$00,$01,$55,$00  ; row 31
        fcb     $01,$55,$50,$00,$01,$55,$00  ; row 32
        fcb     $01,$55,$00,$00,$00,$15,$7F  ; row 33
        fcb     $01,$50,$00,$00,$00,$03,$FF  ; row 34
        fcb     $00,$FF,$C0,$00,$00,$03,$FF  ; row 35
        fcb     $03,$FF,$F0,$00,$00,$03,$FC  ; row 36
        fcb     $7F,$FF,$00,$00,$00,$03,$C0  ; row 37
        fcb     $0F,$C0,$00,$00,$00,$00,$00  ; row 38
