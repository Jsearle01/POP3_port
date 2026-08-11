* p6_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #30 (4x42 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=129  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

p6_src:
        fcb     42,7  ; height=42 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$00,$FC,$00,$00,$00  ; row 0
        fcb     $00,$00,$20,$20,$00,$00,$00  ; row 1
        fcb     $00,$00,$00,$00,$00,$00,$00  ; row 2
        fcb     $00,$3F,$C0,$00,$40,$00,$00  ; row 3
        fcb     $BF,$C0,$00,$05,$40,$00,$00  ; row 4
        fcb     $20,$00,$00,$05,$40,$00,$00  ; row 5
        fcb     $0F,$00,$00,$05,$40,$00,$00  ; row 6
        fcb     $0F,$00,$00,$00,$00,$00,$00  ; row 7
        fcb     $00,$04,$00,$54,$00,$00,$00  ; row 8
        fcb     $00,$02,$00,$55,$40,$00,$00  ; row 9
        fcb     $00,$03,$D5,$55,$F0,$00,$00  ; row 10
        fcb     $00,$00,$55,$55,$FC,$00,$00  ; row 11
        fcb     $00,$00,$55,$55,$FC,$00,$00  ; row 12
        fcb     $00,$00,$55,$55,$F0,$00,$00  ; row 13
        fcb     $00,$00,$5F,$D5,$40,$00,$00  ; row 14
        fcb     $00,$00,$5F,$D4,$00,$40,$00  ; row 15
        fcb     $00,$00,$43,$D5,$55,$40,$00  ; row 16
        fcb     $00,$00,$03,$FF,$00,$00,$00  ; row 17
        fcb     $00,$00,$03,$FF,$00,$00,$00  ; row 18
        fcb     $00,$00,$0F,$FF,$00,$00,$00  ; row 19
        fcb     $00,$00,$0F,$FF,$C0,$00,$00  ; row 20
        fcb     $00,$00,$3F,$FF,$C0,$00,$00  ; row 21
        fcb     $00,$00,$3F,$FF,$C0,$00,$00  ; row 22
        fcb     $00,$00,$FF,$0F,$F0,$00,$00  ; row 23
        fcb     $00,$00,$FC,$20,$F0,$00,$00  ; row 24
        fcb     $00,$03,$FA,$AA,$BC,$00,$00  ; row 25
        fcb     $00,$03,$C2,$AA,$A0,$00,$00  ; row 26
        fcb     $00,$02,$AA,$AA,$AA,$00,$00  ; row 27
        fcb     $00,$00,$2A,$AA,$AA,$00,$00  ; row 28
        fcb     $00,$00,$2A,$AA,$AA,$AA,$00  ; row 29
        fcb     $00,$00,$2A,$AA,$AA,$AA,$00  ; row 30
        fcb     $00,$00,$2A,$AA,$AA,$AA,$A0  ; row 31
        fcb     $00,$00,$2A,$AA,$AA,$AA,$AA  ; row 32
        fcb     $00,$00,$2A,$AA,$AA,$AA,$A0  ; row 33
        fcb     $00,$02,$AA,$AA,$AA,$AA,$00  ; row 34
        fcb     $00,$02,$AA,$AA,$AA,$A0,$00  ; row 35
        fcb     $00,$00,$2A,$AA,$A0,$00,$00  ; row 36
        fcb     $00,$00,$00,$00,$00,$00,$00  ; row 37
        fcb     $00,$00,$3C,$00,$03,$C0,$00  ; row 38
        fcb     $00,$00,$3C,$00,$03,$FC,$00  ; row 39
        fcb     $00,$00,$FF,$00,$03,$FC,$00  ; row 40
        fcb     $00,$00,$FF,$F0,$03,$C0,$00  ; row 41
