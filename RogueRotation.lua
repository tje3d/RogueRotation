--------------------------------------------------------------------
-- Class gate: Rogues only (file-level, zero cost for other classes)
--------------------------------------------------------------------
if select(2, UnitClass("player")) ~= "ROGUE" then
    return
end

-- Configuration
local MAX_ICONS = 3           -- current action + next two
local ICON_SIZE = 40          -- upcoming actions
local NEXT_ICON_SIZE = 54     -- current action, drawn larger
local SPACING = 5
local GLOW_NEXT = true
local SCALE = 1.0

-- Adrenaline Rush rides with Killing Spree: AR is not suggested while KS is
-- ready (even if the trinket gate is still holding it back) or comes off
-- cooldown within the next ~4 GCDs, so AR never gets spent just ahead of a
-- KS that is about to happen.
local KS_PAIR_WINDOW = 6.0

local function IconSize(index)
    if index == 1 then return NEXT_ICON_SIZE end
    return ICON_SIZE
end

-- Spell IDs (WotLK 3.3.5a)
local RAW_SPELLS = {
    SS   = 1752,   -- Sinister Strike
    SND  = 5171,   -- Slice and Dice
    RUPT = 1943,   -- Rupture
    EVIS = 2098,   -- Eviscerate
    KS   = 51690,  -- Killing Spree
    AR   = 13750,  -- Adrenaline Rush
    BF   = 13877,  -- Blade Flurry
    SHIV = 5938,   -- Shiv
    TOT  = 57934,  -- Tricks of the Trade
}

local BUFFS = {
    SND_ID   = 5171,
    RUPT_ID  = 1943,
}

--------------------------------------------------------------------
-- Frame Setup (RetRotation-style)
--------------------------------------------------------------------
-- The current action is drawn larger than the two upcoming ones, all
-- sharing the same vertical center line.
local frameWidth, frameHeight = SPACING * (MAX_ICONS - 1), ICON_SIZE
for i = 1, MAX_ICONS do
    local s = IconSize(i)
    frameWidth = frameWidth + s
    if s > frameHeight then frameHeight = s end
end

local mainFrame = CreateFrame("Frame", "RogueRotationFrame", UIParent)
mainFrame:SetSize(frameWidth, frameHeight)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
mainFrame:SetScale(SCALE)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetClampedToScreen(true)

mainFrame:Hide()

-- Icon Pool (Action Button Template, exactly like RetRotation)
local icons = {}
local iconX = 0
for i = 1, MAX_ICONS do
    local size = IconSize(i)
    local name = "RogueRotationBtn" .. i
    local btn = CreateFrame("CheckButton", name, mainFrame, "ActionButtonTemplate")
    btn:SetSize(size, size)
    btn:SetPoint("LEFT", mainFrame, "LEFT", iconX, 0)
    iconX = iconX + size + SPACING
    btn:EnableMouse(false)

    btn.icon = _G[name .. "Icon"]
    btn.cooldown = _G[name .. "Cooldown"]

    local normal = _G[name .. "NormalTexture"]
    if normal then
        normal:SetWidth(size * 1.6)
        normal:SetHeight(size * 1.6)
    end

    icons[i] = btn
end

--------------------------------------------------------------------
-- Cooldown frame (separate, 4 slots: Blade Flurry, Adrenaline Rush,
-- Killing Spree, Tricks of the Trade)
--------------------------------------------------------------------
local CD_SPELL_IDS = { RAW_SPELLS.BF, RAW_SPELLS.AR, RAW_SPELLS.KS, RAW_SPELLS.TOT }

