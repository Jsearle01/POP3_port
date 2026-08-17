* d.s — app module, same one-source pattern.
                ifdef   OBJTARGET
                import  foo
                export  start
                section code
                else
                org     $4000
                endc
start           jsr     foo
                lda     #$5A
                sta     $0401
spin            bra     spin
                ifdef   OBJTARGET
                endsection
                endc
