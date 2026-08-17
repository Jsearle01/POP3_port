* vwalk53_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #79 (4x47 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=279  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

vwalk53_src:
        fcb     47,7  ; height=47 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$03,$F0,$00,$00,$00,$00  ; row 0
        fcb     $00,$3F,$FF,$C0,$00,$00,$00  ; row 1
        fcb     $00,$FF,$FF,$FC,$00,$00,$00  ; row 2
        fcb     $00,$FF,$FF,$FF,$00,$00,$00  ; row 3
        fcb     $00,$0F,$FF,$FF,$00,$00,$00  ; row 4
        fcb     $00,$00,$FF,$FF,$00,$00,$00  ; row 5
        fcb     $00,$05,$5F,$FC,$00,$00,$00  ; row 6
        fcb     $00,$05,$5F,$C0,$00,$00,$00  ; row 7
        fcb     $00,$3D,$FF,$C0,$00,$00,$00  ; row 8
        fcb     $00,$20,$3F,$F0,$00,$00,$00  ; row 9
        fcb     $00,$00,$3F,$FC,$00,$00,$00  ; row 10
        fcb     $00,$00,$FF,$FC,$00,$00,$00  ; row 11
        fcb     $00,$00,$FF,$FC,$00,$00,$00  ; row 12
        fcb     $00,$03,$FF,$FC,$00,$00,$00  ; row 13
        fcb     $00,$03,$FF,$FF,$00,$00,$00  ; row 14
        fcb     $00,$03,$FF,$FF,$00,$00,$00  ; row 15
        fcb     $00,$03,$FF,$FF,$00,$00,$00  ; row 16
        fcb     $00,$03,$FF,$FF,$00,$00,$00  ; row 17
        fcb     $00,$00,$FF,$FF,$00,$00,$00  ; row 18
        fcb     $00,$00,$FF,$FF,$00,$00,$00  ; row 19
        fcb     $00,$02,$BF,$FF,$00,$00,$00  ; row 20
        fcb     $00,$02,$BF,$FF,$C0,$00,$00  ; row 21
        fcb     $00,$02,$BF,$FF,$C0,$00,$00  ; row 22
        fcb     $00,$02,$BF,$FF,$C0,$00,$00  ; row 23
        fcb     $00,$02,$AB,$FF,$C0,$00,$00  ; row 24
        fcb     $00,$02,$AB,$FF,$C0,$00,$00  ; row 25
        fcb     $00,$02,$AB,$FF,$F0,$00,$00  ; row 26
        fcb     $00,$02,$AB,$FF,$F0,$00,$00  ; row 27
        fcb     $00,$02,$AB,$FF,$F0,$00,$00  ; row 28
        fcb     $00,$02,$AB,$FF,$F0,$00,$00  ; row 29
        fcb     $00,$2A,$AB,$FF,$FC,$00,$00  ; row 30
        fcb     $00,$2A,$AB,$FF,$FC,$00,$00  ; row 31
        fcb     $00,$2A,$AA,$BF,$FF,$00,$00  ; row 32
        fcb     $00,$2A,$AA,$BF,$FF,$00,$00  ; row 33
        fcb     $00,$2A,$AA,$BF,$FF,$C0,$00  ; row 34
        fcb     $00,$2A,$AA,$BF,$FF,$C0,$00  ; row 35
        fcb     $00,$2A,$AA,$0F,$FF,$F0,$00  ; row 36
        fcb     $00,$2A,$AA,$0F,$FF,$F0,$00  ; row 37
        fcb     $00,$2A,$AB,$DF,$FF,$FC,$00  ; row 38
        fcb     $00,$2A,$A0,$FB,$FF,$FF,$00  ; row 39
        fcb     $00,$2A,$A0,$FB,$FF,$FF,$C0  ; row 40
        fcb     $00,$2A,$A0,$3D,$FF,$FF,$C0  ; row 41
        fcb     $00,$2A,$A0,$3D,$FF,$FF,$00  ; row 42
        fcb     $00,$2A,$A0,$00,$3F,$FC,$00  ; row 43
        fcb     $00,$3F,$C0,$00,$3F,$F0,$00  ; row 44
        fcb     $03,$FF,$C0,$00,$0F,$C0,$00  ; row 45
        fcb     $BF,$FF,$C0,$00,$00,$00,$00  ; row 46
