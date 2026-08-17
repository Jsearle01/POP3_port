* v50_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #76 (5x47 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=261  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v50_src:
        fcb     47,8  ; height=47 rows, coco3_width=8 bytes/row (4px/byte)
        fcb     $00,$00,$00,$03,$F0,$00,$00,$00  ; row 0
        fcb     $00,$00,$00,$3F,$FF,$C0,$00,$00  ; row 1
        fcb     $00,$00,$00,$FF,$FF,$FC,$00,$00  ; row 2
        fcb     $00,$00,$00,$FF,$FF,$FF,$00,$00  ; row 3
        fcb     $00,$00,$00,$0F,$FF,$FF,$00,$00  ; row 4
        fcb     $00,$00,$00,$00,$FF,$FF,$00,$00  ; row 5
        fcb     $00,$00,$00,$05,$5F,$FC,$00,$00  ; row 6
        fcb     $00,$00,$00,$05,$5F,$C0,$00,$00  ; row 7
        fcb     $00,$00,$00,$3D,$FF,$C0,$00,$00  ; row 8
        fcb     $00,$00,$00,$20,$3F,$F0,$00,$00  ; row 9
        fcb     $00,$00,$00,$00,$3F,$FC,$00,$00  ; row 10
        fcb     $00,$00,$00,$00,$FF,$FC,$00,$00  ; row 11
        fcb     $00,$00,$00,$03,$FF,$FF,$00,$00  ; row 12
        fcb     $00,$00,$00,$03,$FF,$FF,$00,$00  ; row 13
        fcb     $00,$00,$00,$0F,$FF,$FF,$00,$00  ; row 14
        fcb     $00,$00,$00,$0F,$FF,$FF,$00,$00  ; row 15
        fcb     $00,$00,$00,$0F,$FF,$FF,$C0,$00  ; row 16
        fcb     $00,$00,$00,$0F,$FF,$FF,$C0,$00  ; row 17
        fcb     $00,$00,$00,$03,$FF,$FF,$C0,$00  ; row 18
        fcb     $00,$00,$00,$02,$BF,$FF,$C0,$00  ; row 19
        fcb     $00,$00,$00,$02,$BF,$FF,$F0,$00  ; row 20
        fcb     $00,$00,$00,$02,$BF,$FF,$F0,$00  ; row 21
        fcb     $00,$00,$00,$02,$BF,$FF,$F0,$00  ; row 22
        fcb     $00,$00,$00,$02,$BF,$FF,$F0,$00  ; row 23
        fcb     $00,$00,$00,$02,$BF,$FF,$FC,$00  ; row 24
        fcb     $00,$00,$00,$02,$AB,$FF,$FC,$00  ; row 25
        fcb     $00,$00,$00,$02,$AB,$FF,$FC,$00  ; row 26
        fcb     $00,$00,$00,$02,$AB,$FF,$FC,$00  ; row 27
        fcb     $00,$00,$00,$02,$AB,$FF,$FF,$00  ; row 28
        fcb     $00,$00,$00,$02,$AB,$FF,$FF,$00  ; row 29
        fcb     $00,$00,$00,$02,$AB,$FF,$FF,$00  ; row 30
        fcb     $00,$00,$00,$2A,$AA,$BF,$FF,$C0  ; row 31
        fcb     $00,$00,$00,$2A,$AA,$BF,$FF,$C0  ; row 32
        fcb     $00,$00,$00,$2A,$AA,$BF,$FF,$F0  ; row 33
        fcb     $00,$00,$00,$2A,$AA,$BF,$FF,$F0  ; row 34
        fcb     $00,$00,$02,$AA,$AA,$BF,$FF,$F0  ; row 35
        fcb     $00,$00,$02,$AA,$AA,$AB,$FF,$F0  ; row 36
        fcb     $00,$00,$02,$AA,$AB,$FB,$FF,$FC  ; row 37
        fcb     $00,$00,$2A,$AA,$AB,$FB,$FF,$FC  ; row 38
        fcb     $00,$00,$2A,$AA,$BF,$FB,$FF,$FC  ; row 39
        fcb     $00,$00,$2A,$AA,$BF,$FA,$BF,$FC  ; row 40
        fcb     $00,$02,$AA,$A0,$3F,$FF,$BF,$FC  ; row 41
        fcb     $00,$02,$AA,$A0,$3F,$FF,$BF,$FF  ; row 42
        fcb     $0F,$02,$AA,$00,$0F,$FF,$AB,$FF  ; row 43
        fcb     $03,$FF,$AA,$00,$00,$00,$FD,$FF  ; row 44
        fcb     $00,$3F,$FC,$00,$00,$03,$FF,$BF  ; row 45
        fcb     $00,$00,$F0,$00,$00,$3F,$FF,$BF  ; row 46
