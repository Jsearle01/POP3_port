* src/hal/coco3-dsk/mem.s
*
* HAL Memory subsystem — STUB for P2.3a.3 production boot integration.
*
* STUB-P2.x: HAL_mem_size_detect is a minimal stub returning a
*   reasonable default (128K / D=$8000). Real implementation probes
*   GIME MMU to distinguish 128K from 512K.
*   [no-ref: GIME MMU probing for 128K vs 512K — resolve from CC3-TR
*    MMU section during memory subsystem port]
*
* HAL contract reference: src/hal.inc (HAL_mem_size_detect declaration)
* ---------------------------------------------------------------

        setdp   0

* ---------------------------------------------------------------
* HAL_mem_size_detect  [STUB-P2.x]
*
* Probe installed RAM. Stub: returns $0000 = 128K mode (A=0).
*
* Per hal.inc contract: Returns A = 0 if 128K, 1 if 512K.
*
* Args:    none
* Returns: A = 0 (128K assumed; probe not yet implemented)
*          CC.C clear (success)
* ---------------------------------------------------------------
HAL_mem_size_detect:
        clra                            ; A = 0 = 128K (stub; probe deferred)
        andcc   #$FE                    ; CC.C clear = success
        rts

        end     boot                    ; DECB exec address = $0200 (boot in boot.s)
