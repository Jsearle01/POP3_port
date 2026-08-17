* v59_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #85 (3x48 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=153  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v59_src:
        fcb     48,5  ; height=48 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$03,$F0,$00,$00  ; row 0
        fcb     $00,$3F,$FF,$C0,$00  ; row 1
        fcb     $00,$FF,$FF,$FC,$00  ; row 2
        fcb     $00,$FF,$FF,$FF,$00  ; row 3
        fcb     $00,$3F,$FF,$FF,$00  ; row 4
        fcb     $00,$03,$FF,$FF,$00  ; row 5
        fcb     $00,$05,$FF,$FC,$00  ; row 6
        fcb     $00,$05,$FF,$C0,$00  ; row 7
        fcb     $00,$3D,$FF,$C0,$00  ; row 8
        fcb     $00,$20,$FF,$FF,$00  ; row 9
        fcb     $00,$03,$FF,$FF,$C0  ; row 10
        fcb     $00,$03,$FF,$FF,$F0  ; row 11
        fcb     $00,$0F,$FF,$FF,$F0  ; row 12
        fcb     $00,$0F,$FF,$FF,$F0  ; row 13
        fcb     $00,$0F,$FF,$FF,$F0  ; row 14
        fcb     $00,$0F,$FF,$FF,$F0  ; row 15
        fcb     $00,$0F,$FF,$FF,$F0  ; row 16
        fcb     $00,$0F,$FF,$FF,$F0  ; row 17
        fcb     $00,$3F,$FF,$FF,$F0  ; row 18
        fcb     $00,$3F,$FF,$FF,$F0  ; row 19
        fcb     $00,$3F,$FF,$FF,$F0  ; row 20
        fcb     $00,$3F,$FF,$FF,$F0  ; row 21
        fcb     $00,$3F,$FF,$FF,$F0  ; row 22
        fcb     $00,$3F,$FF,$FF,$C0  ; row 23
        fcb     $00,$3F,$FF,$FF,$C0  ; row 24
        fcb     $00,$3F,$FF,$FF,$C0  ; row 25
        fcb     $00,$3F,$FF,$FF,$C0  ; row 26
        fcb     $00,$FF,$FF,$FF,$F0  ; row 27
        fcb     $00,$FF,$FF,$FF,$F0  ; row 28
        fcb     $00,$FF,$FF,$FF,$F0  ; row 29
        fcb     $00,$3F,$FF,$FF,$F0  ; row 30
        fcb     $00,$3F,$FF,$FF,$F0  ; row 31
        fcb     $00,$3F,$FF,$FF,$F0  ; row 32
        fcb     $00,$2B,$FF,$FF,$F0  ; row 33
        fcb     $00,$2B,$FF,$FF,$F0  ; row 34
        fcb     $00,$2B,$FF,$FF,$FC  ; row 35
        fcb     $00,$2B,$FF,$FF,$FC  ; row 36
        fcb     $00,$2B,$FF,$FF,$FC  ; row 37
        fcb     $00,$2B,$FF,$FF,$FC  ; row 38
        fcb     $00,$2B,$FF,$FF,$FC  ; row 39
        fcb     $00,$03,$FF,$FF,$FC  ; row 40
        fcb     $00,$02,$BF,$FF,$FC  ; row 41
        fcb     $00,$02,$BF,$FF,$FF  ; row 42
        fcb     $00,$02,$BF,$FF,$FC  ; row 43
        fcb     $00,$00,$3F,$FF,$FF  ; row 44
        fcb     $00,$3F,$FF,$00,$FF  ; row 45
        fcb     $03,$FF,$FF,$00,$20  ; row 46
        fcb     $03,$FF,$F0,$00,$00  ; row 47
