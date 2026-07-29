* flame5 opacity — OPAQUE throughout.
* PSETUPFLAME sets OPACITY = sta (a plain store), so the oracle writes every
* pixel of the flame including its black ones. Keying them lets whatever is
* behind show through, which is only invisible while the background happens
* to be black. [GAMEBG.S:761 PSETUPFLAME]
flame5_opacity_mixed:
        fcb     0,2,0,13,1      ; whole cel, opaque
        fcb     0,0,0,0,0       ; terminator
