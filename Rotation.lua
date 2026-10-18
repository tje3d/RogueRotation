local RR = RogueRot

RR.Spells = {
    snd  = "Slice and Dice",
    rupt = "Rupture",
    evis = "Eviscerate",
    ss   = "Sinister Strike",
    ks   = "Killing Spree",
    ar   = "Adrenaline Rush",
    bf   = "Blade Flurry",
    shiv = "Shiv",
    tott = "Tricks of the Trade",
}

local function BuffRemaining(unit, name)
    for i = 1, 24 do
        local n, _, _, _, _, _, exp = UnitBuff(unit, i)
        if not n then return 0 end
        if n == name then
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

local function DebuffRemaining(unit, name)
    for i = 1, 24 do
        local n, _, _, _, _, _, exp = UnitDebuff(unit, i)
        if not n then return 0 end
        if n == name then
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

local function GetComboPoints()
    local cp = 0
    local ok, val = pcall(GetComboPoints, "player")
    if ok and type(val) == "number" then cp = val end
    if (not cp or cp == 0) then
        local ok2, val2 = pcall(GetComboPoints, "player", "target")
        if ok2 and type(val2) == "number" then cp = val2 end
    end
    return cp or 0
end

local function SpellReady(name)
    local usable = IsUsableSpell(name)
    if not usable then return false end
    local start, duration = GetSpellCooldown(name)
    if not start or start == 0 then return true end
    local rem = start + (duration or 0) - GetTime()
    return rem <= 0.1
end

local function CDRemaining(name)
    local start, duration = GetSpellCooldown(name)
    if not start or start == 0 then return 0 end
    local rem = start + (duration or 0) - GetTime()
    if rem < 0 then rem = 0 end
    return rem
end

function RR:GetActionQueue()
    local queue = {}
    if not UnitExists("target") then return queue end

    local sp = self.Spells
    local state = {
        energy = UnitMana("player") or 0,
        maxEnergy = UnitManaMax("player") or 100,
        cp = GetComboPoints(),
        snd = BuffRemaining("player", sp.snd),
        rupt = DebuffRemaining("target", sp.rupt),
        targetHp = 100,
        ksCD = CDRemaining(sp.ks),
        arCD = CDRemaining(sp.ar),
    }
    local hp = UnitHealth("target") or 0
    local maxhp = UnitHealthMax("target") or 0
    if maxhp > 0 then state.targetHp = (hp / maxhp) * 100 end

    for step = 1, 5 do
        local action = nil
        -- Keep Slice and Dice up.
        if state.snd <= 2 and state.cp >= 1 and SpellReady(sp.snd) then
            action = sp.snd
        -- Finishers at 4+ combo points.
        elseif state.cp >= 4 then
            if state.rupt <= 2 and state.targetHp > 30 and SpellReady(sp.rupt) then
                action = sp.rupt
            elseif SpellReady(sp.evis) then
                action = sp.evis
            end
        -- Offensive cooldowns when stable.
        elseif state.snd > 4 and state.cp <= 2 then
            if state.ksCD <= 0 and SpellReady(sp.ks) then
                action = sp.ks
            elseif state.arCD <= 0 and SpellReady(sp.ar) then
                action = sp.ar
            end
        end
        -- Default builder.
        if not action and SpellReady(sp.ss) then
            action = sp.ss
        end
        if not action then break end
        table.insert(queue, action)

        -- Apply
        if action == sp.snd then
            state.energy = state.energy - 25
            state.snd = 6 + (state.cp * 3)
            state.cp = 0
        elseif action == sp.rupt then
            state.energy = state.energy - 25
            state.rupt = 6 + (state.cp * 2)
            state.cp = 0
        elseif action == sp.evis then
            state.energy = state.energy - 35
            state.cp = 0
        elseif action == sp.ks then
            state.ksCD = 120
        elseif action == sp.ar then
            state.energy = state.maxEnergy
            state.arCD = 180
        elseif action == sp.ss then
            state.energy = state.energy - 45
            state.cp = math.min(5, state.cp + 1)
        end
        if state.energy < 0 then state.energy = 0 end
        -- Advance
        state.snd = math.max(0, state.snd - 1.5)
        state.rupt = math.max(0, state.rupt - 1.5)
        state.ksCD = math.max(0, state.ksCD - 1.5)
        state.arCD = math.max(0, state.arCD - 1.5)
        state.targetHp = state.targetHp -- unchanged approx
        state.energy = math.min(state.maxEnergy, state.energy + 15)
    end

    return queue
