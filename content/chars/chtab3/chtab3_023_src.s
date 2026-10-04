* chtab3_023_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #23 (4x22 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_023_src:
        fcb     22,7  ; height=22 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$00,$3F,$FF,$FC,$00  ; row 0
        fcb     $00,$00,$03,$FF,$FF,$FF,$C0  ; row 1
        fcb     $00,$00,$3F,$FF,$FF,$FF,$F0  ; row 2
        fcb     $7F,$F7,$FF,$FF,$FF,$FF,$F0  ; row 3
        fcb     $FF,$FF,$C3,$FF,$FF,$FF,$F0  ; row 4
        fcb     $FF,$FC,$17,$EF,$FF,$FF,$C0  ; row 5
        fcb     $FF,$FF,$55,$7F,$FF,$FF,$00  ; row 6
        fcb     $F5,$55,$50,$3F,$FF,$FC,$00  ; row 7
        fcb     $F5,$01,$57,$FF,$FF,$F0,$00  ; row 8
        fcb     $00,$00,$17,$FF,$FF,$C0,$00  ; row 9
        fcb     $00,$00,$17,$FF,$FC,$00,$00  ; row 10
        fcb     $00,$00,$17,$FF,$F7,$FF,$00  ; row 11
        fcb     $00,$01,$7F,$FF,$F7,$FF,$FF  ; row 12
        fcb     $00,$01,$50,$FF,$FE,$FF,$FF  ; row 13
        fcb     $00,$01,$50,$3F,$FF,$7F,$FF  ; row 14
        fcb     $00,$01,$00,$0F,$FF,$00,$FF  ; row 15
        fcb     $00,$01,$00,$03,$FF,$C0,$FF  ; row 16
        fcb     $00,$01,$00,$80,$FF,$F0,$FC  ; row 17
        fcb     $00,$01,$00,$F0,$03,$FC,$10  ; row 18
        fcb     $00,$01,$00,$F0,$0F,$FF,$00  ; row 19
        fcb     $00,$00,$00,$80,$3F,$FC,$00  ; row 20
        fcb     $00,$00,$00,$00,$0F,$00,$00  ; row 21
