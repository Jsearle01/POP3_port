* a.s — stands in for a HAL module. ONE source, two build models.
                ifdef   OBJTARGET
                export  foo
                endc
                section code
foo             lda     #$A5
                sta     $0400
                rts
                endsection
