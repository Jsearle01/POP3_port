-- harness/smoke/walk_test.lua
--
-- POP P3.31 — THE VIZIER WALKS. Does he walk CORRECTLY, all the way along?
--
-- WHY THIS IS NOT room_test.lua WITH A BIGGER NUMBER. The room suite takes two captures
-- twelve frames apart, and it takes them AFTER a 600-frame star watch -- by which time
-- the vizier has walked fifteen cycles and is off near the left wall. Two adjacent
-- samples at the end of a walk can say "these two frames are right"; they cannot say
-- anything about the frames between the start and there, which is exactly where an
-- accumulating peel error lives. This captures from the first frame the room is up and
-- keeps capturing across the whole walk.
--
-- IT ALSO MEASURES TWO THINGS THAT CANNOT BE READ OFF A CAPTURE:
--
--   OCCUPANCY -- which sub-byte phases the walk actually puts each cel on. walk_phases.py
--   derives it from the sequence table; this reads it off the running machine, sampling
--   the slot record every frame. Two independent derivations of the same set is what
--   makes it a measurement rather than an assertion (P3.30 hand-computed it and got the
--   exact complement of the truth).
--
--   CADENCE -- the gaps between CEL CHANGES, which is frames-per-step as the screen sees
--   it. Measured off the cel byte, not off a counter the VM increments: a counter says
--   what the VM thinks it did.
local ENGINE  = tonumber(os.getenv("P_ENGINE") or "0x2000")
local CUR_BACK= tonumber(os.getenv("P_CURBACK") or "0x7B06")
local BLOCK_A = tonumber(os.getenv("P_BLK_A") or "0x10")
local BLOCK_B = tonumber(os.getenv("P_BLK_B") or "0x14")
local OUT     = os.getenv("P_OUT") or "build/walk_test.log"
local POS     = os.getenv("P_POS") or "build/walk_chars_pos.txt"
local SHOTFMT = os.getenv("P_SHOTFMT") or "build/walk_shot_%s.bin"
local SHOTS   = tonumber(os.getenv("P_SHOTS") or "16")
local GAP     = tonumber(os.getenv("P_GAP") or "10")
-- ★★ A SECOND CAPTURE WINDOW, OVER THE HOURGLASS (P3.88). The first window arms on the
-- first cel change and covers ~280 frames of the vizier's approach; the glass does not
-- exist until ~1,100 frames after it ends. So the suite could not have seen the hourglass
-- however good its expected picture was — which is why P3.87's broken glass change passed
-- both suites. Closing that needed BOTH halves: the compositor has to know the object
-- (verify_room_chars) and a capture has to LAND on it (here).
local SHOTSG  = tonumber(os.getenv("P_SHOTS_GLASS") or "8")
-- ★ A THIRD WINDOW, OVER THE EXIT (P3.90). P3.88 closed the hourglass hole and flagged
-- what it did NOT close: the 8 glass captures cover the beat's START (f4196..f4266) and
-- stop ~600 frames before the exit beats, which is exactly where P3.87's disputed residue
-- appeared. A capture window that covers an object's ARRIVAL but not its LIFE is the same
-- coverage failure one step smaller. Armed on SC_GLASS1, the flag the engine itself raises
-- when the body swaps state after Vexit [cel_plan beat 15].
local SHOTSX  = tonumber(os.getenv("P_SHOTS_EXIT") or "8")
local GAPX    = tonumber(os.getenv("P_GAP_EXIT") or "40")
local SC_GLASS1 = 0x04
local SCENERY = tonumber(os.getenv("P_SCENERY") or "0")
local SCFLOW  = tonumber(os.getenv("P_SCFLOW") or "0")
local VIZ     = tonumber(os.getenv("P_VIZ") or "0")
local PRI     = tonumber(os.getenv("P_PRI") or "0")
local DRAWN   = tonumber(os.getenv("P_DRAWN") or "0")
local LAST    = tonumber(os.getenv("P_LAST") or "0")
local LAST_STRIDE = tonumber(os.getenv("P_LAST_STRIDE") or "8")
-- THE CEL IMAGE'S OWN BOUNDS, handed in by the runner which reads them out of
-- build/assets/cel_image.raw. NOT written down here: they change whenever a beat is
-- added to bake_scene.PLAN (Palert took them from 11/46 to 2/55), and a guard carrying
-- its own copy of a generated value is the P3.65 shape -- it passes for the wrong reason
-- or, as this one did on its first run, fails for the wrong reason.
local WALK_LO = tonumber(os.getenv("P_WALK_LO") or "0")
local WALK_N  = tonumber(os.getenv("P_WALK_N") or "0")
-- ch_bankerr: the ENGINE's own bank guard (P3.77). char_draw checks the image's
-- signature once per frame and refuses to draw from a window that is not the cel bank.
-- This reads what the engine concluded, beside what the harness concludes externally.
local BANKERR = tonumber(os.getenv("P_BANKERR") or "0")
-- ★ THE SPLIT IMAGE'S SECOND HALF (P3.78). The pinned page at $C000 is checked above by
-- its bounds; the ROTATING page at $E000 is the half that moves, so it is the half a
-- check has to earn. cel_pg_sig is the signature the beat schedule says the mapped block
-- must answer with, and 0 means "this beat draws only pinned cels" -- so the harness
-- makes exactly the comparison the engine makes, from outside, against the same two
-- addresses. P_BEAT is the schedule cursor; distinct values of it are beats VISITED,
-- which is how the run proves the scene actually advanced rather than stalling somewhere.
local PGSIG   = tonumber(os.getenv("P_PGSIG") or "0")     -- cel_pg_sig, constant page
local BEAT    = tonumber(os.getenv("P_BEAT") or "0")      -- vm_beat, in the bundle
local PLAN_LO = tonumber(os.getenv("P_PLAN_LO") or "0")   -- cel_plan .. cel_plan_end,
local PLAN_HI = tonumber(os.getenv("P_PLAN_HI") or "0")   --   so garbage is not a "beat"
local RDERR   = tonumber(os.getenv("P_RDERR") or "0")     -- cel_rd_err, in the room
local LOADS   = tonumber(os.getenv("P_LOADS") or "0")     -- probe_loads, in the room
local NBEATS  = tonumber(os.getenv("P_NBEATS") or "0")    -- how many the PLAN has
local NREADS  = tonumber(os.getenv("P_NREADS") or "0")    -- staged reads the pack wants
local RUNTO   = tonumber(os.getenv("P_RUNTO") or "0")     -- frames to keep running for

