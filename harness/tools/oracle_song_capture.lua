-- oracle_song_capture.lua — P4.7/P4.7a: capture the oracle's speaker PER SONG ID.
--
-- ★★★ THE UNIT IS A SONG, AND THREE INSTRUMENTS IN A ROW GOT THAT WRONG IN THE SAME WAY.
-- P4.4 recorded 400 frames of speaker output. P4.6b recorded 5,400 and cut it "where the
-- music stops — on a six-second rest". Both derived a boundary from the OUTPUT. Jay: "that
-- entire track won't be played continuously during the intro. There are sections played at
-- specific times during each intro scene." The boundary is the CALL, and it is observable:
--
--     SUBS.S:667   lda #s_Princess / ldx #8 / jsr PlaySongI
--
-- PlaySongI BLOCKS until the song ends, so a song occupies one contiguous stretch between
-- its call and the next thing the caller does. Recording the calls and the speaker in ONE
-- run puts both on one clock and removes the alignment assumption entirely.
--
-- ---------------------------------------------------------------------------
-- TAPPING A CODE ROUTINE ON A 6502, WHICH CANNOT BE DONE DIRECTLY
-- ---------------------------------------------------------------------------
-- ★★ 6502 read-taps on CODE addresses silently false-0 through the opcode-fetch bypass
-- [mame-idioms-apple2e-oracle.md §1], so $FFB5 cannot be tapped. But PlaySongI reads
-- `musicon` at $031A four instructions in — a DATA read, not subject to the bypass — and
-- the song number is in Y at that instant, because `tay` two instructions earlier put it
-- there. So the tap is on the data the routine touches, and the id comes from the register.
--
-- ★★★ AND $031A HAS OTHER READERS, WHICH ALREADY COST ONE RUN. A first pass kept the first
-- 500 events flat; a per-frame caller at $0CAE produced 1,514 of the 1,521 reads and
-- crowded out every song trigger after ~30 s. The cap is now PER PC, so a caller that fires
-- 200x more often cannot hide one that fires six times. The histogram is printed either
-- way: a filter you cannot see is a filter you cannot check.
local OUT   = os.getenv("P_OUT") or "build/tmp/oracle_song_capture.log"
local DIR   = os.getenv("P_DIR") or "build/tmp"
local AFTER = tonumber(os.getenv("P_AFTER") or "5400")
local PERPC = tonumber(os.getenv("P_PERPC") or "40")
local MAXEV = tonumber(os.getenv("P_MAXEV") or "400000")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local SPEED, MUSICON, SPKR = 0x030C, 0x031A, 0xC030

