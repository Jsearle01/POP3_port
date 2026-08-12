* v49_m_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #75 (4x47 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=168  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v49_m_src:
        fcb     47,6  ; height=47 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$FC,$00  ; row 0
        fcb     $00,$00,$00,$3F,$FF,$C0  ; row 1
        fcb     $00,$00,$03,$FF,$FF,$F0  ; row 2
        fcb     $00,$00,$0F,$FF,$FF,$F0  ; row 3
        fcb     $00,$00,$0F,$FF,$FF,$00  ; row 4
        fcb     $00,$00,$0F,$FF,$F0,$00  ; row 5
        fcb     $00,$00,$03,$FF,$55,$00  ; row 6
        fcb     $00,$00,$00,$3F,$55,$00  ; row 7
        fcb     $00,$00,$00,$3F,$F7,$C0  ; row 8
        fcb     $00,$00,$00,$FF,$C0,$80  ; row 9
        fcb     $00,$00,$03,$FF,$C0,$00  ; row 10
        fcb     $00,$00,$0F,$FF,$C0,$00  ; row 11
        fcb     $00,$00,$0F,$FF,$F0,$00  ; row 12
        fcb     $00,$00,$0F,$FF,$F0,$00  ; row 13
        fcb     $00,$00,$3F,$FF,$FC,$00  ; row 14
        fcb     $00,$00,$3F,$FF,$FC,$00  ; row 15
        fcb     $00,$00,$3F,$FF,$FC,$00  ; row 16
        fcb     $00,$00,$3F,$FF,$FC,$00  ; row 17
        fcb     $00,$00,$3F,$FF,$FC,$00  ; row 18
        fcb     $00,$00,$FF,$FF,$E8,$00  ; row 19
        fcb     $00,$00,$FF,$FF,$E8,$00  ; row 20
        fcb     $00,$00,$FF,$FF,$E8,$00  ; row 21
        fcb     $00,$00,$FF,$FF,$E8,$00  ; row 22
        fcb     $00,$00,$FF,$FE,$A8,$00  ; row 23
        fcb     $00,$03,$FF,$FE,$A8,$00  ; row 24
        fcb     $00,$03,$FF,$FE,$A8,$00  ; row 25
        fcb     $00,$03,$FF,$FE,$A8,$00  ; row 26
        fcb     $00,$03,$FF,$FE,$A8,$00  ; row 27
        fcb     $00,$03,$FF,$FE,$A8,$00  ; row 28
        fcb     $00,$03,$FF,$FE,$A8,$00  ; row 29
        fcb     $00,$0F,$FF,$EA,$A8,$00  ; row 30
        fcb     $00,$0F,$FF,$EA,$A8,$00  ; row 31
        fcb     $00,$0F,$FF,$EA,$AA,$80  ; row 32
        fcb     $00,$0F,$FF,$EA,$AA,$80  ; row 33
        fcb     $00,$0F,$FF,$EA,$AA,$80  ; row 34
        fcb     $00,$3F,$FF,$EA,$AA,$80  ; row 35
        fcb     $00,$3F,$FE,$AA,$AA,$80  ; row 36
        fcb     $00,$3F,$FE,$AA,$AA,$80  ; row 37
        fcb     $00,$FF,$FE,$AA,$AA,$80  ; row 38
        fcb     $00,$FF,$FE,$AA,$AA,$80  ; row 39
        fcb     $00,$FF,$FE,$AA,$AA,$80  ; row 40
        fcb     $03,$FF,$EA,$AA,$AA,$80  ; row 41
        fcb     $03,$FF,$EA,$80,$AA,$80  ; row 42
        fcb     $03,$FF,$0A,$80,$0F,$C0  ; row 43
        fcb     $0F,$FC,$0F,$C0,$3F,$C0  ; row 44
        fcb     $0F,$F0,$3F,$F0,$FF,$F0  ; row 45
        fcb     $0F,$00,$3F,$FF,$FF,$FF  ; row 46
