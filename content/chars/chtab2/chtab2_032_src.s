* chtab2_032_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB2
*         POP cel: #32 (2x48 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab2_032_src:
        fcb     48,3  ; height=48 rows, coco3_width=3 bytes/row (4px/byte)
        fcb     $00,$80,$00  ; row 0
        fcb     $00,$80,$00  ; row 1
        fcb     $00,$80,$00  ; row 2
        fcb     $00,$80,$00  ; row 3
        fcb     $00,$80,$00  ; row 4
        fcb     $00,$A8,$00  ; row 5
        fcb     $7E,$AF,$C0  ; row 6
        fcb     $7E,$AF,$C0  ; row 7
        fcb     $00,$AF,$C0  ; row 8
        fcb     $0A,$AF,$C0  ; row 9
        fcb     $0A,$AF,$00  ; row 10
        fcb     $0A,$A8,$00  ; row 11
        fcb     $00,$AF,$C0  ; row 12
        fcb     $0F,$EF,$F0  ; row 13
        fcb     $0F,$EF,$F0  ; row 14
        fcb     $7F,$EF,$F0  ; row 15
        fcb     $7F,$FF,$F0  ; row 16
        fcb     $7F,$FF,$C0  ; row 17
        fcb     $FF,$FF,$C0  ; row 18
        fcb     $FF,$FF,$C0  ; row 19
        fcb     $FF,$FF,$F0  ; row 20
        fcb     $FF,$FF,$F0  ; row 21
        fcb     $FF,$FF,$FC  ; row 22
        fcb     $0F,$FF,$FC  ; row 23
        fcb     $0F,$FF,$FC  ; row 24
        fcb     $0F,$FF,$FC  ; row 25
        fcb     $0F,$FF,$FC  ; row 26
        fcb     $0F,$FF,$FC  ; row 27
        fcb     $0F,$FF,$F0  ; row 28
        fcb     $0F,$FF,$F0  ; row 29
        fcb     $0F,$FF,$F0  ; row 30
        fcb     $03,$FF,$F0  ; row 31
        fcb     $03,$FF,$F0  ; row 32
        fcb     $03,$FF,$F0  ; row 33
        fcb     $03,$FF,$F0  ; row 34
        fcb     $03,$FF,$F0  ; row 35
        fcb     $00,$FF,$FC  ; row 36
        fcb     $00,$FF,$FC  ; row 37
        fcb     $00,$FF,$FC  ; row 38
        fcb     $00,$FF,$FC  ; row 39
        fcb     $00,$FF,$FC  ; row 40
        fcb     $00,$3F,$F0  ; row 41
        fcb     $00,$03,$F0  ; row 42
        fcb     $00,$03,$FC  ; row 43
        fcb     $00,$0F,$FC  ; row 44
        fcb     $00,$0F,$F0  ; row 45
        fcb     $00,$3F,$00  ; row 46
        fcb     $00,$10,$00  ; row 47
