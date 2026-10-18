local ADDON = "RogueRotation"

RogueRot = RogueRot or {}
local RR = RogueRot

RR.isRogue = false

local function InitDB()
    RogueRotationDB = RogueRotationDB or {}
    RogueRotationDB.pos = RogueRotationDB.pos or {
        point = "CENTER", relativePoint = "CENTER", x = 0, y = -180,
    }
    if RogueRotationDB.locked == nil then RogueRotationDB.locked = false end
    if RogueRotationDB.enabled == nil then RogueRotationDB.enabled = true end
    if RogueRotationDB.scale == nil then RogueRotationDB.scale = 1 end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
    elseif event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        RR.isRogue = (class == "ROGUE")
        print("|cff00ff00RogueRotation|r loaded (class: " .. tostring(class) .. ").")
        if RR.isRogue and RR.CreateUI then
            local ok, err = pcall(RR.CreateUI, RR)
            if not ok then
                print("|cffff0000RogueRotation UI error:|r " .. tostring(err))
            end
        end
    end
end)

SLASH_ROGUEROT1 = "/rr"
SlashCmdList["ROGUEROT"] = function(msg)
    msg = (msg or ""):lower()
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "lock" then
        RogueRotationDB.locked = true
        print("|cff00ff00RogueRotation:|r frame locked.")
    elseif msg == "unlock" then
        RogueRotationDB.locked = false
        print("|cff00ff00RogueRotation:|r frame unlocked (drag to move).")
    elseif msg == "toggle" then
        RogueRotationDB.enabled = not RogueRotationDB.enabled
        print("|cff00ff00RogueRotation:|r " .. (RogueRotationDB.enabled and "enabled" or "disabled") .. ".")
    elseif msg == "diag" then
        if not RR.Diag then
            print("|cffff0000RogueRotation: RR.Diag missing (Rotation.lua not loaded?)|r")
        else
            print("|cff00ff00RogueRotation: calling diag...|r")
            local ok, err = pcall(RR.Diag, RR)
            if not ok then print("|cffff0000RogueRotation diag error:|r " .. tostring(err)) end
            print("|cff00ff00RogueRotation: diag returned|r")
        end
    elseif msg == "t1" then
        if RR.TestCP then RR:TestCP() end
    elseif msg == "t2" then
        if RR.TestBuff then RR:TestBuff() end
    elseif msg == "t3" then
        if RR.TestDebuff then RR:TestDebuff() end
    elseif msg == "t4" then
        if RR.TestQueue then RR:TestQueue() end
    elseif msg == "t5" then
        if RR.TestTex then RR:TestTex() end
    elseif msg == "tr" then
        print("main: tr branch")
        if RR.TestRefresh then
            print("main: calling TestRefresh")
            RR:TestRefresh()
        else
            print("main: TestRefresh missing")
        end
    elseif msg == "tr2" then
        print("main: tr2 branch")
        if RR.TestRefresh2 then
            print("main: calling TestRefresh2")
            RR:TestRefresh2()
        else
            print("main: TestRefresh2 missing")
        end
    elseif msg == "tr3" then
        print("main: tr3 branch")
        if RR.TestRefresh3 then
            print("main: calling TestRefresh3")
            RR:TestRefresh3()
        else
            print("main: TestRefresh3 missing")
        end
    elseif msg == "tr4" then
        print("main: tr4 branch")
        if RR.TestRefresh4 then
            print("main: calling TestRefresh4")
            RR:TestRefresh4()
        else
            print("main: TestRefresh4 missing")
        end
    elseif msg == "show" then
        if RR.frame then
            RR.frame:Show()
            print("|cff00ff00RogueRotation:|r frame shown.")
        else
            print("|cff00ff00RogueRotation:|r no frame (rogue only).")
        end
    elseif msg == "now" then
        if RR.Refresh then
            local ok, err = pcall(RR.Refresh, RR)
            if not ok then
                print("|cffff0000RogueRotation refresh error:|r " .. tostring(err))
            else
                local q = (RR.GetActionQueue and RR:GetActionQueue()) or {}
                print("|cff00ff00RogueRotation:|r refreshed, " .. #q .. " actions.")
            end
        end
    elseif msg == "reset" then
        RogueRotationDB.pos = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -180 }
        if RR.frame then
            RR.frame:ClearAllPoints()
            RR.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
        end
        print("|cff00ff00RogueRotation:|r frame reset.")
    else
        print("|cff00ff00RogueRotation commands:|r /rr lock | unlock | toggle | reset")
    end
end