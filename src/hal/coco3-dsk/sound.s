* src/hal/coco3-dsk/sound.s
*
* HAL Sound subsystem — STUB for P2.3a.3 production boot integration.
*
* STUB-P3.x: HAL_sound_init is a no-op stub. Real implementation
*   requires CoCo3 DAC register programming and tone-record playback.
*   [no-ref: CoCo3 DAC register address — resolve from CC3-TR during
*    sound subsystem port]
*
* HAL contract reference: src/hal.inc (HAL_sound_* declarations)
* ---------------------------------------------------------------

        setdp   0

* ---------------------------------------------------------------
* HAL_sound_init  [STUB-P3.x]
*
* Initialize sound hardware. Stub: returns success immediately.
*
* Args:    none
* Returns: CC.C clear (success)
* ---------------------------------------------------------------
HAL_sound_init:
        andcc   #$FE                    ; CC.C clear = success (stub)
        rts
