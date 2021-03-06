--[[
    DamageReport v2.3

    Created By Dorian Gray

    Discord: Dorian Gray#2623
    InGame: DorianGray
    GitHub: https://github.com/DorianTheGrey/DU-DamageReport

    GNU Public License 3.0. Use whatever you want, be so kind to leave credit.

    Thanks to Jericho, Dmentia and Archaegeo for learning from their fine scripts.
]] 
-----------------------------------------------
-- CONFIG
-----------------------------------------------
UseMyElementNames = true --export: If you active this, the display will not show the element type of damaged/broken elements but the name you gave them (truncated to 25 characters)
AllowElementHighlighting = true --export: Are you allowing damaged/broken elements to be highlighted in 3D space when selected in the HUD?
UpdateInterval = 1 --export: Interval in seconds between updates of the calculations and (if anything changed) redrawing to the screen(s). You need to restart the script after changing this value.
HighlightBlinkingInterval = 0.5 --export: If an element is marked, how fast do you want the arrows to blink?
SimulationMode = false --export Randomize simluated damage on elements to check out the functionality of this script. And, no, your elements won't be harmed in the process :) You need to restart the script after changing this value.
YourShipsName = "Enter here" --export Enter your ship name here if you want it displayed instead of the ship's ID. YOU NEED TO LEAVE THE QUOTATION MARKS.

DebugMode = false -- Activate if you want some console messages
VersionNumber = 2.3 -- Version number

core = nil
screens = {}

shipID = 0
forceRedraw = false
SimulationActive = false

clickAreas = {}
DamagedSortingMode = 1 -- Define default sorting mode for damaged elements. 1 to sort by damage amount, 2 to sort by element id, 3 to sort by damage percent, 
BrokenSortingMode = 1 -- Define default sorting mode for broken elements. 1 to sort by damage amount, 2 to sort by element id

HUDMode = false -- Is Hud active?
hudSelectedIndex = 0 -- Which element is selected?
hudSelectedType = 0 -- Is selected element damaged (1) or broken (2)
hudArrowSticker = {}
highlightOn = false
highlightID = 0
highlightX = 0
highlightY = 0
highlightZ = 0

CurrentDamagedPage = 1
CurrentBrokenPage = 1

coreWorldOffset = 0
totalShipHP = 0
totalShipMaxHP = 0
totalShipIntegrity = 100
elementsId = {}
damagedElements = {}
brokenElements = {}
ElementCounter = 0
healthyElements = 0

OkayCenterMessage = "All systems nominal."

-----------------------------------------------
-- FUNCTIONS
-----------------------------------------------

function GenerateCommaValue(amount)
    local formatted = amount
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then break end
    end
    return formatted
end

function PrintDebug(output, highlight)
    highlight = highlight or false
    if DebugMode then
        if highlight then
            system.print(
                "------------------------------------------------------------------------")
        end
        system.print(output)
        if highlight then
            system.print(
                "------------------------------------------------------------------------")
        end
    end
end

function PrintError(output) system.print(output) end

function DrawCenteredText(output)
    for i = 1, #screens, 1 do screens[i].setCenteredText(output) end
end

function DrawSVG(output) for i = 1, #screens, 1 do screens[i].setSVG(output) end end

function ClearConsole() for i = 1, 10, 1 do PrintDebug() end end

function SwitchScreens(state)
    state = state or true
    if #screens > 0 then
        for i = 1, #screens, 1 do
            if state==true then
                screens[i].clear()
                screens[i].activate()
            else
                screens[i].deactivate()
                screens[i].clear()
            end
        end
    end
end

