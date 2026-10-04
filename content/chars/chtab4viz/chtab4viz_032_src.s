* chtab4viz_032_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.VIZ
*         POP cel: #32 (7x11 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4viz_032_src:
        fcb     11,11  ; height=11 rows, coco3_width=11 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$00,$00,$3F,$FC,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$00,$00,$3F,$FF,$FF,$C0,$00,$00  ; row 1
        fcb     $00,$00,$00,$0F,$FF,$F5,$57,$FF,$F0,$FF,$00  ; row 2
        fcb     $00,$00,$00,$3F,$FF,$55,$57,$FF,$F7,$FF,$F0  ; row 3
        fcb     $00,$00,$00,$FF,$FF,$55,$57,$FF,$EF,$FF,$F0  ; row 4
        fcb     $00,$00,$03,$FF,$F5,$55,$55,$57,$FF,$FF,$FC  ; row 5
        fcb     $00,$3F,$FF,$FF,$F5,$55,$55,$50,$AF,$FF,$FC  ; row 6
        fcb     $03,$FF,$FF,$FF,$C1,$01,$55,$50,$AA,$FF,$FC  ; row 7
        fcb     $03,$FF,$FF,$F5,$0A,$81,$55,$57,$EA,$FF,$FC  ; row 8
        fcb     $03,$FF,$FF,$55,$0A,$81,$55,$7F,$EA,$FF,$F0  ; row 9
        fcb     $01,$00,$15,$55,$55,$55,$55,$55,$00,$FF,$C0  ; row 10
