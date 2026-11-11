local ADDON_NAME = ...

-- Hides every name tag while the UI is hidden (Alt+Z) and puts the player's
-- own name settings back when the UI returns. Inspired by FlyCandy.
--
-- Safety rules: every CVar call is protected (a CVar missing on this client is
-- skipped, never an error), and the player's real settings are saved BEFORE
-- they are switched off, so they can always be restored.

local CVARS = {
    "UnitNameOwn",
    "UnitNameNPC",
    "UnitNamePlayerGuild",
    "UnitNamePlayerPVPTitle",
    "UnitNameFriendlyPlayerName",
    "UnitNameFriendlyPetName",
    "UnitNameFriendlyGuardianName",
    "UnitNameFriendlyTotemName",
    "UnitNameEnemyPlayerName",
    "UnitNameEnemyPetName",
    "UnitNameEnemyGuardianName",
    "UnitNameEnemyTotemName",
    "UnitNameNonCombatCreatureName",
    "UnitNameGuildTitle",
}

local PREFIX = "|cff33ff99HideUINames|r "

local function GetCVarSafe(name)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    local ok, value = pcall(getter, name)
    if ok and value ~= nil then
        return tostring(value)
    end
    return nil
end

local function SetCVarSafe(name, value)
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    pcall(setter, name, value)
end

local function DB()
    if type(HideUINamesDB) ~= "table" then
        HideUINamesDB = {}
    end
    if type(HideUINamesDB.values) ~= "table" then
        HideUINamesDB.values = {}
    end
    return HideUINamesDB
end

-- True while we have switched the names off and not yet restored them.
local namesHidden = false

local function Snapshot()
    local values = DB().values
    for _, name in ipairs(CVARS) do
        local current = GetCVarSafe(name)
        if current ~= nil then
            values[name] = current
        end
    end
end

local function HideNames()
    if namesHidden then
        return
    end
    Snapshot() -- remember the player's real settings first
    namesHidden = true
    DB().hidden = true
    for _, name in ipairs(CVARS) do
        if GetCVarSafe(name) ~= nil then
            SetCVarSafe(name, "0")
        end
    end
end

local function RestoreNames()
    local db = DB()
    for _, name in ipairs(CVARS) do
        local saved = db.values[name]
        if saved ~= nil then
            SetCVarSafe(name, saved)
        end
    end
    namesHidden = false
    db.hidden = false
end

local function Safe(fn)
    return function()
        local ok, err = pcall(fn)
        if not ok then
            print(PREFIX .. "|cffff5555error:|r " .. tostring(err))
        end
    end
end

UIParent:HookScript("OnHide", Safe(HideNames))
UIParent:HookScript("OnShow", Safe(RestoreNames))

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", Safe(function()
    -- Runs after saved variables exist. If the previous session ended (crash,
    -- logout) while names were hidden, the real values are in the saved
    -- snapshot: put them back now that the UI is visible.
    local db = DB()
    if db.hidden and UIParent:IsShown() then
        RestoreNames()
    elseif not db.hidden and UIParent:IsShown() then
        Snapshot()
    end
    events:UnregisterEvent("ADDON_LOADED")
end))
events:SetScript("OnEvent", (function(handler)
    return function(_, _, addon)
        if addon == ADDON_NAME then
            handler()
        end
    end
end)(events:GetScript("OnEvent")))
