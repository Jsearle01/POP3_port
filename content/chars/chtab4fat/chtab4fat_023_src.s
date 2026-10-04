* chtab4fat_023_src.s
* CoCo3 cel data - converted from POP Apple II HGR source.
*
* ORIGIN: IMG.CHTAB4.FAT
*         POP cel: #23 (4x38 bytes)
* Colour model: adjacency + screen-col parity + colour-cell fill.
*   Carried VERBATIM from karateka_coco3 sprite_convert.py (MAME-verified
*   TASK 1/2 gate 2026-05-16; colour-cell fill P4 gate 2026-06-13).
*   0=Black 1=Orange(odd screen col) 2=Blue(even screen col) 3=White
*   start_col=0  screen-col parity=EVEN
* [ref: HIRES.S:180-186 cel format; GRAFIX.S:341 ADDMID; TABLES.S:51-67]

chtab4fat_023_src:
        fcb     38,6  ; height=38 rows, coco3_width=6 bytes/row (4px/byte)
        fcb     $00,$00,$FF,$F0,$00,$00  ; row 0
        fcb     $00,$3F,$FF,$FF,$00,$00  ; row 1
        fcb     $00,$FF,$FF,$FF,$00,$00  ; row 2
        fcb     $00,$FF,$FF,$FF,$00,$00  ; row 3
        fcb     $00,$3F,$FF,$FC,$00,$00  ; row 4
        fcb     $00,$10,$FF,$F0,$00,$00  ; row 5
        fcb     $00,$0A,$AF,$F0,$00,$00  ; row 6
        fcb     $00,$0A,$FF,$FF,$00,$00  ; row 7
        fcb     $00,$03,$FF,$FF,$F0,$00  ; row 8
        fcb     $00,$0F,$FF,$FF,$FC,$00  ; row 9
        fcb     $00,$0F,$FF,$FF,$FF,$00  ; row 10
        fcb     $00,$15,$57,$FF,$FF,$00  ; row 11
        fcb     $00,$15,$57,$FF,$FF,$00  ; row 12
        fcb     $00,$15,$57,$FF,$FC,$00  ; row 13
        fcb     $00,$FF,$7F,$FF,$E8,$00  ; row 14
        fcb     $00,$AA,$FF,$FE,$AF,$C0  ; row 15
        fcb     $03,$EA,$FE,$AA,$FF,$C0  ; row 16
        fcb     $0F,$F5,$55,$7F,$FF,$F0  ; row 17
        fcb     $0F,$55,$55,$57,$FF,$F0  ; row 18
        fcb     $7C,$15,$55,$57,$FF,$F0  ; row 19
        fcb     $F0,$15,$55,$57,$FF,$F0  ; row 20
        fcb     $80,$15,$55,$55,$7F,$C0  ; row 21
        fcb     $00,$15,$55,$55,$7F,$00  ; row 22
        fcb     $00,$15,$55,$55,$7F,$00  ; row 23
        fcb     $00,$15,$55,$55,$50,$00  ; row 24
        fcb     $00,$15,$55,$55,$50,$00  ; row 25
        fcb     $00,$01,$55,$55,$00,$00  ; row 26
        fcb     $00,$01,$55,$55,$00,$00  ; row 27
        fcb     $00,$01,$55,$55,$50,$00  ; row 28
        fcb     $00,$00,$15,$55,$55,$00  ; row 29
        fcb     $00,$00,$15,$55,$55,$00  ; row 30
        fcb     $00,$00,$01,$55,$55,$00  ; row 31
        fcb     $00,$00,$01,$50,$17,$F0  ; row 32
        fcb     $00,$00,$01,$55,$7F,$F0  ; row 33
        fcb     $00,$00,$00,$FF,$7F,$F0  ; row 34
        fcb     $00,$00,$03,$FF,$7F,$C0  ; row 35
        fcb     $00,$00,$0F,$FE,$FF,$00  ; row 36
        fcb     $00,$00,$3F,$C0,$F0,$00  ; row 37
