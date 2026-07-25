# oracle/ — the reference the port is graded against

Two artifacts, one origin, one role: the reference POP is measured by.

- oracle/source/ (TRACKED) — the buildable adamgreen tree @ ec78dbf. Read the port FROM this
  (tier 1b) and BUILD the .hdv FROM this. See PROVENANCE.md.
- oracle/source/PrinceOfPersia_3.5.hdv (GITIGNORED) — the behavioral oracle (tier 1a). A build
  artifact: reproduce it with `Build/win32/make.exe all` from oracle/source/, do not commit it.

Why one tree: reading and building from the SAME source collapses source-vs-oracle drift — the
thing you read is provably the thing you trace. (backlog §5.10)

To rebuild the oracle (Windows / Git Bash):
  cd oracle/source && ./Build/win32/make.exe all
  md5sum PrinceOfPersia_3.5.hdv   # expect c4f0b13e49b77dd0fbc5063e27e53a24
