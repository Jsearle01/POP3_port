* chtab5_021_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #21 (4x24 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_021_src:
        fcb     24,7  ; height=24 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$FF,$C0,$00,$00,$00,$00  ; row 0
        fcb     $03,$FF,$FC,$3F,$FF,$00,$00  ; row 1
        fcb     $0F,$FF,$FE,$F5,$7F,$F0,$00  ; row 2
        fcb     $7F,$F5,$57,$F5,$57,$FF,$00  ; row 3
        fcb     $7F,$55,$55,$7F,$57,$FF,$C0  ; row 4
        fcb     $00,$15,$55,$7F,$55,$7F,$F0  ; row 5
        fcb     $00,$00,$17,$FF,$F5,$7F,$FC  ; row 6
        fcb     $00,$00,$10,$0F,$F5,$7F,$FC  ; row 7
        fcb     $00,$00,$10,$03,$F5,$7F,$FC  ; row 8
        fcb     $03,$F5,$00,$3F,$57,$FF,$FC  ; row 9
        fcb     $03,$F5,$03,$F5,$7F,$FF,$F0  ; row 10
        fcb     $03,$F5,$03,$C3,$FF,$FF,$00  ; row 11
        fcb     $03,$FC,$03,$EF,$FF,$F0,$00  ; row 12
        fcb     $03,$FF,$03,$EF,$FF,$C0,$00  ; row 13
        fcb     $03,$FC,$00,$AF,$FF,$C0,$00  ; row 14
        fcb     $00,$00,$00,$3F,$FF,$F0,$00  ; row 15
        fcb     $00,$00,$00,$0F,$FF,$F0,$00  ; row 16
        fcb     $00,$00,$00,$03,$FF,$F0,$00  ; row 17
        fcb     $00,$00,$00,$03,$FF,$F0,$00  ; row 18
        fcb     $00,$00,$00,$3F,$FF,$F0,$00  ; row 19
        fcb     $00,$00,$00,$3F,$03,$FC,$00  ; row 20
        fcb     $00,$00,$00,$00,$03,$FC,$00  ; row 21
        fcb     $00,$00,$00,$00,$3F,$F0,$00  ; row 22
        fcb     $00,$00,$00,$00,$10,$00,$00  ; row 23
