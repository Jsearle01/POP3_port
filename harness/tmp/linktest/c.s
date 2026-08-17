* c.s — the one-source pattern candidate: BOTH the export AND the section
* directives guarded, so the identical file builds absolute or object.
                ifdef   OBJTARGET
                export  foo
                section code
                else
                org     $4000
                endc
foo             lda     #$A5
                sta     $0400
                rts
                ifdef   OBJTARGET
                endsection
                endc
