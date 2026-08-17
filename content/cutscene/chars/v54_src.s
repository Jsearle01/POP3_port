* v54_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #80 (3x48 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=279  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v54_src:
        fcb     48,4  ; height=48 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $00,$3F,$00,$00  ; row 0
        fcb     $03,$FF,$FC,$00  ; row 1
        fcb     $0F,$FF,$FF,$C0  ; row 2
        fcb     $0F,$FF,$FF,$F0  ; row 3
        fcb     $00,$FF,$FF,$F0  ; row 4
        fcb     $00,$0F,$FF,$F0  ; row 5
        fcb     $00,$55,$FF,$C0  ; row 6
        fcb     $00,$55,$FC,$00  ; row 7
        fcb     $03,$DF,$FC,$00  ; row 8
        fcb     $02,$03,$FF,$C0  ; row 9
        fcb     $00,$03,$FF,$C0  ; row 10
        fcb     $00,$0F,$FF,$F0  ; row 11
        fcb     $00,$0F,$FF,$F0  ; row 12
        fcb     $00,$3F,$FF,$F0  ; row 13
        fcb     $00,$3F,$FF,$F0  ; row 14
        fcb     $00,$3F,$FF,$F0  ; row 15
        fcb     $00,$3F,$FF,$F0  ; row 16
        fcb     $00,$3F,$FF,$F0  ; row 17
        fcb     $00,$3F,$FF,$FC  ; row 18
        fcb     $00,$2B,$FF,$FC  ; row 19
        fcb     $00,$2B,$FF,$FC  ; row 20
        fcb     $00,$2B,$FF,$FC  ; row 21
        fcb     $00,$2B,$FF,$FC  ; row 22
        fcb     $00,$2B,$FF,$FC  ; row 23
        fcb     $00,$2B,$FF,$FC  ; row 24
        fcb     $00,$2B,$FF,$FC  ; row 25
        fcb     $00,$2B,$FF,$FC  ; row 26
        fcb     $00,$2B,$FF,$FC  ; row 27
        fcb     $00,$2B,$FF,$FC  ; row 28
        fcb     $00,$2B,$FF,$FC  ; row 29
        fcb     $00,$2B,$FF,$FC  ; row 30
        fcb     $00,$2B,$FF,$FC  ; row 31
        fcb     $00,$2B,$FF,$FC  ; row 32
        fcb     $00,$2B,$FF,$FC  ; row 33
        fcb     $00,$2B,$FF,$FC  ; row 34
        fcb     $00,$2B,$FF,$FC  ; row 35
        fcb     $00,$2B,$FF,$FC  ; row 36
        fcb     $00,$2A,$BF,$F0  ; row 37
        fcb     $00,$2A,$BF,$F0  ; row 38
        fcb     $00,$2A,$BF,$F0  ; row 39
        fcb     $00,$02,$BF,$F0  ; row 40
        fcb     $00,$02,$BF,$F0  ; row 41
        fcb     $00,$02,$BF,$F0  ; row 42
        fcb     $00,$02,$BF,$F0  ; row 43
        fcb     $00,$02,$AB,$F0  ; row 44
        fcb     $00,$03,$FB,$F0  ; row 45
        fcb     $00,$3F,$FB,$FC  ; row 46
        fcb     $03,$FF,$FF,$00  ; row 47
