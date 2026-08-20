-- oracle_width_by_song.lua — P4.42: on the ORACLE, is s_Princess also the harshest song?
--
-- ★★★ THE QUESTION, AND WHY IT DECIDES BETWEEN TWO VERY DIFFERENT FIXES. Jay hears the
-- port's cutscene as correct everywhere except s_Princess. P4.41 found the structural
-- reason: s_Princess is the ONLY song in the game that uses envelope 5, and envelope 5 is
-- the only one in use whose pattern ends on a HIGH amplitude --
--
--     envelope 0,1,3,4   ... 01 00 FF   -> "$FF = hold the last amplitude" holds SILENCE
--     envelope 5          01 0B 0D FF   -> holds $0D, 13 of a maximum 14
--
-- so s_Princess sustains near maximum where every other song fades. The port's data is
-- byte-exact and its hold is implemented to spec, which PREDICTS that the oracle's own
-- s_Princess is the harshest song on the oracle too.
--
--   if it IS      the port is faithful and the fuzziness is the COMPOSITION. Softening it
--                 becomes a §2I decision for Jay, not a bug to fix.
--   if it is NOT  the difference is in how a held amplitude reaches the speaker, and that
--                 is finally a narrow question.
--
-- ---------------------------------------------------------------------------
-- HOW EACH SONG IS SEGMENTED AND MEASURED IN ONE RUN
-- ---------------------------------------------------------------------------
-- $C030 is the speaker soft switch; `LDA $C030` toggles it, so the ADDRESS is the event and
-- this is a read tap. ★ The standing 6502 warning is about read-taps on CODE addresses
-- silently false-0 through the opcode-fetch bypass [mame-idioms-apple2e-oracle.md §1];
-- $C030 is an I/O read performed as data, so the bypass does not apply -- the same reason
-- P4.4's tap worked. The run reports its toggle count FIRST so a tap that never fired reads
-- as a failure rather than as silence.
--
-- Song boundaries come from `musicon` $031A read at PC=$E479 -- PlaySongI's own read, with
-- the id in Y. P4.26b's histogram established that $E479 is the real call site and $0CAE is
-- the play loop firing hundreds of times; the filter is on PC and the histogram is still
-- printed so it stays checkable.
--
-- ★★ SHORT vs LONG: P4.4 measured the two populations as 7.8-22.5 us (the PULSE, whose
-- width IS the amplitude) and 1061-9883 us (the rest of the segment). 100 us separates them
-- with two orders of magnitude to spare, so the split needs no fitting.
local OUT   = os.getenv("P_OUT") or "build/tmp/oracle_width_by_song.log"
local SPLIT = tonumber(os.getenv("P_SPLIT") or "100")     -- us; below = a pulse

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)

local SPK     = 0xC030
local MUSICON = 0x031A

local NAME = { [1]="s_Presents",[2]="s_Byline",[3]="s_Title",[4]="s_Prolog",[5]="s_Sumup",
               [7]="s_Princess",[8]="s_Squeek",[9]="s_Vizier",[10]="s_Buildup",
               [11]="s_Magic",[12]="s_StTimer" }

local function now() return manager.machine.time:as_double() end

local cur, order, acc = nil, {}, {}
local last_t, ntog = nil, 0
local pcs = {}

_G._tm = mem:install_read_tap(MUSICON, MUSICON, "mon", function(off, data, mask)
    local pc = cpu.state["PC"].value
    pcs[pc] = (pcs[pc] or 0) + 1
    if pc ~= 0xE479 then return data end
    local y = cpu.state["Y"].value
    local nm = NAME[y]
    if nm then
        if acc[nm] == nil then acc[nm] = { n = 0, sum = 0, mx = 0, mn = 1e9 }
                               order[#order + 1] = nm end
        cur = nm
        last_t = nil
    end
    return data
end)

_G._ts = mem:install_read_tap(SPK, SPK, "spk", function(off, data, mask)
    ntog = ntog + 1
    if cur == nil then return data end
    local t = now()
    if last_t ~= nil then
        local us = (t - last_t) * 1e6
        if us < SPLIT then
            local a = acc[cur]
            a.n = a.n + 1; a.sum = a.sum + us
            if us > a.mx then a.mx = us end
            if us < a.mn then a.mn = us end
        end
    end
    last_t = t
    return data
end)

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    if done then return end
    if scr:frame_number() < 7600 then return end     -- ~127 s: the intro AND the cutscene
    done = true

    local f = io.open(OUT, "w")
    f:write("# the ORACLE's pulse WIDTH per song -- the width IS the amplitude.\n")
    f:write(string.format("# speaker toggles observed: %d\n", ntog))
    if ntog == 0 then
        f:write("# ZERO — the tap never fired. FAILURE, not silence.\n")
        f:close(); manager.machine:exit(); return
    end
    f:write(string.format("# intervals under %d us counted as pulses (P4.4: 7.8-22.5 vs 1061-9883).\n#\n",
            SPLIT))
    f:write(string.format("  %-12s %7s %9s %9s %9s\n",
            "song", "pulses", "mean us", "min", "max"))
    for _, nm in ipairs(order) do
        local a = acc[nm]
        if a.n > 16 then
            f:write(string.format("  %-12s %7d %9.1f %9.1f %9.1f\n",
                    nm, a.n, a.sum / a.n, a.mn, a.mx))
        else
            f:write(string.format("  %-12s %7d   (too few to characterise)\n", nm, a.n))
        end
    end
    f:write("#\n# --- PC histogram for the $031A tap (unfiltered) ---\n")
    for pc, c in pairs(pcs) do f:write(string.format("#   $%04X  x%d\n", pc, c)) end
    f:write("#\n# ★ THE COMPARISON: if s_Princess's MEAN sits near its MAX while the other\n")
    f:write("# songs' means sit well below theirs, then the oracle sustains that song near\n")
    f:write("# full amplitude too -- the port is faithful and the harshness is the music.\n")
    f:close()
    manager.machine:exit()
end)
