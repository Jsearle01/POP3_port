* ---------------------------------------------------------------
* interp_probe.s — P4.19: the INTERPRETED player, on the target, and the A/B against
* the capture it replaces.
*
* ★★★ WHY BOTH PLAYERS LIVE IN ONE BINARY. P4.6 built the dither A/B this way and Jay's
* words were the reason: "it's going to be hard to gate something without knowing what it
* would sound like the other way." Two binaries is how the thing measured and the thing
* demonstrated drift apart — and this A/B is a bigger question than the dither's, because
* the two paths do not share a note. One reads 1,024 bytes of score; the other replays
* 3,137 bytes of recording -- of this one song.
*
* PASS A = INTERPRET   msys_player.s walking MUSIC.SET1's own bytes.
* PASS B = CAPTURE     the oracle's own per-song recording of THE SAME SONG, replayed by
*                      the same FIRQ+DAC back end gated on Jay's ear since P4.5.
*
* ★ The two passes SHARE the audio path, the DAC, the pulse shape and the tear-down. The
* only thing that differs is where the (period, width) pairs come from. That is what makes
* the A/B answerable: anything Jay hears is the decode, not the hardware.
*
* Published for the harness:
*   $2003  probe_status  1B  0=boot 1=playing 2=finished 3=torn down
*   $2004  probe_ticks   2B  msys ticks elapsed in the last interpret pass
*   $2006  probe_pass    1B  0 = interpret, 1 = capture
*   $2008  probe_magic   2B  $50 4E once torn down
*   $200A  probe_mode    1B  POKED BEFORE EXEC:
*                              0 = ONE interpret pass, then stop   (headless / measured)
*                              1 = interpret, gap, capture, gap, repeat  (Jay's ear)
*                              2 = ONE capture pass, then stop     (the same measurement,
*                                  aimed at the other path)
*   $200B  probe_song    1B  POKED BEFORE EXEC: the song id to interpret. Default 7
*                            (s_Princess) — the one song whose capture is uncontaminated
*                            and therefore the only clean A/B available.
*   $200C  probe_frames  2B  VBL frames the last pass occupied — the PLAN-duration assert
* ---------------------------------------------------------------
                ifdef   OBJTARGET
                section prog
                export  probe_entry
                else
                org     $2000
                setdp   0
                endc

                import  HAL_sys_init
                import  HAL_time_init
                import  HAL_time_vbl_wait
                import  HAL_gfx_set_mode
                import  msys_init
                import  msys_play
                import  msys_stop
                import  msys_playing
                import  msys_ticks

probe_entry     jmp     probe_start     ; $2000 — EXEC address

probe_status    fcb     0               ; $2003
probe_ticks     fdb     0               ; $2004
probe_pass      fcb     0               ; $2006
                fcb     0               ; $2007 (pad)
probe_magic     fdb     0               ; $2008
probe_mode      fcb     0               ; $200A
probe_song      fcb     7               ; $200B
probe_frames    fdb     0               ; $200C

PROBE_MAGIC     equ     $504E
DAC             equ     $FF20
STACK_TOP       equ     $7F00
GAP_FRAMES      equ     90              ; ~1.5 s of silence between the two passes

* ---------------------------------------------------------------
probe_start
                orcc    #$50
                lds     #STACK_TOP
                clra
                tfr     a,dp

                jsr     HAL_sys_init
                jsr     HAL_time_init
                lda     #0              ; GFX_MODE_320x192x4 — a screen, so the run is visible
                jsr     HAL_gfx_set_mode
                jsr     msys_init

                lda     #1
                sta     probe_status
                andcc   #$EF            ; VBL IRQs on, so HAL_time_vbl_wait works

ip_pass
                lda     probe_mode
                cmpa    #2
                beq     ip_bonly

                clr     probe_pass
                bsr     play_interp
                lda     probe_mode
                bne     ip_loopb
                lda     #2
                sta     probe_status
                bra     ip_finish

ip_bonly        lda     #1
                sta     probe_pass
                bsr     play_capture
                lda     #2
                sta     probe_status
                bra     ip_finish

ip_loopb        bsr     ip_gap
                lda     #1
                sta     probe_pass
                bsr     play_capture
                bsr     ip_gap
                bra     ip_pass

ip_finish
                jsr     msys_stop
                jsr     cap_stop
                lda     #3
                sta     probe_status
                ldd     #PROBE_MAGIC
                std     probe_magic
ip_hold         jsr     HAL_time_vbl_wait
                bra     ip_hold

ip_gap          pshs    a
                lda     #GAP_FRAMES
                sta     ip_gapn
ip_gap1         jsr     HAL_time_vbl_wait
                dec     ip_gapn
                bne     ip_gap1
                puls    a,pc

* ---------------------------------------------------------------
* play_interp — one pass of the interpreted player, timed in VBL frames.
*
* ★ THE FOREGROUND DOES NOTHING BUT COUNT FRAMES. That is deliberate and it is the same
* choice song_probe.s made: the whole claim of the interrupt architecture is that the
* music does not need the CPU's attention, and a foreground that helped would hide a
* failure of exactly that. The frame count IS the PLAN-duration assert's input.
* ---------------------------------------------------------------
play_interp
                pshs    a,b,x
                ldd     #0
                std     probe_frames
                lda     probe_song
                jsr     msys_play
pi_wait         jsr     HAL_time_vbl_wait
                ldd     probe_frames
                addd    #1
                std     probe_frames
                jsr     msys_playing
                bne     pi_wait
                jsr     msys_stop
                ldd     msys_ticks
                std     probe_ticks
                puls    a,b,x,pc

* ---------------------------------------------------------------
* play_capture — one pass of the CAPTURED table, through the identical back end.
* This is song_probe.s's handler, unchanged except for the dither (retired at P4.6a).
* ---------------------------------------------------------------
play_capture
                pshs    a,b,x
                ldd     #0
                std     probe_frames
                ldx     #song_a
                bsr     cap_start
pc_wait         jsr     HAL_time_vbl_wait
                ldd     probe_frames
                addd    #1
                std     probe_frames
                lda     cap_playing
                bne     pc_wait
                bsr     cap_stop
                puls    a,b,x,pc

cap_start
                stx     cap_ptr
                lda     #1
                sta     cap_playing
                lda     #$7E                    ; JMP
                sta     $010F
                ldd     #cap_handler
                std     $0110
                clr     $FF91                   ; TINS=0 — the table is packed for it
                lda     #$6C+$10                ; FEN on
                sta     $FF90
                bsr     cap_load
                ldd     cap_ticks
                stb     $FF95                   ; ★ LSB THEN MSB: writing $FF94 restarts it
                sta     $FF94
                lda     #$20
                sta     $FF93
                andcc   #$BF
                rts

cap_stop
                orcc    #$40
                clr     $FF93
                clr     $FF94
                clr     $FF95
                lda     #$6C
                sta     $FF90
                clr     DAC
                clr     cap_playing
                rts

cap_load
                pshs    a,b,x
                ldx     cap_ptr
                ldd     ,x++
                beq     cl_end
                std     cap_ticks
                lda     ,x+                     ; the retired dither numerator; ignored
                lda     ,x+
                sta     cap_width
                lda     ,x+
                sta     cap_count
                stx     cap_ptr
                ldd     cap_ticks
                stb     $FF95
                sta     $FF94
                andcc   #$FE
                puls    a,b,x,pc
cl_end          clr     $FF94
                clr     $FF95
                clr     DAC
                clr     cap_playing
                orcc    #$01
                puls    a,b,x,pc

cap_handler
                pshs    a,b,x
                lda     $FF93                   ; acknowledge
                dec     cap_count
                bne     ch_tick
                bsr     cap_load
                bcs     ch_out
ch_tick         ldb     cap_width
                beq     ch_quiet
                lda     #$FC
                sta     DAC
ch_pulse        decb
                bne     ch_pulse
                stb     DAC
ch_quiet
ch_out          puls    a,b,x
                rti

* ---------------------------------------------------------------
ip_gapn         fcb     0
cap_ptr         fdb     0
cap_ticks       fdb     0
cap_width       fcb     1
cap_count       fcb     0
cap_playing     fcb     0

* ★★★ song_princess.s, NOT song_a.s — AND THE DIFFERENCE IS WHAT MAKES THE A/B ANSWERABLE.
* `song_a` is the P4.4 capture of PlayCut0's WHOLE music stretch, cut at 37.6 s. The
* interpret pass plays s_Princess, which is 12.7 s. Pairing them asks the listener to
* compare thirteen seconds of one piece against thirty-seven seconds of a different one —
* which is not an A/B, and is the same shape as P4.6's "the port sounds like the same piece
* repeated 3 times" and P4.15's "I captured the wrong songs."
* ★★ This is the oracle's own per-song capture of song 7 — 6,930 segments, 12,724 ms,
* the SAME piece and the SAME length the interpreter walks. One variable: the decode.
                include "build/gen/song_princess.s"

                ifdef   OBJTARGET
                endsection
                else
                end     probe_entry
                endc
