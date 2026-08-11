* p11_m_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #25 (3x43 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=121  screen-col parity=ODD
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

p11_m_src:
        fcb     43,5  ; height=43 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$00,$03,$F7,$C0  ; row 0
        fcb     $00,$00,$0F,$C0,$10  ; row 1
        fcb     $00,$00,$08,$00,$00  ; row 2
        fcb     $00,$00,$3C,$00,$80  ; row 3
        fcb     $00,$00,$10,$0A,$80  ; row 4
        fcb     $00,$00,$10,$0A,$80  ; row 5
        fcb     $00,$00,$10,$00,$80  ; row 6
        fcb     $00,$00,$80,$00,$00  ; row 7
        fcb     $00,$00,$80,$00,$00  ; row 8
        fcb     $00,$00,$80,$80,$00  ; row 9
        fcb     $00,$00,$80,$AF,$00  ; row 10
        fcb     $00,$00,$F0,$AF,$C0  ; row 11
        fcb     $00,$00,$F0,$AF,$F0  ; row 12
        fcb     $00,$00,$10,$AF,$F0  ; row 13
        fcb     $00,$00,$10,$AF,$C0  ; row 14
        fcb     $00,$00,$10,$AF,$08  ; row 15
        fcb     $00,$00,$00,$AA,$A8  ; row 16
        fcb     $00,$00,$03,$FF,$00  ; row 17
        fcb     $00,$00,$03,$FF,$00  ; row 18
        fcb     $00,$00,$0F,$FF,$00  ; row 19
        fcb     $00,$00,$0F,$FF,$00  ; row 20
        fcb     $00,$00,$3F,$FF,$00  ; row 21
        fcb     $00,$00,$3F,$FF,$00  ; row 22
        fcb     $00,$00,$3F,$FF,$00  ; row 23
        fcb     $00,$00,$3F,$FF,$00  ; row 24
        fcb     $00,$00,$FF,$FF,$C0  ; row 25
        fcb     $00,$00,$FF,$FF,$C0  ; row 26
        fcb     $00,$01,$57,$FF,$C0  ; row 27
        fcb     $00,$01,$57,$FF,$C0  ; row 28
        fcb     $00,$01,$55,$7F,$C0  ; row 29
        fcb     $00,$01,$55,$7F,$C0  ; row 30
        fcb     $00,$15,$55,$57,$C0  ; row 31
        fcb     $00,$15,$55,$55,$50  ; row 32
        fcb     $00,$15,$55,$55,$50  ; row 33
        fcb     $00,$15,$55,$55,$50  ; row 34
        fcb     $01,$55,$55,$55,$50  ; row 35
        fcb     $01,$55,$55,$55,$50  ; row 36
        fcb     $01,$50,$15,$55,$50  ; row 37
        fcb     $00,$00,$01,$55,$50  ; row 38
        fcb     $00,$00,$0F,$00,$00  ; row 39
        fcb     $00,$00,$0F,$00,$00  ; row 40
        fcb     $00,$00,$3F,$F0,$00  ; row 41
        fcb     $00,$00,$3F,$FF,$00  ; row 42
