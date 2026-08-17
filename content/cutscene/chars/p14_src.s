* p14_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #37 (3x43 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=117  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

p14_src:
        fcb     43,5  ; height=43 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$00,$0F,$FC,$00  ; row 0
        fcb     $00,$00,$F0,$03,$C0  ; row 1
        fcb     $00,$00,$40,$02,$00  ; row 2
        fcb     $00,$00,$00,$04,$00  ; row 3
        fcb     $00,$02,$00,$54,$00  ; row 4
        fcb     $00,$0F,$00,$54,$00  ; row 5
        fcb     $00,$04,$00,$04,$00  ; row 6
        fcb     $00,$04,$00,$00,$00  ; row 7
        fcb     $00,$20,$00,$00,$00  ; row 8
        fcb     $00,$20,$04,$00,$00  ; row 9
        fcb     $00,$20,$05,$40,$00  ; row 10
        fcb     $00,$20,$05,$F0,$00  ; row 11
        fcb     $00,$20,$5F,$FC,$00  ; row 12
        fcb     $00,$00,$5F,$FC,$00  ; row 13
        fcb     $00,$00,$5F,$F0,$00  ; row 14
        fcb     $00,$00,$5F,$C0,$00  ; row 15
        fcb     $00,$05,$FF,$C0,$00  ; row 16
        fcb     $00,$05,$FF,$C0,$00  ; row 17
        fcb     $00,$05,$FF,$C0,$00  ; row 18
        fcb     $00,$55,$FF,$C0,$00  ; row 19
        fcb     $00,$5F,$FF,$C0,$00  ; row 20
        fcb     $00,$43,$FF,$C0,$00  ; row 21
        fcb     $00,$5F,$FF,$C0,$00  ; row 22
        fcb     $05,$5F,$FF,$C0,$00  ; row 23
        fcb     $05,$5F,$FF,$C0,$00  ; row 24
        fcb     $02,$AB,$FF,$F0,$00  ; row 25
        fcb     $02,$A0,$FF,$F0,$00  ; row 26
        fcb     $02,$AA,$BF,$F0,$00  ; row 27
        fcb     $02,$AA,$0F,$FC,$00  ; row 28
        fcb     $02,$AA,$AB,$FC,$00  ; row 29
        fcb     $2A,$AA,$AA,$BC,$00  ; row 30
        fcb     $2A,$AA,$AA,$A0,$00  ; row 31
        fcb     $2A,$AA,$AA,$A0,$00  ; row 32
        fcb     $2A,$AA,$AA,$AA,$00  ; row 33
        fcb     $2A,$AA,$AA,$AA,$00  ; row 34
        fcb     $2A,$AA,$AA,$AA,$00  ; row 35
        fcb     $2A,$AA,$AA,$AA,$A0  ; row 36
        fcb     $2A,$AA,$AA,$AA,$A0  ; row 37
        fcb     $00,$00,$00,$00,$00  ; row 38
        fcb     $0F,$00,$00,$0F,$00  ; row 39
        fcb     $0F,$00,$00,$0F,$F0  ; row 40
        fcb     $BF,$F0,$00,$0F,$FF  ; row 41
        fcb     $BF,$FC,$00,$00,$00  ; row 42
