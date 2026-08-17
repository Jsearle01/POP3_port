"""PA.11 — measure k = 6809/6502 cycle ratio on POP's ANIMCHAR sequence interpreter.
Counts are per-instruction, from the assembled 6502 listing (obj/COLL.LST, obj/CTRLSUBS.LST)
and from the 6809 translation. MOS6502 + MC6809 documented timings."""

# ---------- 6502: counted from the assembled listing ----------
# GETSEQ body $D6F4 (CTRLSUBS.LST), common path (bne taken, no page cross)
G6502 = [("ldy #0",2),("lda (CharSeq),y",5),("pha",3),("inc CharSeq",5),
         ("bne :done",3),("pla",4),("rts",6)]
GETSEQ_6502 = 6 + 3 + sum(c for _,c in G6502)      # jsr(6) + jump-table jmp(3) + body
# ADDCHARX body $D1BC, facing-left path (bpl NOT taken -> negate)
A6502 = [("bit CharFace",3),("bpl :right",2),("eor #$ff",2),("clc",2),("adc #1",2),
         (":right clc",2),("adc CharX",3),("rts",6)]
ADDCHARX_6502 = 6 + 3 + sum(c for _,c in A6502)
CHX_6502  = GETSEQ_6502 + 2 + 2 + GETSEQ_6502 + ADDCHARX_6502 + 3 + 3   # cmp2,bne-not-taken2,sta3,jmp3
GOTO_6502 = GETSEQ_6502 + (2+3)*3 + (2+2) + GETSEQ_6502 + 3 + GETSEQ_6502 + 3 + 4 + 3 + 3

# ---------- 6809 LITERAL: instruction-for-instruction transliteration ----------
# 6502 (zp),y has no 1-instruction 6809 twin: the pointer must be loaded to a register first.
G_LIT = [("ldu <CharSeq",5),("ldb ,u",4),("pshs b",6),("inc <CharSeq",6),
         ("bne done",3),("puls b",6),("rts",5)]
GETSEQ_LIT = 8 + 4 + sum(c for _,c in G_LIT)       # jsr ext(8) + jmp ext(4) + body
# BIT differs (6809 BITB is AND, not bit7-of-memory) -> lda <CharFace; NEGB replaces eor/clc/adc#1
A_LIT = [("lda <CharFace",4),("bpl right",3),("negb",2),("right addb <CharX",4),("rts",5)]
ADDCHARX_LIT = 8 + 4 + sum(c for _,c in A_LIT)
CHX_LIT  = GETSEQ_LIT + 2 + 3 + GETSEQ_LIT + ADDCHARX_LIT + 4 + 4   # cmpb2, bne3, stb4, jmp ext4
GOTO_LIT = GETSEQ_LIT + (2+3)*3 + (2+3) + GETSEQ_LIT + 6 + GETSEQ_LIT + 4 + 6 + 4 + 4

# ---------- 6809 IDIOMATIC: sequence pointer lives in X across the interpreter ----------
# `ldb ,x+` reads AND advances in ONE 6-cycle instruction, replacing the whole GETSEQ sub.
GETSEQ_IDIOM = 6
ADDCHARX_IDIOM = 7 + sum(c for _,c in A_LIT)       # bsr(7) + body; no LC jump table needed
CHX_IDIOM  = GETSEQ_IDIOM + 2 + 3 + GETSEQ_IDIOM + ADDCHARX_IDIOM + 4 + 3   # bra=3
GOTO_IDIOM = GETSEQ_IDIOM + (2+3)*3 + (2+3) + 6 + 6 + 3   # ldx ,x++ style reload: ldd ,x++ (8) -> tfr d,x (6)
GOTO_IDIOM = GETSEQ_IDIOM + (2+3)*3 + (2+3) + 8 + 6 + 3    # ldd ,x++ = 5+3 = 8 ; tfr d,x = 6 ; bra = 3

print("=== 6502 (counted from the assembled listing) ===")
print(f"  GETSEQ call        {GETSEQ_6502:4d} cy   (jsr 6 + jmp-table 3 + body {sum(c for _,c in G6502)})")
print(f"  ADDCHARX call      {ADDCHARX_6502:4d} cy")
print(f"  chx  path          {CHX_6502:4d} cy")
print(f"  goto path          {GOTO_6502:4d} cy\n")
print("=== 6809 LITERAL transliteration ===")
print(f"  GETSEQ call        {GETSEQ_LIT:4d} cy      chx {CHX_LIT:4d}   goto {GOTO_LIT:4d}")
print("=== 6809 IDIOMATIC (seq pointer in X) ===")
print(f"  GETSEQ (ldb ,x+)   {GETSEQ_IDIOM:4d} cy      chx {CHX_IDIOM:4d}   goto {GOTO_IDIOM:4d}\n")

print("=== k per path ===")
for lbl,a,b,c in (("chx", CHX_6502, CHX_LIT, CHX_IDIOM), ("goto", GOTO_6502, GOTO_LIT, GOTO_IDIOM)):
    print(f"  {lbl:5s} 6502 {a:4d} | literal {b:4d} k={b/a:4.2f} | idiomatic {c:4d} k={c/a:4.2f}")
# equal-weight aggregate (SEQTABLE opcode frequency not cheaply available -> stated)
tot6502 = CHX_6502 + GOTO_6502
K_LIT = (CHX_LIT+GOTO_LIT)/tot6502
K_IDIOM = (CHX_IDIOM+GOTO_IDIOM)/tot6502
print(f"\n  AGGREGATE (equal weight)  k_literal = {K_LIT:.2f}   k_idiomatic = {K_IDIOM:.2f}")

# ---------- feasibility re-check ----------
BUDGET=178968; NB_MED,NB_P90=105259,153270; BLIT_T,BLIT_P=17099,27730
print(f"\n=== feasibility re-check (PA.9 blit + PA.5 non-blit x measured k) ===")
print(f"{'case':9s}{'k':>6s}{'blit':>9s}{'nonblit':>10s}{'total':>10s}{'vs budget':>11s}  verdict")
for lbl,blit,nb in (("typical",BLIT_T,NB_MED),("p90",BLIT_P,NB_P90)):
    for kl,k in (("literal",K_LIT),("idiomatic",K_IDIOM)):
        t=blit+nb*k
        v="FEASIBLE" if t<=BUDGET else ("MARGINAL" if t<=BUDGET*1.05 else "INFEASIBLE")
        print(f"{lbl:9s}{k:6.2f}{blit:9,.0f}{nb*k:10,.0f}{t:10,.0f}{t/BUDGET:10.2f}x  {v}  [{kl}]")
