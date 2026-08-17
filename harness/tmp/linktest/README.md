# P2.3-recon throwaway probes — DISPOSABLE

Minimal lwasm/lwlink probes establishing whether ONE HAL source can build both the
absolute (`--decb`) and object/linked (`--obj` + `lwlink`) models.

**Answer: yes, via `ifdef OBJTARGET` guards.** See
`reports/20260726-171154-p2-3-recon-linked-build.md`.

Nothing here is production. Delete freely — retained only so the evidence is reproducible.

- `q1_without.s` / `q1_with.s`  — absolute tolerance of `export` (it ERRORS)
- `q1_import.s`                 — same for `import`
- `q1_guarded.s`                — guarded export, absolute, byte-identical output
- `c.s` / `d.s`                 — the one-source pattern: build BOTH ways
- `link.scr`                    — minimal linker script (`--section-base` is silently ignored)
- `run.lua`                     — MAME loader asserting $0400=$A5 and $0401=$5A
