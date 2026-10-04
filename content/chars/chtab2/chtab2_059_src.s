* chtab2_059_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #59 (3x22 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_059_src:
        fcb     22,6  ; height=22 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $0F,$FC,$00,$00,$00,$00  ; row 0
        fcb     $FF,$FF,$00,$00,$00,$00  ; row 1
        fcb     $FF,$FE,$FF,$00,$00,$00  ; row 2
        fcb     $03,$FF,$FF,$FF,$00,$00  ; row 3
        fcb     $15,$7F,$FF,$FF,$F0,$00  ; row 4
        fcb     $15,$7F,$FF,$FF,$FC,$00  ; row 5
        fcb     $15,$57,$FF,$FF,$FF,$C0  ; row 6
        fcb     $00,$17,$FF,$FF,$FF,$C0  ; row 7
        fcb     $00,$17,$FF,$FF,$FF,$C0  ; row 8
        fcb     $00,$17,$FF,$FF,$FF,$C0  ; row 9
        fcb     $00,$17,$FF,$FF,$FF,$00  ; row 10
        fcb     $00,$17,$FF,$FF,$FC,$00  ; row 11
        fcb     $00,$17,$FF,$FF,$C0,$00  ; row 12
        fcb     $00,$17,$FF,$FE,$80,$00  ; row 13
        fcb     $00,$17,$FF,$FC,$00,$00  ; row 14
        fcb     $00,$17,$FF,$FF,$FF,$00  ; row 15
        fcb     $00,$10,$3F,$FF,$FF,$00  ; row 16
        fcb     $00,$10,$0F,$C0,$FF,$00  ; row 17
        fcb     $00,$10,$00,$00,$FF,$00  ; row 18
        fcb     $00,$10,$00,$00,$FC,$00  ; row 19
        fcb     $00,$10,$00,$03,$F0,$00  ; row 20
        fcb     $01,$50,$00,$00,$00,$00  ; row 21