local FB_BASE, FB_SIZE = 0x8000, 15360
local ROOM_MAGIC = 0x4B00
-- Slot record offsets [char_draw.s]. CH_X became 16-BIT at P3.78 (the vizier's exit
-- walked him past 255 and a byte wrapped him to the left edge), so every field after it
-- shifted by one and x must be read as a word.
local CH_X, CH_CEL = 0, 4

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end
local function rd8(a) return mem:read_u8(a) end

-- TWO REGISTERS, NOT FOUR (P3.71). This wrote $FFA4-$FFA7 and restored all four to the
-- back buffer's blocks -- a restore scheme that predates the $C000 cel bank and does not
-- know it exists. Every capture therefore silently UN-MAPPED the bank, and the engine's
-- next chars_frame read WALK_LO/WALK_N out of the framebuffer's unwritten reserved tail
-- ($FF), which is how a checker came to cause the failure it was measuring.
--
-- The read below covers $8000..$BBFF = 15,360 B, which lies entirely within $FFA4
-- ($8000-$9FFF) and $FFA5 ($A000-$BFFF). $FFA6/$FFA7 were never needed for it. Touching
-- only what the read requires is what makes this instrument passive.
local function map_blocks(first)
    for i = 0, 1 do mem:write_u8(0xFFA4 + i, first + i) end
end

