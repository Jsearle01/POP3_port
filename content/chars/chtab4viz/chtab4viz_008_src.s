* chtab4viz_008_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.VIZ
*         POP cel: #8 (4x38 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4viz_008_src:
        fcb     38,7  ; height=38 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$FF,$F0,$00,$00,$00  ; row 0
        fcb     $00,$0F,$FF,$FF,$00,$00,$00  ; row 1
        fcb     $00,$0F,$FF,$FF,$C0,$00,$00  ; row 2
        fcb     $00,$00,$FF,$FF,$F0,$00,$00  ; row 3
        fcb     $00,$00,$03,$FF,$F0,$00,$00  ; row 4
        fcb     $00,$00,$AF,$FF,$C0,$00,$00  ; row 5
        fcb     $00,$03,$EF,$F0,$00,$00,$00  ; row 6
        fcb     $00,$03,$FF,$F0,$00,$00,$00  ; row 7
        fcb     $00,$0F,$C3,$FF,$00,$00,$00  ; row 8
        fcb     $00,$10,$15,$7F,$F0,$00,$00  ; row 9
        fcb     $00,$00,$15,$7F,$FC,$00,$00  ; row 10
        fcb     $00,$00,$15,$57,$FF,$00,$00  ; row 11
        fcb     $00,$00,$15,$57,$FF,$00,$00  ; row 12
        fcb     $00,$00,$15,$57,$FF,$C0,$00  ; row 13
        fcb     $00,$00,$01,$57,$FF,$C0,$00  ; row 14
        fcb     $00,$00,$01,$50,$FF,$F0,$00  ; row 15
        fcb     $00,$00,$F5,$57,$FF,$F0,$00  ; row 16
        fcb     $00,$0F,$FF,$0F,$FF,$F0,$00  ; row 17
        fcb     $00,$AF,$F5,$7F,$FF,$F0,$00  ; row 18
        fcb     $00,$A8,$01,$7F,$FF,$F0,$00  ; row 19
        fcb     $00,$80,$01,$57,$FF,$FC,$00  ; row 20
        fcb     $00,$00,$15,$57,$FF,$FC,$00  ; row 21
        fcb     $00,$01,$55,$57,$FF,$FC,$00  ; row 22
        fcb     $00,$15,$55,$57,$FF,$FC,$00  ; row 23
        fcb     $00,$15,$55,$57,$FF,$FC,$00  ; row 24
        fcb     $01,$55,$55,$0F,$FF,$FC,$00  ; row 25
        fcb     $01,$55,$50,$3F,$FF,$F0,$00  ; row 26
        fcb     $01,$55,$50,$FF,$FF,$F0,$00  ; row 27
        fcb     $01,$55,$57,$FF,$FF,$F0,$00  ; row 28
        fcb     $01,$55,$57,$FF,$FF,$F5,$00  ; row 29
        fcb     $01,$55,$57,$FF,$FF,$55,$00  ; row 30
        fcb     $00,$15,$57,$FF,$FF,$55,$50  ; row 31
        fcb     $00,$15,$57,$FF,$FC,$15,$50  ; row 32
        fcb     $00,$15,$7F,$FF,$F0,$15,$50  ; row 33
        fcb     $00,$3F,$03,$FF,$00,$03,$FC  ; row 34
        fcb     $00,$FF,$C0,$00,$00,$03,$FF  ; row 35
        fcb     $03,$FF,$C0,$00,$00,$0F,$FF  ; row 36
        fcb     $7F,$FF,$C0,$00,$00,$00,$00  ; row 37
