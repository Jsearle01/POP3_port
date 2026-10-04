* chtab4skel_023_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.SKEL
*         POP cel: #23 (4x36 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4skel_023_src:
        fcb     36,6  ; height=36 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $00,$FF,$C0,$00,$00,$00  ; row 0
        fcb     $0F,$FF,$F0,$00,$00,$00  ; row 1
        fcb     $00,$FF,$F0,$00,$00,$00  ; row 2
        fcb     $0A,$FF,$C0,$00,$00,$00  ; row 3
        fcb     $0F,$F0,$00,$00,$00,$00  ; row 4
        fcb     $0F,$F0,$00,$80,$00,$00  ; row 5
        fcb     $00,$00,$00,$F7,$F0,$00  ; row 6
        fcb     $00,$00,$00,$FF,$FC,$00  ; row 7
        fcb     $00,$03,$FF,$F0,$FC,$00  ; row 8
        fcb     $F0,$3F,$50,$0F,$7C,$00  ; row 9
        fcb     $FF,$C0,$00,$F0,$F0,$00  ; row 10
        fcb     $00,$FF,$7C,$00,$FC,$00  ; row 11
        fcb     $00,$00,$01,$00,$FC,$00  ; row 12
        fcb     $00,$00,$00,$3C,$0F,$C0  ; row 13
        fcb     $00,$00,$00,$3F,$FF,$C0  ; row 14
        fcb     $00,$00,$00,$FF,$FF,$F0  ; row 15
        fcb     $00,$00,$00,$FF,$F0,$F0  ; row 16
        fcb     $00,$00,$00,$03,$F0,$10  ; row 17
        fcb     $00,$00,$00,$03,$FC,$00  ; row 18
        fcb     $00,$00,$00,$03,$FC,$00  ; row 19
        fcb     $00,$00,$00,$00,$3F,$00  ; row 20
        fcb     $00,$0F,$C0,$00,$3F,$00  ; row 21
        fcb     $00,$0F,$C0,$00,$3F,$C0  ; row 22
        fcb     $00,$03,$F0,$00,$0F,$C0  ; row 23
        fcb     $00,$00,$F0,$3C,$08,$00  ; row 24
        fcb     $00,$00,$FC,$0F,$00,$00  ; row 25
        fcb     $00,$00,$0F,$03,$C0,$00  ; row 26
        fcb     $00,$00,$03,$F0,$F0,$00  ; row 27
        fcb     $00,$00,$03,$F0,$3F,$00  ; row 28
        fcb     $00,$00,$00,$10,$0F,$C0  ; row 29
        fcb     $00,$00,$00,$3F,$08,$00  ; row 30
        fcb     $00,$00,$00,$3F,$00,$FC  ; row 31
        fcb     $00,$00,$00,$3F,$03,$F0  ; row 32
        fcb     $00,$00,$00,$3F,$0F,$C0  ; row 33
        fcb     $00,$00,$03,$FC,$3F,$00  ; row 34
        fcb     $00,$00,$3F,$C0,$F0,$00  ; row 35
