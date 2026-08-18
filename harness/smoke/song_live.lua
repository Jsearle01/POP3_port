-- song_live.lua — P4.5/P4.6: drive DECB to LOADM"SONG" + EXEC, and measure what came out.
--
-- ★ THE PROVEN LAUNCH PATTERN, and P4.5's first cut did not use it. It passed
-- `-autoboot_command` with a 3-second delay, which fires before DECB has a prompt — Jay:
-- "so it didn't laod the diskin mame, at least i didnt see it." Every working runner in
-- this project instead posts keystrokes from a frame notifier once the boot has settled
-- [mame-idioms-coco3-port.md §1/§2: no autoboot, DECB is the entry point; natkeyboard:post
-- AFTER boot settles], and the frame numbers below are the ones room_live/walk_test use.
--
-- ★★ THE GAP AFTER LOADM IS NOT COSMETIC. LOADM returns to the prompt only when the disk
-- read has finished; posting EXEC too early types into a busy DECB and the characters land
-- in the line-input buffer instead. 900 frames is what the other runners allow.
--
-- ★★★ ONE HOME FOR THE LAUNCH, FOUR USES. The same boot sequence serves: the audible run
-- for Jay (nothing set), the headless liveness check (P_OUT), the cost split (P_SPIN), and
-- the fidelity measurement (P_PULSE). The alternative was a script per use with a copy of
-- the boot sequence in each, and a copy is how the thing measured and the thing
-- demonstrated drift apart — which is exactly the failure P4.5 shipped.
--
--   P_OUT    write a report here and exit (otherwise: leave the window to Jay)
--   P_MODE   poked into probe_mode before EXEC. 0 = one pass of A then stop; 1 = A/gap/
--            B/gap, looping — the A/B for the ear.
--   P_SPIN   hal_vbl_spin address; enables the cost block
--   P_PULSE  set to 1 to tap $FF20 and measure the EMITTED pulse and segment period
--   P_TICKS  sp_ticks address }  needed by P_PULSE: they turn "what came out" into
--   P_WIDTH  sp_width address }  "what came out FOR THIS INTENDED VALUE"
local OUT   = os.getenv("P_OUT")
local ENTRY = tonumber(os.getenv("P_ENTRY") or "2000", 16)
local TO    = tonumber(os.getenv("P_TO") or "3000")
local MODE  = tonumber(os.getenv("P_MODE") or "0")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local ST, RUNS, FQ, MG = ENTRY + 3, ENTRY + 4, ENTRY + 6, ENTRY + 8
local MODEA = ENTRY + 10
local SPIN  = tonumber(os.getenv("P_SPIN") or "0", 16)
local PULSE = tonumber(os.getenv("P_PULSE") or "0")
local TICKA = tonumber(os.getenv("P_TICKS") or "0", 16)
local WIDA  = tonumber(os.getenv("P_WIDTH") or "0", 16)
local PTRA  = tonumber(os.getenv("P_PTR") or "0", 16)
local DUR   = tonumber(os.getenv("P_DUR") or "0")     -- intended song length, ms

local CPU_MHZ, TICK_US, VBL, SC = 1.7897725, 63.695, 29859, 7
local DLY_CYC = 5

-- ★★ THE COST, FROM THIS RUN'S OWN CONTROL. The probe's foreground is nothing but
-- HAL_time_vbl_wait, and status 1 (playing, FIRQ live) versus status 3 (torn down, FIRQ
-- gone) are the SAME loop on the SAME machine with and without the music. So the spin
-- difference is the player's cost, and needs no separate baseline run to be wrong about.
-- Method and the 7-cycle constant: mame-idioms-coco3-port.md §0a, as P4.2 used.
local spins, per = 0, {}
local function u16(a) return mem:read_u8(a) * 256 + mem:read_u8(a + 1) end

local out = OUT and io.open(OUT, "w") or nil
local function log(s) if out then out:write(s .. "\n"); out:flush() end end

if SPIN ~= 0 then
    _G._t_spin = mem:install_read_tap(SPIN, SPIN, "spin", function(off, data, mask)
        spins = spins + 1
        return data
    end)
