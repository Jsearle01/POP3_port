-- oracle_song_ids.lua — P4.7: WHICH songs play in the cutscene, and WHEN.
--
-- ★★★ WHY THIS EXISTS. P4.6b captured 42.5 s off the oracle's speaker and called it "the
-- song". It is not one song. MASTER.S:1389 `PlaySongI` is called four times in the first
-- forty lines of PlayCut0 alone — s_Princess, s_Squeek ("door squeaks..."), s_Vizier,
-- s_Buildup — and the capture flattens all of them into one undifferentiated pulse train
-- with no boundary anywhere in it. Jay heard exactly that: "the oracle sounds like 3
-- different pieces."
--
-- ★★ SO THE BOUNDARY COMES FROM THE CONTENT, NOT FROM THE INSTRUMENT. Reading the gap
-- histogram and guessing which silences are song boundaries is inference; this measures the
-- calls.
--
-- ---------------------------------------------------------------------------
-- HOW A CODE ROUTINE IS TAPPED ON A 6502 WHEN CODE ADDRESSES CANNOT BE TAPPED
-- ---------------------------------------------------------------------------
-- ★★★ The standing warning [mame-idioms-apple2e-oracle.md §1]: 6502 read-taps on CODE
-- addresses silently false-0 through the opcode-fetch bypass. `PlaySongI` at $FFB5 is code,
-- so it cannot be tapped directly.
--
-- ★ But four instructions in it reads `musicon` at $031A — a DATA read, which is not
-- subject to the bypass (the same reason P4.4's $C030 tap works). And at that instant the
-- song number is in Y, because `tay` two instructions earlier put it there:
--
--     FFB5  jsr setaux
--     FFB8  beq ]rts
--     FFBA  tay            <- song # into Y
--     FFBB  lda musicon    <- $031A, the tap
--
-- ★★ $031A HAS OTHER READERS (GRAFIX.S, SPECIALK.S, SUBS.S), so the PC is recorded and
-- reported as a histogram rather than filtered silently. A filter you cannot see is a
-- filter you cannot check.
local OUT   = os.getenv("P_OUT") or "build/tmp/oracle_song_ids.log"
local AFTER = tonumber(os.getenv("P_AFTER") or "5400")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local SPEED   = 0x030C          -- MASTER.LST:530
local MUSICON = 0x031A          -- GAMEEQ.S:536

-- the title set, from SOUNDNAMES.S. ★ The ids OVERLAP between sets (s_Princess=7 and
-- s_Vict=7) and are disambiguated only by which MUSIC.SET is resident — P4.1 named that
-- open and it still is. PlayCut0 runs under set 1, so these are the right names HERE.
local NAME = { [7]="s_Princess", [8]="s_Squeek", [9]="s_Vizier",
               [10]="s_Buildup", [11]="s_Magic", [12]="s_StTimer" }

local armed_at, t0, ev, pcs, n = nil, nil, {}, {}, 0

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
    n = n + 1
    local pc = cpu.state["PC"].value
    pcs[pc] = (pcs[pc] or 0) + 1
    if #ev < 500 then
        ev[#ev + 1] = { t = now() - t0, pc = pc, y = cpu.state["Y"].value }
    end
    return data
end)

local reported = false
_G._n = emu.add_machine_frame_notifier(function()
    if reported or armed_at == nil then return end
    if scr:frame_number() <= armed_at + AFTER then return end
    reported = true

    log("# WHICH SONGS, AND WHEN — $031A reads with the PC and Y, on the running oracle")
    log(string.format("# armed at frame %d (PlayCut0's SPEED 12); recorded %d frames", armed_at, AFTER))
    log("")
    log(string.format("# ★ READS OBSERVED: %d. Zero would mean the tap never fired, which reads", n))
    log("#   exactly like a machine that played no music — only the count separates them.")
    if n == 0 then
        log("# ★★★ ZERO. Do not read this as 'no songs'.")
        out:close(); manager.machine:exit(); return
    end
    log("")
    log("# PC HISTOGRAM — which reader of $031A this was. $FFBE is the instruction AFTER")
    log("#   `lda musicon` at $FFBB inside PlaySongI; anything else is a different caller.")
    local ks = {}
    for k in pairs(pcs) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do
        log(string.format("#   $%04X  %d", k, pcs[k]))
    end
    log("")
    log("# THE SEQUENCE — every read, in order, with the song number in Y at that instant.")
    log("# id     t (s)    PC      name")
    local prev = nil
    for _, e in ipairs(ev) do
        log(string.format("  %-3d  %8.2f   $%04X   %s%s", e.y, e.t, e.pc,
                          NAME[e.y] or "(not a title-set id)",
                          prev and string.format("   [+%.2f s]", e.t - prev) or ""))
        prev = e.t
    end
    log("")
    log("# ★★ THE GAPS BETWEEN CONSECUTIVE ENTRIES ARE NOT SONG DURATIONS — PlaySongI blocks")
    log("#    until the song ends, but the caller animates frames in between. The duration of")
    log("#    a song is (next call) minus (this call) minus whatever animation followed it,")
    log("#    and this instrument cannot separate those two. It says WHICH and WHEN STARTED.")
    out:close()
    manager.machine:exit()
end)
