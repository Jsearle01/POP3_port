# Oracle provenance

Source of record for the POP → CoCo3 port (authority tier 1b), and the tree the behavioral
oracle (tier 1a, PrinceOfPersia_3.5.hdv) is built from.

- Upstream:   github.com/adamgreen/Prince-of-Persia-Apple-II
- Branch:     build
- Commit:     ec78dbfd51013ba349cda8c51c3ce0595fe75342  ("Project being archived", 2021-06-10)
- Retrieved:  2026-07-24 (vendored into POP3_port; upstream is an ARCHIVED repo)
- Toolchain:  Build/win32/ only (snap.exe, crackle.exe, make.exe, applydiff.exe + MinGW DLLs).
              Build/lin32/ and Build/osx32/ deliberately OMITTED — Windows-native project;
              32-bit ELF/Mach-O are dead weight and reintroduce the Phase 0 loader trap.
- Upstream contains the complete Mechner assembly source (adamgreen forked jmechner's archive).
  jmechner's separate archive does not build on modern systems and is NOT referenced.

Reference build (Linux x86-64, g++13, no RELEASE_PATCH), for md5 reproducibility checks:
  c4f0b13e49b77dd0fbc5063e27e53a24  PrinceOfPersia_3.5.hdv
  48f9d6723e55dab6f7382b1dd7225022  PrinceOfPersia_5.25_SideA.nib
  d820fb8a74a6cc215e0112769f43cb7b  PrinceOfPersia_5.25_SideB.nib
md5s are a reproducibility check, not behavioral verification. The hard verification is
behavioral, in an emulator (Jay's gate).
