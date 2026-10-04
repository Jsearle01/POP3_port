* chtab5_020_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #20 (4x20 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_020_src:
        fcb     20,7  ; height=20 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$3F,$F0,$00,$00,$00,$00  ; row 0
        fcb     $00,$FF,$FC,$3F,$FF,$C0,$00  ; row 1
        fcb     $03,$FF,$FF,$F5,$7F,$FF,$00  ; row 2
        fcb     $0F,$FF,$F7,$F5,$57,$FF,$C0  ; row 3
        fcb     $0F,$55,$57,$FF,$55,$7F,$F0  ; row 4
        fcb     $00,$15,$55,$7F,$F5,$57,$FC  ; row 5
        fcb     $00,$01,$55,$7F,$55,$7F,$FF  ; row 6
        fcb     $00,$00,$01,$55,$7F,$FF,$FF  ; row 7
        fcb     $00,$00,$17,$F7,$FF,$FF,$FC  ; row 8
        fcb     $00,$00,$17,$F7,$FF,$FF,$F0  ; row 9
        fcb     $01,$01,$50,$83,$FF,$FF,$C0  ; row 10
        fcb     $7F,$01,$00,$F7,$FF,$F0,$00  ; row 11
        fcb     $0F,$55,$00,$3F,$FF,$F0,$00  ; row 12
        fcb     $01,$50,$00,$0F,$FF,$F0,$00  ; row 13
        fcb     $0F,$F0,$00,$00,$FF,$F0,$00  ; row 14
        fcb     $7F,$F0,$00,$00,$FF,$F0,$00  ; row 15
        fcb     $7F,$C0,$00,$03,$FF,$F0,$00  ; row 16
        fcb     $00,$00,$00,$0F,$C0,$F0,$00  ; row 17
        fcb     $00,$00,$00,$00,$00,$FC,$00  ; row 18
        fcb     $00,$00,$00,$00,$0F,$F0,$00  ; row 19
