* chtab5_023_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #23 (4x32 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_023_src:
        fcb     32,6  ; height=32 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $00,$3F,$00,$00,$00,$00  ; row 0
        fcb     $03,$FF,$F0,$00,$00,$00  ; row 1
        fcb     $0F,$FF,$FC,$00,$00,$00  ; row 2
        fcb     $7F,$FF,$F7,$FF,$C0,$00  ; row 3
        fcb     $7F,$55,$57,$F5,$7C,$00  ; row 4
        fcb     $00,$15,$57,$F5,$7F,$00  ; row 5
        fcb     $00,$15,$7F,$F5,$7F,$C0  ; row 6
        fcb     $00,$F5,$7F,$FF,$57,$F0  ; row 7
        fcb     $03,$F5,$57,$FF,$57,$FC  ; row 8
        fcb     $00,$FF,$00,$3F,$57,$FC  ; row 9
        fcb     $03,$FC,$00,$0F,$F5,$7F  ; row 10
        fcb     $03,$FF,$00,$00,$F5,$7F  ; row 11
        fcb     $03,$FF,$00,$00,$15,$7F  ; row 12
        fcb     $00,$00,$00,$01,$57,$FF  ; row 13
        fcb     $00,$00,$00,$01,$7F,$FF  ; row 14
        fcb     $00,$00,$00,$15,$7F,$FC  ; row 15
        fcb     $00,$00,$00,$17,$FF,$F0  ; row 16
        fcb     $00,$00,$00,$3F,$FF,$C0  ; row 17
        fcb     $00,$00,$03,$FF,$FF,$00  ; row 18
        fcb     $00,$00,$0F,$FF,$FC,$00  ; row 19
        fcb     $00,$00,$0F,$FF,$FC,$00  ; row 20
        fcb     $00,$00,$0F,$FF,$FC,$00  ; row 21
        fcb     $00,$00,$03,$FF,$FC,$00  ; row 22
        fcb     $00,$00,$03,$FF,$FF,$00  ; row 23
        fcb     $00,$00,$00,$FF,$FF,$C0  ; row 24
        fcb     $00,$00,$00,$FF,$FF,$C0  ; row 25
        fcb     $00,$00,$00,$0F,$FF,$C0  ; row 26
        fcb     $00,$00,$00,$0F,$FF,$C0  ; row 27
        fcb     $00,$00,$00,$0F,$FF,$C0  ; row 28
        fcb     $00,$00,$00,$FF,$7F,$C0  ; row 29
        fcb     $00,$00,$00,$00,$3F,$F0  ; row 30
        fcb     $00,$00,$00,$00,$FF,$C0  ; row 31
