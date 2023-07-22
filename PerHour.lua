-- First, we create a namespace for our addon by declaring a top-level table that will hold everything else.
PerHourAddon = {}
 
-- This isn't strictly necessary, but we'll use this string later when registering events.
-- Better to define it in a single place rather than retyping the same string.
PerHourAddon.name = "PerHour"

local function log(msg)
    d("Per Hour: " .. msg)
end

-- Handle seting the item to track
local LCM = LibCustomMenu

function PerHourAddon.TrackItem(itemLink)
    PerHourAddon.itemTrack = itemLink
    log("Tracking: " .. PerHourAddon.itemTrack)
    PerHourAddon.Reset()
    PerHourAddon.UpdateUI()
end

ZO_CreateStringId("TRACK_ITEM", "Per Hour: Track Item")
local function AddItem(inventorySlot, slotActions)
  local valid = ZO_Inventory_GetBagAndIndex(inventorySlot)
  if not valid then return end
  slotActions:AddCustomSlotAction(TRACK_ITEM, function()
    PerHourAddon.itemName = GetItemName(bagId, slotIndex)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    local itemLink = GetItemLink(bagId, slotIndex)
    PerHourAddon.TrackItem(itemLink)
  end , "")
end
 
LCM:RegisterContextMenu(AddItem, LCM.CATEGORY_LATE)


local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end


local ignoreEvent = {
    42, -- CURRENCY_CHANGE_REASON_BANK_DEPOSIT
    43, -- CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
    51, -- CURRENCY_CHANGE_REASON_GUILD_BANK_DEPOSIT
    52, -- CURRENCY_CHANGE_REASON_GUILD_BANK_WITHDRAWAL
    35, -- CURRENCY_CHANGE_REASON_PLAYER_INIT (Fixes telvar on login)
}


function PerHourAddon.OnGoldUpdate(eventCode, newMoney, oldMoney, reason)
    if has_value(ignoreEvent, reason) then
        return
    end
    
    PerHourAddon.gold = PerHourAddon.gold + newMoney - oldMoney
    PerHourAddon.UpdateUI()
end

function PerHourAddon.OnAPUpdate(eventCode, newAlliancePoints, playSound, difference, reason)
    if has_value(ignoreEvent, reason) then
        return
    end

    PerHourAddon.ap = PerHourAddon.ap + newAlliancePoints - oldAlliancePoints
    PerHourAddon.UpdateUI()
end

function PerHourAddon.OnTelvarUpdate(eventCode, newTelvarStones, oldTelvarStones, reason)
    if has_value(ignoreEvent, reason) then
        return
    end

    PerHourAddon.telvar = PerHourAddon.telvar + newTelvarStones - oldTelvarStones
    PerHourAddon.UpdateUI()
end

function PerHourAddon.OnLootReceived(eventCode, lootedBy, itemLink, quantity, itemSound, lootType, isStolen)
    log("Looted: " .. itemLink)
    if lootedBy ~= GetUnitName("player") then
        return
    end

    if itemLink ~= PerHourAddon.itemTrack then
        log("Not tracking: " .. itemLink)
        return
    end

    if has_value(ignoreEvent, reason) then
        log("Ignoring: " .. itemLink)
        return
    end

    log("PerHour: Looted: " .. itemLink)

    PerHourAddon.item = PerHourAddon.item + quantity
    PerHourAddon.UpdateUI()
end

function PerHourAddon.CalculatePerHour(oldValue, newValue)
    local timeDiff = GetTimeStamp() - PerHourAddon.oldTime
    local diff = newValue - oldValue
    local perHour = diff / timeDiff * 3600
    return math.floor(perHour)
end

function PerHourAddon.UpdateUI()
    if PerHourAddon.gold ~= 0 then
        PerHourAddonIndicatorGold:SetText("Gold: " .. PerHourAddon.CalculatePerHour(0, PerHourAddon.gold) .. "/hr")
    end

    if PerHourAddon.ap ~= 0 then
        PerHourAddonIndicatorAP:SetText("AP: " .. PerHourAddon.CalculatePerHour(0, PerHourAddon.ap) .. "/hr")
    end

    if PerHourAddon.telvar ~= 0 then
        PerHourAddonIndicatorTelvar:SetText("Telvar: " .. PerHourAddon.CalculatePerHour(0, PerHourAddon.telvar) .. "/hr")
    end

    if PerHourAddon.item ~= 0 then
        PerHourAddonIndicatorItem:SetText(PerHourAddon.itemName .. ": " .. PerHourAddon.CalculatePerHour(0, PerHourAddon.item) .. "/hr")
    end
end

function PerHourAddon.Reset()
    log("Resetting")
    PerHourAddon.oldTime = GetTimeStamp()

    PerHourAddon.gold = 0
    PerHourAddon.telvar = 0
    PerHourAddon.ap = 0
    PerHourAddon.item = 0
    PerHourAddon.itemName = ""

    PerHourAddon.UpdateUI()
end



function PerHourAddon.RestorePosition()
    local left = PerHourAddon.savedVariables.left
    local top = PerHourAddon.savedVariables.top
    
    PerHourAddonIndicator:ClearAnchors()
    PerHourAddonIndicator:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end


function PerHourAddon.OnIndicatorMoveStop()
    PerHourAddon.savedVariables.left = PerHourAddonIndicator:GetLeft()
    PerHourAddon.savedVariables.top = PerHourAddonIndicator:GetTop()
end

-- Next we create a function that will initialize our addon
function PerHourAddon.Initialize()
    PerHourAddon.Reset()

    EVENT_MANAGER:RegisterForEvent(PerHourAddon.name, EVENT_MONEY_UPDATE, PerHourAddon.OnGoldUpdate)
    EVENT_MANAGER:RegisterForEvent(PerHourAddon.name, EVENT_TELVAR_STONE_UPDATE, PerHourAddon.OnTelvarUpdate)
    EVENT_MANAGER:RegisterForEvent(PerHourAddon.name, EVENT_ALLIANCE_POINT_UPDATE, PerHourAddon.OnAPUpdate)
    EVENT_MANAGER:RegisterForEvent(PerHourAddon.name, EVENT_LOOT_RECEIVED, PerHourAddon.OnLootReceived)

    PerHourAddon.savedVariables = ZO_SavedVars:NewCharacterIdSettings("PerHourAddonSavedVariables", 1, nil, {})

    PerHourAddon.RestorePosition()
end


-- Then we create an event handler function which will be called when the "addon loaded" event
-- occurs. We'll use this to initialize our addon after all of its resources are fully loaded.
function PerHourAddon.OnAddOnLoaded(event, addonName)
    -- The event fires each time *any* addon loads - but we only care about when our own addon loads.
    if addonName == PerHourAddon.name then
        PerHourAddon.Initialize()
        --unregister the event again as our addon was loaded now and we do not need it anymore to be run for each other addon that will load
        EVENT_MANAGER:UnregisterForEvent(PerHourAddon.name, EVENT_ADD_ON_LOADED) 
    end
end

-- Finally, we'll register our event handler function to be called when the proper event occurs.
-->This event EVENT_ADD_ON_LOADED will be called for EACH of the addns/libraries enabled, this is why there needs to be a check against the addon name
-->within your callback function! Else the very first addon loaded would run your code + all following addons too.
EVENT_MANAGER:RegisterForEvent(PerHourAddon.name, EVENT_ADD_ON_LOADED, PerHourAddon.OnAddOnLoaded)