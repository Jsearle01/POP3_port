* src/harness/hal_link_proof.s
*
* POP CoCo3 — P2.4 ABI LINK PROOF.
*
* THIS IS NOT ENGINE CODE, NOT THE HAL, NOT A DRIVER. It exists to make one claim
* checkable by the toolchain rather than by assertion:
*
*   hal.inc's declarations are a REAL ABI — every entry point it imports resolves,
*   at link time, to the actual implementation in the HAL kernel object.
*
* WHY THIS FILE HAD TO EXIST (the honest reason):
*   P2.2 found that hal.inc has never been assembled by anything. Its 20 `import`
*   directives error under `lwasm --decb` (P2.3-recon §3.1), so the contract file
*   was documentation that nothing checked. Guarding the imports behind OBJTARGET
*   (P2.4) makes hal.inc includable — but includable is not the same as enforced.
*   Something has to actually INCLUDE it and CALL through it, or the file goes
*   right back to being unchecked prose.
*
* WHY IT CALLS ALL FOURTEEN, NOT ONE:
*   `lwlink` only errors on a REFERENCED undefined symbol. An unreferenced `import`
*   links clean — measured, not assumed:
*       import never_defined_symbol, never called  -> lwlink exit 0
*       import never_defined_symbol, JSR'd         -> "External symbol ... not found", exit 1
*   So the ABI is enforced at the point of USE. One call proves one symbol; proving
*   the live contract means calling every live member of it.
*
* THE SIX THAT ARE DELIBERATELY ABSENT:
*   HAL_gfx_blit_sprite{,_opaque,_mixed,_masked}, HAL_gfx_blit_stencil_punch and
*   HAL_gfx_blit_scroll are inside POP's dormancy guard (PA.6 ruled the runtime blit
*   infeasible for POP; P1.3 replaced it with compiled sprites). They are not
*   exported here, so a POP call to one is now a LINK ERROR naming the symbol —
*   where in the absolute build it was a JSR to whatever happened to occupy the
*   address. The linked model turned a silent wrong answer into a loud one.
*
* IT IS NOT MEANT TO RUN. Control never reaches the end of the call chain in any
* useful state — HAL_sys_panic spins by design. The deliverable is the LINK, and
* the resolved JSR operands in the emitted binary.
* ---------------------------------------------------------------

                include "src/hal.inc"

                ifdef   OBJTARGET
                section prog
                export  link_proof_entry
                endc

                ifdef   OBJTARGET
                * setdp is NOT permitted for the object target — the fourth
                * object-incompatible directive class (P2.4; the recon found three).
                * The HAL uses explicit `<` direct-mode operands, so omitting the
                * declaration changes nothing it relies on.
                else
                setdp   0
                endc

link_proof_entry
* --- sys ---------------------------------------------------------
                jsr     HAL_sys_init
* --- time --------------------------------------------------------
                jsr     HAL_time_init
                jsr     HAL_time_vbl_wait
                jsr     HAL_time_frame_count
                lda     #1
                jsr     HAL_time_delay
* --- gfx (the three that are live in POP) ------------------------
                jsr     HAL_gfx_init
                jsr     HAL_gfx_clear
                jsr     HAL_gfx_present
* --- input -------------------------------------------------------
                jsr     HAL_input_init
                jsr     HAL_input_poll
* --- sound / file / mem (P2 stubs, but real linkable entry points) -
                jsr     HAL_sound_init
                jsr     HAL_file_init
                jsr     HAL_mem_size_detect
* --- and the one that never returns ------------------------------
                jsr     HAL_sys_panic

                ifdef   OBJTARGET
                endsection
                else
                end     link_proof_entry
                endc
