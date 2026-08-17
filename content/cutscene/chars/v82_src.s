* v82_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB7
*         POP cel: #5 (2x48 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=155  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v82_src:
        fcb     48,4  ; height=48 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $03,$F0,$00,$00  ; row 0
        fcb     $BF,$FF,$C0,$00  ; row 1
        fcb     $FF,$FF,$FC,$00  ; row 2
        fcb     $FF,$FF,$FF,$00  ; row 3
        fcb     $0F,$FF,$FF,$00  ; row 4
        fcb     $00,$FF,$FF,$00  ; row 5
        fcb     $05,$5F,$FC,$00  ; row 6
        fcb     $05,$5F,$C0,$00  ; row 7
        fcb     $BD,$FF,$C0,$00  ; row 8
        fcb     $20,$3F,$FC,$00  ; row 9
        fcb     $00,$3F,$FC,$00  ; row 10
        fcb     $00,$FF,$FF,$00  ; row 11
        fcb     $00,$FF,$FF,$00  ; row 12
        fcb     $03,$FF,$FF,$00  ; row 13
        fcb     $03,$FF,$FF,$00  ; row 14
        fcb     $03,$FF,$FF,$00  ; row 15
        fcb     $03,$FF,$FF,$00  ; row 16
        fcb     $03,$FF,$FF,$00  ; row 17
        fcb     $03,$FF,$FF,$C0  ; row 18
        fcb     $02,$BF,$FF,$C0  ; row 19
        fcb     $02,$BF,$FF,$C0  ; row 20
        fcb     $02,$BF,$FF,$C0  ; row 21
        fcb     $02,$BF,$FF,$C0  ; row 22
        fcb     $02,$BF,$FF,$C0  ; row 23
        fcb     $02,$BF,$FF,$C0  ; row 24
        fcb     $02,$BF,$FF,$C0  ; row 25
        fcb     $04,$3F,$FF,$C0  ; row 26
        fcb     $04,$3F,$FF,$C0  ; row 27
        fcb     $04,$3F,$FF,$C0  ; row 28
        fcb     $00,$3F,$FF,$C0  ; row 29
        fcb     $02,$BF,$FF,$C0  ; row 30
        fcb     $02,$BF,$FF,$C0  ; row 31
        fcb     $02,$BF,$FF,$C0  ; row 32
        fcb     $02,$BF,$FF,$C0  ; row 33
        fcb     $02,$BF,$FF,$C0  ; row 34
        fcb     $02,$AB,$FF,$C0  ; row 35
        fcb     $02,$AB,$FF,$C0  ; row 36
        fcb     $02,$AB,$FF,$00  ; row 37
        fcb     $02,$AB,$FF,$00  ; row 38
        fcb     $02,$AB,$FF,$00  ; row 39
        fcb     $00,$2B,$FF,$00  ; row 40
        fcb     $00,$2B,$FF,$00  ; row 41
        fcb     $00,$2B,$FF,$00  ; row 42
        fcb     $00,$2B,$FF,$00  ; row 43
        fcb     $00,$2A,$BF,$00  ; row 44
        fcb     $00,$3F,$BF,$00  ; row 45
        fcb     $03,$FF,$BF,$C0  ; row 46
        fcb     $BF,$FF,$F0,$00  ; row 47
