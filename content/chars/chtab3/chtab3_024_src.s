* chtab3_024_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #24 (4x24 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_024_src:
        fcb     24,7  ; height=24 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$0F,$F0,$00  ; row 0
        fcb     $0F,$FF,$00,$03,$FF,$FF,$C0  ; row 1
        fcb     $7F,$FF,$C3,$FF,$FF,$FF,$F0  ; row 2
        fcb     $FF,$FF,$FF,$FF,$FF,$FF,$F0  ; row 3
        fcb     $FF,$FF,$EA,$FF,$FF,$FF,$F0  ; row 4
        fcb     $FF,$EF,$EA,$FF,$FF,$FF,$C0  ; row 5
        fcb     $FE,$A8,$08,$3F,$FF,$FF,$C0  ; row 6
        fcb     $80,$00,$08,$3C,$3F,$FF,$00  ; row 7
        fcb     $00,$00,$08,$00,$3F,$FF,$00  ; row 8
        fcb     $00,$00,$08,$00,$FF,$F0,$00  ; row 9
        fcb     $00,$00,$0A,$AF,$FF,$C0,$00  ; row 10
        fcb     $00,$00,$0A,$FF,$FF,$C0,$00  ; row 11
        fcb     $00,$00,$AA,$FF,$FF,$00,$00  ; row 12
        fcb     $00,$00,$AA,$83,$FF,$00,$00  ; row 13
        fcb     $00,$00,$80,$83,$FF,$C0,$00  ; row 14
        fcb     $00,$00,$80,$80,$FF,$C0,$00  ; row 15
        fcb     $00,$00,$80,$F0,$FF,$F0,$00  ; row 16
        fcb     $00,$00,$80,$F0,$0F,$F0,$00  ; row 17
        fcb     $00,$00,$80,$80,$03,$FC,$00  ; row 18
        fcb     $00,$00,$80,$00,$00,$FF,$00  ; row 19
        fcb     $00,$00,$80,$00,$00,$FF,$00  ; row 20
        fcb     $00,$00,$00,$00,$00,$FF,$00  ; row 21
        fcb     $00,$00,$00,$00,$03,$FF,$C0  ; row 22
        fcb     $00,$00,$00,$00,$01,$50,$00  ; row 23
