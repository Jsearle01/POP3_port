* chtab4viz_021_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.VIZ
*         POP cel: #21 (5x34 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4viz_021_src:
        fcb     34,8  ; height=34 rows, coco3_width=8 bytes/row (4px/byte)
        fcb     $00,$00,$0F,$FF,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$FF,$FF,$F0,$00,$00,$00  ; row 1
        fcb     $00,$00,$FF,$FF,$FC,$00,$00,$00  ; row 2
        fcb     $00,$00,$0F,$FF,$FC,$00,$00,$00  ; row 3
        fcb     $00,$00,$00,$3F,$FC,$00,$00,$00  ; row 4
        fcb     $00,$00,$0A,$FF,$F0,$00,$00,$00  ; row 5
        fcb     $00,$00,$3E,$FF,$00,$00,$00,$00  ; row 6
        fcb     $0A,$80,$3F,$FF,$F0,$00,$00,$00  ; row 7
        fcb     $0A,$F5,$57,$FF,$FC,$00,$00,$00  ; row 8
        fcb     $00,$F5,$50,$FF,$FF,$00,$00,$00  ; row 9
        fcb     $00,$01,$57,$FF,$FF,$00,$00,$00  ; row 10
        fcb     $00,$00,$00,$FF,$FF,$C0,$00,$00  ; row 11
        fcb     $00,$00,$00,$3F,$FF,$C0,$00,$00  ; row 12
        fcb     $00,$00,$00,$0F,$FF,$C0,$00,$00  ; row 13
        fcb     $00,$00,$00,$0F,$FF,$F0,$00,$00  ; row 14
        fcb     $00,$00,$00,$03,$FF,$F0,$00,$00  ; row 15
        fcb     $00,$00,$00,$03,$FF,$F0,$00,$00  ; row 16
        fcb     $00,$00,$00,$17,$FF,$FC,$00,$00  ; row 17
        fcb     $00,$00,$00,$17,$FF,$FC,$00,$00  ; row 18
        fcb     $00,$00,$01,$57,$FF,$FC,$00,$00  ; row 19
        fcb     $00,$00,$01,$57,$FF,$FC,$00,$00  ; row 20
        fcb     $00,$00,$01,$55,$7F,$FF,$00,$00  ; row 21
        fcb     $00,$00,$15,$55,$7F,$FF,$00,$00  ; row 22
        fcb     $00,$00,$15,$55,$7F,$FF,$C0,$00  ; row 23
        fcb     $00,$00,$15,$55,$0F,$FF,$F0,$00  ; row 24
        fcb     $00,$00,$01,$55,$0F,$FF,$FC,$00  ; row 25
        fcb     $00,$00,$01,$55,$0F,$FF,$FF,$00  ; row 26
        fcb     $00,$00,$01,$55,$0F,$FF,$FF,$FC  ; row 27
        fcb     $00,$00,$00,$15,$0F,$FF,$FF,$7F  ; row 28
        fcb     $00,$00,$00,$01,$03,$FF,$C1,$7F  ; row 29
        fcb     $00,$00,$00,$3F,$F7,$FC,$00,$FF  ; row 30
        fcb     $00,$00,$00,$3F,$F7,$C0,$00,$3F  ; row 31
        fcb     $00,$00,$00,$FF,$C0,$00,$00,$3F  ; row 32
        fcb     $00,$00,$00,$FC,$00,$00,$00,$3C  ; row 33