end

-- Keep Diag minimal but useful
function RR:Diag()
    print("diag: start")
    if not UnitExists("target") then print("diag: no target") return end
    print("diag: cp=" .. tostring(GetComboPoints()))
    print("diag: snd=" .. tostring(BuffRemaining("player", self.Spells.snd)))
    print("diag: rupt=" .. tostring(DebuffRemaining("target", self.Spells.rupt)))
    -- test queue
    local q = self:GetActionQueue()
    print("diag: queue size=" .. tostring(#q))
    for _, name in ipairs({self.Spells.snd, self.Spells.rupt, self.Spells.evis, self.Spells.ss}) do
        local tex = GetSpellTexture(name)
        print("diag: texture " .. name .. " = " .. tostring(tex))
    end
    print("diag: end")
end

function RR:TestCP()
    print("T1 start")
    local cp = GetComboPoints()
    local en = UnitMana("player")
    print("T1 done cp=" .. tostring(cp) .. " en=" .. tostring(en))
end

function RR:TestBuff()
    print("T2 start")
    local r = BuffRemaining("player", self.Spells.snd)
    print("T2 done r=" .. tostring(r))
end

function RR:TestDebuff()
    print("T3 start")
    local r = DebuffRemaining("target", self.Spells.rupt)
    print("T3 done r=" .. tostring(r))
end

function RR:TestQueue()
    print("T4 start")
    local q = self:GetActionQueue()
    print("T4 done size=" .. tostring(#q))
end

function RR:TestTex()
    print("T5 start")
    for _, name in ipairs({self.Spells.snd, self.Spells.rupt, self.Spells.evis, self.Spells.ss}) do
        local tex = GetSpellTexture(name)
        print("T5 " .. name .. " = " .. tostring(tex))
    end
    print("T5 done")
end

function RR:TestRefresh()
    print("TR start")
    if not self.frame then print("TR no frame") return end
    self.frame:Show()
    for i = 1, 5 do
        local icon = self.icons[i]
        icon:Show()
        icon.texture:SetTexture(GetSpellTexture(self.Spells.ss))
    end
    print("TR done")
end

function RR:TestRefresh2()
    print("TR2 start")
    if not self.frame then print("TR2 no frame") return end
    self.frame:Show()
    local ok, q = pcall(self.GetActionQueue, self)
    print("TR2 queue ok=" .. tostring(ok) .. " size=" .. tostring(ok and #q or 0))
    if not ok then return end
    for i = 1, 5 do
        local icon = self.icons[i]
        local action = q[i]
        print("TR2 icon " .. i .. " action=" .. tostring(action))
        if action then
            icon:Show()
            icon.spellName = action
            icon.texture:SetTexture(GetSpellTexture(action))
        else
            icon:Hide()
        end
        print("TR2 icon " .. i .. " done")
    end
    print("TR2 done")
end

function RR:TestRefresh3()
    print("TR3 start")
    if not self.frame then print("TR3 no frame") return end
    self.frame:Show()
    for i = 1, 5 do
        local icon = self.icons[i]
        if i == 1 then
            icon:Show()
            icon.texture:SetTexture(GetSpellTexture(self.Spells.ss))
        else
            icon:Hide()
        end
    end
    print("TR3 done")
end

function RR:TestRefresh4()
    print("TR4 start")
    if not self.frame then print("TR4 no frame") return end
    self.frame:Show()
    local names = {self.Spells.ss, self.Spells.snd, self.Spells.rupt, self.Spells.evis}
    for i = 1, #names do
        local icon = self.icons[i]
        icon:Show()
        print("TR4 " .. i .. " before SetTexture " .. tostring(names[i]))
        icon.texture:SetTexture(GetSpellTexture(names[i]))
        print("TR4 " .. i .. " after")
    end
    print("TR4 done")
end