local cdFrame = CreateFrame("Frame", nil, mainFrame)
cdFrame:SetSize((36 * #CD_SPELL_IDS) + (SPACING * (#CD_SPELL_IDS - 1)), 36)
cdFrame:SetPoint("BOTTOM", mainFrame, "TOP", 0, SPACING)
cdFrame:Show()

local cdButtons = {}
for i = 1, #CD_SPELL_IDS do
    local btnName = "RogueRotationCD" .. i
    local btn = CreateFrame("CheckButton", btnName, cdFrame, "ActionButtonTemplate")
    btn:SetSize(36, 36)
    btn:SetPoint("LEFT", (i - 1) * (36 + SPACING), 0)
    btn:EnableMouse(false)
    btn.icon = _G[btnName .. "Icon"]
    btn.cooldown = _G[btnName .. "Cooldown"]
    local normal = _G[btnName .. "NormalTexture"]
    if normal then
        normal:SetWidth(36 * 1.6)
        normal:SetHeight(36 * 1.6)
    end
    btn.lastStart = 0
    btn.lastDuration = 0
    btn:Show()
    cdButtons[i] = btn
end

-- Tricks of the Trade: bouncing animation while off cooldown and in combat.
local TOT_CD_INDEX = nil
for i, id in ipairs(CD_SPELL_IDS) do
    if id == RAW_SPELLS.TOT then TOT_CD_INDEX = i break end
end

local function MakeTotBounce(frame)
    local g = frame:CreateAnimationGroup()
    local move = g:CreateAnimation("Translation")
    move:SetOffset(0, 9)
    move:SetDuration(0.22)
    g:SetLooping("BOUNCE")
    return g
end

if TOT_CD_INDEX and cdButtons[TOT_CD_INDEX] then
    local totBtn = cdButtons[TOT_CD_INDEX]
    totBtn.bounce = MakeTotBounce(totBtn)
    -- Animate the cooldown swipe together with the button, since swipe visuals
    -- do not always follow the parent transform on their own.
    if totBtn.cooldown then
        totBtn.cooldownBounce = MakeTotBounce(totBtn.cooldown)
    end
end

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------
local SPELL_MAP = {}

-- Spell names and textures never change while the client is running, so they
-- are resolved through GetSpellInfo() once and then served from this cache.
-- This removes a dozen GetSpellInfo calls from every update tick.
local SPELL_INFO = {}
local function GetSpell(id)
    local info = SPELL_INFO[id]
    if info == nil then
        local name, _, texture = GetSpellInfo(id)
        if not name then return nil end
        info = { name = name, texture = texture, id = id }
        SPELL_INFO[id] = info
    end
    return info
end

local function InitSpells()
    for key, id in pairs(RAW_SPELLS) do
        local info = GetSpell(id)
        if info then
            SPELL_MAP[key] = info
        end
    end
end

local function IsRogue()
    local _, class = UnitClass("player")
    return class == "ROGUE"
end

local function UpdateFrameVisibility()
    if IsRogue() then
        mainFrame:Show()
    else
        mainFrame:Hide()
    end
end

local function ComboPoints()
    local cp = 0
    -- Prefer the (unit, target) form used by oUF/DragonUI in WotLK;
    -- fall back to the single-arg form used by some clients/addons.
    local ok, val = pcall(GetComboPoints, "player", "target")
    if ok and type(val) == "number" then cp = val end
    if (not cp or cp == 0) then
        local ok2, val2 = pcall(GetComboPoints, "player")
        if ok2 and type(val2) == "number" then cp = val2 end
    end
    return cp or 0
end

--------------------------------------------------------------------
-- Player aura cache
--------------------------------------------------------------------
-- S&D, BF and AR used to be looked up by scanning up to 40 UnitAura slots on
-- every query (about 5 full scans per 0.1s tick). The cache is rebuilt when
-- UNIT_AURA reports that the player's buffs changed (plus a slow safety
-- refresh), and each lookup is then a table hit plus time arithmetic.
-- Remaining times are derived from the cached expiration, so values stay
-- correct as time passes between rebuilds.
local auraExp, auraDur = {}, {}
local auraNames, auraCount = {}, 0
local aurasReady = false

local function RebuildPlayerAuras()
    for i = 1, auraCount do
        local name = auraNames[i]
        auraExp[name] = nil
        auraDur[name] = nil
        auraNames[i] = nil
    end
    auraCount = 0

    for i = 1, 40 do
        local name, _, _, _, _, dur, exp = UnitAura("player", i)
        if not name then break end
        -- Keep the first occurrence, same as the old per-lookup scan.
        if auraExp[name] == nil then
            auraCount = auraCount + 1
            auraNames[auraCount] = name
            auraExp[name] = exp or 0
            auraDur[name] = dur or 0
        end
    end
    aurasReady = true
end

-- Remaining time of a player buff, by spell name (0 when it is not up).
local function BuffRemain(name)
    if not name then return 0 end
    local exp = auraExp[name]
    if exp == nil then return 0 end
    if exp > 0 then
        local rem = exp - GetTime()
        if rem < 0 then rem = 0 end
        return rem
    end
    return 999
end

-- Tracker info for the buff icons: remaining, total duration, expiration.
local function PlayerBuffInfo(name)
    if not name then return 0, 0, 0 end
    local exp = auraExp[name]
    if exp == nil then return 0, 0, 0 end
    local dur = auraDur[name] or 0
    local rem = 0
    if exp > 0 then
        rem = exp - GetTime()
        if rem < 0 then rem = 0 end
    end
    local total = dur
    if total <= 0 and exp > 0 then
        total = exp - GetTime() + dur
    end
    return rem, total, exp
end

local function DebuffRemain(spellID)
    local name = GetSpellInfo(spellID)
    if not name then return 0 end
    if not UnitExists("target") then return 999 end
    for i = 1, 40 do
        local debuffName, _, _, _, _, _, exp = UnitAura("target", i, "HARMFUL")
        if not debuffName then break end
        if debuffName == name then
            if exp and exp > 0 then
                local rem = exp - GetTime()
                if rem < 0 then rem = 0 end
                return rem
            end
            return 999
        end
    end
    return 0
end

--------------------------------------------------------------------
-- Per-tick cooldown cache
--------------------------------------------------------------------
-- The rotation queue, the action icons and the cooldown row all query
-- GetSpellCooldown() for the same handful of spells. Each entry is read from
-- the API at most once per update tick and reused for the rest of that tick.
local cdTick = 0
local cdCache = {}
local function SpellCooldown(name)
    if not name then return 0, 0 end
    local v = cdCache[name]
    if not v then
        v = { 0, 0, 0 }
        cdCache[name] = v
    end
    if v[3] ~= cdTick then
        v[1], v[2] = GetSpellCooldown(name)
        v[1] = v[1] or 0
        v[2] = v[2] or 0
        v[3] = cdTick
    end
    return v[1], v[2]
end

-- Remaining cooldown of a spell in seconds, ignoring the global cooldown.
-- GetSpellCooldown() reports the GCD (duration <= 1.5s) for spells that are
-- otherwise ready; counting that swipe as a real cooldown made Killing Spree
-- and Adrenaline Rush look unavailable during every GCD, so they were only
-- suggested once the GCD had already expired.
local function SpellCooldownRemaining(name)
    if not name then return 0 end
    local start, duration = SpellCooldown(name)
    if start == 0 then return 0 end
    if duration <= 1.5 then return 0 end
    local rem = start + duration - GetTime()
    if rem < 0 then rem = 0 end
    return rem
end

local function CooldownReady(name)
    if not name then return false end
    -- Ready now, or within one GCD: the suggestion should switch while the
    -- current GCD is still running, not only after it expires.
    return SpellCooldownRemaining(name) <= 1.5
end

-- Evaluate the Killing Spree trinket gate for this tick. State is read live
-- from TrinketCDs: item.applied is true while the proc/use effect is up,
-- item.cd_end is when the cooldown (or proc ICD) ends. Tracked trinkets end
-- up in one of three buckets:
--   active    -> effect is up
--   available -> off cooldown and no effect up yet (use/proc it)
--   spent     -> on cooldown (already used or proc on ICD)
-- KS should go when a trinket effect is up and no off-cooldown trinket is
-- left unused:
--   one on CD + other active      -> KS
--   both off CD, not both active  -> wait for the second
--   both on CD, neither active    -> wait
-- This only depends on trinket/cooldown state, which cannot change inside a
-- single tick, so it runs once per tick instead of once per queue step.
local TRINKET_SLOTS = { 13, 14 }
local function AllowKillingSpree()
    local tracked, activeTr, availableTr = 0, 0, 0
    for i = 1, #TRINKET_SLOTS do
        local slot = TRINKET_SLOTS[i]
        local f = _G.TrinketCDs and _G.TrinketCDs.FRAMES and _G.TrinketCDs.FRAMES[slot]
        local item = f and f.item
        if item and item.proc_in_DB then
            tracked = tracked + 1
            local cdEnd = item.cd_end
            local onCD = cdEnd and cdEnd > GetTime()
            if not onCD then
                local s, d = GetInventoryItemCooldown("player", slot)
                onCD = s and d and d > 0 and (s + d - GetTime()) > 0.5
            end
            if item.applied == true then
                activeTr = activeTr + 1
            elseif not onCD then
                availableTr = availableTr + 1
            end
        end
    end
    if tracked > 0 then
        return (activeTr >= 1) and (availableTr == 0)
    end
    -- No proc data available (no TrinketCDs, or passive/stat trinkets):
    -- hold KS only while every equipped trinket is on cooldown.
    local equipped, onCDCount = 0, 0
    for i = 1, #TRINKET_SLOTS do
        local slot = TRINKET_SLOTS[i]
        if GetInventoryItemLink("player", slot) then
            equipped = equipped + 1
            local s, d = GetInventoryItemCooldown("player", slot)
            if s and d and d > 0 and (s + d - GetTime()) > 0.5 then
                onCDCount = onCDCount + 1
            end
        end
    end
    return (equipped == 0) or (onCDCount < equipped)
end

-- Rotation queue. Reuses one queue table and one predicted-state table
-- instead of allocating fresh ones on every tick.
local actionQueue = {}
local actionState = {}
local function GetActionQueue(hasTarget)
    local queue = actionQueue
    local n = 0

    if hasTarget then
        local sp = RAW_SPELLS
        local M = SPELL_MAP
        local sndInfo = M.SND or GetSpell(sp.SND)
        local bfInfo = M.BF or GetSpell(sp.BF)
        local ksInfo = M.KS or GetSpell(sp.KS)
        local arInfo = M.AR or GetSpell(sp.AR)

        local state = actionState
        state.cp = ComboPoints()
        state.snd = BuffRemain(sndInfo and sndInfo.name)
        state.bf = BuffRemain(bfInfo and bfInfo.name) > 0
        state.ksCD = SpellCooldownRemaining(ksInfo and ksInfo.name)
        state.arCD = SpellCooldownRemaining(arInfo and arInfo.name)

        local allowKS -- trinket gate, evaluated on first use (once per tick)

        for step = 1, MAX_ICONS do
            local action = nil
            -- Keep Slice and Dice up
            if state.snd <= 2 and state.cp >= 1 and M.SND and CooldownReady(M.SND.name) then
                action = M.SND
            -- Cooldowns when stable (KS not gated by combo points)
            elseif state.snd > 2 then
                if not state.bf and M.BF and CooldownReady(M.BF.name) then
                    action = M.BF
                else
                    -- Hold Adrenaline Rush back while Killing Spree is ready or
                    -- about to come off cooldown: using AR there would waste it,
                    -- AR belongs with the KS burst. Once KS is queued, AR shows
                    -- up right after it.
                    local ksSoon = M.KS and state.ksCD <= KS_PAIR_WINDOW
                    if allowKS == nil then allowKS = AllowKillingSpree() end
                    if allowKS and state.ksCD <= 0 and M.KS and CooldownReady(M.KS.name) then
                        action = M.KS
                    elseif state.cp <= 2 and state.arCD <= 0 and not ksSoon and M.AR and CooldownReady(M.AR.name) then
                        action = M.AR
                    end
                end
            end
            -- Finisher
            if not action and state.cp >= 4 and M.EVIS and CooldownReady(M.EVIS.name) then
                action = M.EVIS
            end
            -- Builder
            if not action and M.SS and CooldownReady(M.SS.name) then
                action = M.SS
            end
            if not action then break end
            n = n + 1
            queue[n] = action

            -- Apply to predicted state
            if action == M.SND then
                state.snd = 6 + (state.cp * 3)
                state.cp = 0
            elseif action == M.EVIS then
                state.cp = 0
            elseif action == M.KS then
                state.ksCD = 120
            elseif action == M.AR then
                state.arCD = 180
            elseif action == M.BF then
                state.bf = true
            elseif action == M.SS then
                state.cp = math.min(5, state.cp + 1)
            end
            state.snd = math.max(0, state.snd - 1.5)
            state.ksCD = math.max(0, state.ksCD - 1.5)
            state.arCD = math.max(0, state.arCD - 1.5)
        end
    end

    -- Clear entries left over from a longer previous queue.
    for i = n + 1, #queue do queue[i] = nil end
    return queue
end

--------------------------------------------------------------------
-- Main Update Loop
--------------------------------------------------------------------
-- BEGIN BUFF ICONS
local BUFF_TRACKERS = {
    { id = RAW_SPELLS.SND, label = "SND" },
    { id = RAW_SPELLS.BF,  label = "BF" },
    { id = RAW_SPELLS.AR,  label = "AR" },
}

local BUFF_ICON_SIZE = 30
local buffFrame = CreateFrame("Frame", nil, mainFrame)
buffFrame:SetSize((BUFF_ICON_SIZE * #BUFF_TRACKERS) + (SPACING * (#BUFF_TRACKERS - 1)), BUFF_ICON_SIZE)
buffFrame:SetPoint("TOP", mainFrame, "BOTTOM", 0, -SPACING)
buffFrame:Show()

local buffIcons = {}
for i = 1, #BUFF_TRACKERS do
    local info = BUFF_TRACKERS[i]
    local f = CreateFrame("Frame", nil, buffFrame)
    f:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    local spell = GetSpell(info.id)
    if spell then
        info.name = spell.name
        tex:SetTexture(spell.texture)
    end
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints(f)
    cd:SetDrawEdge(false)

    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetJustifyH("CENTER")
    fs:SetTextColor(1, 1, 1)

    f.icon = tex
    f.cooldown = cd
    f.text = fs

    -- Start hidden; the update loop shows them while the buff is up.
    f:Hide()
    cd:Hide()
    fs:Hide()

    buffIcons[i] = f
end
-- END BUFF ICONS
--------------------------------------------------------------------
-- Update helpers
--------------------------------------------------------------------
-- The queue is recomputed 10x/second while there is a target to act on and
-- falls back to 2x/second with no target, where there is nothing to suggest.
local ACTIVE_INTERVAL = 0.1
local IDLE_INTERVAL = 0.5

-- Action icons. The frames are only touched when something the display shows
-- actually changed: same spells, same cooldown state, same warnings. During a
-- steady rotation the tick only runs the comparison below.
local shownSlots = {}
local shownCount = -1

local function UpdateActionIcons(spellData)
    local count = #spellData

    local dirty = count ~= shownCount
    if not dirty then
        for i = 1, count do
            local data = spellData[i]
            local s = shownSlots[i]
            local glow = ((i == 1) and GLOW_NEXT and (data.cdLeft <= 0.5)) or false
            if s.ref ~= data or s.start ~= data.start or s.duration ~= data.duration
                or s.oom ~= data.isOOM or s.glow ~= glow then
                dirty = true
                break
            end
        end
    end
    if not dirty then return end

    for i = 1, MAX_ICONS do
        local icon = icons[i]
        local data = spellData[i]
        local s = shownSlots[i]
        if not s then
            s = {}
            shownSlots[i] = s
        end

        if data then
            if not icon:IsShown() then icon:Show() end

            if s.tex ~= data.texture then
                icon.icon:SetTexture(data.texture)
                s.tex = data.texture
            end

            if s.start ~= data.start or s.duration ~= data.duration then
                icon.cooldown:SetCooldown(data.start, data.duration)
                s.start = data.start
                s.duration = data.duration
            end

            if s.oom ~= data.isOOM then
                if data.isOOM then
                    icon.icon:SetVertexColor(0.5, 0.5, 1.0)
                else
                    icon.icon:SetVertexColor(1, 1, 1)
                end
                s.oom = data.isOOM
            end

            local glow = ((i == 1) and GLOW_NEXT and (data.cdLeft <= 0.5)) or false
            if s.glow ~= glow then
                icon:SetChecked(glow)
                s.glow = glow
            end

            local alpha = (i == 1) and 1 or 0.6
            if s.alpha ~= alpha then
                icon:SetAlpha(alpha)
                s.alpha = alpha
            end

            s.ref = data
        else
            if icon:IsShown() then icon:Hide() end
            s.ref, s.tex, s.start, s.duration, s.oom, s.glow = nil, nil, nil, nil, nil, nil
        end
    end

    shownCount = count
end

-- Cooldown row (BF / AR / KS / TOT). Textures and cooldown reads are served
-- from the spell/cooldown caches, so only real changes hit the frames.
local function UpdateCooldownRow()
    for i = 1, #CD_SPELL_IDS do
        local btn = cdButtons[i]
        local info = GetSpell(CD_SPELL_IDS[i])
        if info then
            if btn.lastTexture ~= info.texture then
                btn.icon:SetTexture(info.texture)
                btn.lastTexture = info.texture
            end

            local start, duration = SpellCooldown(info.name)
            if btn.lastStart ~= start or btn.lastDuration ~= duration then
                if start > 0 and duration > 0 then
                    btn.cooldown:SetCooldown(start, duration)
                else
                    btn.cooldown:Hide()
                end
                btn.lastStart = start
                btn.lastDuration = duration
            end
            if not btn:IsShown() then btn:Show() end

            -- Bounce TOT icon (and its cooldown swipe) while it is usable and
            -- we are in combat. Use a small hysteresis on the remaining cooldown
            -- to avoid flickering around the 1.5s ready boundary.
            if TOT_CD_INDEX and i == TOT_CD_INDEX and btn.bounce then
                local rem = 0
                if start > 0 and duration > 0 then
                    rem = start + duration - GetTime()
                end
                if rem < 0 then rem = 0 end
                local shouldPlay = (rem <= 1.0) and UnitAffectingCombat("player")
                if shouldPlay then
                    if not btn.bounce:IsPlaying() then btn.bounce:Play() end
                    if btn.cooldownBounce and not btn.cooldownBounce:IsPlaying() then
                        btn.cooldownBounce:Play()
                    end
                else
                    if btn.bounce:IsPlaying() then btn.bounce:Stop() end
                    if btn.cooldownBounce and btn.cooldownBounce:IsPlaying() then
                        btn.cooldownBounce:Stop()
                    end
                end
            end
        else
            btn:Hide()
            if TOT_CD_INDEX and i == TOT_CD_INDEX then
                if btn.bounce and btn.bounce:IsPlaying() then btn.bounce:Stop() end
                if btn.cooldownBounce and btn.cooldownBounce:IsPlaying() then btn.cooldownBounce:Stop() end
            end
        end
    end
end

-- Buff tracker icons (S&D, BF, AR). Values come from the aura cache; frames
-- are only touched when the whole-second countdown, the swipe or the visible
-- set actually changed.
local function UpdateBuffIcons()
    local nextX = 0
    for i = 1, #BUFF_TRACKERS do
        local info = BUFF_TRACKERS[i]
        local f = buffIcons[i]
        if not info.name then
            local spell = GetSpell(info.id)
            if spell then
                info.name = spell.name
                f.icon:SetTexture(spell.texture)
            end
        end

        local rem, total, exp = PlayerBuffInfo(info.name)
        if rem > 0 then
            if not f.visible then
                f.visible = true
                f.icon:SetVertexColor(1, 1, 1)
                f.text:Show()
                f:Show()
            end

            if f.posX ~= nextX then
                f:ClearAllPoints()
                f:SetPoint("LEFT", buffFrame, "LEFT", nextX, 0)
                f.posX = nextX
            end
            nextX = nextX + BUFF_ICON_SIZE + SPACING

            if total > 0 and exp > 0 then
                local start = exp - total
                if f.lastStart ~= start or f.lastTotal ~= total then
                    f.cooldown:SetCooldown(start, total)
                    f.lastStart = start
                    f.lastTotal = total
                end
                if not f.cdShown then
                    f.cooldown:Show()
                    f.cdShown = true
                end
            elseif f.cdShown then
                f.cooldown:Hide()
                f.cdShown = false
            end

            local secs = math.floor(rem + 0.5)
            if f.lastText ~= secs then
                f.text:SetText(secs)
                f.lastText = secs
            end
        elseif f.visible then
            f.visible = false
            f:Hide()
            f.cooldown:Hide()
            f.text:Hide()
            f.cdShown = false
            f.lastStart, f.lastTotal, f.lastText = nil, nil, nil
        end
    end

    if nextX > 0 then
        local w = nextX - SPACING
        if buffFrame.lastWidth ~= w then
            buffFrame:SetWidth(w)
            buffFrame.lastWidth = w
        end
    elseif buffFrame.lastWidth ~= 1 then
        buffFrame:SetWidth(1)
        buffFrame.lastWidth = 1
    end
end

--------------------------------------------------------------------
-- Main Update Loop
--------------------------------------------------------------------
local lastUpdate = 0
local updateInterval = ACTIVE_INTERVAL
local visTimer = 0

mainFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < updateInterval then return end
    lastUpdate = 0
    cdTick = cdTick + 1

    if not IsRogue() then
        mainFrame:Hide()
        updateInterval = IDLE_INTERVAL
        return
    end

    -- Slow safety net (was a second frame with its own OnUpdate): keep the
    -- frame visible and refresh the aura cache in case an event was missed.
    -- Runs at most once every two seconds.
    visTimer = visTimer + updateInterval
    if visTimer >= 2 then
        visTimer = 0
        UpdateFrameVisibility()
        RebuildPlayerAuras()
    end

    if not SPELL_MAP.SS then InitSpells() end
    if not aurasReady then RebuildPlayerAuras() end

    local hasTarget = UnitExists("target")
    updateInterval = hasTarget and ACTIVE_INTERVAL or IDLE_INTERVAL

    local spellData = GetActionQueue(hasTarget)

    if hasTarget then
        -- attach cooldown info like RetRotation state caching
        for i = 1, #spellData do
            local data = spellData[i]
            local start, duration = SpellCooldown(data.name)
            data.start = start
            data.duration = duration
            local _, nomana = IsUsableSpell(data.name)
            data.isOOM = nomana
            local cdLeft = 0
            if start > 0 and duration > 1.5 then
                cdLeft = start + duration - GetTime()
            end
            data.cdLeft = cdLeft
        end
    end
    UpdateActionIcons(spellData)

    UpdateCooldownRow()

    UpdateBuffIcons()

end)

mainFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_AURA" then
        -- Refresh the player buff cache when the player's auras change.
        if arg1 == nil or arg1 == "player" then
            RebuildPlayerAuras()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Wake the update loop immediately: if it was idling (no target), the
        -- next frame should refresh instead of waiting out the slow interval.
        updateInterval = ACTIVE_INTERVAL
        lastUpdate = ACTIVE_INTERVAL
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitSpells()
        RebuildPlayerAuras()
        UpdateFrameVisibility()
    elseif event == "PLAYER_LOGIN" or event == "LEARNED_SPELL_IN_TAB" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        InitSpells()
        UpdateFrameVisibility()
    end
end)

mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
mainFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
mainFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
mainFrame:RegisterEvent("UNIT_AURA")

