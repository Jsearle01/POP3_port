* v77_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #103 (2x54 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=157  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v77_src:
        fcb     54,4  ; height=54 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $05,$40,$00,$00  ; row 0
        fcb     $00,$40,$00,$00  ; row 1
        fcb     $03,$C0,$00,$00  ; row 2
        fcb     $02,$A0,$00,$00  ; row 3
        fcb     $02,$A0,$00,$00  ; row 4
        fcb     $02,$A0,$00,$00  ; row 5
        fcb     $02,$A0,$00,$00  ; row 6
        fcb     $2A,$BF,$C0,$00  ; row 7
        fcb     $FA,$BF,$FC,$00  ; row 8
        fcb     $FA,$AB,$FF,$00  ; row 9
        fcb     $02,$AB,$FF,$00  ; row 10
        fcb     $02,$AB,$FF,$00  ; row 11
        fcb     $04,$2B,$FC,$00  ; row 12
        fcb     $04,$2B,$F0,$00  ; row 13
        fcb     $BC,$2B,$F0,$00  ; row 14
        fcb     $00,$2B,$FC,$00  ; row 15
        fcb     $00,$2B,$FC,$00  ; row 16
        fcb     $02,$AB,$FC,$00  ; row 17
        fcb     $02,$AB,$FC,$00  ; row 18
        fcb     $02,$AB,$FC,$00  ; row 19
        fcb     $02,$AB,$FF,$00  ; row 20
        fcb     $02,$AB,$FF,$00  ; row 21
        fcb     $02,$AB,$FF,$00  ; row 22
        fcb     $02,$AB,$FF,$00  ; row 23
        fcb     $02,$AB,$FF,$00  ; row 24
        fcb     $02,$AA,$BF,$00  ; row 25
        fcb     $02,$AA,$BF,$00  ; row 26
        fcb     $02,$AA,$BF,$00  ; row 27
        fcb     $02,$AA,$BF,$00  ; row 28
        fcb     $02,$AA,$BF,$00  ; row 29
        fcb     $02,$AA,$BF,$C0  ; row 30
        fcb     $02,$AA,$BF,$C0  ; row 31
        fcb     $00,$2A,$BF,$C0  ; row 32
        fcb     $00,$2A,$BF,$C0  ; row 33
        fcb     $00,$2A,$BF,$C0  ; row 34
        fcb     $00,$2A,$BF,$C0  ; row 35
        fcb     $00,$2A,$BF,$C0  ; row 36
        fcb     $00,$2A,$BF,$C0  ; row 37
        fcb     $00,$2A,$BF,$C0  ; row 38
        fcb     $00,$2A,$BF,$C0  ; row 39
        fcb     $00,$2A,$BF,$C0  ; row 40
        fcb     $00,$2A,$BF,$C0  ; row 41
        fcb     $00,$2A,$BF,$C0  ; row 42
        fcb     $00,$02,$BF,$C0  ; row 43
        fcb     $00,$02,$BF,$C0  ; row 44
        fcb     $00,$02,$BF,$C0  ; row 45
        fcb     $00,$02,$BF,$C0  ; row 46
        fcb     $00,$02,$BF,$C0  ; row 47
        fcb     $00,$02,$BF,$C0  ; row 48
        fcb     $00,$02,$BF,$00  ; row 49
        fcb     $00,$02,$A0,$00  ; row 50
        fcb     $00,$00,$FF,$00  ; row 51
        fcb     $00,$0F,$FF,$00  ; row 52
        fcb     $00,$FF,$FC,$00  ; row 53