end

-- ---------------------------------------------------------------------------
-- ★★★ THE FIDELITY TAP. P4.5 shipped two pulse-width defects in a row — a fixed 4 us
-- pulse, then a mapping that ignored the handler's own overhead — and NOTHING in the
-- harness could see either, because 4 us and 22 us consume the same rows and tear down
-- identically. A liveness check is not a fidelity check. This times the actual $FF20
-- writes, so the emitted pulse and the emitted period are measured rather than modelled,
-- and each is attributed to the intended value that produced it.
-- ---------------------------------------------------------------------------
local by_w, by_t, ev, t_rise, prev_ticks = {}, {}, 0, nil, nil
local lat, prev_ptr, t_first, t_last = {}, nil, nil, nil
if PULSE ~= 0 then
    local function now()
        local t = manager.machine.time
        return t.seconds + t.attoseconds / 1.0e18
    end
    _G._t_dac = mem:install_write_tap(0xFF20, 0xFF20, "dac", function(off, data, mask)
        local t = now()
        if data ~= 0 then
-- ★★★ THE INTERVAL BELONGS TO THE PREVIOUS SEGMENT'S TICK VALUE, NOT THIS ONE. The handler
-- restarts the timer BEFORE it opens the pulse, so the value in force at rise k is what
-- governs rise k -> rise k+1. P4.6's first cut attributed each interval to the value read
-- at its END and got ticks 96 reporting a 1.5 ms period — an off-by-one that reads as a
-- broken clock rather than as a broken index, which is why the fit below is printed
-- alongside the per-value rows: a wrong attribution cannot produce a straight line.
            local tk = TICKA ~= 0 and u16(TICKA) or 0
            local pt = PTRA ~= 0 and u16(PTRA) or 0
            if t_rise and prev_ticks and prev_ticks > 0 and prev_ticks <= 4095 then
                local pd = (t - t_rise) * 1.0e6
                if pd > 0 and pd < 20000 then       -- drops the inter-pass gap and the arm
                    by_t[prev_ticks] = by_t[prev_ticks] or { n = 0, s = 0 }
                    by_t[prev_ticks].n = by_t[prev_ticks].n + 1
                    by_t[prev_ticks].s = by_t[prev_ticks].s + pd
-- ★★★ TWO LATENCIES, NOT ONE, AND WHICH ONE APPLIES IS A PROPERTY OF THE ROW. The
-- interrupt that ENDS a run also walks the table before it restarts the timer, so that one
-- segment is longer by the whole of load_run. Split by whether sp_ptr moved — the
-- mechanism — rather than by the tick value, which merely CORRELATES with it here because
-- the low notes happen to be the singleton runs. §2H: name the routine, do not infer it
-- from the pattern it happens to make in this song.
                    local k = (pt ~= prev_ptr) and "adv" or "steady"
                    lat[k] = lat[k] or { n = 0, s = 0, lo = 1e9, hi = -1e9 }
                    local b = lat[k]
                    local o = pd - prev_ticks * TICK_US
                    b.n, b.s = b.n + 1, b.s + o
                    if o < b.lo then b.lo = o end
                    if o > b.hi then b.hi = o end
                    if not t_first then t_first = t_rise end
                    t_last = t
                end
            end
            prev_ticks, prev_ptr = tk, pt
            t_rise = t
        elseif t_rise then
            local w = WIDA ~= 0 and mem:read_u8(WIDA) or 0
            local pw = (t - t_rise) * 1.0e6
            if w > 0 and pw > 0 and pw < 200 then
                by_w[w] = by_w[w] or { n = 0, s = 0, lo = 1e9, hi = 0 }
                local b = by_w[w]
                b.n, b.s = b.n + 1, b.s + pw
                if pw < b.lo then b.lo = pw end
                if pw > b.hi then b.hi = pw end
                ev = ev + 1
            end
        end
        return data
    end)
end

