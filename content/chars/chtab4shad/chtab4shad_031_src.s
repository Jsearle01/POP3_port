* chtab4shad_031_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.SHAD
*         POP cel: #31 (6x19 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4shad_031_src:
        fcb     19,10  ; height=19 rows, coco3_width=10 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$0A,$80,$00,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$00,$0A,$80,$00,$00,$00,$00  ; row 1
        fcb     $00,$00,$00,$00,$0A,$F5,$00,$00,$00,$00  ; row 2
        fcb     $00,$00,$00,$00,$00,$15,$00,$00,$00,$00  ; row 3
        fcb     $00,$00,$00,$00,$00,$15,$50,$00,$00,$00  ; row 4
        fcb     $00,$00,$00,$00,$00,$15,$55,$00,$00,$00  ; row 5
        fcb     $00,$00,$00,$00,$00,$01,$55,$00,$00,$00  ; row 6
        fcb     $00,$00,$00,$00,$00,$00,$3E,$AF,$F0,$00  ; row 7
        fcb     $00,$00,$00,$00,$00,$03,$FE,$AF,$FF,$C0  ; row 8
        fcb     $00,$00,$00,$00,$00,$03,$FE,$AF,$FF,$F0  ; row 9
        fcb     $00,$00,$00,$00,$00,$0F,$FE,$AF,$FF,$F0  ; row 10
        fcb     $00,$00,$00,$00,$00,$FF,$EA,$AF,$FF,$F0  ; row 11
        fcb     $00,$03,$F0,$00,$10,$FF,$EA,$AF,$FF,$C0  ; row 12
        fcb     $00,$03,$FF,$01,$50,$FF,$00,$3F,$FF,$00  ; row 13
        fcb     $00,$00,$01,$55,$57,$FF,$FC,$3F,$F0,$00  ; row 14
        fcb     $00,$00,$15,$55,$57,$FC,$3F,$FF,$FC,$00  ; row 15
        fcb     $00,$0F,$55,$55,$55,$55,$7F,$FF,$FC,$00  ; row 16
        fcb     $00,$0F,$F7,$E8,$15,$55,$57,$FF,$FC,$00  ; row 17
        fcb     $00,$00,$17,$EA,$F5,$55,$50,$FF,$C0,$00  ; row 18
