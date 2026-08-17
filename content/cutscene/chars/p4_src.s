* p4_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #28 (3x42 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=125  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

p4_src:
        fcb     42,5  ; height=42 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$3F,$00,$00,$00  ; row 0
        fcb     $02,$00,$3C,$00,$00  ; row 1
        fcb     $0F,$00,$0F,$00,$00  ; row 2
        fcb     $0F,$00,$0F,$00,$00  ; row 3
        fcb     $04,$00,$3F,$C0,$00  ; row 4
        fcb     $04,$00,$3F,$F0,$00  ; row 5
        fcb     $02,$00,$03,$C0,$00  ; row 6
        fcb     $00,$00,$00,$00,$00  ; row 7
        fcb     $55,$40,$00,$00,$00  ; row 8
        fcb     $55,$40,$00,$00,$00  ; row 9
        fcb     $55,$54,$00,$40,$00  ; row 10
        fcb     $55,$55,$55,$40,$00  ; row 11
        fcb     $5F,$FF,$FD,$40,$00  ; row 12
        fcb     $5F,$FF,$FD,$40,$00  ; row 13
        fcb     $43,$FF,$FD,$40,$00  ; row 14
        fcb     $43,$FF,$FD,$40,$00  ; row 15
        fcb     $55,$FF,$FC,$00,$00  ; row 16
        fcb     $00,$FF,$FC,$00,$00  ; row 17
        fcb     $00,$FF,$FF,$00,$00  ; row 18
        fcb     $03,$FF,$FF,$00,$00  ; row 19
        fcb     $03,$FF,$FF,$C0,$00  ; row 20
        fcb     $03,$FF,$FF,$C0,$00  ; row 21
        fcb     $03,$FF,$FF,$F0,$00  ; row 22
        fcb     $03,$FF,$FB,$F0,$00  ; row 23
        fcb     $00,$FF,$F0,$FC,$00  ; row 24
        fcb     $00,$FF,$FA,$BF,$00  ; row 25
        fcb     $00,$3F,$FA,$0F,$00  ; row 26
        fcb     $00,$3F,$FA,$AB,$C0  ; row 27
        fcb     $00,$0F,$FA,$A0,$F0  ; row 28
        fcb     $00,$2A,$AA,$AA,$A0  ; row 29
        fcb     $00,$2A,$AA,$AA,$A0  ; row 30
        fcb     $00,$2A,$AA,$AA,$AA  ; row 31
        fcb     $02,$AA,$AA,$AA,$AA  ; row 32
        fcb     $02,$AA,$AA,$AA,$AA  ; row 33
        fcb     $02,$AA,$AA,$AA,$AA  ; row 34
        fcb     $2A,$AA,$AA,$AA,$AA  ; row 35
        fcb     $02,$AA,$AA,$A0,$00  ; row 36
        fcb     $00,$00,$00,$00,$00  ; row 37
        fcb     $00,$04,$03,$C0,$00  ; row 38
        fcb     $00,$3C,$03,$C0,$00  ; row 39
        fcb     $00,$3C,$0F,$C0,$00  ; row 40
        fcb     $00,$3F,$FF,$C0,$00  ; row 41
