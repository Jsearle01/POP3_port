* src/hal/coco3-dsk/hal_globals.s
*
* HAL-owned Direct Page allocations for the POP CoCo3 port.
*
* ADOPTION NOTE (P2.1). Karateka carries these in `src/engine/globals.s`, a file
* that also declares the ENGINE bands ($20-$7F). POP has no engine yet and engine
* code is out of scope for this dispatch, so only the HAL-owned declarations are
* adopted here — same symbols, same addresses, same meaning. When POP's engine
* arrives it takes the engine bands; this file keeps the HAL band.
*
* The addresses are NOT a POP choice — they are the shared contract:
*   [ref: src/hal.inc — DIRECT PAGE (DP) USAGE POLICY]
*     HAL owns    $00-$1F
*     Engine owns $20-$7F
*     Reserved    $80-$FF  (CoCo3 system use)
*
* Values are byte-for-byte the same as karateka's globals.s. Any divergence here
* would fork the shared contract, which P2.1's governing rules forbid.
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                * setdp is NOT permitted for the object target — the fourth
                * object-incompatible directive class (P2.4; the recon found three).
                * The HAL uses explicit `<` direct-mode operands, so omitting the
                * declaration changes nothing it relies on.
                else
                setdp   0
                endc

* ---------------------------------------------------------------
* HAL scratch band $00-$1F
*   $00-$03  HAL_ZP_PARAM0-3  (declared in hal.inc)
*   $04-$05  HAL_ZP_PTR0      (declared in hal.inc)
*   $06-$07  HAL_ZP_PTR1      (declared in hal.inc)
*   $08-$0F  reserved for HAL internal use
* ---------------------------------------------------------------

* --- HAL time subsystem ($10-$11) ---
hal_frame_hi        equ $10     ; frame counter high byte (time.s, irq_vbl.s)
hal_frame_lo        equ $11     ; frame counter low byte  (time.s, irq_vbl.s)

* --- HAL gfx subsystem ($12) ---
gfx_initialized     equ $12     ; $00 = not init; $01 = HAL_gfx_init complete

* --- HAL sys subsystem ($13) ---
sys_init_cc_mask    equ $13     ; CC captured after HAL_sys_init; test diagnostic only

* $14-$1F: reserved for future HAL subsystem allocations

* ---------------------------------------------------------------
* page_register — ENGINE-owned by the DP policy, but HAL-CONSUMED.
*
* HAL_gfx_present (gfx.s) READS $50 to decide which buffer to show, so the HAL
* cannot assemble without it. It sits in the engine band, so POP's engine will own
* it once the engine exists; it is declared here only so the adopted HAL builds
* standalone. Flagged in the P2.1 report as a contract observation, not changed —
* altering it would reshape the shared interface.
*
*   Option I convention (karateka-canonical): page_register identifies the BACK
*   buffer (the active draw target). HAL_gfx_present displays the buffer it points
*   at.  $20 = buffer A ($8000).  $40 = buffer B ($C000).
*   [ref: src/hal.inc; karateka src/engine/globals.s]
* ---------------------------------------------------------------
page_register       equ $50     ; active draw buffer ($20 = A, $40 = B)
page_source_blit    equ $51     ; prior draw buffer (blit source)

* ---------------------------------------------------------------
* Page tokens — also engine-band constants that the HAL COMPARES against.
* gfx.s does `cmpa #PAGE_A_TOKEN` in HAL_gfx_present and the blit paths, so the
* HAL cannot assemble without them. Same values as karateka; adopted, not chosen.
*   $20 = buffer A ($8000-range) — Apple II hires page 1 high byte
*   $40 = buffer B ($C000-range) — Apple II hires page 2 high byte
* [ref: karateka src/engine/globals.s:142-143]
* ---------------------------------------------------------------
PAGE_A_TOKEN        equ $20     ; draw target = buffer A
PAGE_B_TOKEN        equ $40     ; draw target = buffer B

* ---------------------------------------------------------------
* s4_dest_row — engine-band scratch used by HAL_gfx_blit_scroll (gfx.s:968).
* Declared here for the same reason as page_register: the HAL reads it, so the HAL
* cannot assemble without it. Adopted at karateka's address, unchanged.
* [ref: karateka src/engine/globals.s:119]
* ---------------------------------------------------------------
s4_dest_row         equ $66     ; 16-bit scroll-blit destination row ($66/$67)

* ═══════════════════════════════════════════════════════════════════
* GRAPHICS MODE DESCRIPTOR TABLE — PROJECT-LOCAL (POP-HAL-01)
* ═══════════════════════════════════════════════════════════════════
* Moved here from src/hal/coco3-dsk/gfx.s, which is SHARED across POP, karateka and coco_agi
* and kept byte-aligned by harness/tools/hal_sync_check.py.
*
* ★★ WHY IT MOVED. A shared table is a shared BINARY. coco_agi needed a third mode; adding one
* 7-byte row to the shared table shifted every address after it and changed 27 of POP's built
* artifacts, each +7 bytes. POP's byte-identity rule and a growable shared table cannot both
* hold. The table is the one part that is genuinely per-project, so it became per-project:
* SHARED MECHANISM, PROJECT-LOCAL DATA.
*
* ★ THE CONTENT BELOW IS UNCHANGED FROM gfx.s — same bytes, same order, new home. This is a
* RELOCATION, not a revision (POP CLAUDE.md §2F.1.7: "a migration must not fix placement").
*
* ★ It is guarded by HAL_GFX_MODE_SERVICE so a project that does not take the mode service
* emits nothing from here — the same condition that guarded it in gfx.s. karateka does not
* define the symbol and its build is unchanged by any of this.
*
* Row layout is the SHARED contract and stays in gfx.s as GFX_MODE_ENTSZ = 7:
*   +0 VRES  +1 stride  +2 size in WORDS  +4 palette ptr  +6 palette count
* The palettes themselves are shared and still live in gfx.s.
                ifdef   HAL_GFX_MODE_SERVICE

                ifdef   OBJTARGET
                * Object build: emitted data needs a section. hal_globals.s was pure equates
                * before this and opened none. The absolute build (karateka) never reaches
                * here, because the guard above is undefined there.
                section code
                endc

* ★ GFX_MODE_MAX sits INSIDE the section deliberately. Defined outside it, lwasm keeps it out
* of the object's symbol table, and every linker .map lost its `Symbol: GFX_MODE_MAX` line
* (-53 B per map, -20 B in hal_build.o). No emitted byte changed either way -- it is an equ --
* but leaving it outside would add a symbol-table delta on top of the relocation, and AC-2's
* evidence is cleaner when the ONLY change is that addresses moved.
GFX_MODE_MAX        equ 1           ; highest supported id — POP ships modes 0 and 1

gfx_mode_table:
        fcb     $15                     ; mode 0: 320x192x4  VRES  [GIME-RM §10]
        fcb     80                      ;   80 bytes/row
        fdb     $1E00                   ;   15,360 B / 2 = $1E00 words
        fdb     gfx_pal4                ;   shared palette, defined in gfx.s
        fcb     4                       ;   palette regs $FFB0-$FFB3

        fcb     $1E                     ; mode 1: 320x192x16 VRES  [GIME-RM §10]
        fcb     160                     ;   160 bytes/row
        fdb     $3C00                   ;   30,720 B / 2 = $3C00 words
        fdb     gfx_pal16               ;   shared palette, defined in gfx.s
        fcb     16                      ;   palette regs $FFB0-$FFBF

                ifdef   OBJTARGET
                endsection
                endc

                endc                    ; HAL_GFX_MODE_SERVICE
