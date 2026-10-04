* chtab5_029_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #29 (3x45 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_029_src:
        fcb     45,4  ; height=45 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $03,$FC,$00,$00  ; row 0
        fcb     $0F,$FF,$00,$00  ; row 1
        fcb     $0F,$FC,$00,$00  ; row 2
        fcb     $03,$FF,$00,$00  ; row 3
        fcb     $00,$17,$C0,$00  ; row 4
        fcb     $00,$10,$03,$C0  ; row 5
        fcb     $00,$10,$17,$FC  ; row 6
        fcb     $00,$15,$57,$FC  ; row 7
        fcb     $00,$15,$57,$FC  ; row 8
        fcb     $00,$15,$57,$FC  ; row 9
        fcb     $00,$15,$57,$C0  ; row 10
        fcb     $00,$17,$F5,$00  ; row 11
        fcb     $00,$FF,$FF,$00  ; row 12
        fcb     $03,$FF,$55,$00  ; row 13
        fcb     $0F,$FF,$55,$00  ; row 14
        fcb     $0F,$FF,$55,$00  ; row 15
        fcb     $7F,$FF,$F5,$50  ; row 16
        fcb     $7F,$FF,$F5,$50  ; row 17
        fcb     $FF,$FF,$F5,$50  ; row 18
        fcb     $FF,$FF,$C0,$10  ; row 19
        fcb     $FF,$FF,$C0,$10  ; row 20
        fcb     $FF,$FF,$C1,$50  ; row 21
        fcb     $0F,$FF,$C1,$00  ; row 22
        fcb     $7F,$FF,$F5,$00  ; row 23
        fcb     $7F,$FF,$F5,$00  ; row 24
        fcb     $7F,$FF,$55,$00  ; row 25
        fcb     $7F,$FF,$55,$00  ; row 26
        fcb     $0F,$FF,$C0,$00  ; row 27
        fcb     $0F,$FF,$C0,$00  ; row 28
        fcb     $0F,$FF,$00,$00  ; row 29
        fcb     $0F,$FF,$00,$00  ; row 30
        fcb     $0F,$FF,$00,$00  ; row 31
        fcb     $0F,$FF,$00,$00  ; row 32
        fcb     $0F,$FC,$00,$00  ; row 33
        fcb     $0F,$FF,$00,$00  ; row 34
        fcb     $03,$FF,$C0,$00  ; row 35
        fcb     $03,$FF,$F0,$00  ; row 36
        fcb     $00,$FF,$F0,$00  ; row 37
        fcb     $00,$FF,$FC,$00  ; row 38
        fcb     $00,$3F,$FC,$00  ; row 39
        fcb     $00,$3F,$FC,$00  ; row 40
        fcb     $00,$0F,$FF,$00  ; row 41
        fcb     $00,$3F,$FF,$00  ; row 42
        fcb     $03,$FF,$7F,$C0  ; row 43
        fcb     $00,$00,$FF,$C0  ; row 44
