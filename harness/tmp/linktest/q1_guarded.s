* ONE source, two build models. The guard is the same mechanism P2.1 used for
* dormancy, which the HAL governance already sanctions as per-project CONFIGURATION.
                ifdef   OBJTARGET
                export  foo
                endc
                org     $4000
foo             lda     #$A5
                sta     $0400
                rts
                end
