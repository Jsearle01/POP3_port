* v54_m_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #80 (3x48 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=289  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v54_m_src:
        fcb     48,5  ; height=48 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$00,$00,$3F,$00  ; row 0
        fcb     $00,$00,$0F,$FF,$F0  ; row 1
        fcb     $00,$00,$FF,$FF,$FC  ; row 2
        fcb     $00,$03,$FF,$FF,$FC  ; row 3
        fcb     $00,$03,$FF,$FF,$C0  ; row 4
        fcb     $00,$03,$FF,$FC,$00  ; row 5
        fcb     $00,$00,$FF,$D5,$40  ; row 6
        fcb     $00,$00,$0F,$D5,$40  ; row 7
        fcb     $00,$00,$0F,$FD,$F0  ; row 8
        fcb     $00,$00,$FF,$F0,$20  ; row 9
        fcb     $00,$00,$FF,$F0,$00  ; row 10
        fcb     $00,$03,$FF,$FC,$00  ; row 11
        fcb     $00,$03,$FF,$FC,$00  ; row 12
        fcb     $00,$03,$FF,$FF,$00  ; row 13
        fcb     $00,$03,$FF,$FF,$00  ; row 14
        fcb     $00,$03,$FF,$FF,$00  ; row 15
        fcb     $00,$03,$FF,$FF,$00  ; row 16
        fcb     $00,$03,$FF,$FF,$00  ; row 17
        fcb     $00,$0F,$FF,$FF,$00  ; row 18
        fcb     $00,$0F,$FF,$FA,$00  ; row 19
        fcb     $00,$0F,$FF,$FA,$00  ; row 20
        fcb     $00,$0F,$FF,$FA,$00  ; row 21
        fcb     $00,$0F,$FF,$FA,$00  ; row 22
        fcb     $00,$0F,$FF,$FA,$00  ; row 23
        fcb     $00,$0F,$FF,$FA,$00  ; row 24
        fcb     $00,$0F,$FF,$FA,$00  ; row 25
        fcb     $00,$0F,$FF,$FA,$00  ; row 26
        fcb     $00,$0F,$FF,$FA,$00  ; row 27
        fcb     $00,$0F,$FF,$FA,$00  ; row 28
        fcb     $00,$0F,$FF,$FA,$00  ; row 29
        fcb     $00,$0F,$FF,$FA,$00  ; row 30
        fcb     $00,$0F,$FF,$FA,$00  ; row 31
        fcb     $00,$0F,$FF,$FA,$00  ; row 32
        fcb     $00,$0F,$FF,$FA,$00  ; row 33
        fcb     $00,$0F,$FF,$FA,$00  ; row 34
        fcb     $00,$0F,$FF,$FA,$00  ; row 35
        fcb     $00,$0F,$FF,$FA,$00  ; row 36
        fcb     $00,$03,$FF,$AA,$00  ; row 37
        fcb     $00,$03,$FF,$AA,$00  ; row 38
        fcb     $00,$03,$FF,$AA,$00  ; row 39
        fcb     $00,$03,$FF,$A0,$00  ; row 40
        fcb     $00,$03,$FF,$A0,$00  ; row 41
        fcb     $00,$03,$FF,$A0,$00  ; row 42
        fcb     $00,$03,$FF,$A0,$00  ; row 43
        fcb     $00,$03,$FA,$A0,$00  ; row 44
        fcb     $00,$03,$FB,$F0,$00  ; row 45
        fcb     $00,$0F,$FB,$FF,$00  ; row 46
        fcb     $00,$00,$3F,$FF,$F0  ; row 47
