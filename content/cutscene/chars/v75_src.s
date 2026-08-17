* v75_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #101 (3x56 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=159  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v75_src:
        fcb     56,6  ; height=56 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $00,$00,$00,$05,$40,$00  ; row 0
        fcb     $00,$00,$00,$05,$40,$00  ; row 1
        fcb     $00,$00,$00,$05,$40,$00  ; row 2
        fcb     $00,$00,$02,$A0,$54,$00  ; row 3
        fcb     $00,$00,$02,$A0,$00,$00  ; row 4
        fcb     $00,$00,$2A,$A0,$00,$00  ; row 5
        fcb     $00,$00,$2A,$00,$00,$00  ; row 6
        fcb     $03,$FF,$AA,$00,$00,$00  ; row 7
        fcb     $BF,$FF,$AA,$00,$00,$00  ; row 8
        fcb     $FF,$FA,$A0,$00,$00,$00  ; row 9
        fcb     $FF,$FA,$A0,$00,$00,$00  ; row 10
        fcb     $0F,$FA,$A0,$00,$00,$00  ; row 11
        fcb     $00,$FA,$A0,$00,$00,$00  ; row 12
        fcb     $05,$42,$A0,$00,$00,$00  ; row 13
        fcb     $05,$42,$A0,$00,$00,$00  ; row 14
        fcb     $BD,$FA,$A0,$00,$00,$00  ; row 15
        fcb     $20,$FA,$BC,$00,$00,$00  ; row 16
        fcb     $2B,$FA,$BC,$00,$00,$00  ; row 17
        fcb     $02,$AA,$BC,$00,$00,$00  ; row 18
        fcb     $02,$AA,$BC,$00,$00,$00  ; row 19
        fcb     $02,$AA,$BC,$00,$00,$00  ; row 20
        fcb     $02,$AA,$BF,$00,$00,$00  ; row 21
        fcb     $02,$AA,$BF,$00,$00,$00  ; row 22
        fcb     $02,$AA,$BF,$00,$00,$00  ; row 23
        fcb     $02,$AA,$BF,$00,$00,$00  ; row 24
        fcb     $02,$AA,$BF,$00,$00,$00  ; row 25
        fcb     $02,$AA,$BF,$00,$00,$00  ; row 26
        fcb     $02,$AA,$BF,$C0,$00,$00  ; row 27
        fcb     $02,$AA,$BF,$C0,$00,$00  ; row 28
        fcb     $02,$AA,$BF,$C0,$00,$00  ; row 29
        fcb     $02,$AA,$BF,$C0,$00,$00  ; row 30
        fcb     $02,$AA,$BF,$F0,$00,$00  ; row 31
        fcb     $02,$AA,$AB,$F0,$00,$00  ; row 32
        fcb     $00,$2A,$AB,$F0,$00,$00  ; row 33
        fcb     $00,$2A,$AB,$FC,$00,$00  ; row 34
        fcb     $00,$2A,$AB,$FC,$00,$00  ; row 35
        fcb     $00,$2A,$AB,$FF,$00,$00  ; row 36
        fcb     $00,$2A,$AB,$FF,$00,$00  ; row 37
        fcb     $00,$2A,$AB,$FF,$00,$00  ; row 38
        fcb     $00,$2A,$AB,$FF,$C0,$00  ; row 39
        fcb     $00,$2A,$AB,$FF,$F0,$00  ; row 40
        fcb     $00,$2A,$AB,$FF,$F0,$00  ; row 41
        fcb     $00,$02,$AB,$FF,$FF,$C0  ; row 42
        fcb     $00,$02,$AB,$FF,$FF,$C0  ; row 43
        fcb     $00,$02,$AA,$BF,$FF,$C0  ; row 44
        fcb     $00,$02,$AA,$BF,$FF,$00  ; row 45
        fcb     $00,$02,$AA,$BF,$FC,$00  ; row 46
        fcb     $00,$02,$AA,$BF,$F0,$00  ; row 47
        fcb     $00,$00,$2A,$AA,$00,$00  ; row 48
        fcb     $00,$00,$2A,$AA,$00,$00  ; row 49
        fcb     $00,$00,$2A,$A0,$00,$00  ; row 50
        fcb     $00,$00,$03,$F0,$00,$00  ; row 51
        fcb     $00,$00,$03,$F0,$00,$00  ; row 52
        fcb     $00,$00,$0F,$FC,$00,$00  ; row 53
        fcb     $00,$00,$3F,$FC,$00,$00  ; row 54
        fcb     $00,$03,$FF,$00,$00,$00  ; row 55
