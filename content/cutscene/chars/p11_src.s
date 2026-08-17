* p11_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #25 (3x43 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=125  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

p11_src:
        fcb     43,5  ; height=43 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$FB,$F0,$00,$00  ; row 0
        fcb     $02,$00,$FC,$00,$00  ; row 1
        fcb     $00,$00,$04,$00,$00  ; row 2
        fcb     $00,$40,$0F,$00,$00  ; row 3
        fcb     $00,$54,$02,$00,$00  ; row 4
        fcb     $00,$54,$02,$00,$00  ; row 5
        fcb     $00,$40,$02,$00,$00  ; row 6
        fcb     $00,$00,$00,$40,$00  ; row 7
        fcb     $00,$00,$00,$40,$00  ; row 8
        fcb     $00,$00,$40,$40,$00  ; row 9
        fcb     $00,$3D,$40,$40,$00  ; row 10
        fcb     $00,$FD,$43,$C0,$00  ; row 11
        fcb     $03,$FD,$43,$C0,$00  ; row 12
        fcb     $03,$FD,$42,$00,$00  ; row 13
        fcb     $00,$FD,$42,$00,$00  ; row 14
        fcb     $04,$3D,$42,$00,$00  ; row 15
        fcb     $05,$55,$40,$00,$00  ; row 16
        fcb     $00,$3F,$F0,$00,$00  ; row 17
        fcb     $00,$3F,$F0,$00,$00  ; row 18
        fcb     $00,$3F,$FC,$00,$00  ; row 19
        fcb     $00,$3F,$FC,$00,$00  ; row 20
        fcb     $00,$3F,$FF,$00,$00  ; row 21
        fcb     $00,$3F,$FF,$00,$00  ; row 22
        fcb     $00,$3F,$FF,$00,$00  ; row 23
        fcb     $00,$3F,$FF,$00,$00  ; row 24
        fcb     $00,$FF,$FF,$C0,$00  ; row 25
        fcb     $00,$FF,$FF,$C0,$00  ; row 26
        fcb     $00,$FF,$FA,$A0,$00  ; row 27
        fcb     $00,$FF,$FA,$A0,$00  ; row 28
        fcb     $00,$FF,$AA,$A0,$00  ; row 29
        fcb     $00,$FF,$AA,$A0,$00  ; row 30
        fcb     $00,$FA,$AA,$AA,$00  ; row 31
        fcb     $02,$AA,$AA,$AA,$00  ; row 32
        fcb     $02,$AA,$AA,$AA,$00  ; row 33
        fcb     $02,$AA,$AA,$AA,$00  ; row 34
        fcb     $02,$AA,$AA,$AA,$A0  ; row 35
        fcb     $02,$AA,$AA,$AA,$A0  ; row 36
        fcb     $02,$AA,$AA,$02,$A0  ; row 37
        fcb     $02,$AA,$A0,$00,$00  ; row 38
        fcb     $00,$00,$3C,$00,$00  ; row 39
        fcb     $00,$00,$3C,$00,$00  ; row 40
        fcb     $00,$03,$FF,$00,$00  ; row 41
        fcb     $00,$3F,$FF,$00,$00  ; row 42
