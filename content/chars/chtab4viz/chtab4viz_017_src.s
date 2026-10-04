* chtab4viz_017_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.VIZ
*         POP cel: #17 (6x36 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4viz_017_src:
        fcb     36,11  ; height=36 rows, coco3_width=11 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$0F,$FF,$00,$00,$00,$00,$00  ; row 0
        fcb     $FC,$00,$00,$00,$FF,$FF,$F0,$00,$00,$00,$00  ; row 1
        fcb     $A8,$00,$00,$00,$FF,$FF,$FC,$00,$00,$00,$00  ; row 2
        fcb     $AA,$80,$00,$00,$0F,$FF,$FF,$00,$00,$00,$00  ; row 3
        fcb     $0A,$FF,$00,$00,$00,$3F,$FF,$00,$00,$00,$00  ; row 4
        fcb     $00,$3F,$F0,$00,$0A,$FF,$FC,$00,$00,$00,$00  ; row 5
        fcb     $00,$0F,$FF,$50,$3E,$FF,$00,$00,$00,$00,$00  ; row 6
        fcb     $00,$03,$F5,$55,$7F,$FF,$C0,$00,$00,$00,$00  ; row 7
        fcb     $00,$00,$15,$55,$57,$FF,$FC,$00,$00,$00,$00  ; row 8
        fcb     $00,$00,$01,$55,$57,$FF,$FF,$00,$00,$00,$00  ; row 9
        fcb     $00,$00,$00,$15,$55,$7F,$FF,$00,$00,$00,$00  ; row 10
        fcb     $00,$00,$00,$00,$15,$7F,$FF,$C0,$00,$00,$00  ; row 11
        fcb     $00,$00,$00,$00,$01,$57,$FF,$C0,$00,$00,$00  ; row 12
        fcb     $00,$00,$00,$00,$00,$17,$FF,$F0,$00,$00,$00  ; row 13
        fcb     $00,$00,$00,$00,$00,$17,$FF,$F0,$00,$00,$00  ; row 14
        fcb     $00,$00,$00,$00,$00,$17,$FF,$F0,$00,$00,$00  ; row 15
        fcb     $00,$00,$00,$00,$00,$17,$FF,$C0,$00,$00,$00  ; row 16
        fcb     $00,$00,$00,$00,$00,$17,$FF,$C0,$00,$00,$00  ; row 17
        fcb     $00,$00,$00,$00,$00,$17,$FF,$F0,$00,$00,$00  ; row 18
        fcb     $00,$00,$00,$00,$01,$57,$FF,$F0,$00,$00,$00  ; row 19
        fcb     $00,$00,$00,$00,$15,$57,$FF,$F0,$00,$00,$00  ; row 20
        fcb     $00,$00,$00,$01,$55,$57,$FF,$FC,$00,$00,$00  ; row 21
        fcb     $00,$00,$00,$01,$55,$57,$FF,$FC,$00,$00,$00  ; row 22
        fcb     $00,$00,$00,$15,$55,$57,$FF,$FC,$00,$00,$00  ; row 23
        fcb     $00,$00,$01,$55,$55,$57,$FF,$FF,$00,$00,$00  ; row 24
        fcb     $00,$00,$01,$55,$55,$00,$FF,$FF,$C0,$00,$00  ; row 25
        fcb     $00,$00,$01,$55,$50,$00,$FF,$FF,$F0,$00,$00  ; row 26
        fcb     $00,$00,$15,$55,$00,$FE,$FF,$FF,$FC,$00,$00  ; row 27
        fcb     $00,$00,$15,$55,$03,$FF,$7F,$FF,$FF,$C0,$00  ; row 28
        fcb     $00,$00,$15,$55,$03,$FF,$7F,$FF,$FF,$50,$00  ; row 29
        fcb     $00,$00,$15,$55,$0F,$FF,$7F,$FF,$F5,$7F,$C0  ; row 30
        fcb     $00,$00,$15,$50,$0F,$FF,$7F,$FF,$55,$0F,$F0  ; row 31
        fcb     $00,$00,$01,$00,$0F,$FF,$7F,$F0,$00,$0F,$F0  ; row 32
        fcb     $00,$00,$3F,$00,$00,$00,$0F,$00,$00,$0F,$C0  ; row 33
        fcb     $00,$03,$FF,$00,$00,$00,$00,$00,$00,$3F,$00  ; row 34
        fcb     $00,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00  ; row 35