-- the TITLE set, from SOUNDNAMES.S. ★ The ids OVERLAP between sets (s_Princess=7 and the
-- game set's s_Vict=7) and are disambiguated ONLY by which MUSIC.SET is resident — P4.1
-- named that open and it still is. PlayCut0 runs under set 1, so these names apply HERE and
-- the id-space is recorded with every capture rather than assumed.
local NAME = { [7]="s_Princess", [8]="s_Squeek", [9]="s_Vizier",
               [10]="s_Buildup", [11]="s_Magic", [12]="s_StTimer" }

local armed_at, t0 = nil, nil
local calls, pcs, kept = {}, {}, {}
local ev, nev = {}, 0

local function now()
    local t = manager.machine.time
    return t.seconds + t.attoseconds / 1.0e18
end

_G._tsp = mem:install_write_tap(SPEED, SPEED, "sp", function(off, data, mask)
    if data == 12 and armed_at == nil then armed_at = scr:frame_number(); t0 = now() end
    return data
end)

_G._tm = mem:install_read_tap(MUSICON, MUSICON, "mon", function(off, data, mask)
    if armed_at == nil then return data end
    local pc = cpu.state["PC"].value
    pcs[pc] = (pcs[pc] or 0) + 1
    kept[pc] = kept[pc] or 0
    if kept[pc] < PERPC then
        kept[pc] = kept[pc] + 1
        calls[#calls + 1] = { t = now() - t0, pc = pc, y = cpu.state["Y"].value }
    end
    return data
end)

_G._tk = mem:install_read_tap(SPKR, SPKR, "spkr", function(off, data, mask)
    if armed_at == nil then return data end
    nev = nev + 1
    if #ev < MAXEV then ev[#ev + 1] = now() - t0 end
    return data
end)

local reported = false
_G._n = emu.add_machine_frame_notifier(function()
    if reported or armed_at == nil then return end
    if scr:frame_number() <= armed_at + AFTER then return end
    reported = true

    log("# PER-SONG CAPTURE — the calls and the speaker, on one clock, one run")
    log(string.format("# armed at frame %d (PlayCut0's SPEED 12); recorded %d frames",
                      armed_at, AFTER))
    log("")
    log(string.format("# ★ SPEAKER TOGGLES %d (%d kept)   $031A READS %d", nev, #ev, (function()
        local s = 0; for _, v in pairs(pcs) do s = s + v end; return s end)()))
    log("#   A zero on either reads exactly like a machine that made no sound; only the")
    log("#   count separates a silent machine from a tap that never fired.")
    if nev == 0 or #calls == 0 then
        log("# ★★★ ZERO on one of them. Do not read this as a finding about the music.")
        out:close(); manager.machine:exit(); return
    end
    log("")
    log("# PC HISTOGRAM for $031A — which reader this was, and how the trigger was picked")
    local ks = {}
    for k in pairs(pcs) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do
        log(string.format("#   $%04X  %6d seen, %d kept", k, pcs[k], kept[k] or 0))
    end
    log("")

    -- ★ A TRIGGER IS A READ CARRYING A PLAUSIBLE SONG ID. The flood callers carry 100 and
    -- 255 in Y; PlaySongI carries the song number. Both criteria are stated and both are
    -- visible above, so this is a filter the reader can audit rather than trust.
    local trig = {}
    for _, c in ipairs(calls) do
        if c.y >= 1 and c.y <= 16 and pcs[c.pc] < 100 then trig[#trig + 1] = c end
    end
    table.sort(trig, function(a, b) return a.t < b.t end)

    log(string.format("# ★★ SONG CALLS: %d", #trig))
    log("# id   name          called at    speaker events    span (s)   last event")
    local lines = {}
    for i, c in ipairs(trig) do
        local stop = (i < #trig) and trig[i + 1].t or 1e9
        local n, first, last = 0, nil, nil
        for _, t in ipairs(ev) do
            if t >= c.t and t < stop then
                n = n + 1
                first = first or t
                last = t
            end
        end
        lines[#lines + 1] = { c = c, n = n, first = first, last = last, stop = stop }
        log(string.format("  %-4d %-13s %8.2f     %8d      %8.2f   %8.2f",
                          c.y, NAME[c.y] or "(not title-set)", c.t, n,
                          last and (last - c.t) or 0, last or 0))
    end
    log("")
    log("# ★★★ THE SPAN IS THE SONG; THE REST OF THE INTERVAL IS THE BEATS. PlaySongI blocks")
    log("#   until the song ends, so the speaker goes quiet at the end of the song and stays")
    log("#   quiet while the caller animates. Storing that quiet inside the audio would be a")
    log("#   SECOND HOME for durations the port already owns as frame counts.")
    log("")

    -- ---- one pairs file per song -------------------------------------------------
    for i, L in ipairs(lines) do
        local name = NAME[L.c.y] or ("id" .. L.c.y)
        local path = string.format("%s/song_%d_%s.txt", DIR, L.c.y, name)
        local f = io.open(path, "w")
        if f then
            f:write(string.format("# P4.7a — %s (title set, id %d), captured PER SONG\n", name, L.c.y))
            f:write(string.format("# armed frame %d; called at t=%.3f s after the arm\n", armed_at, L.c.t))
            f:write("# pulse_us rest_us, one segment per line. The inter-song silence is NOT\n")
            f:write("# here: it belongs to the beat structure, which the port already owns.\n")
            -- write the (pulse, rest) pairs in order
            local seq = {}
            for _, t in ipairs(ev) do
                if t >= L.c.t and L.last and t <= L.last then seq[#seq + 1] = t end
            end
            local np = 0
            for k = 1, #seq - 2, 2 do
                f:write(string.format("%.3f %.3f\n",
                        (seq[k + 1] - seq[k]) * 1e6, (seq[k + 2] - seq[k + 1]) * 1e6))
                np = np + 1
            end
            f:close()
            log(string.format("# wrote %-5d segments to %s", np, path))
        end
    end
    out:close()
    manager.machine:exit()
end)
