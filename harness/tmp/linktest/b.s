* b.s — stands in for an app calling into the kernel.
                ifdef   OBJTARGET
                import  foo
                export  start           ; the linker needs the entry symbol exported
                endc
                section code
start           jsr     foo             ; THE cross-module call the linker must resolve
                lda     #$5A
                sta     $0401           ; proof we returned
spin            bra     spin
                endsection
