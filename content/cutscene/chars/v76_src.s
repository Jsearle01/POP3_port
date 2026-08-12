* v76_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #102 (3x58 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=159  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v76_src:
        fcb     58,4  ; height=58 rows, coco3_width=4 bytes/row (4px/byte)
        fcb     $00,$00,$04,$00  ; row 0
        fcb     $00,$00,$05,$40  ; row 1
        fcb     $00,$00,$05,$40  ; row 2
        fcb     $00,$00,$05,$40  ; row 3
        fcb     $00,$00,$3F,$00  ; row 4
        fcb     $00,$00,$2A,$00  ; row 5
        fcb     $00,$00,$2A,$00  ; row 6
        fcb     $00,$00,$2A,$00  ; row 7
        fcb     $00,$00,$2A,$00  ; row 8
        fcb     $00,$3F,$AA,$00  ; row 9
        fcb     $03,$FF,$AA,$00  ; row 10
        fcb     $0F,$FF,$AA,$00  ; row 11
        fcb     $0F,$FF,$AA,$00  ; row 12
        fcb     $00,$FF,$AA,$00  ; row 13
        fcb     $00,$0F,$AA,$00  ; row 14
        fcb     $00,$42,$AB,$C0  ; row 15
        fcb     $00,$42,$AB,$C0  ; row 16
        fcb     $03,$C2,$AB,$C0  ; row 17
        fcb     $02,$02,$AB,$C0  ; row 18
        fcb     $00,$2A,$AB,$C0  ; row 19
        fcb     $00,$2A,$AB,$C0  ; row 20
        fcb     $00,$2A,$AB,$C0  ; row 21
        fcb     $02,$AA,$AB,$C0  ; row 22
        fcb     $02,$AA,$AB,$C0  ; row 23
        fcb     $02,$AA,$AB,$C0  ; row 24
        fcb     $02,$AA,$AB,$C0  ; row 25
        fcb     $02,$AA,$AB,$C0  ; row 26
        fcb     $02,$AA,$AB,$C0  ; row 27
        fcb     $02,$AA,$AB,$C0  ; row 28
        fcb     $02,$AA,$AB,$C0  ; row 29
        fcb     $00,$2A,$AB,$F0  ; row 30
        fcb     $00,$2A,$AB,$F0  ; row 31
        fcb     $00,$2A,$AB,$F0  ; row 32
        fcb     $00,$2A,$AB,$F0  ; row 33
        fcb     $00,$2A,$AB,$F0  ; row 34
        fcb     $00,$2A,$AB,$F0  ; row 35
        fcb     $00,$2A,$AB,$F0  ; row 36
        fcb     $00,$2A,$AB,$F0  ; row 37
        fcb     $00,$2A,$AB,$F0  ; row 38
        fcb     $00,$2A,$AB,$F0  ; row 39
        fcb     $00,$2A,$AB,$F0  ; row 40
        fcb     $00,$02,$AB,$F0  ; row 41
        fcb     $00,$02,$AB,$FC  ; row 42
        fcb     $00,$02,$AB,$FC  ; row 43
        fcb     $00,$02,$AB,$FC  ; row 44
        fcb     $00,$02,$AB,$FC  ; row 45
        fcb     $00,$02,$AB,$FC  ; row 46
        fcb     $00,$02,$AB,$FC  ; row 47
        fcb     $00,$02,$AB,$FC  ; row 48
        fcb     $00,$00,$2B,$FC  ; row 49
        fcb     $00,$00,$2B,$FC  ; row 50
        fcb     $00,$00,$2B,$F0  ; row 51
        fcb     $00,$00,$2A,$00  ; row 52
        fcb     $00,$00,$3F,$F0  ; row 53
        fcb     $00,$00,$3F,$FC  ; row 54
        fcb     $00,$00,$3F,$FC  ; row 55
        fcb     $00,$00,$FF,$C0  ; row 56
        fcb     $00,$0F,$FC,$00  ; row 57