local function dump_front(path)
    local back = rd8(CUR_BACK)
    local back_blk  = (back == 0) and BLOCK_A or BLOCK_B
    local front_blk = (back == 0) and BLOCK_B or BLOCK_A
    map_blocks(front_blk)
    local t = {}
    for i = 0, FB_SIZE - 1 do t[#t + 1] = string.char(rd8(FB_BASE + i)) end
    map_blocks(back_blk)
    local o = io.open(path, "wb")
    if not o then return false end
    o:write(table.concat(t)); o:close()
    return true
end

-- POSITION AND CEL COME FROM WHERE THE CAPTURED BUFFER DREW, not from the slot record.
-- The record holds what the VM has decided for the frame being built; the buffer being
-- captured was drawn earlier and still holds the previous state until it is redrawn.
-- Reading the record instead is the mistake this project has now made five ways
-- (P3.27 for the cel, P3.29 for the position) -- ch_drawn and ch_last are written at
-- DRAW time, indexed by (character, slot), so they are what reached these pixels.
-- ── which sand frame is IN each buffer (P3.90) ───────────────────────────────────────
-- Recorded at the BUFFER SWAP, not at the top of the iteration: sc_flow can still change
-- inside chars_frame (vm_beat_tick advances it, then scenery_frame draws with the new
-- value), so a sample taken before that reads the frame the LAST iteration used. At the
-- moment HAL_gfx_cur_back is rewritten, the buffer just finished is `1 - (new back)` and
-- sc_flow is exactly what was drawn into it.
local flow_shown = {}
if SCFLOW ~= 0 then
    _G._flowtap = mem:install_write_tap(CUR_BACK, CUR_BACK, "flow", function(o, d)
        flow_shown[1 - (d % 2)] = mem:read_u8(SCFLOW)
        return d
    end)
end

local pf = io.open(POS, "w")
local function log_positions(tag)
    if VIZ == 0 or not pf then return end
    local shown = 1 - (rd8(CUR_BACK) % 2)
    local function lastxy(ch)
        -- STRIDE FROM THE MAP, NOT A LITERAL (P3.58). This held its own `* 4` while
        -- ch_last's entry grew to 8 bytes to carry the parity, so it read the vizier's
        -- record for both characters and reported the princess standing where he was.
        -- Third home of one constant; the runner now derives it from the symbols.
        -- entry layout since P3.78: x(2), y, w, h, par, face, fdx, awid = 9 bytes
        local o = LAST + (ch * 2 + shown) * LAST_STRIDE
        -- +5 is the FACING, recorded at draw time beside x/y/w/h/parity (P3.71). Palert
        -- ends `aboutface`, so the princess is drawn from the MIRRORED bake thereafter
        -- and a checker without this reconstructs her from the wrong source.
        return rd8(o) * 256 + rd8(o + 1), rd8(o + 2), rd8(o + 6)
    end
    local vx, vy, vf = lastxy(0)
    local px, py, pf_ = lastxy(1)
    -- ELEVEN FIELDS SINCE P3.88, not nine: the scenery flags and the sand frame, so the
    -- checker can composite the hourglass rather than leaving a live object out of its
    -- expected picture. Read from the engine's own bytes at capture time, exactly as the
    -- positions and the facing are — the checker must never decide for itself which beat
    -- it is looking at. verify_room_chars accepts both widths, so room_test.lua (whose
    -- two captures land ~2,000 frames before the glass exists) stays at nine.
    pf:write(string.format("%s %d %d %d %d %d %d %d %d %d %d\n", tag,
                           vx, vy, rd8(DRAWN + 0 * 2 + shown),
                           px, py, rd8(DRAWN + 1 * 2 + shown), vf, pf_,
                           SCENERY ~= 0 and rd8(SCENERY) or 0,
    -- ★ THE SAND FRAME OF THE BUFFER BEING SHOWN, NOT THE ENGINE'S CURRENT ONE.
    --
    -- sc_flow is the frame the NEXT draw will use; the buffer on screen was drawn an
    -- iteration ago and may hold the previous one. Reading the live byte made the checker
    -- composite sand the displayed buffer does not contain, and it reported that as five
    -- wrong bytes in the port — all of them inside the sand rectangle, all of them a
    -- neighbouring flow frame's pixels. A checker racing the engine, reported as a
    -- rendering defect: the same shape as capture 29's flip lag, one object along.
    --
    -- flow_shown is recorded per buffer at the top of each drawing iteration, off the
    -- engine's own flm_idx tick, so what is composited is what was drawn.
                           flow_shown[shown] or
                             (SCFLOW ~= 0 and rd8(SCFLOW) or 0)))
    pf:flush()
end

local state, t0, started, loaded = "boot", nil, nil, nil
local shot_n, next_shot, first_fn = 0, nil, nil
local shots_max, glass_fn = SHOTS, nil   -- the budget grows when the hourglass arrives
local exit_fn, cur_gap = nil, nil        -- ...and again when it swaps state after Vexit
local occ, prev_cel, last_change, gaps, steps = {}, nil, nil, {}, 0
local xs = {}
local bank_bad = 0        -- captures at which the $C000 cel bank was NOT mapped
local room_fn, first_cel = nil, nil   -- the room's arrival, and the cels it arrived with
-- the split image's rotating half, sampled every frame for the WHOLE scene
local page_bad, page_run, page_worst, page_seen = 0, 0, nil, 0
local beats_seen, n_beats_seen = {}, 0
local loads_at_room = nil

local function finish(reason)
    -- THE BANK GUARD FIRST, because everything below it is meaningless if the window
    -- was not showing the cels. This is the assertion P3.69 needed and did not have.
    log(string.format("# bank_mapped_at_every_capture %s (%d of %d captures unmapped)",
                      bank_bad == 0 and "PASS" or "FAIL", bank_bad, shot_n))
    if BANKERR ~= 0 then
        local e = rd8(BANKERR)
        log(string.format("# engine_bank_guard %s (ch_bankerr = %d)",
                          e == 0 and "PASS" or "FIRED — the engine refused to draw", e))
    end
    -- ★ THE ROTATING PAGE, THE STAGED READS, AND WHETHER THE SCENE ACTUALLY RAN (P3.78).
    if PGSIG ~= 0 then
        -- ★★ AND IT MUST HAVE LOOKED AT SOMETHING. On the run that first exposed the
        -- room crash this printed "PASS (0 sustained mismatches)" having compared
        -- NOTHING AT ALL — the scene never started, so cel_pg_sig was 0 on every frame
        -- and the check sailed through an empty observation. That is the third time in
        -- this arc a suite has been green over nothing (P3.72l, P3.77, here), and it is
        -- the same shape every time: the check tests a condition, and "no samples" is
        -- not a violation of any condition. So the sample count is part of the
        -- assertion, not a statistic printed beside it.
        log(string.format("# page_sig_matched_every_frame %s (%d checked, %d sustained "
                          .. "mismatches%s)",
                          (page_bad == 0 and page_seen > 0) and "PASS" or "FAIL",
                          page_seen, page_bad,
                          page_worst and (", worst " .. page_worst) or ""))
    end
    if BEAT ~= 0 then
        -- A SCENE THAT STALLS IS THE FAILURE THIS CATCHES, and it is the one the pixel
        -- captures structurally cannot: they all land in the first few hundred frames.
        -- If a beat's page never arrives the guard refuses to draw, the VM goes on
        -- stepping, and the scene runs to the end looking like a held pose.
        log(string.format("# beats_visited %s (%d of %d)",
                          n_beats_seen >= NBEATS and "PASS" or "FAIL",
                          n_beats_seen, NBEATS))
    end
    if RDERR ~= 0 and loads_at_room then
        -- TWO load_tracks CALLS PER PAGE, not one. The page is two whole tracks and the
        -- second is read SKEWED so it ends at the top of the window (char_draw
        -- cel_read_page), so probe_loads advances by two per staged read. Counting calls
        -- and comparing against pages reported "4 of 2 completed" for a run in which
        -- both reads were perfect — a check wrong in the direction that cries wolf,
        -- which spends attention just as surely as one that stays quiet.
        local calls = rd8(LOADS) - loads_at_room
        local e = rd8(RDERR)
        log(string.format("# staged_reads %s (%d of %d pages, %d disk calls, "
                          .. "cel_rd_err = %d)",
                          (calls == NREADS * 2 and e == 0) and "PASS" or "FAIL",
                          calls // 2, NREADS, calls, e))
    end
    log("# --- PHASE OCCUPANCY, measured on the running machine ---")
    local cels = {}
    for c in pairs(occ) do cels[#cels + 1] = c end
    table.sort(cels)
    for _, c in ipairs(cels) do
        local ph = {}
        for p = 0, 3 do if occ[c][p] then ph[#ph + 1] = p end end
        log(string.format("#   cel %d -> phases {%s}", c, table.concat(ph, ",")))
    end
    log("# --- CADENCE: gaps between cel changes (video frames) ---")
    local keys, tot, cnt = {}, 0, 0
    for k in pairs(gaps) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        log(string.format("#   %2d frames : %d times", k, gaps[k]))
        tot = tot + k * gaps[k]; cnt = cnt + gaps[k]
    end
    if cnt > 0 then
        -- THE MODE, BESIDE THE MEAN (P3.72d). "A gap IS a step" stops being true at a
        -- beat boundary: while Palert runs, the vizier HOLDS cel 54, and that shows up
        -- as one 52-frame gap which drags the mean from 6.00 to 7.39 and reads as an
        -- overrun that is not happening. The modal gap is the actual step rate.
        local mode, moden = nil, 0
        for _, k in ipairs(keys) do
            if gaps[k] > moden then mode, moden = k, gaps[k] end
        end
        log(string.format("# modal gap %d frames x%d = THE STEP RATE; holds between "
                          .. "beats inflate the mean", mode, moden))
        log(string.format("# mean %.2f frames per step over %d steps "
                          .. "(the walk changes cel EVERY step, so a gap IS a step)",
                          tot / cnt, cnt))
        log(string.format("# oracle floor 6.00 (measured, P3.72d); overrun %+.2f frames",
                          tot / cnt - 6.00))
    end
    log(string.format("# x ran %s", table.concat(xs, " ")))
    log("# VERDICT: " .. reason)
    if f then f:close() end
    if pf then pf:close() end
    manager.machine:exit()
end

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if loaded == nil and rd8(0x2000) == 0x7E then
            loaded = fn
            log("# LOADM first byte landed at frame " .. fn)
        end
        if fn > t0 + 900 then
            nk:post('EXEC\n')
            log("# posted EXEC at frame " .. fn)
            state, started = "running", fn
        end
        return
    end
    local magic = rd8(ENGINE + 6) * 256 + rd8(ENGINE + 7)

    -- ★★ BEATS ARE COUNTED FROM THE MOMENT THE SCHEDULE STARTS, NOT FROM FIRST MOVEMENT.
    --
    -- This sampler used to sit below the `state == "running"` early return, so it only ran
    -- once the scene MOVED — and the first two beats are `Pstand` and the 761-frame
    -- s_Princess hold, during which nothing moves by design. It therefore reported
    -- "beats_visited 16 of 18" for a scene that reaches all eighteen, and it did so for
    -- five dispatches while being read as evidence the scene did not finish.
    --
    -- Measured on the machine before changing it: the schedule reaches beat 17, the
    -- terminal beat, at f5011 — vm_beat walks rows 0..17 in order with no gaps. The scene
    -- was never the problem; the window was.
    if BEAT ~= 0 then
        local b = rd8(BEAT) * 256 + rd8(BEAT + 1)
        local in_table = (PLAN_LO == 0) or (b >= PLAN_LO and b < PLAN_HI)
        if b ~= 0 and in_table and not beats_seen[b] then
            beats_seen[b] = true
            n_beats_seen = n_beats_seen + 1
        end
    end

    if state == "running" then
        -- CAPTURE FROM THE FIRST MOVEMENT, NOT FROM THE ROOM (P3.72l).
        --
        -- This used to arm on the room coming up, which was the same instant the scene
        -- started moving -- until the s_Princess song stub restored the oracle's 761-frame
        -- opening hold. With that in, 28 captures at a 10-frame gap cover 280 frames and
        -- ALL OF THEM LAND INSIDE THE SONG: every capture identical, both characters
        -- standing, and the suite passes byte-exact while observing nothing at all.
        --
        -- That is the sharpest form of "a green check is not evidence" this project has
        -- hit: not a check that misses a rare failure, but one that can no longer fail on
        -- anything it was written to test. Arming on the first CEL CHANGE puts the window
        -- back over the action, wherever the scene's opening holds move it to.
        if magic == ROOM_MAGIC and rd8(ENGINE + 8) > 0 then
            if room_fn == nil then
                room_fn = fn
                first_cel = rd8(VIZ + CH_CEL) * 256 + rd8(PRI + CH_CEL)
                -- the startup reads are done by now; anything after this is a STAGED one
                loads_at_room = (LOADS ~= 0) and rd8(LOADS) or nil
                log(string.format("# room up at frame %d, loads=%d status $%02X",
                                  fn, rd8(ENGINE + 4), rd8(ENGINE + 5)))
            end
            if rd8(VIZ + CH_CEL) * 256 + rd8(PRI + CH_CEL) ~= first_cel then
                log(string.format("# first movement at frame %d (+%d held frames)",
                                  fn, fn - room_fn))
                first_fn, next_shot, state = fn, fn, "walking"
            end
        elseif fn > started + 1800 then
            log(string.format("# NEVER REACHED THE ROOM: magic $%04X status %d loads %d "
                              .. "dskerr $%02X", magic, rd8(ENGINE + 3),
                              rd8(ENGINE + 4), rd8(ENGINE + 5)))
            finish("FAIL — the room never came up")
        end
        return
    end

    -- ── THE ROTATING PAGE, EVERY FRAME, FOR THE WHOLE SCENE (P3.78) ────────────────
    --
    -- ★ A MISMATCH ONLY COUNTS IF IT PERSISTS, and that is not leniency — it is the one
    -- thing that makes this instrument sound. room_present is `jsr HAL_gfx_swap` then
    -- `jsr cel_bank_map`, and HAL_gfx_swap ends by writing ALL FOUR window registers to
    -- bring the new back buffer in (P3.68). So between those two calls $FFA6/$FFA7 hold
    -- framebuffer blocks, legitimately, for a few hundred cycles per frame -- and
    -- HAL_gfx_swap waits for VBL, which is exactly when a frame notifier fires. A
    -- single-sample check would report the engine's own correct swap as a fault: an
    -- instrument reading a transient it is synchronised to (P3.71's shape, one register
    -- along). Requiring the mismatch to survive consecutive frames tests for a mapping
    -- that is actually WRONG rather than one that is mid-update.
    --
    -- The engine's own guard has no such problem -- it runs inside chars_frame with the
    -- mapping settled -- which is why ch_bankerr stays the primary and this is
    -- corroboration from outside.
    if PGSIG ~= 0 then
        local want = rd8(PGSIG) * 256 + rd8(PGSIG + 1)
        if want ~= 0 then
            page_seen = page_seen + 1
            local got = rd8(0xE000) * 256 + rd8(0xE001)
            if got ~= want then
                page_run = page_run + 1
                if page_run == 3 then
                    page_bad = page_bad + 1
                    page_worst = string.format("frame %d: $%04X, wanted $%04X",
                                               fn, got, want)
                    log(string.format("#   PAGE WRONG at frame %d: $%04X, wanted $%04X",
                                      fn, got, want))
                end
            else
                page_run = 0
            end
        else
            page_run = 0
        end
    end

    -- SAMPLE EVERY FRAME. The VM steps every ~3 frames, so per-frame sampling sees every
    -- (cel, x) pair the walk visits; a sample per capture would see one in ten.
    local cel = rd8(VIZ + CH_CEL)
    local x = rd8(VIZ + CH_X) * 256 + rd8(VIZ + CH_X + 1)
    if cel >= 48 and cel <= 53 then
        occ[cel] = occ[cel] or {}
        occ[cel][(x + 20) % 4] = true
    end
    if prev_cel == nil then
        prev_cel, last_change = cel, fn
    elseif cel ~= prev_cel then
        local g = fn - last_change
        gaps[g] = (gaps[g] or 0) + 1
        steps = steps + 1
        if #xs < 60 then xs[#xs + 1] = string.format("%d:%d", cel, x) end
        prev_cel, last_change = cel, fn
    end

    -- ARM THE SECOND WINDOW the first frame the scenery flags go non-zero, which is the
    -- first frame the glass is on screen. Keyed off the engine's own vm_scenery rather
    -- than a frame number, because a frame number would go stale the moment the pace or
    -- any hold above it changed — and this arc has already moved every beat boundary once.
    if SCENERY ~= 0 and glass_fn == nil and rd8(SCENERY) ~= 0 then
        glass_fn = fn
        shots_max = shots_max + SHOTSG
        -- ★ START ONE GAP LATER, NOT ON THE ARMING FRAME. vm_scenery goes non-zero at the
        -- top of the beat and scenery_frame draws the body into the BACK buffer; the
        -- capture reads the FRONT. So on this exact frame the flag says "glass" and the
        -- displayed buffer is still the previous one, without it — measured, as 101 bytes
        -- of the body's own top rows reading $00 where the checker wanted $3F/$FF, with
        -- every later capture byte-exact. That is the flip lag this file already warns
        -- about ("the buffer captured was drawn earlier and still holds the previous
        -- state"), and reporting it as a defect would be the checker racing the engine.
        next_shot = fn + GAP
        cur_gap = GAP
        log(string.format("# hourglass up at frame %d (+%d) — %d more captures from +%d",
                          fn, fn - first_fn, SHOTSG, GAP))
    end

    -- THE EXIT WINDOW. A WIDER GAP ON PURPOSE: the point is to span the beats the glass
    -- lives through, not to sample one of them densely, and at 10 frames the eight shots
    -- would cover 80 frames of a ~600-frame stretch.
    if SCENERY ~= 0 and exit_fn == nil and glass_fn ~= nil
       and (rd8(SCENERY) & SC_GLASS1) ~= 0 then
        exit_fn = fn
        shots_max = shots_max + SHOTSX
        next_shot = fn + GAPX
        cur_gap = GAPX
        log(string.format("# glass state 1 at frame %d (+%d) — %d more captures every %d",
                          fn, fn - first_fn, SHOTSX, GAPX))
    end

    if fn >= next_shot and shot_n < shots_max then
        shot_n = shot_n + 1
        local tag = string.format("%02d", shot_n)
        -- THE BANK, SAMPLED AT THE CAPTURE FRAME AND AGAIN AFTER THE CAPTURE (P3.71).
        --
        -- P3.69 checked the mapping on a schedule unrelated to the captures and read it
        -- as sound; P3.70 showed that could not be evidence, because the capture path is
        -- itself an MMU writer and a probe that never lands on the perturbed window
        -- cannot see it. So the sample is taken HERE, at the one moment that was blind,
        -- and again on the far side of dump_front -- which is where the old four-register
        -- restore did its damage. $C000/$C001 are the image's own WALK_LO/WALK_N; $FF
        -- means the window is showing the framebuffer's unwritten reserved tail instead.
        local pre_lo, pre_n = rd8(0xC002), rd8(0xC003)
        log_positions(tag)
        local ok = dump_front(string.format(SHOTFMT, tag))
        local post_lo, post_n = rd8(0xC002), rd8(0xC003)
        if pre_lo ~= WALK_LO or pre_n ~= WALK_N
           or post_lo ~= WALK_LO or post_n ~= WALK_N then
            bank_bad = bank_bad + 1
            log(string.format("#   BANK UNMAPPED at capture %s: before %d/%d after %d/%d"
                              .. " (want %d/%d)", tag, pre_lo, pre_n, post_lo, post_n,
                              WALK_LO, WALK_N))
        end
        log(string.format("# capture %s at frame %d (+%d): %s",
                          tag, fn, fn - first_fn, ok and "ok" or "WRITE FAILED"))
        next_shot = fn + (cur_gap or GAP)
    elseif shot_n >= shots_max and (RUNTO == 0 or fn - first_fn >= RUNTO) then
        -- ★ THE CAPTURES END LONG BEFORE THE SCENE DOES (P3.78), and stopping with them
        -- would have made every check above blind to fourteen of the eighteen beats. The
        -- 28 pixel captures cover ~280 frames; the scene is ~2,500 and both staged reads
        -- land past frame 1,000. So the run continues, sampling the page and the beat
        -- cursor, and only the framebuffer capturing stops. RUNTO is derived by the
        -- runner from the PLAN's own play counts rather than guessed.
        finish(string.format("%d captures over %d frames, scene ran %d frames past them",
                             shot_n, GAP * shot_n, fn - first_fn - GAP * shot_n))
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
