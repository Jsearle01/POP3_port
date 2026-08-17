* v70_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #96 (3x48 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=158  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

v70_src:
        fcb     48,5  ; height=48 rows, coco3_width=5 bytes/row (4px/byte)
        fcb     $00,$FC,$00,$00,$00  ; row 0
        fcb     $0F,$FF,$F0,$00,$00  ; row 1
        fcb     $7F,$FF,$FF,$00,$00  ; row 2
        fcb     $7F,$FF,$FF,$C0,$00  ; row 3
        fcb     $03,$FF,$FF,$C0,$00  ; row 4
        fcb     $00,$3F,$FF,$C0,$00  ; row 5
        fcb     $01,$57,$FF,$00,$00  ; row 6
        fcb     $01,$57,$F0,$00,$00  ; row 7
        fcb     $0F,$7F,$FF,$00,$00  ; row 8
        fcb     $08,$0F,$FF,$C0,$00  ; row 9
        fcb     $00,$3F,$FF,$F0,$00  ; row 10
        fcb     $00,$3F,$FF,$F0,$00  ; row 11
        fcb     $00,$3F,$FF,$FC,$00  ; row 12
        fcb     $00,$0A,$FF,$FC,$00  ; row 13
        fcb     $00,$0A,$AF,$FF,$00  ; row 14
        fcb     $00,$0A,$AF,$FF,$00  ; row 15
        fcb     $00,$0A,$AF,$FF,$00  ; row 16
        fcb     $00,$0A,$AF,$FF,$00  ; row 17
        fcb     $00,$AA,$AF,$FF,$C0  ; row 18
        fcb     $00,$AA,$AF,$FF,$C0  ; row 19
        fcb     $00,$AA,$AA,$FF,$C0  ; row 20
        fcb     $03,$F0,$AA,$FF,$C0  ; row 21
        fcb     $01,$50,$0A,$FF,$C0  ; row 22
        fcb     $15,$00,$0A,$FF,$F0  ; row 23
        fcb     $01,$00,$0A,$FF,$F0  ; row 24
        fcb     $00,$00,$0A,$FF,$F0  ; row 25
        fcb     $00,$00,$0A,$FF,$F0  ; row 26
        fcb     $00,$00,$0A,$FF,$F0  ; row 27
        fcb     $00,$00,$0A,$FF,$F0  ; row 28
        fcb     $00,$00,$0A,$FF,$F0  ; row 29
        fcb     $00,$00,$0A,$AF,$F0  ; row 30
        fcb     $00,$00,$0A,$AF,$FC  ; row 31
        fcb     $00,$00,$0A,$AF,$FC  ; row 32
        fcb     $00,$00,$0A,$AF,$FC  ; row 33
        fcb     $00,$00,$0A,$AF,$FC  ; row 34
        fcb     $00,$00,$0A,$AF,$FC  ; row 35
        fcb     $00,$00,$00,$AF,$FC  ; row 36
        fcb     $00,$00,$00,$AF,$FC  ; row 37
        fcb     $00,$00,$00,$AF,$FC  ; row 38
        fcb     $00,$00,$00,$AF,$FC  ; row 39
        fcb     $00,$00,$00,$AA,$FC  ; row 40
        fcb     $00,$00,$00,$AA,$FC  ; row 41
        fcb     $00,$00,$00,$AA,$FC  ; row 42
        fcb     $00,$00,$00,$AA,$FC  ; row 43
        fcb     $00,$00,$00,$AA,$FC  ; row 44
        fcb     $00,$00,$00,$FE,$FC  ; row 45
        fcb     $00,$00,$0F,$FE,$FF  ; row 46
        fcb     $00,$00,$FF,$FF,$00  ; row 47