local state, t0, reported, maxst, done_at = "boot", nil, false, 0, nil
local fq_prev, fq_frames, fq_sum = 0, 0, 0
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if reported then return end
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"SONG"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then
            mem:write_u8(MODEA, MODE)      -- ★ poked AFTER the load, or LOADM overwrites it
            nk:post('EXEC\n'); state = "run"
        end
        return
    end
    if not out then return end

    local st = mem:read_u8(ST)
    if st > maxst and st <= 3 then maxst = st end
    if SPIN ~= 0 and (st == 1 or st == 3) then
        per[st] = per[st] or { f = 0, s = 0 }
        per[st].f = per[st].f + 1
        per[st].s = per[st].s + spins
    end
    -- the FIRQ RATE, measured. The cost per frame is rate x cost per interrupt, and
    -- without the rate the per-interrupt number cannot be checked against the handler.
    if st == 1 then
        local f = u16(FQ)
        local d = f - fq_prev
        if d < 0 then d = d + 65536 end
        if fq_prev ~= 0 and d > 0 and d < 200 then
            fq_frames, fq_sum = fq_frames + 1, fq_sum + d
        end
        fq_prev = f
    end
    spins = 0
-- ★ THE TORN-DOWN STATE IS THE CONTROL, SO IT NEEDS FRAMES OF ITS OWN. The first cut
-- exited the instant status reached 3 and the cost block never had a baseline to compare
-- against — a control with zero samples, which is the shape P4.2's timing seed hit too.
    if st == 3 then
        done_at = done_at or fn
        if fn <= done_at + 150 then return end
    elseif fn <= TO then
        return
    end
    reported = true

    log("# THE SLICE, HEADLESS — does it load, play and tear down?")
    log(string.format("# probe_mode %d   probe_status high-water %d of 3 (1=playing 2=finished 3=torn down)",
                      MODE, maxst))
    log(string.format("# runs consumed %d   FIRQ entries %d   magic $%04X (want $504E)",
                      u16(RUNS), u16(FQ), u16(MG)))
    if maxst >= 3 and u16(MG) == 0x504E then
        log("# PASS — it loaded, played to the terminator and tore the FIRQ down.")
    elseif maxst == 0 then
        log("# FAIL — the probe never started. The LOADM/EXEC did not take.")
    else
        log(string.format("# FAIL — stalled at status %d.", maxst))
    end

    if fq_frames > 30 then
        log("")
        log(string.format("# ★ FIRQ RATE, MEASURED: %.2f interrupts/frame over %d frames",
                          fq_sum / fq_frames, fq_frames))
    end

    if SPIN ~= 0 and per[1] and per[3] and per[1].f > 30 and per[3].f > 30 then
        local wp = VBL - (per[1].s / per[1].f) * SC
        local wq = VBL - (per[3].s / per[3].f) * SC
        log("")
        log("# ★ MEASURED COST — the same wait loop, with the player live and torn down.")
        log(string.format("#   playing   %6.1f spins/f -> %6.0f cyc/f   (%d frames)",
                          per[1].s / per[1].f, wp, per[1].f))
        log(string.format("#   torn down %6.1f spins/f -> %6.0f cyc/f   (%d frames)",
                          per[3].s / per[3].f, wq, per[3].f))
        log(string.format("#   THE PLAYER COSTS %+.0f cyc/frame = %.1f%% of the VBL budget",
                          wp - wq, 100.0 * (wp - wq) / VBL))
        if fq_frames > 30 then
            local rate = fq_sum / fq_frames
            log(string.format("#   -> %.0f cycles per interrupt, at %.2f interrupts/frame",
                              (wp - wq) / rate, rate))
        end
    end

    if PULSE ~= 0 then
        log("")
        log("# ★★★ WHAT ACTUALLY CAME OUT — $FF20 writes, timed on the bus.")
        log(string.format("#   %d pulses observed. A zero here is the tap failing, not silence;", ev))
        log("#   the two read identically and only the count tells them apart.")
        if ev > 0 then
            log("#")
            log("#   EMITTED PULSE, per intended width (the AMPLITUDE):")
            local ks = {}
            for k in pairs(by_w) do ks[#ks + 1] = k end
            table.sort(ks)
            local sn, ss = 0, 0
            for _, w in ipairs(ks) do
                local b = by_w[w]
                local m = b.s / b.n
                log(string.format("#     width %-3d -> %6.2f us  (%.2f..%.2f, n=%d)  overhead %.1f cyc",
                                  w, m, b.lo, b.hi, b.n, m * CPU_MHZ - DLY_CYC * w))
                sn = sn + b.n
                ss = ss + (m * CPU_MHZ - DLY_CYC * w) * b.n
            end
            log(string.format("#   => PULSE OVERHEAD, MEASURED: %.2f cycles outside the delay loop",
                              ss / sn))
            log("#      Feed this back to pack_song.py --pulse-overhead-cyc.")
            log("#")
            log("#   EMITTED SEGMENT PERIOD, per intended tick count (the PITCH):")
            local kt = {}
            for k in pairs(by_t) do kt[#kt + 1] = k end
            table.sort(kt)
            for i = 1, math.min(#kt, 40) do
                local t = kt[i]
                local b = by_t[t]
                log(string.format("#     ticks %-5d -> %8.1f us  (n=%d)  vs %.1f us at %.3f us/tick",
                                  t, b.s / b.n, b.n, t * TICK_US, TICK_US))
            end
            if #kt > 40 then log(string.format("#     ... %d more tick values", #kt - 40)) end
-- ★★ THE TICK LENGTH IS CONFIRMED, NOT ASSUMED, and the cheapest confirmation is the
-- ADJACENT DIFFERENCE: consecutive tick values one apart must differ by exactly one tick,
-- and that is independent of any offset. If this says 63.7 the clock is nominal and every
-- remaining error is an offset; if it does not, the offset numbers below mean nothing.
            local dn, ds = 0, 0
            for i = 2, #kt do
                local d = kt[i] - kt[i - 1]
                if d >= 1 and d <= 4 then
                    dn = dn + 1
                    ds = ds + (by_t[kt[i]].s / by_t[kt[i]].n
                             - by_t[kt[i - 1]].s / by_t[kt[i - 1]].n) / d
                end
            end
            if dn > 0 then
                log("#")
                log(string.format("#   TICK LENGTH from %d adjacent pairs: %.3f us  (nominal %.3f, %+.2f%%)",
                                  dn, ds / dn, TICK_US, 100.0 * (ds / dn - TICK_US) / TICK_US))
            end
-- ★★★ AND THEN THE OFFSET, SPLIT BY MECHANISM. Two populations, because two different
-- amounts of code run before the timer is rewritten. The steady one is FIRQ entry plus the
-- handler's prologue; the other adds the whole of load_run. Both are handler constants and
-- both go into pack_song.py, which weights them per row by the run length.
            log("#")
            log("#   ★ SEGMENT-PERIOD OFFSET (emitted minus ticks*63.695), BY MECHANISM:")
            for _, k in ipairs({ "steady", "adv" }) do
                local b = lat[k]
                if b then
                    log(string.format("#     %-7s n=%-5d mean %+7.2f us  (%.1f..%.1f)  = %.0f cyc, %.2f ticks",
                                      k, b.n, b.s / b.n, b.lo, b.hi,
                                      (b.s / b.n) * CPU_MHZ, (b.s / b.n) / TICK_US))
                end
            end
            log("#     steady -> pack_song.py --latency-us ; adv -> --latency-adv-us")
            log("#     ★ A large part of the steady offset is NOT the handler: SockmasterGime.md")
            log("#       records that the GIME runs nnn+2 (1986) or nnn+1 (1987) ticks, so ~127 us")
            log("#       of it is the chip, not the code, and no amount of tightening removes it.")
            if t_first and t_last and DUR > 0 then
                local got = (t_last - t_first) * 1000.0
                log("#")
                log(string.format("#   ★★ TOTAL EMITTED DURATION %.1f ms vs %.1f ms measured off the oracle",
                                  got, DUR))
                log(string.format("#      = %+.2f%%. This is the one number that says whether the song is",
                                  100.0 * (got - DUR) / DUR))
                log("#      IN TUNE ON AVERAGE, and it is not derivable from anything above.")
            end
        end
    end
    out:close()
    manager.machine:exit()
end)
