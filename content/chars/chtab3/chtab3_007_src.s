* chtab3_007_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB3
*         POP cel: #7 (4x38 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab3_007_src:
        fcb     38,7  ; height=38 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$00,$00,$00,$3F,$F0,$00  ; row 0
        fcb     $00,$00,$00,$00,$FF,$FF,$00  ; row 1
        fcb     $00,$00,$00,$03,$FF,$FF,$00  ; row 2
        fcb     $00,$00,$00,$03,$FF,$FF,$00  ; row 3
        fcb     $00,$00,$00,$00,$17,$FF,$00  ; row 4
        fcb     $00,$00,$00,$00,$15,$50,$00  ; row 5
        fcb     $00,$00,$00,$00,$01,$50,$00  ; row 6
        fcb     $00,$00,$00,$00,$00,$FF,$00  ; row 7
        fcb     $00,$00,$00,$00,$03,$FF,$00  ; row 8
        fcb     $00,$00,$00,$00,$0F,$F5,$00  ; row 9
        fcb     $00,$00,$00,$00,$0F,$F5,$00  ; row 10
        fcb     $00,$00,$00,$00,$0F,$F5,$00  ; row 11
        fcb     $00,$00,$00,$00,$3F,$F5,$00  ; row 12
        fcb     $00,$00,$00,$15,$01,$55,$00  ; row 13
        fcb     $00,$00,$00,$15,$55,$55,$00  ; row 14
        fcb     $00,$00,$00,$01,$50,$10,$00  ; row 15
        fcb     $00,$00,$00,$03,$FF,$F0,$00  ; row 16
        fcb     $00,$00,$00,$0F,$FF,$F0,$00  ; row 17
        fcb     $00,$00,$00,$0F,$FF,$F0,$00  ; row 18
        fcb     $00,$00,$00,$3F,$FF,$F0,$00  ; row 19
        fcb     $00,$00,$00,$FF,$FF,$C0,$00  ; row 20
        fcb     $00,$00,$03,$FF,$FF,$C0,$00  ; row 21
        fcb     $00,$00,$03,$FF,$FF,$00,$00  ; row 22
        fcb     $00,$00,$0F,$FF,$FC,$00,$00  ; row 23
        fcb     $00,$00,$3F,$FF,$F7,$C0,$00  ; row 24
        fcb     $00,$00,$FF,$FF,$EF,$C0,$00  ; row 25
        fcb     $00,$03,$FF,$FC,$3F,$C0,$00  ; row 26
        fcb     $00,$03,$FF,$C0,$FF,$C0,$00  ; row 27
        fcb     $00,$0F,$FF,$00,$FF,$F0,$00  ; row 28
        fcb     $00,$0F,$FC,$00,$3F,$FC,$00  ; row 29
        fcb     $00,$0F,$FC,$00,$3F,$FF,$00  ; row 30
        fcb     $00,$3F,$F0,$00,$0F,$FF,$C0  ; row 31
        fcb     $00,$3F,$F0,$00,$00,$FF,$F0  ; row 32
        fcb     $00,$3F,$C0,$00,$00,$3F,$50  ; row 33
        fcb     $00,$10,$00,$00,$00,$00,$3C  ; row 34
        fcb     $01,$50,$00,$00,$00,$03,$FF  ; row 35
        fcb     $FF,$FC,$00,$00,$00,$3F,$F0  ; row 36
        fcb     $0F,$FC,$00,$00,$00,$00,$00  ; row 37