function InitiateSlots()
    for slot_name, slot in pairs(unit) do
        if type(slot) == "table" and type(slot.export) == "table" and
            slot.getElementClass then
            if slot.getElementClass():lower():find("coreunit") then
                core = slot
                local coreHP = core.getMaxHitPoints()
                if coreHP > 10000 then
                    coreWorldOffset = 128
                elseif coreHP > 1000 then
                    coreWorldOffset = 64
                elseif coreHP > 150 then
                    coreWorldOffset = 32
                else
                    coreWorldOffset = 16
                end
            end
            if slot.getElementClass():lower():find("screenunit") then
                screens[#screens + 1] = slot
            end
        end
    end
end

function AddClickArea(newEntry) table.insert(clickAreas, newEntry) end

function RemoveFromClickAreas(candidate)
    for k, v in pairs(clickAreas) do
        if v.id == candidate then
            clickAreas[k] = nil
            break
        end
    end
end

function UpdateClickArea(candidate, newEntry)
    for k, v in pairs(clickAreas) do
        if v.id == candidate then
            clickAreas[k] = newEntry
            break
        end
    end
end

function DisableClickArea(candidate)
    for k, v in pairs(clickAreas) do
        if v.id == candidate then
            UpdateClickArea(candidate, {
                id = candidate,
                x1 = -1,
                x2 = -1,
                y1 = -1,
                y2 = -1
            })
            break
        end
    end
end

function InitiateClickAreas()
    clickAreas = {}
    AddClickArea({id = "DamagedDamage", x1 = 725, x2 = 870, y1 = 380, y2 = 415})
    AddClickArea({id = "DamagedHealth", x1 = 520, x2 = 655, y1 = 380, y2 = 415})
    AddClickArea({id = "DamagedID", x1 = 90, x2 = 150, y1 = 380, y2 = 415})
    AddClickArea({id = "BrokenDamage", x1 = 1675, x2 = 1835, y1 = 380, y2 = 415})
    AddClickArea({id = "BrokenID", x1 = 1050, x2 = 1110, y1 = 380, y2 = 415})
    AddClickArea({id = "ToggleSimulation", x1 = 65, x2 = 660, y1 = 100, y2 = 145})
    AddClickArea({id = "ToggleSimulation2", x1 = 1650, x2 = 1850, y1 = 75, y2 = 117})
    AddClickArea({id = "ToggleElementLabel", x1 = 225, x2 = 460, y1 = 380, y2 = 415})
    AddClickArea({id = "ToggleElementLabel2", x1 = 1185, x2 = 1440, y1 = 380, y2 = 415})
    AddClickArea({id = "ToggleHudMode", x1 = 1650, x2 = 1850, y1 = 125, y2 = 167})
    AddClickArea({id = "DamagedPageDown", x1 = -1, x2 = -1, y1 = -1, y2 = -1})
    AddClickArea({id = "DamagedPageUp", x1 = -1, x2 = -1, y1 = -1, y2 = -1})
    AddClickArea({id = "BrokenPageDown", x1 = -1, x2 = -1, y1 = -1, y2 = -1})
    AddClickArea({id = "BrokenPageUp", x1 = -1, x2 = -1, y1 = -1, y2 = -1})
end

function FlushClickAreas() clickAreas = {} end

function CheckClick(x, y, HitTarget)
    HitTarget = HitTarget or ""
    if HitTarget == "" then
        for k, v in pairs(clickAreas) do
            if v and x >= v.x1 and x <= v.x2 and y >= v.y1 and y <= v.y2 then
                HitTarget = v.id
                break
            end
        end
    end
    if HitTarget == "DamagedDamage" then
        DamagedSortingMode = 1
        CurrentDamagedPage = 1
        SortTables()
        HudDeselectElement()
        DrawScreens()
    elseif HitTarget == "DamagedHealth" then
        DamagedSortingMode = 3
        CurrentDamagedPage = 1
        SortTables()
        HudDeselectElement()
        DrawScreens()
    elseif HitTarget == "DamagedID" then
        DamagedSortingMode = 2
        CurrentDamagedPage = 1
        SortTables()
        HudDeselectElement()
        DrawScreens()
    elseif HitTarget == "BrokenDamage" then
        BrokenSortingMode = 1
        CurrentBrokenPage = 1
        SortTables()
        HudDeselectElement()
        DrawScreens()
    elseif HitTarget == "BrokenID" then
        BrokenSortingMode = 2
        CurrentBrokenPage = 1
        SortTables()
        HudDeselectElement()
        DrawScreens()
    elseif HitTarget == "DamagedPageDown" then
        CurrentDamagedPage = CurrentDamagedPage + 1
        if CurrentDamagedPage > math.ceil(#damagedElements / 12) then
            CurrentDamagedPage = math.ceil(#damagedElements / 12)
        end
        HudDeselectElement()
        DrawScreens()
    elseif HitTarget == "DamagedPageUp" then
        CurrentDamagedPage = CurrentDamagedPage - 1
        if CurrentDamagedPage < 1 then CurrentDamagedPage = 1 end
        HudDeselectElement()
        DrawScreens()
    elseif HitTarget == "BrokenPageDown" then
        CurrentBrokenPage = CurrentBrokenPage + 1
        if CurrentBrokenPage > math.ceil(#brokenElements / 12) then
            CurrentBrokenPage = math.ceil(#brokenElements / 12)
        end
        HudDeselectElement()
        DrawScreens()
    elseif HitTarget == "BrokenPageUp" then
        CurrentBrokenPage = CurrentBrokenPage - 1
        if CurrentBrokenPage < 1 then CurrentBrokenPage = 1 end
        HudDeselectElement()
        DrawScreens()
    elseif HitTarget == "ToggleHudMode" then
        if HUDMode == true then
            HUDMode = false
            forceRedraw = true
            HudDeselectElement()
            DrawScreens()
        else
            HUDMode = true
            forceRedraw = true
            HudDeselectElement()
            DrawScreens()
        end
    elseif HitTarget == "ToggleSimulation" or HitTarget == "ToggleSimulation2" then
        CurrentDamagedPage = 1
        CurrentBrokenPage = 1
        if SimulationMode == true then
            SimulationMode = false
            SimulationActive = false
            GenerateDamageData()
            forceRedraw = true
            HudDeselectElement()
            DrawScreens()
        else
            SimulationMode = true
            SimulationActive = false
            GenerateDamageData()
            forceRedraw = true
            HudDeselectElement()
            DrawScreens()
        end
    elseif HitTarget == "ToggleElementLabel" or HitTarget ==
        "ToggleElementLabel2" then
        if UseMyElementNames == true then
            UseMyElementNames = false
            SimulationActive = false
            GenerateDamageData()
            forceRedraw = true
            HudDeselectElement()
            DrawScreens()
        else
            UseMyElementNames = true
            SimulationActive = false
            GenerateDamageData()
            forceRedraw = true
            HudDeselectElement()
            DrawScreens()
        end
    end
end

function ToggleHUD()
    HideHighlight()
    CheckClick(nil, nil, "ToggleHudMode")
end

function HudDeselectElement()
    if HUDMode == true then
        hudSelectedType = 0
        hudSelectedIndex = 0
        HideHighlight()
        DrawScreens()
    end
end

function ChangeHudSelectedElement(step)
    if HUDMode == true and (#damagedElements or #brokenElements) then
        local damagedElementsHUD = 12
        if #damagedElements < 12 then
            damagedElementsHUD = #damagedElements
        end
        local brokenElementsHUD = 12
        if #brokenElements < 12 then brokenElementsHUD = #brokenElements end
        if step == 1 then
            if hudSelectedIndex == 0 then
                if damagedElementsHUD > 0 then
                    hudSelectedType = 1
                    hudSelectedIndex = 1
                elseif brokenElementsHUD > 0 then
                    hudSelectedType = 2
                    hudSelectedIndex = 1
                end
            elseif hudSelectedType == 1 then
                if damagedElementsHUD > hudSelectedIndex then
                    hudSelectedIndex = hudSelectedIndex + 1
                elseif brokenElementsHUD > 0 then
                    hudSelectedType = 2
                    hudSelectedIndex = 1
                elseif damagedElementsHUD > 0 then
                    hudSelectedIndex = 1
                end
            elseif hudSelectedType == 2 then
                if brokenElementsHUD > hudSelectedIndex then
                    hudSelectedIndex = hudSelectedIndex + 1
                elseif damagedElementsHUD > 0 then
                    hudSelectedType = 1
                    hudSelectedIndex = 1
                elseif brokenElementsHUD > 0 then
                    hudSelectedIndex = 1
                end
            end
        elseif step == -1 then
            if hudSelectedIndex == 0 then
                if brokenElementsHUD > 0 then
                    hudSelectedType = 2
                    hudSelectedIndex = 1
                elseif damagedElementsHUD > 0 then
                    hudSelectedType = 1
                    hudSelectedIndex = 1
                end
            elseif hudSelectedType == 1 then
                if hudSelectedIndex > 1 then
                    hudSelectedIndex = hudSelectedIndex - 1
                elseif brokenElementsHUD > 0 then
                    hudSelectedType = 2
                    hudSelectedIndex = brokenElementsHUD
                elseif damagedElementsHUD > 0 then
                    hudSelectedIndex = damagedElementsHUD
                end
            elseif hudSelectedType == 2 then
                if hudSelectedIndex > 1 then
                    hudSelectedIndex = hudSelectedIndex - 1
                elseif damagedElementsHUD > 0 then
                    hudSelectedType = 1
                    hudSelectedIndex = damagedElementsHUD
                elseif brokenElementsHUD > 0 then
                    hudSelectedIndex = brokenElementsHUD
                end
            end
        end
        HighlightElement()
        DrawScreens()
        -- PrintDebug("-> Type: "..hudSelectedType.. " Index: "..hudSelectedIndex)
    end
end

function HideHighlight()
    if #hudArrowSticker > 0 then
        for i in pairs(hudArrowSticker) do
            core.deleteSticker(hudArrowSticker[i])
        end
        hudArrowSticker = {}
    end
end

function ShowHighlight()
    if highlightOn == true and highlightID > 0 then
        table.insert(hudArrowSticker, core.spawnArrowSticker(highlightX + 2,
                                                             highlightY,
                                                             highlightZ, "north"))
        table.insert(hudArrowSticker, core.spawnArrowSticker(highlightX,
                                                             highlightY - 2,
                                                             highlightZ, "east"))
        table.insert(hudArrowSticker, core.spawnArrowSticker(highlightX - 2,
                                                             highlightY,
                                                             highlightZ, "south"))
        table.insert(hudArrowSticker, core.spawnArrowSticker(highlightX,
                                                             highlightY + 2,
                                                             highlightZ, "west"))
        table.insert(hudArrowSticker, core.spawnArrowSticker(highlightX,
                                                             highlightY,
                                                             highlightZ - 2,
                                                             "up"))
        table.insert(hudArrowSticker, core.spawnArrowSticker(highlightX,
                                                             highlightY,
                                                             highlightZ + 2,
                                                             "down"))
    end
end

function ToggleHighlight()
    if highlightOn == true then
        highlightOn = false
        HideHighlight()
    else
        highlightOn = true
        ShowHighlight()
    end
end

function HighlightElement(elementID)
    elementID = elementID or 0
    local targetElement = {}

    if elementID == 0 then
        if hudSelectedType == 1 then
            elementID = damagedElements[(CurrentDamagedPage - 1) * 12 +
                            hudSelectedIndex].id
        elseif hudSelectedType == 2 then
            elementID = brokenElements[(CurrentBrokenPage - 1) * 12 +
                            hudSelectedIndex].id
        end

        if elementID ~= 0 then
            local bFound = false
            for k, v in pairs(damagedElements) do
                if v.id == elementID then
                    targetElement = v
                    bFound = true
                    break
                end
            end
            if bFound == false then
                for k, v in pairs(brokenElements) do
                    if v.id == elementID then
                        targetElement = v
                        bFound = true
                        break
                    end
                end
            end

            if bFound == true and AllowElementHighlighting == true then
                HideHighlight()
                elementPosition = vec3(targetElement.pos)
                highlightX = elementPosition.x - coreWorldOffset
                highlightY = elementPosition.y - coreWorldOffset
                highlightZ = elementPosition.z - coreWorldOffset
                highlightID = targetElement.id
                highlightOn = true
                ShowHighlight()
            end
        end
    end
end

function SortTables()
    -- Sort damaged elements descending by percent damaged according to setting
    if DamagedSortingMode == 1 then
        table.sort(damagedElements,
                   function(a, b) return a.missinghp > b.missinghp end)
    elseif DamagedSortingMode == 2 then
        table.sort(damagedElements, function(a, b) return a.id < b.id end)
    else
        table.sort(damagedElements,
                   function(a, b) return a.percent < b.percent end)
    end

    -- Sort broken elements descending according to setting
    if BrokenSortingMode == 1 then
        table.sort(brokenElements, function(a, b)
            return a.maxhp > b.maxhp
        end)
    else
        table.sort(brokenElements, function(a, b) return a.id < b.id end)
    end
end

function GenerateDamageData()
    if SimulationActive == true then return end

    local formerTotalShipHP = totalShipHP
    totalShipHP = 0
    totalShipMaxHP = 0
    totalShipIntegrity = 100
    elementsId = {}
    damagedElements = {}
    brokenElements = {}
    ElementCounter = 0
    healthyElements = 0

    elementsIdList = core.getElementIdList()

    for _, id in pairs(elementsIdList) do
        ElementCounter = ElementCounter + 1
        idHP = core.getElementHitPointsById(id) or 0
        idMaxHP = core.getElementMaxHitPointsById(id) or 0

        if SimulationMode then
            SimulationActive = true
            local dice = math.random(0, 10)
            if dice < 2 then
                idHP = 0
            elseif dice >= 2 and dice < 5 then
                idHP = idMaxHP
            else
                idHP = math.random(1, math.ceil(idMaxHP))
            end
        end

        totalShipHP = totalShipHP + idHP
        totalShipMaxHP = totalShipMaxHP + idMaxHP

        idName = core.getElementNameById(id)
        idType = core.getElementTypeById(id)

        -- Is element damaged?
        if idMaxHP > idHP then
            idPos = core.getElementPositionById(id)
            if idHP > 0 then
                table.insert(damagedElements, {
                    id = id,
                    name = idName,
                    type = idType,
                    counter = ElementCounter,
                    hp = idHP,
                    maxhp = idMaxHP,
                    missinghp = idMaxHP - idHP,
                    percent = math.ceil(100 / idMaxHP * idHP),
                    pos = idPos
                })
                -- if DebugMode then PrintDebug("Damaged: "..idName.." --- Type: "..idType.."") end
                -- Is element broken?
            else
                table.insert(brokenElements, {
                    id = id,
                    name = idName,
                    type = idType,
                    counter = ElementCounter,
                    hp = idHP,
                    maxhp = idMaxHP,
                    missinghp = idMaxHP - idHP,
                    percent = 0,
                    pos = idPos
                })
                -- if DebugMode then PrintDebug("Broken: "..idName.." --- Type: "..idType.."") end
            end
        else
            healthyElements = healthyElements + 1
            if id == highlightID then
                highlightID = 0
            end
        end
    end

    -- Sort tables by current settings    
    SortTables()

    -- Update clickAreas

    -- Determine total ship integrity
    totalShipIntegrity = string.format("%2.0f",
                                       100 / totalShipMaxHP * totalShipHP)

    -- Has anything changes since last check? If yes, force redrawing the screens
    if formerTotalShipHP ~= totalShipHP then
        forceRedraw = true
        formerTotalShipHP = totalShipHP
    else
        forceRedraw = false
    end
end

function GetAllSystemsNominalBackground()
    local output = ""
    output = output .. [[<g>
    <g>
      <path d="M53.44,153.77H42.76a106.89,106.89,0,0,0,93.12,103.29V246.28C90.47,239.59,54.84,200,53.44,153.77Z" transform="translate(-1.55 -10.19)" style="fill: #39b54a"/>
      <path d="M256.79,153.77H246.1c-1.39,46.23-36.76,85.82-82.17,92.51v10.78C214.68,250.4,255.37,206.61,256.79,153.77Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
      <path d="M42.76,147.09H53.44c1.4-46.23,37-85.82,82.44-92.51V43.8A106.89,106.89,0,0,0,42.76,147.09Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
      <path d="M246.1,147.09h10.69c-1.42-52.84-42.11-96.63-92.86-103.29V54.58C209.34,61.27,244.7,100.86,246.1,147.09Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
      <rect x="148.06" y="46.11" width="3.56" height="6.08" transform="translate(99.15 188.8) rotate(-90)" style="fill: #fff;opacity: 0.30000000000000004"/>
      <rect x="148.06" y="249.01" width="3.56" height="6.08" transform="translate(-103.76 391.7) rotate(-90)" style="fill: #fff;opacity: 0.30000000000000004"/>
    </g>
    <g>
      <path d="M42.19,252.92l13.59-13.51c-1.63-1.74-3.2-3.56-4.73-5.4l-6.51,6.47a128.44,128.44,0,0,1-32.63-80h9.23c-.18-2.4-.32-4.81-.37-7.23H1.55A148.7,148.7,0,0,0,42.19,252.92Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
      <path d="M42.19,47.69,55.78,61.15c-1.63,1.75-3.2,3.55-4.73,5.39l-6.51-6.45a127.9,127.9,0,0,0-32.63,79.75h9.23c-.18,2.39-.32,4.79-.37,7.21H1.55A148.05,148.05,0,0,1,42.19,47.69Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
      <path d="M257.36,47.69l-13.59,13.5c1.63,1.75,3.2,3.56,4.73,5.4L255,60.12a128.37,128.37,0,0,1,32.62,80h-9.22c.18,2.4.32,4.8.37,7.22H298A148.67,148.67,0,0,0,257.36,47.69Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
      <path d="M257.36,254.84l-13.59-13.47c1.63-1.74,3.2-3.55,4.73-5.38l6.51,6.45a127.83,127.83,0,0,0,32.62-79.76h-9.22c.18-2.39.32-4.79.37-7.2H298A148.07,148.07,0,0,1,257.36,254.84Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
      <g>
        <path d="M53.42,249.89l-.68.68a139.89,139.89,0,0,0,91,40v-1A139,139,0,0,1,53.42,249.89Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
        <path d="M246.33,253.27l-.68-.69a138.82,138.82,0,0,1-90.28,37.13v1A139.78,139.78,0,0,0,246.33,253.27Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
        <path d="M52.78,50.25l.68.68a139,139,0,0,1,90.24-39.7v-1A139.89,139.89,0,0,0,52.78,50.25Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
        <path d="M245.61,48.23l.68-.67a139.77,139.77,0,0,0-90.92-37.37v1A138.86,138.86,0,0,1,245.61,48.23Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
      </g>
    </g>
    <g>
      <g style="opacity: 0.30000000000000004">
        <path d="M233.5,150.76v.05c0,.4,0,.8,0,1.2l-6-.08v-1.12Zm-.34-7.5-6,.54c0-.39-.07-.78-.11-1.16l6-.63Zm-.11,16.24c0,.42-.09.83-.14,1.25l-6-.71c0-.39.09-.77.13-1.15Zm-1.13-24.91L226,135.74c-.07-.38-.15-.75-.23-1.13l5.89-1.25C231.76,133.77,231.84,134.18,231.92,134.59Zm-.22,33.57-.27,1.23-5.87-1.34.24-1.13Zm-1.92-42.07L224,127.86c-.11-.37-.23-.74-.35-1.1l5.73-1.86C229.53,125.29,229.66,125.69,229.78,126.09Zm-.34,50.54-.39,1.18-5.71-1.93c.13-.37.25-.74.37-1.11Zm-2.68-58.76-5.53,2.37c-.15-.36-.31-.71-.46-1.06l5.49-2.46C226.43,117.1,226.6,117.48,226.76,117.87Zm-.46,66.95c-.17.38-.34.76-.52,1.14l-5.46-2.53.48-1.06ZM222.9,110,217.64,113l-.57-1,5.21-3C222.49,109.29,222.7,109.65,222.9,110Zm-.58,82.61-.63,1.08-5.17-3.09.59-1Zm-4.09-90-4.92,3.48c-.22-.32-.45-.64-.68-1l4.87-3.54C217.75,101.92,218,102.26,218.23,102.6ZM217.55,200l-.74,1-4.83-3.6c.24-.31.47-.63.7-.94ZM212.81,95.72l-4.53,4-.77-.87,4.47-4C212.26,95.09,212.54,95.4,212.81,95.72ZM212,206.79c-.27.31-.55.61-.83.92l-4.43-4.09.79-.86ZM206.71,89.44l-4.09,4.41c-.29-.26-.57-.53-.86-.78l4-4.48C206.1,88.87,206.41,89.15,206.71,89.44ZM205.84,213c-.3.28-.62.55-.93.83l-4-4.53c.29-.26.58-.51.87-.78ZM200,83.81l-3.61,4.83-.94-.7L199,83.07Zm-.94,134.7-1,.72-3.48-4.91.95-.68ZM192.71,78.92l-3.08,5.18-1-.6,3-5.21Zm-1,144.37-1.08.62-2.95-5.25c.34-.19.68-.38,1-.58ZM185,74.83l-2.53,5.46-1.07-.48,2.46-5.5Zm-1.06,152.45-1.14.5-2.37-5.53,1.06-.47ZM176.82,71.56l-1.93,5.7-1.11-.37,1.86-5.73Zm-1.08,158.87-1.19.38-1.78-5.75,1.11-.36ZM168.4,69.17,167.06,75l-1.13-.25,1.24-5.89ZM167.28,232.7l-1.22.25L164.89,227l1.14-.23Zm-7.52-165-.7,6-1.16-.13.61-6Zm-1.13,166.39c-.42.05-.83.09-1.25.12l-.54-6,1.16-.12ZM151,67.1l-.08,6h-1.38v-6H151Zm-1.14,167.43h-1.25l.09-6h1.05ZM142.61,73.44c-.39,0-.78.07-1.16.12l-.64-6,1.24-.13Zm-.86,154.67-.61,6-1.25-.14.71-6ZM134.56,74.6l-1.14.24L132.16,69l1.22-.26Zm-.84,152.25-1.24,5.9-1.22-.27,1.32-5.87Zm-7-150.25-1.11.36-1.87-5.73,1.19-.38Zm-.82,148.17L124,230.5l-1.2-.4,1.94-5.7Zm-6.8-145.35-1.06.47-2.46-5.5,1.14-.5Zm-.79,142.44-2.45,5.5-1.14-.51,2.53-5.47ZM111.78,83l-1,.58-3-5.21,1.08-.62ZM111,218.17l-3,5.22c-.37-.21-.73-.42-1.08-.64l3.08-5.17Zm-6.11-130.8L104,88l-3.56-4.85,1-.74Zm-.72,126.37-3.53,4.88-1-.75,3.62-4.81ZM98.53,92.41c-.3.25-.58.51-.87.77l-4-4.47.94-.83Zm-.67,116.22-4,4.48-.92-.84L97,207.85ZM92.7,98.09l-.78.85-4.48-4,.85-.93Zm-.59,104.8-4.47,4c-.28-.31-.56-.62-.83-.94l4.52-4ZM87.5,104.34l-.69.93-4.87-3.53c.24-.34.49-.68.74-1ZM87,196.58l-4.87,3.55-.73-1,4.92-3.48ZM83,111.1c-.2.33-.4.66-.59,1l-5.22-3c.21-.36.42-.72.64-1.08Zm-.45,78.67-5.21,3c-.21-.36-.41-.72-.61-1.09L82,188.77Zm-3.34-71.48c-.17.35-.33.71-.48,1.06l-5.51-2.44c.17-.38.34-.76.52-1.14Zm-.37,64.25L73.33,185c-.17-.38-.34-.76-.5-1.14l5.53-2.38C78.51,181.84,78.67,182.19,78.82,182.54Zm-2.65-56.69c-.12.36-.25.73-.37,1.1l-5.73-1.84c.13-.4.26-.8.4-1.2ZM75.9,175l-5.72,1.88c-.13-.4-.26-.8-.38-1.2l5.75-1.78C75.66,174.23,75.78,174.6,75.9,175ZM74,133.67c-.08.38-.17.76-.25,1.14l-5.89-1.23c.08-.41.17-.82.26-1.23Zm-.18,33.45-5.89,1.25c-.09-.4-.17-.81-.25-1.22l5.9-1.17ZM72.6,141.69l-.12,1.15-6-.61c0-.41.08-.83.13-1.24Zm-.09,17.4-6,.63-.12-1.24,6-.55C72.43,158.32,72.47,158.7,72.51,159.09Zm-.43-9.29c0,.34,0,.68,0,1V151h-6v-.16c0-.36,0-.72,0-1.08Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
      </g>
      <path d="M214,150.43a62,62,0,0,1-1.74,14.45h25.38a84.15,84.15,0,0,0,0-28.9H212.29A62,62,0,0,1,214,150.43Z" transform="translate(-1.55 -10.19)" style="fill: none"/>
      <path d="M60.63,150.43A85.14,85.14,0,0,1,61.88,136H59.43a86.89,86.89,0,0,0,0,28.9h2.45A85.14,85.14,0,0,1,60.63,150.43Z" transform="translate(-1.55 -10.19)" style="fill: #fff;opacity: 0.30000000000000004"/>
      <g>
        <path d="M149.77,239.28a88.72,88.72,0,0,1-87.23-70.79H60.07a91.56,91.56,0,0,0,179.4,0H237A88.72,88.72,0,0,1,149.77,239.28Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
        <path d="M149.77,59.17a91.28,91.28,0,0,0-89.7,73.2h2.47a89.15,89.15,0,0,1,174.47,0h2.46A91.26,91.26,0,0,0,149.77,59.17Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
      </g>
      <path d="M238.92,150.43a85.14,85.14,0,0,1-1.25,14.45h2.45a87.6,87.6,0,0,0,0-28.9h-2.45A85.14,85.14,0,0,1,238.92,150.43Z" transform="translate(-1.55 -10.19)" style="fill: #fff;opacity: 0.30000000000000004"/>
      <path d="M150,81.42a59.07,59.07,0,0,1,15.66,2V80.66a64.13,64.13,0,0,0-31.31,0v2.77A59,59,0,0,1,150,81.42Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
      <path d="M165.61,220.61v-2.76a62.27,62.27,0,0,1-31.31,0v2.76a64.13,64.13,0,0,0,31.31,0Z" transform="translate(-1.55 -10.19)" style="fill: #0a0"/>
      <path d="M219.1,150.64c0,31-21,57.33-48.67,66.1v2.8c28.9-8.86,51.37-36.39,51.37-68.9s-22.47-60-51.37-68.91v2.8C198.12,93.3,219.1,119.62,219.1,150.64Z" transform="translate(-1.55 -10.19)" style="fill: #fff;opacity: 0.30000000000000004"/>
      <path d="M80.8,150.64c0-31,21-57.34,48.68-66.11v-2.8c-28.9,8.86-51.37,36.39-51.37,68.91s22.47,60,51.37,68.9v-2.8C101.78,208,80.8,181.65,80.8,150.64Z" transform="translate(-1.55 -10.19)" style="fill: #fff;opacity: 0.30000000000000004"/>
    </g>
    <g>
      <g>
        <g style="opacity: 0.30000000000000004">
          <path d="M187.86,269.7l1.71-.15V267l-2.12.27a136.63,136.63,0,0,1-26.5,4.77v2.44A141.27,141.27,0,0,0,187.86,269.7Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
          <path d="M112.18,267.29l-2.13-.27v2.53l1.72.15a141.27,141.27,0,0,0,26.91,4.8v-2.44A136.63,136.63,0,0,1,112.18,267.29Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
          <path d="M111.77,31.16l-1.72.15v2.53l2.13-.27a137.39,137.39,0,0,1,26.5-4.77V26.36A141.27,141.27,0,0,0,111.77,31.16Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
          <path d="M187.45,33.57l2.12.27V31.31l-1.71-.15A141.27,141.27,0,0,0,161,26.36V28.8A137.39,137.39,0,0,1,187.45,33.57Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
        </g>
        <g>
          <path d="M146.63,272.35v1.53l2.39,0,2.38,0v-1.53h-4.77Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
          <path d="M146.63,26.71v1.53h4.77V26.71l-2.38,0Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
        </g>
      </g>
      <g>
        <path d="M271.12,181h-.88a126.46,126.46,0,0,1-69.53,84v.92A129.61,129.61,0,0,0,271.12,181Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
        <path d="M29.25,181h-.88c9.63,38.16,37.15,69.48,70.55,84.87v-.92A126.62,126.62,0,0,1,29.25,181Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
        <path d="M270.35,119h.87c-9.54-38.17-37.12-67.24-70.51-82.67v1.17C234.1,53.07,260.86,82.37,270.35,119Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
        <path d="M28.27,119h.87c9.49-36.58,36.38-65.88,69.78-81.5V36.28C65.52,51.71,37.82,80.78,28.27,119Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
      </g>
      <g>
        <path d="M39.52,150.55a110.76,110.76,0,0,1,1.73-19.31c-.24-.26-.48-.54-.71-.83a110,110,0,0,0,0,40.28,10.31,10.31,0,0,1,.73-.75A109.68,109.68,0,0,1,39.52,150.55Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
        <path d="M258.24,131.35a107.85,107.85,0,0,1,0,38.59,8.69,8.69,0,0,1,.75.61,109.09,109.09,0,0,0,0-39.85A9.05,9.05,0,0,1,258.24,131.35Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
      </g>
      <g>
        <path d="M31.66,150.55a118.63,118.63,0,0,1,1.85-20.69c-.26-.28-.52-.57-.76-.88a117.32,117.32,0,0,0,0,43.14c.24-.27.5-.54.77-.8A118.5,118.5,0,0,1,31.66,150.55Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
        <path d="M266,130a116.09,116.09,0,0,1,0,41.34c.28.21.55.43.8.66a116.68,116.68,0,0,0,0-42.7C266.52,129.53,266.26,129.76,266,130Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
      </g>
      <g style="opacity: 0.30000000000000004">
        <rect x="25.83" y="176.23" width="17.38" height="0.55" transform="translate(-116.25 65.92) rotate(-45)" style="fill: #fff"/>
      </g>
      <g style="opacity: 0.30000000000000004">
        <rect x="34.24" y="116.94" width="0.55" height="17.38" transform="translate(-80.28 51.02) rotate(-45)" style="fill: #fff"/>
      </g>
      <g style="opacity: 0.30000000000000004">
        <path d="M259,132.05a.27.27,0,0,1-.2-.08.29.29,0,0,1,0-.39l12.29-12.28a.27.27,0,0,1,.39,0,.26.26,0,0,1,0,.38L259.18,132A.24.24,0,0,1,259,132.05Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
      </g>
      <g style="opacity: 0.30000000000000004">
        <path d="M271.28,182.92a.27.27,0,0,1-.2-.08l-12.29-12.29a.28.28,0,0,1,0-.38.27.27,0,0,1,.39,0l12.29,12.28a.27.27,0,0,1,0,.39A.24.24,0,0,1,271.28,182.92Z" transform="translate(-1.55 -10.19)" style="fill: #fff"/>
      </g>
    </g>
  </g>]]
    return output
end

function GetDRLogo()
    output =
        [[<defs><style>.a{fill:#fff;}.b{fill:red;}</style></defs><path class="a" d="M8.94,1.94c3,0,5.35.84,6.94,2.54s2.37,4.3,2.37,7.81-.79,6.09-2.37,7.78S12,22.61,8.94,22.61H1.65A1.5,1.5,0,0,1-.07,20.93V3.62A1.5,1.5,0,0,1,1.65,1.94ZM3.55,18.63c0,.25.13.37.39.37h5a5.41,5.41,0,0,0,4.35-1.59c.9-1.07,1.35-2.78,1.35-5.15s-.45-4.08-1.34-5.13S11,5.55,8.94,5.55h-5c-.26,0-.39.12-.39.37Z" transform="translate(0.07 -1.57)"/><path class="a" d="M23.34,22.61h-4c2.91-7.35,4.36-11,7.26-18.38a3.88,3.88,0,0,1,1.64-2.06A5.46,5.46,0,0,1,31,1.57a5.34,5.34,0,0,1,2.68.6,3.71,3.71,0,0,1,1.61,2.06c2.8,7.36,4.19,11,7,18.38h-4C35.71,16,34.46,12.63,31.94,6a1,1,0,0,0-1-.7,1.05,1.05,0,0,0-1,.7Z" transform="translate(0.07 -1.57)"/><path class="a" d="M48.85,22.61H45.27V6.19a4.66,4.66,0,0,1,1.22-3.35,5,5,0,0,1,3.74-1.27,5.29,5.29,0,0,1,3.49,1.06,5.19,5.19,0,0,1,1.72,3c1.16,5.06,1.75,7.59,2.91,12.65a1.32,1.32,0,0,0,1.38,1.17,1.36,1.36,0,0,0,1.38-1.17C62.27,13.23,62.85,10.7,64,5.64a5.33,5.33,0,0,1,1.64-3A5,5,0,0,1,69.1,1.57a5,5,0,0,1,3.74,1.27,4.62,4.62,0,0,1,1.22,3.35V22.61H70.48V6.38a1.28,1.28,0,0,0-.38-1A1.59,1.59,0,0,0,69,5.06a1.47,1.47,0,0,0-1,.29,1.48,1.48,0,0,0-.46.81c-1.19,5.06-1.78,7.59-3,12.66A6.1,6.1,0,0,1,63,21.92,4.62,4.62,0,0,1,59.7,23a4.86,4.86,0,0,1-3.36-1.07,5.88,5.88,0,0,1-1.64-3.09c-1.17-5.07-1.76-7.6-2.94-12.66a1.5,1.5,0,0,0-.47-.81,1.52,1.52,0,0,0-1-.29,1.54,1.54,0,0,0-1.08.35,1.25,1.25,0,0,0-.39,1Z" transform="translate(0.07 -1.57)"/><path class="a" d="M81.11,22.61h-4L84.39,4.23A3.84,3.84,0,0,1,86,2.17a6.35,6.35,0,0,1,5.39,0A3.75,3.75,0,0,1,93,4.23c2.79,7.36,4.19,11,7,18.38H96L89.72,6a1,1,0,0,0-1-.7,1.05,1.05,0,0,0-1,.7C85,12.63,83.73,16,81.11,22.61Z" transform="translate(0.07 -1.57)"/><path class="a" d="M118.94,1.94V5.55h-8.51a5.48,5.48,0,0,0-4.37,1.58q-1.36,1.58-1.36,5.16t1.35,5.13c.89,1,2.35,1.58,4.38,1.58h3.43a2.71,2.71,0,0,0,2.2-.81,3.17,3.17,0,0,0,.68-2.1,2.79,2.79,0,0,0-.63-1.95,2.47,2.47,0,0,0-1.92-.69H109.6V10.3h5a5.16,5.16,0,0,1,4.14,1.58A6.33,6.33,0,0,1,120,16.15a8.64,8.64,0,0,1-.35,2.53,5.28,5.28,0,0,1-1.13,2.05,5.54,5.54,0,0,1-2,1.38,7.63,7.63,0,0,1-3,.5h-3.18q-4.55,0-6.94-2.55t-2.41-7.77q0-5.23,2.41-7.8t6.94-2.55Z" transform="translate(0.07 -1.57)"/><path class="a" d="M140.69,1.94V5.55H130.34a3.36,3.36,0,0,0-2.39.71,2.51,2.51,0,0,0-.74,1.9c0,1.63,1,2.45,3.16,2.45h10.17v3.27H130.28c-2.11,0-3.16.84-3.16,2.52a2.45,2.45,0,0,0,.77,1.91,3.43,3.43,0,0,0,2.36.69h10.47v3.61H130.25a10.24,10.24,0,0,1-3.14-.42A6.06,6.06,0,0,1,125,21a4.34,4.34,0,0,1-1.22-1.8,6.3,6.3,0,0,1-.39-2.23,5.34,5.34,0,0,1,.77-3,4.8,4.8,0,0,1,2.2-1.79,4.57,4.57,0,0,1-2.91-4.66,6.39,6.39,0,0,1,.4-2.26,4.59,4.59,0,0,1,1.24-1.8,5.89,5.89,0,0,1,2.15-1.16,10.31,10.31,0,0,1,3.14-.41Z" transform="translate(0.07 -1.57)"/><path class="b" d="M156.56,1.94a8,8,0,0,1,3,.5,5.9,5.9,0,0,1,2.07,1.35,5.13,5.13,0,0,1,1.19,2,7.15,7.15,0,0,1,.39,2.35,8,8,0,0,1-.25,2,6.56,6.56,0,0,1-.76,1.81,5.63,5.63,0,0,1-3.37,2.46c1.92,3.31,2.88,5,4.81,8.27h-4c-1.88-3.19-2.83-4.79-4.71-8h-5.4a.46.46,0,0,0-.52.52v7.47h-3.61V14.43a3.46,3.46,0,0,1,.76-2.51,3.42,3.42,0,0,1,2.49-.76h8.05a3.14,3.14,0,0,0,1.32-.25,2.49,2.49,0,0,0,.89-.64,2.74,2.74,0,0,0,.5-.92,3.24,3.24,0,0,0,.17-1.07,2.87,2.87,0,0,0-.69-1.92,2.72,2.72,0,0,0-2.19-.81H145.35V1.94Z" transform="translate(0.07 -1.57)"/><path class="b" d="M183.79,1.94V5.55H173.44a3.38,3.38,0,0,0-2.39.71,2.51,2.51,0,0,0-.74,1.9c0,1.63,1.06,2.45,3.16,2.45h10.17v3.27H173.38c-2.11,0-3.16.84-3.16,2.52a2.45,2.45,0,0,0,.77,1.91,3.43,3.43,0,0,0,2.36.69h10.47v3.61H173.35a10.24,10.24,0,0,1-3.14-.42A6.06,6.06,0,0,1,168.06,21a4.34,4.34,0,0,1-1.22-1.8,6.3,6.3,0,0,1-.39-2.23,5.34,5.34,0,0,1,.77-3,4.85,4.85,0,0,1,2.2-1.79,4.57,4.57,0,0,1-2.91-4.66,6.39,6.39,0,0,1,.4-2.26,4.59,4.59,0,0,1,1.24-1.8,6,6,0,0,1,2.15-1.16,10.31,10.31,0,0,1,3.14-.41Z" transform="translate(0.07 -1.57)"/><path class="b" d="M199.05,1.94a8,8,0,0,1,3,.5,5.9,5.9,0,0,1,2.07,1.35,5.13,5.13,0,0,1,1.19,2,7.14,7.14,0,0,1,.38,2.35,7.79,7.79,0,0,1-.35,2.33,5.64,5.64,0,0,1-1.15,2.09,6.07,6.07,0,0,1-2.06,1.5,7.36,7.36,0,0,1-3.08.58h-6.44a.46.46,0,0,0-.52.52v7.47h-3.61V14.43a3.46,3.46,0,0,1,.76-2.51,3.42,3.42,0,0,1,2.49-.76h7.44a3.14,3.14,0,0,0,1.32-.25,2.58,2.58,0,0,0,.89-.64,2.84,2.84,0,0,0,.5-.9,3.41,3.41,0,0,0,.17-1.06,2.91,2.91,0,0,0-.69-1.95,2.68,2.68,0,0,0-2.16-.81H188.45V1.94Z" transform="translate(0.07 -1.57)"/><path class="b" d="M220.7,1.94c3,0,5.34.85,6.94,2.57s2.41,4.32,2.41,7.81-.8,6.06-2.41,7.75-3.91,2.54-6.94,2.54h-2.81c-3,0-5.34-.84-6.94-2.54s-2.41-4.28-2.41-7.75.8-6.09,2.41-7.81,3.91-2.57,6.94-2.57Zm-2.81,3.61a5.45,5.45,0,0,0-4.37,1.59c-.91,1.07-1.36,2.79-1.36,5.18s.45,4.08,1.35,5.12S215.86,19,217.89,19h2.81A5.44,5.44,0,0,0,225,17.42q1.36-1.58,1.36-5.13c0-2.37-.45-4.08-1.35-5.15s-2.34-1.59-4.35-1.59Z" transform="translate(0.07 -1.57)"/><path class="b" d="M245.46,1.94a8,8,0,0,1,3,.5,5.9,5.9,0,0,1,2.07,1.35,5.13,5.13,0,0,1,1.19,2,7.14,7.14,0,0,1,.38,2.35,8,8,0,0,1-.24,2,6.59,6.59,0,0,1-.77,1.81,5.51,5.51,0,0,1-1.34,1.48,5.82,5.82,0,0,1-2,1l4.81,8.27h-4l-4.72-8h-5.39a.46.46,0,0,0-.52.52v7.47h-3.61V14.43a3.46,3.46,0,0,1,.76-2.51,3.41,3.41,0,0,1,2.48-.76h8.06a3.14,3.14,0,0,0,1.32-.25,2.45,2.45,0,0,0,.88-.64,2.59,2.59,0,0,0,.51-.92,3.52,3.52,0,0,0,.17-1.07,2.87,2.87,0,0,0-.69-1.92,2.72,2.72,0,0,0-2.19-.81H234.24V1.94Z" transform="translate(0.07 -1.57)"/><path class="b" d="M269.87,1.94V5.55h-6V22.61h-3.65V5.55h-6V1.94Z" transform="translate(0.07 -1.57)"/>]]
    return output
end

function GenerateHUDOutput()

    local hudWidth = 300
    local hudHeight = 125
    if #damagedElements > 0 or #brokenElements > 0 then hudHeight = 780 end
    local screenHeight = 1080

    local healthyColor = "#00aa00"
    local brokenColor = "#aa0000"
    local damagedColor = "#aaaa00"
    local integrityColor = "#aaaaaa"
    local healthyTextColor = "white"
    local brokenTextColor = "#ff4444"
    local damagedTextColor = "#ffff44"
    local integrityTextColor = "white"

    if #damagedElements == 0 then
        damagedColor = "#aaaaaa"
        damagedTextColor = "white"
    end
    if #brokenElements == 0 then
        brokenColor = "#aaaaaa"
        brokenTextColor = "white"
    end

    local hudOutput = ""

    -- Draw Header
    hudOutput = hudOutput .. [[<svg style="position:absolute;top:]] ..
                    (math.ceil(screenHeight / 2 - hudHeight / 2)) ..
                    [[;left:0;" class="bootstrap" viewBox="0 0 ]] .. hudWidth ..
                    [[ ]] .. hudHeight .. [[" width="]] .. hudWidth ..
                    [[" height="]] .. hudHeight .. [[">
            <defs><style>
                  .fhudM1 { font-size: 18px; font-weight:bold; fill: black; text-anchor: middle}
                  .fhudM2 { font-size: 15px; font-weight:bold; fill: white; text-anchor: middle}
                  .fhudM3 { font-size: 12px; fill: #4e4e4e; text-anchor: start}
                  .fhudM4 { font-size: 18px; fill: #00aa00; text-anchor: middle}
                  .fmstartsmall { font-size: 15px; font-weight: bold; text-anchor: start; fill:black}
                  .fmstartsmally { font-size: 15px; text-anchor: start; fill:yellow}
                  .fmendsmall { font-size: 15px; font-weight: bold; text-anchor: end; fill: black } 
                  .fmendsmally { font-size: 15px; text-anchor: end; fill: yellow}
                  .fmstartsmallr { font-size: 15px; text-anchor: start; fill: red}
                  .fmendsmallr { font-size: 15px; text-anchor: end; fill: red}
            </style></defs>]]

    hudOutput = hudOutput .. [[<rect x="0" y="0" rx="10" ry="10" width="]] ..
                    hudWidth .. [[" height="]] .. hudHeight ..
                    [[" style="fill: #1e1e1e;opacity: 0.8;"/>]] ..
                    [[<svg x="20" y="15">]] .. GetDRLogo() .. [[</svg>]]

    hudOutput = hudOutput .. [[<svg x="0" y="40">
                <rect x="10" y="5" rx="5" ry="5" width="80" height="20" style="fill: ]] ..
                    healthyColor .. [[; stroke: #1e1e1e; stroke-width:1;"/>
                <text x="50" y="21" class="fhudM1">]] .. healthyElements ..
                    [[</text>
                <rect x="115" y="5" rx="5" ry="5" width="80" height="20" style="fill: ]] ..
                    damagedColor .. [[; stroke: #1e1e1e; stroke-width:1;"/>
                <text x="155" y="21" class="fhudM1">]] .. #damagedElements ..
                    [[</text>
                <rect x="215" y="5" rx="5" ry="5" width="80" height="20" style="fill: ]] ..
                    brokenColor .. [[; stroke: #1e1e1e; stroke-width:1;"/>
                <text x="255" y="21" class="fhudM1">]] .. #brokenElements ..
                    [[</text>]]
    if #damagedElements > 0 or #brokenElements > 0 then
        hudOutput = hudOutput ..
                        [[<rect x="10" y="31" rx="5" ry="5" width="285" height="20" style="fill: #6e6e6e; stroke: #1e1e1e; stroke-width:1;"/> ]] ..
                        [[<text x="150" y="46" class="fhudM2">]] ..
                        GenerateCommaValue(
                            string.format("%.0f", totalShipMaxHP - totalShipHP)) ..
                        [[ HP damage in total</text>]]
    else
        hudOutput = hudOutput .. [[<text x="150" y="46" class="fhudM4">]] ..
                        OkayCenterMessage .. [[</text>]] ..
                        [[<text x="150" y="66" class="fhudM4">Ship stands ]] ..
                        GenerateCommaValue(string.format("%.0f", totalShipMaxHP)) ..
                        [[ HP strong.</text>]]

    end
    hudOutput = hudOutput .. [[</svg>]]

    hudRowDistance = 25
    if #damagedElements > 0 then
        local damagedElementsToDraw = #damagedElements
        if damagedElementsToDraw > 12 then damagedElementsToDraw = 12 end
        if CurrentDamagedPage == math.ceil(#damagedElements / 12) then
            damagedElementsToDraw = #damagedElements % 12
        end
        local i = 0
        hudOutput = hudOutput .. [[<svg x="0" y="100">]] ..
                        [[<rect x="0" y="6" rx="0" ry="0" width="]] .. hudWidth ..
                        [[" height="300" style="fill: yellow;opacity: 0.05;"/>]]

        for j = 1 + (CurrentDamagedPage - 1) * 12, damagedElementsToDraw +
            (CurrentDamagedPage - 1) * 12, 1 do
            i = i + 1
            local DP = damagedElements[j]
            if (hudSelectedType == 1 and hudSelectedIndex == i) then
                hudOutput = hudOutput .. [[<rect x="0" y="]] ..
                                (i * hudRowDistance - 19) ..
                                [[" rx="0" ry="0" width="300" height="26" style="fill: yellow;"/>]]
                if UseMyElementNames == true then
                    hudOutput = hudOutput .. [[<text x="15" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmstartsmall">]] ..
                                    string.format("%.32s", DP.name) ..
                                    [[</text>]]
                else
                    hudOutput = hudOutput .. [[<text x="15" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmstartsmall">]] ..
                                    string.format("%.32s", DP.type) ..
                                    [[</text>]]
                end
                if (DamagedSortingMode == 3) then
                    hudOutput = hudOutput .. [[<text x="295" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmendsmall">]] .. DP.percent ..
                                    [[%</text>]]
                else
                    hudOutput = hudOutput .. [[<text x="295" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmendsmall">]] ..
                                    GenerateCommaValue(
                                        string.format("%.0f", DP.missinghp)) ..
                                    [[</text>]]
                end
            else
                if UseMyElementNames == true then
                    hudOutput = hudOutput .. [[<text x="15" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmstartsmally">]] ..
                                    string.format("%.32s", DP.name) ..
                                    [[</text>]]
                else
                    hudOutput = hudOutput .. [[<text x="15" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmstartsmally">]] ..
                                    string.format("%.32s", DP.type) ..
                                    [[</text>]]
                end
                if (DamagedSortingMode == 3) then
                    hudOutput = hudOutput .. [[<text x="295" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmendsmally">]] .. DP.percent ..
                                    [[%</text>]]
                else
                    hudOutput = hudOutput .. [[<text x="295" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmendsmally">]] ..
                                    GenerateCommaValue(
                                        string.format("%.0f", DP.missinghp)) ..
                                    [[</text>]]
                end
                hudOutput = hudOutput .. [[<line x1="0" x2="300" y1="]] ..
                                (7 + i * hudRowDistance) .. [[" y2="]] ..
                                (5 + i * hudRowDistance) ..
                                [[" style="stroke:#797953;" />]]
            end
        end
        hudOutput = hudOutput .. [[</svg>]]
    end

    if #brokenElements > 0 then
        local brokenElementsToDraw = #brokenElements
        if brokenElementsToDraw > 12 then brokenElementsToDraw = 12 end
        if CurrentbrokenPage == math.ceil(#brokenElements / 12) then
            brokenElementsToDraw = #brokenElements % 12
        end
        local i = 0
        hudOutput = hudOutput .. [[<svg x="0" y="400">]] ..
                        [[<rect x="0" y="6" rx="0" ry="0" width="]] .. hudWidth ..
                        [[" height="300" style="fill: red;opacity: 0.05;"/>]]

        for j = 1 + (CurrentBrokenPage - 1) * 12, brokenElementsToDraw +
            (CurrentBrokenPage - 1) * 12, 1 do
            i = i + 1
            local DP = brokenElements[j]
            if (hudSelectedType == 2 and hudSelectedIndex == i) then
                hudOutput = hudOutput .. [[<rect x="0" y="]] ..
                                (i * hudRowDistance - 19) ..
                                [[" rx="0" ry="0" width="300" height="26" style="fill: red;"/>]]
                if UseMyElementNames == true then
                    hudOutput = hudOutput .. [[<text x="15" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmstartsmall">]] ..
                                    string.format("%.32s", DP.name) ..
                                    [[</text>]]
                else
                    hudOutput = hudOutput .. [[<text x="15" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmstartsmall">]] ..
                                    string.format("%.32s", DP.type) ..
                                    [[</text>]]
                end
                if (brokenSortingMode == 3) then
                    hudOutput = hudOutput .. [[<text x="295" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmendsmall">]] .. DP.percent ..
                                    [[%</text>]]
                else
                    hudOutput = hudOutput .. [[<text x="295" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmendsmall">]] ..
                                    GenerateCommaValue(
                                        string.format("%.0f", DP.missinghp)) ..
                                    [[</text>]]
                end
            else
                if UseMyElementNames == true then
                    hudOutput = hudOutput .. [[<text x="15" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmstartsmallr">]] ..
                                    string.format("%.32s", DP.name) ..
                                    [[</text>]]
                else
                    hudOutput = hudOutput .. [[<text x="15" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmstartsmallr">]] ..
                                    string.format("%.32s", DP.type) ..
                                    [[</text>]]
                end
                if (brokenSortingMode == 3) then
                    hudOutput = hudOutput .. [[<text x="295" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmendsmallr">]] .. DP.percent ..
                                    [[%</text>]]
                else
                    hudOutput = hudOutput .. [[<text x="295" y="]] ..
                                    (i * hudRowDistance) ..
                                    [[" class="fmendsmallr">]] ..
                                    GenerateCommaValue(
                                        string.format("%.0f", DP.missinghp)) ..
                                    [[</text>]]
                end
                hudOutput = hudOutput .. [[<line x1="0" x2="300" y1="]] ..
                                (5 + i * hudRowDistance) .. [[" y2="]] ..
                                (5 + i * hudRowDistance) ..
                                [[" style="stroke:#795353;" />]]
            end
        end
        hudOutput = hudOutput .. [[</svg>]]
    end

    if #damagedElements or #brokenElements then
        hudOutput = hudOutput .. [[<svg x="0" y="720">]] ..
                        [[<text x="15" y="10" class="fhudM3">Use up/down arrows to select element to find.</text>]] ..
                        [[<text x="15" y="25" class="fhudM3">Use right arrow to deselect.</text>]] ..
                        [[<text x="15" y="40" class="fhudM3">Use left arrow to exit HUD mode.</text>]] ..
                        [[</svg>]]
    end

    hudOutput = hudOutput .. [[</svg>]]

    return hudOutput
end

function DrawScreens()
    if #screens > 0 then

        local healthyColor = "#00aa00"
        local brokenColor = "#aa0000"
        local damagedColor = "#aaaa00"
        local integrityColor = "#aaaaaa"
        local healthyTextColor = "white"
        local brokenTextColor = "#ff4444"
        local damagedTextColor = "#ffff44"
        local integrityTextColor = "white"

        if #damagedElements == 0 then
            damagedColor = "#aaaaaa"
            damagedTextColor = "white"
        end
        if #brokenElements == 0 then
            brokenColor = "#aaaaaa"
            brokenTextColor = "white"
        end

        local screenOutput = ""

        -- Draw Header
        screenOutput = screenOutput ..
                           [[<svg class="bootstrap" viewBox="0 0 1920 1120" width="1920" height="1120">
                <defs><style>
                      .ftitle { font-size: 60px; text-anchor: start;fill: white; }
                      .ftitlew { font-size: 60px; text-anchor: start;fill: red; }
                      .ftitle2 { font-size: 60px; text-anchor: start;fill: #565656; }
                      .ftopmiddle { font-size: 40px; text-anchor: middle;}
                      .ftopend { font-size: 40px; text-anchor: end;}
                      .fcapstart { font-size: 30px; text-anchor: start; fill: white;}
                      .fcapstarthy { font-size: 30px; text-anchor: start; fill: yellow;}
                      .fcapstarthr { font-size: 30px; text-anchor: start; fill: red;}
                      .fcapmiddle { font-size: 30px; text-anchor: middle; fill: white;}
                      .fcapend { font-size: 30px; text-anchor: end; fill: white;}
                      .fmstart { font-size: 25px; text-anchor: start; fill: white;}
                      .fmstartg { font-size: 25px; text-anchor: start; fill: #1e1e1e;}
                      .fmstarty { font-size: 25px; text-anchor: start; fill: #aaaa00;}
                      .fmstartr { font-size: 25px; text-anchor: end; fill: #ff0000;}
                      .fmmiddle { font-size: 25px; text-anchor: middle; fill: white;}
                      .fmmiddleb { font-size: 30px; text-anchor: middle; fill: black;}
                      .fmmiddler { font-size: 30px; text-anchor: middle; fill: red;}
                      .fmend { font-size: 25px; text-anchor: end; fill: white;}
                </style></defs>]]

        -- Draw main background
        screenOutput = screenOutput ..
                           [[<rect width="1920" height="1120" style="fill: #1e1e1e"/>
              <g>
                <path d="M1839.05,206.36H1396.29a10.3,10.3,0,0,1,.34,2.48,9.84,9.84,0,0,1-.29,2.09h442.71c14.15,0,25.67,8.36,25.67,18.65v40.64c0,10.29-11.52,18.65-25.67,18.65H81.41c-14.16,0-25.68-8.36-25.68-18.65V229.58c0-10.29,11.52-18.65,25.68-18.65H1359.35a10.51,10.51,0,0,1-.28-2.09,10.3,10.3,0,0,1,.34-2.48H81.41c-17.65,0-32,10.4-32,23.22v40.64c0,12.82,14.31,23.22,32,23.22H1839.05c17.65,0,32-10.4,32-23.22V229.58C1871,216.76,1856.7,206.36,1839.05,206.36Z" style="fill: #fff"/>
                <path d="M1377.86,202.29a11.78,11.78,0,0,0-3.88.66l-11-8c-83.9-61-83.9-61-202.71-61H73.25v4.57h1087c116.21,0,116.21,0,198.27,59.62l11.06,8a5.07,5.07,0,0,0-.77,2.64c0,3.62,4,6.56,9,6.56s9-2.94,9-6.56S1382.83,202.29,1377.86,202.29Z" style="fill: #fff"/>
                <path d="M1349.79,224H1230.18a4.56,4.56,0,0,0-4.56,4.56V271.2a4.56,4.56,0,0,0,4.56,4.56h119.61a4.56,4.56,0,0,0,4.56-4.56V228.59A4.56,4.56,0,0,0,1349.79,224Zm2.28,47.17a2.28,2.28,0,0,1-2.28,2.28H1230.18a2.28,2.28,0,0,1-2.28-2.28V228.59a2.29,2.29,0,0,1,2.28-2.28h119.61a2.29,2.29,0,0,1,2.28,2.28Z" style="fill: #fff"/>
                <rect x="966.95" y="224.03" width="232.81" height="51.73" rx="4.56" style="fill: ]] ..
                           brokenColor .. [["/>
                <path d="M900.33,224H779.44a4.56,4.56,0,0,0-4.57,4.56V271.2a4.56,4.56,0,0,0,4.57,4.56H900.33a4.56,4.56,0,0,0,4.56-4.56V228.59A4.56,4.56,0,0,0,900.33,224Zm2.28,47.17a2.28,2.28,0,0,1-2.28,2.28H779.44a2.29,2.29,0,0,1-2.29-2.28V228.59a2.29,2.29,0,0,1,2.29-2.28H900.33a2.29,2.29,0,0,1,2.28,2.28Z" style="fill: #fff"/>
                <rect x="516.2" y="224.03" width="232.81" height="51.73" rx="4.56" style="fill: ]] ..
                           damagedColor .. [["/>
                <path d="M449.59,224H330a4.56,4.56,0,0,0-4.56,4.56V271.2a4.56,4.56,0,0,0,4.56,4.56H449.59a4.56,4.56,0,0,0,4.56-4.56V228.59A4.56,4.56,0,0,0,449.59,224Zm2.28,47.17a2.28,2.28,0,0,1-2.28,2.28H330a2.28,2.28,0,0,1-2.28-2.28V228.59a2.29,2.29,0,0,1,2.28-2.28H449.59a2.29,2.29,0,0,1,2.28,2.28Z" style="fill: #fff"/>
                <rect x="66.74" y="224.03" width="232.81" height="51.73" rx="4.56" style="fill: ]] ..
                           healthyColor .. [["/>
                <path d="M1833.79,224H1714.18a4.57,4.57,0,0,0-4.57,4.57v42.6a4.56,4.56,0,0,0,4.57,4.57h119.61a4.56,4.56,0,0,0,4.56-4.57v-42.6A4.57,4.57,0,0,0,1833.79,224Zm2.28,47.17a2.29,2.29,0,0,1-2.28,2.29H1714.18a2.29,2.29,0,0,1-2.28-2.29v-42.6a2.28,2.28,0,0,1,2.28-2.28h119.61a2.29,2.29,0,0,1,2.28,2.28Z" style="fill: #fff"/>
                <path d="M1683.75,271.17c0,2.53-2.51,4.57-5.62,4.57H1402.62c-3.11,0-5.62-2-5.62-4.57v-42.6c0-2.52,2.51-4.57,5.62-4.57h275.51c3.11,0,5.62,2.05,5.62,4.57Z" style="fill: ]] ..
                           integrityColor .. [["/>
              </g>]]

        -- Draw Title and summary
        if SimulationActive == true then
            screenOutput = screenOutput ..
                               [[<text x="70" y="120" class="ftitlew">Simulated Report</text>]]
        else
            screenOutput = screenOutput ..
                               [[<text x="70" y="120" class="ftitle">Damage Report</text>]]
        end
        if YourShipsName == nil or YourShipsName == "" or YourShipsName ==
            "Enter here" then
            screenOutput = screenOutput ..
                               [[<text x="690" y="120" class="ftitle2">SHIP ID ]] ..
                               shipID .. [[</text>]]
        else
            screenOutput = screenOutput ..
                               [[<text x="650" y="120" class="ftitle2">]] ..
                               YourShipsName .. [[</text>]]
        end
        screenOutput = screenOutput .. [[
                 <text x="185" y="263" class="ftopmiddle" fill="black">Healthy</text>
                 <text x="435" y="263" class="ftopend" fill="]] ..
                           healthyTextColor .. [[">]] .. healthyElements ..
                           [[</text>

                 <text x="635" y="263" class="ftopmiddle" fill="black">Damaged</text>
                 <text x="885" y="263" class="ftopend" fill="]] ..
                           damagedTextColor .. [[">]] .. #damagedElements ..
                           [[</text>

                 <text x="1085" y="263" class="ftopmiddle" fill="black">Broken</text>
                 <text x="1335" y="263" class="ftopend" fill="]] ..
                           brokenTextColor .. [[">]] .. #brokenElements ..
                           [[</text>

                 <text x="1545" y="263" class="ftopmiddle" fill="black">Integrity</text>
                 <text x="1825" y="263" class="ftopend" fill="]] ..
                           integrityTextColor .. [[">]] .. totalShipIntegrity ..
                           [[%</text>]]

        -- Draw damage elements

        if #damagedElements > 0 then
            local damagedElementsToDraw = #damagedElements
            if damagedElementsToDraw > 12 then
                damagedElementsToDraw = 12
            end
            if CurrentDamagedPage == math.ceil(#damagedElements / 12) then
                damagedElementsToDraw = #damagedElements % 12
            end
            screenOutput = screenOutput ..
                               [[<rect x="70" y="350" rx="10" ry="10" width="820" height="]] ..
                               ((damagedElementsToDraw + 1) * 50) ..
                               [[" style="fill:#66663f;stroke:#ffff00;stroke-width:3;" />]]
            screenOutput = screenOutput ..
                               [[<rect x="80" y="360" rx="5" ry="5" width="800" height="40" style="fill:#33331a;" />]]
            if (DamagedSortingMode == 2) then
                screenOutput = screenOutput ..
                                   [[<text x="100" y="391" class="fcapstarthy">ID</text>]]
            else
                screenOutput = screenOutput ..
                                   [[<text x="100" y="391" class="fcapstart">ID</text>]]
            end
            if UseMyElementNames == true then
                screenOutput = screenOutput ..
                                   [[<text x="230" y="391" class="fcapstart">Element Name</text>]]
            else
                screenOutput = screenOutput ..
                                   [[<text x="230" y="391" class="fcapstart">Element Type</text>]]
            end

            if (DamagedSortingMode == 3) then
                screenOutput = screenOutput ..
                                   [[<text x="525" y="391" class="fcapstarthy">Health</text>]]
            else
                screenOutput = screenOutput ..
                                   [[<text x="525" y="391" class="fcapstart">Health</text>]]
            end
            if (DamagedSortingMode == 1) then
                screenOutput = screenOutput ..
                                   [[<text x="730" y="391" class="fcapstarthy">Damage</text>]]
            else
                screenOutput = screenOutput ..
                                   [[<text x="730" y="391" class="fcapstart">Damage</text>]]
            end

            local i = 0
            for j = 1 + (CurrentDamagedPage - 1) * 12, damagedElementsToDraw +
                (CurrentDamagedPage - 1) * 12, 1 do
                i = i + 1
                local DP = damagedElements[j]
                screenOutput = screenOutput .. [[<text x="90" y="]] ..
                                   (380 + i * 50) .. [[" class="fmstartg">]] ..
                                   string.format("%03.0f", DP.id) .. [[</text>]]
                if UseMyElementNames == true then
                    screenOutput = screenOutput .. [[<text x="160" y="]] ..
                                       (380 + i * 50) .. [[" class="fmstart">]] ..
                                       string.format("%.25s", DP.name) ..
                                       [[</text>]]
                else
                    screenOutput = screenOutput .. [[<text x="160" y="]] ..
                                       (380 + i * 50) .. [[" class="fmstart">]] ..
                                       string.format("%.25s", DP.type) ..
                                       [[</text>]]
                end
                screenOutput = screenOutput .. [[<text x="605" y="]] ..
                                   (380 + i * 50) .. [[" class="fmend">]] ..
                                   DP.percent .. [[%</text>]] ..
                                   [[<text x="835" y="]] .. (380 + i * 50) ..
                                   [[" class="fmend">]] ..
                                   GenerateCommaValue(
                                       string.format("%.0f", DP.missinghp)) ..
                                   [[</text>]] ..
                                   [[<line x1="160" x2="834" y1="]] ..
                                   (386 + i * 50) .. [[" y2="]] ..
                                   (386 + i * 50) ..
                                   [[" style="stroke:#797953;" />]]
            end
            screenOutput = screenOutput ..
                               [[<line x1="640" x2="480" y1="290" y2="350" style="stroke:#ffff00;" stroke-dasharray="2 5" />
                        <circle cx="640" cy="290" r="10" stroke="#ffff00" stroke-width="3" fill="#66663f" />
                        <circle cx="480" cy="350" r="10" stroke="#ffff00" stroke-width="3" fill="#66663f" />]]

            if #damagedElements > 12 then
                screenOutput = screenOutput ..
                                   [[<text x="70" y="343" class="fmstarty">Page ]] ..
                                   CurrentDamagedPage .. " of " ..
                                   math.ceil(#damagedElements / 12) ..
                                   [[</text>]]

                if CurrentDamagedPage < math.ceil(#damagedElements / 12) then
                    screenOutput = screenOutput .. [[<svg x="70" y="]] ..
                                       (350 + 11 + (damagedElementsToDraw + 1) *
                                           50) .. [[">
                                <rect x="0" y="0" rx="10" ry="10" width="200" height="50" style="fill:#aaaa00;" />
                                <svg x="80" y="15"><path d="M52.48,35.23,69.6,19.4a3.23,3.23,0,0,0-2.19-5.6H32.59a3.23,3.23,0,0,0-2.19,5.6L47.52,35.23A3.66,3.66,0,0,0,52.48,35.23Z" transform="translate(-29.36 -13.8)"/></svg>
                            </svg>]]
                    UpdateClickArea("DamagedPageDown", {
                        id = "DamagedPageDown",
                        x1 = 70,
                        x2 = 270,
                        y1 = 350 + 11 + (damagedElementsToDraw + 1) * 50,
                        y2 = 350 + 11 + 50 + (damagedElementsToDraw + 1) * 50
                    })
                else
                    DisableClickArea("DamagedPageDown")
                end

                if CurrentDamagedPage > 1 then
                    screenOutput = screenOutput .. [[<svg x="280" y="]] ..
                                       (350 + 11 + (damagedElementsToDraw + 1) *
                                           50) .. [[">
                                <rect x="0" y="0" rx="10" ry="10" width="200" height="50" style="fill:#aaaa00;" />
                                <svg x="80" y="15"><path d="M47.52,14.77,30.4,30.6a3.23,3.23,0,0,0,2.19,5.6H67.41a3.23,3.23,0,0,0,2.19-5.6L52.48,14.77A3.66,3.66,0,0,0,47.52,14.77Z" transform="translate(-29.36 -13.8)"/></svg>
                            </svg>]]
                    UpdateClickArea("DamagedPageUp", {
                        id = "DamagedPageUp",
                        x1 = 280,
                        x2 = 480,
                        y1 = 350 + 11 + (damagedElementsToDraw + 1) * 50,
                        y2 = 350 + 11 + 50 + (damagedElementsToDraw + 1) * 50
                    })
                else
                    DisableClickArea("DamagedPageUp")
                end
            end
        end

        -- Draw broken elements
        if #brokenElements > 0 then
            local brokenElementsToDraw = #brokenElements
            if brokenElementsToDraw > 12 then
                brokenElementsToDraw = 12
            end
            if CurrentBrokenPage == math.ceil(#brokenElements / 12) then
                brokenElementsToDraw = #brokenElements % 12
            end
            screenOutput = screenOutput ..
                               [[<rect x="1030" y="350" rx="10" ry="10" width="820" height="]] ..
                               ((brokenElementsToDraw + 1) * 50) ..
                               [[" style="fill:#663f3f;stroke:#ff0000;stroke-width:3;" />]]
            screenOutput = screenOutput ..
                               [[<rect x="1040" y="360" rx="5" ry="5" width="800" height="40" style="fill:#331a1a;" />]]
            if (BrokenSortingMode == 2) then
                screenOutput = screenOutput ..
                                   [[<text x="1060" y="391" class="fcapstarthr">ID</text>]]
            else
                screenOutput = screenOutput ..
                                   [[<text x="1060" y="391" class="fcapstart">ID</text>]]
            end
            if UseMyElementNames == true then
                screenOutput = screenOutput ..
                                   [[<text x="1190" y="391" class="fcapstart">Element Name</text>]]
            else
                screenOutput = screenOutput ..
                                   [[<text x="1190" y="391" class="fcapstart">Element Type</text>]]
            end
            if (BrokenSortingMode == 1) then
                screenOutput = screenOutput ..
                                   [[<text x="1690" y="391" class="fcapstarthr">Damage</text>]]
            else
                screenOutput = screenOutput ..
                                   [[<text x="1690" y="391" class="fcapstart">Damage</text>]]
            end

            local i = 0
            for j = 1 + (CurrentBrokenPage - 1) * 12, brokenElementsToDraw +
                (CurrentBrokenPage - 1) * 12, 1 do
                i = i + 1
                local DP = brokenElements[j]
                screenOutput = screenOutput .. [[<text x="1050" y="]] ..
                                   (380 + i * 50) .. [[" class="fmstartg">]] ..
                                   string.format("%03.0f", DP.id) .. [[</text>]]
                if UseMyElementNames == true then
                    screenOutput = screenOutput .. [[<text x="1120" y="]] ..
                                       (380 + i * 50) .. [[" class="fmstart">]] ..
                                       string.format("%.25s", DP.name) ..
                                       [[</text>]]
                else
                    screenOutput = screenOutput .. [[<text x="1120" y="]] ..
                                       (380 + i * 50) .. [[" class="fmstart">]] ..
                                       string.format("%.25s", DP.type) ..
                                       [[</text>]]
                end
                screenOutput = screenOutput .. [[<text x="1795" y="]] ..
                                   (380 + i * 50) .. [[" class="fmend">]] ..
                                   GenerateCommaValue(
                                       string.format("%.0f", DP.missinghp)) ..
                                   [[</text>]] ..
                                   [[<line x1="1120" x2="1794" y1="]] ..
                                   (386 + i * 50) .. [[" y2="]] ..
                                   (386 + i * 50) ..
                                   [[" style="stroke:#795353;" />]]
            end

            screenOutput = screenOutput ..
                               [[<line x1="1085" x2="1440" y1="290" y2="350" style="stroke:#ff0000;" stroke-dasharray="2 5" />
                            <circle cx="1085" cy="290" r="10" stroke="#ff0000" stroke-width="3" fill="#663f3f" />
                            <circle cx="1440" cy="350" r="10" stroke="#ff0000" stroke-width="3" fill="#663f3f" />]]

            if #brokenElements > 12 then
                screenOutput = screenOutput ..
                                   [[<text x="1854" y="343" class="fmstartr">Page ]] ..
                                   CurrentBrokenPage .. " of " ..
                                   math.ceil(#brokenElements / 12) ..
                                   [[</text>]]

                if CurrentBrokenPage > 1 then
                    screenOutput = screenOutput .. [[<svg x="1442" y="]] ..
                                       (350 + 11 + (brokenElementsToDraw + 1) *
                                           50) .. [[">
                                <rect x="0" y="0" rx="10" ry="10" width="200" height="50" style="fill:#aa0000;" />
                                <svg x="80" y="15"><path d="M47.52,14.77,30.4,30.6a3.23,3.23,0,0,0,2.19,5.6H67.41a3.23,3.23,0,0,0,2.19-5.6L52.48,14.77A3.66,3.66,0,0,0,47.52,14.77Z" transform="translate(-29.36 -13.8)"/></svg>
                            </svg>]]
                    UpdateClickArea("BrokenPageUp", {
                        id = "BrokenPageUp",
                        x1 = 1442,
                        x2 = 1642,
                        y1 = 350 + 11 + (brokenElementsToDraw + 1) * 50,
                        y2 = 350 + 11 + 50 + (brokenElementsToDraw + 1) * 50
                    })
                else
                    DisableClickArea("BrokenPageUp")
                end

                if CurrentBrokenPage < math.ceil(#brokenElements / 12) then
                    screenOutput = screenOutput .. [[<svg x="1652" y="]] ..
                                       (350 + 11 + (brokenElementsToDraw + 1) *
                                           50) .. [[">
                                <rect x="0" y="0" rx="10" ry="10" width="200" height="50" style="fill:#aa0000;" />
                                <svg x="80" y="15"><path d="M52.48,35.23,69.6,19.4a3.23,3.23,0,0,0-2.19-5.6H32.59a3.23,3.23,0,0,0-2.19,5.6L47.52,35.23A3.66,3.66,0,0,0,52.48,35.23Z" transform="translate(-29.36 -13.8)"/></svg>
                            </svg>]]
                    UpdateClickArea("BrokenPageDown", {
                        id = "BrokenPageDown",
                        x1 = 1652,
                        x2 = 1852,
                        y1 = 350 + 11 + (brokenElementsToDraw + 1) * 50,
                        y2 = 350 + 11 + 50 + (brokenElementsToDraw + 1) * 50
                    })
                else
                    DisableClickArea("BrokenPageDown")
                end
            end

        end

        -- Draw damage summary
        if #damagedElements > 0 or #brokenElements > 0 then
            screenOutput = screenOutput ..
                               [[<text x="960" y="1070" class="ftopmiddle" fill="white">]] ..
                               GenerateCommaValue(
                                   string.format("%.0f",
                                                 totalShipMaxHP - totalShipHP)) ..
                               [[ HP damage in total</text>]]
        else
            screenOutput = screenOutput .. [[<svg x="810" y="410">]] ..
                               GetAllSystemsNominalBackground() .. [[</svg>]] ..
                               [[<text x="960" y="750" class="ftopmiddle" fill="#00aa00">]] ..
                               OkayCenterMessage .. [[</text>]] ..
                               [[<text x="960" y="800" class="ftopmiddle" fill="#00aa00">Ship stands ]] ..
                               GenerateCommaValue(
                                   string.format("%.0f", totalShipMaxHP)) ..
                               [[ HP strong.</text>]]
        end

        -- Draw Sim Mode button
        if SimulationMode == true then
            screenOutput = screenOutput ..
                               [[<rect x="1650" y="50" rx="10" ry="10" width="200" height="40" style="fill:#ff6666;" />]] ..
                               [[<text x="1750" y="80" class="fmmiddler">Sim Mode</text>]]

        else
            screenOutput = screenOutput ..
                               [[<rect x="1650" y="50" rx="10" ry="10" width="200" height="40" style="fill:#666666;" />]] ..
                               [[<text x="1750" y="80" class="fmmiddleb">Sim Mode</text>]]
        end

        -- Draw HUD Mode button
        if HUDMode == true then
            screenOutput = screenOutput ..
                               [[<rect x="1650" y="100" rx="10" ry="10" width="200" height="40" style="fill:#ff6666;" />]] ..
                               [[<text x="1750" y="130" class="fmmiddler">HUD Mode</text>]]

        else
            screenOutput = screenOutput ..
                               [[<rect x="1650" y="100" rx="10" ry="10" width="200" height="40" style="fill:#666666;" />]] ..
                               [[<text x="1750" y="130" class="fmmiddleb">HUD Mode</text>]]
        end

        screenOutput = screenOutput .. [[</svg>]]

        if HUDMode == true then
            system.setScreen(GenerateHUDOutput())
            system.showScreen(1)
        else
            system.showScreen(0)
        end

        DrawSVG(screenOutput)

        forceRedraw = false
    end
end

-----------------------------------------------
-- Execute
-----------------------------------------------

unit.hide()
ClearConsole()
PrintDebug("SCRIPT STARTED", true)

InitiateSlots()
SwitchScreens(true)
InitiateClickAreas()

if core == nil then
    DrawCenteredText("ERROR: No core connected.")
    PrintError("ERROR: No core connected.")
    goto exit
else
    shipID = core.getConstructId()
end

GenerateDamageData()
if forceRedraw then DrawScreens() end

unit.setTimer('UpdateData', UpdateInterval)
unit.setTimer('UpdateHighlight', HighlightBlinkingInterval)

::exit::
