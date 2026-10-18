local RR = RogueRot

local function CreateIcon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    f.texture = tex

    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints()
    f.cd = cd

    local border = f:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetVertexColor(1, 1, 1, 0.6)
    f.border = border

    f:SetScript("OnEnter", function(self)
        if self.spellName then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.spellName, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.texture:SetTexture(nil)
    f:Show()
    return f
end

function RR:CreateUI()
    if self.frame then return end

    local f = CreateFrame("Frame", "RogueRotationFrame", UIParent)
    f:SetSize(280, 74)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not RogueRotationDB.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        RogueRotationDB.pos = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)

    local p = RogueRotationDB.pos or { point = "CENTER", relativePoint = "CENTER", x = 0, y = -180 }
    f:SetPoint(p.point or "CENTER", UIParent, p.relativePoint or "CENTER", p.x or 0, p.y or -180)
    f:SetScale(RogueRotationDB.scale or 1)

    -- backdrop
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(0, 0, 0, 0.55)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", f, "TOP", 0, -2)
    title:SetText("Rogue Rotation")

    self.frame = f

    self.icons = {}
    local sizes = { 54, 36, 36, 36, 36 }
    for i = 1, 5 do
        local icon = CreateIcon(f, sizes[i])
        if i == 1 then
            icon:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 6)
        else
            icon:SetPoint("LEFT", self.icons[i - 1], "RIGHT", 4, 0)
        end
        self.icons[i] = icon
    end

    f:Show()
    -- Auto-updating disabled for debugging; use /rr now
    RR.frame = f
end

local function SetIconTexture(iconFrame, spellName)
    if not spellName then
        iconFrame.texture:SetTexture(nil)
        return
    end
    local tex = GetSpellTexture(spellName)
    iconFrame.texture:SetTexture(tex)
end

function RR:Refresh()
    if not self.frame then return end
    if not self.isRogue then
        self.frame:Hide()
        return
    end
    if not RogueRotationDB or not RogueRotationDB.enabled then
        self.frame:Hide()
        return
    end

    if not InCombatLockdown() then
        self.frame:Show()
    end

    local ok, q = pcall(self.GetActionQueue, self)
    if not ok then
        print("|cffff0000RogueRotation queue error:|r " .. tostring(q))
        if not InCombatLockdown() then self.frame:Hide() end
        return
    end
    for i = 1, 5 do
        local icon = self.icons[i]
        local action = q[i]
        if action then
            icon.spellName = action
            SetIconTexture(icon, action)
        else
            SetIconTexture(icon, nil)
        end
        -- keep icons always visible (avoid combat-locked Show/Hide)
    end
end