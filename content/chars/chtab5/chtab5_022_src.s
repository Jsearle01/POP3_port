* chtab5_022_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB5
*         POP cel: #22 (4x28 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab5_022_src:
        fcb     28,7  ; height=28 rows, coco3_width=7 bytes/row (4px/byte)
        fcb     $00,$FC,$00,$00,$00,$00,$00  ; row 0
        fcb     $0F,$FF,$C0,$00,$00,$00,$00  ; row 1
        fcb     $7F,$FF,$F7,$FF,$F0,$00,$00  ; row 2
        fcb     $7F,$FF,$EF,$FE,$AF,$00,$00  ; row 3
        fcb     $FF,$EA,$AF,$FE,$AF,$F0,$00  ; row 4
        fcb     $7E,$AA,$AF,$FE,$AF,$FC,$00  ; row 5
        fcb     $00,$AA,$FF,$FE,$AF,$FF,$00  ; row 6
        fcb     $00,$0A,$80,$FF,$EA,$FF,$00  ; row 7
        fcb     $03,$FE,$80,$0F,$EA,$FF,$C0  ; row 8
        fcb     $03,$FC,$00,$00,$AA,$FF,$C0  ; row 9
        fcb     $00,$FC,$00,$00,$AF,$FF,$C0  ; row 10
        fcb     $03,$FC,$00,$0A,$FF,$FF,$00  ; row 11
        fcb     $03,$FF,$00,$AF,$FF,$FC,$00  ; row 12
        fcb     $00,$F0,$03,$FF,$FF,$F0,$00  ; row 13
        fcb     $00,$00,$0F,$FF,$FF,$C0,$00  ; row 14
        fcb     $00,$00,$0F,$FF,$FC,$00,$00  ; row 15
        fcb     $00,$00,$0F,$FF,$F0,$00,$00  ; row 16
        fcb     $00,$00,$0F,$FF,$FC,$00,$00  ; row 17
        fcb     $00,$00,$0F,$FF,$FC,$00,$00  ; row 18
        fcb     $00,$00,$03,$FF,$FC,$00,$00  ; row 19
        fcb     $00,$00,$00,$FF,$FF,$00,$00  ; row 20
        fcb     $00,$00,$00,$FF,$FF,$00,$00  ; row 21
        fcb     $00,$00,$00,$0F,$FF,$00,$00  ; row 22
        fcb     $00,$00,$00,$0F,$FF,$00,$00  ; row 23
        fcb     $00,$00,$00,$FF,$FF,$C0,$00  ; row 24
        fcb     $00,$00,$00,$F0,$3F,$F0,$00  ; row 25
        fcb     $00,$00,$00,$00,$3F,$F0,$00  ; row 26
        fcb     $00,$00,$00,$00,$FF,$00,$00  ; row 27
