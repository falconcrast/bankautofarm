local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
 
local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
 
local FLAMETHROWER_NAME = "[Flamethrower]"
local FLAMETHROWER_AMMO_NAME = "140 [Flamethrower Ammo] - $1126"
local LMG_NAME = "[LMG]"
local LMG_AMMO_NAME = "200 [LMG Ammo] - $338"
local SHOP_PATH = Workspace.Ignored.Shop
 
-- Wait for map to load before resolving paths
task.wait(3)
 
-- Paths (lazy, safe resolution)
local function getVaultDoor()
    local mapModel = Workspace.MAP:FindFirstChild("Map")
    if mapModel then
        local vault = mapModel:FindFirstChild("Vault")
        if vault then
            return vault:FindFirstChild("VaultDoor")
        end
    end
    return Workspace.MAP:FindFirstChild("VaultDoor", true)
        or Workspace:FindFirstChild("VaultDoor", true)
end
 
local VAULTS_CASHIER_PATH = Workspace:FindFirstChild("Cashiers") and Workspace.Cashiers:FindFirstChild("VAULT") and Workspace.Cashiers or Workspace:FindFirstChild("VAULT", true)
 
-- Thresholds
local FT_LOW = 500
local FT_FULL = 1000
local LMG_LOW = 1000
local LMG_FULL = 1500
 
-- Function to teleport to a position
local function teleportTo(targetPosition)
    if character and character.PrimaryPart then
        character:SetPrimaryPartCFrame(CFrame.new(targetPosition + Vector3.new(0, 3, 0)))
        task.wait(0.2)
    end
end
 
-- Persistence: Force re-execution on teleport
if queue_on_teleport then
    local scriptName = "FlamethrowerVaultAttack.lua"
    queue_on_teleport([[
task.wait(15)
if isfile and isfile("]] .. scriptName .. [[") then
loadstring(readfile("]] .. scriptName .. [["))()
else
warn("Auto-load failed: ]] .. scriptName .. [[ not found in executor workspace folder.")
end
]])
end
 
-- Server Hopping Function
local function serverHop()
    print("Finding new server...")
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local PlaceId = game.PlaceId
 
    local servers = {}
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")).data
    end)
 
    if success and result then
        for _, server in pairs(result) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                table.insert(servers, server.id)
            end
        end
    end
 
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], localPlayer)
    else
        print("No other servers found. Trying again in 5s...")
        task.wait(5)
    end
end
 
-- Function to buy an item
local function buyItem(itemName)
    local item = SHOP_PATH:FindFirstChild(itemName)
    if item and item:FindFirstChild("ClickDetector") then
        teleportTo(item:GetModelCFrame().Position)
        task.wait(0.1)
        fireclickdetector(item.ClickDetector)
        return true
    end
    warn("Item not found or ClickDetector missing: " .. itemName)
    return false
end
 
-- Function to get total ammo for a specific weapon (Reserves)
local function getWeaponAmmo(weaponName)
    local playerFolder = localPlayer:FindFirstChild("DataFolder")
    if playerFolder then
        local inventory = playerFolder:FindFirstChild("Inventory")
        if inventory then
            local reserve = inventory:FindFirstChild(weaponName)
            if reserve and (reserve:IsA("StringValue") or reserve:IsA("IntValue")) then
                return tonumber(reserve.Value) or 0
            end
        end
    end
 
    local function deepSearch(parent)
        for _, v in pairs(parent:GetChildren()) do
            if v.Name == weaponName and (v:IsA("StringValue") or v:IsA("IntValue")) then
                return tonumber(v.Value) or 0
            end
            if v.Name ~= "Backpack" and v.Name ~= "Character" then
                local found = deepSearch(v)
                if found then return found end
            end
        end
        return nil
    end
    return deepSearch(localPlayer) or 0
end
 
-- Function to check if reload is needed (Magazine check)
local function needsReload(weaponName)
    local weapon = character:FindFirstChild(weaponName)
    if weapon then
        local clip = weapon:FindFirstChild("Ammo")
        if clip and clip.Value <= 0 then
            return true
        end
    end
    return false
end
 
-- Function to trigger reload (Stabilized Version)
local function reloadWeapon(weaponName)
    local weapon = character:FindFirstChild(weaponName)
    if weapon then
        local ammoVal = weapon:FindFirstChild("Ammo")
        local startAmmo = ammoVal and ammoVal.Value or 0
 
        print("Reloading " .. weaponName .. "...")
 
        pcall(function() weapon:Deactivate() end)
        task.wait(0.1)
 
        game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.R, false, game)
        task.wait(0.05)
        game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.R, false, game)
 
        local totalWait = 0
        while ammoVal and ammoVal.Value <= startAmmo and totalWait < 3 do
            task.wait(0.1)
            totalWait = totalWait + 0.1
        end
 
        task.wait(0.2)
        print("Reload confirmed for " .. weaponName)
    end
end
 
-- Function to equip a specific weapon
local function equipWeapon(weaponName)
    local weapon = localPlayer.Backpack:FindFirstChild(weaponName)
    if weapon then
        humanoid:EquipTool(weapon)
        return true
    end
    return character:FindFirstChild(weaponName) ~= nil
end
 
-- Function to collect cash in a radius (Robust Version)
local function collectCash(radius)
    radius = radius or 30
    local center = character.PrimaryPart.Position
    print("Collecting all cash within " .. radius .. " studs...")
 
    local function getDrops()
        local drops = {}
        local dropFolder = Workspace:FindFirstChild("Ignored") and Workspace.Ignored:FindFirstChild("Drop")
        if dropFolder then
            for _, drop in pairs(dropFolder:GetChildren()) do
                if drop.Name == "MoneyDrop" and drop:FindFirstChild("ClickDetector") then
                    local dist = (center - drop.Position).Magnitude
                    if dist <= radius then
                        table.insert(drops, drop)
                    end
                end
            end
        end
        return drops
    end
 
    local attempts = 0
    while attempts < 3 do
        local currentDrops = getDrops()
        if #currentDrops > 0 then
            attempts = 0
            for _, drop in pairs(currentDrops) do
                pcall(function()
                    if drop and drop.Parent then
                        local detector = drop:FindFirstChild("ClickDetector")
                        if detector then
                            teleportTo(drop.Position)
                            task.wait(0.1)
                            fireclickdetector(detector)
                            task.wait(0.05)
                        end
                    end
                end)
            end
        else
            attempts = attempts + 1
            task.wait(0.5)
        end
    end
    print("Collection pass finished.")
end
 
-- Main Attack Loop
local function startAttack()
    print("Starting Full Vault Raid Sequence...")
 
    while true do
        -- 0. PRE-SCAN: Check for internal vaults first
        local activeVaults = {}
        if VAULTS_CASHIER_PATH then
            for _, v in pairs(VAULTS_CASHIER_PATH:GetChildren()) do
                if v.Name == "VAULT" and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                    table.insert(activeVaults, v)
                end
            end
        end
 
        if #activeVaults > 0 then
            -- Resolve vault door fresh every loop iteration
            local vaultDoor = getVaultDoor()
 
            -- 1. PHASE 1: Flamethrower Vault Door Burn (Only if needed)
            if vaultDoor and vaultDoor.Parent then
                print("Vaults found! Burning door to reach them...")
 
                if not (localPlayer.Backpack:FindFirstChild(FLAMETHROWER_NAME) or character:FindFirstChild(FLAMETHROWER_NAME)) then
                    buyItem("[Flamethrower] - $10130")
                    task.wait(0.5)
                end
 
                local ftReserve = getWeaponAmmo(FLAMETHROWER_NAME)
                if ftReserve < FT_LOW then
                    print("Flamethrower ammo low, restocking...")
                    humanoid:UnequipTools() -- ✅ FIXED: unequip before buying ammo
                    task.wait(0.2)
                    while getWeaponAmmo(FLAMETHROWER_NAME) < FT_FULL do
                        buyItem(FLAMETHROWER_AMMO_NAME)
                        task.wait(0.3)
                    end
                end
 
                if (character.PrimaryPart.Position - vaultDoor.Position).Magnitude > 12 then
                    teleportTo(vaultDoor.Position + Vector3.new(0, 0, 6))
                end
 
                equipWeapon(FLAMETHROWER_NAME)
                local ft = character:FindFirstChild(FLAMETHROWER_NAME)
                if ft then
                    character:SetPrimaryPartCFrame(CFrame.new(character.PrimaryPart.Position, vaultDoor.Position))
                    if needsReload(FLAMETHROWER_NAME) then
                        reloadWeapon(FLAMETHROWER_NAME)
                    else
                        ft:Activate()
                        task.wait(0.8)
                        if ft.Parent then ft:Deactivate() end
                        task.wait(2.5)
                    end
                end
            else
                -- 2. PHASE 2: LMG Vault Raid (Door is already gone)
                if not (localPlayer.Backpack:FindFirstChild(LMG_NAME) or character:FindFirstChild(LMG_NAME)) then
                    buyItem("[LMG] - $4221")
                    task.wait(0.5)
                end
 
                if getWeaponAmmo(LMG_NAME) < LMG_LOW then
                    print("LMG ammo low, unequipping and restocking...")
                    humanoid:UnequipTools()
                    task.wait(0.2)
                    while getWeaponAmmo(LMG_NAME) < LMG_FULL do
                        buyItem(LMG_AMMO_NAME)
                        task.wait(0.3)
                    end
                end
 
                local targetVault = activeVaults[1]
                print("Targeting Vault: " .. targetVault:GetFullName())
 
                if (character.PrimaryPart.Position - targetVault.Head.Position).Magnitude > 10 then
                    teleportTo(targetVault.Head.Position + Vector3.new(0, 0, 4))
                end
 
                equipWeapon(LMG_NAME)
                local lmg = character:FindFirstChild(LMG_NAME)
                if lmg then
                    character:SetPrimaryPartCFrame(CFrame.new(character.PrimaryPart.Position, targetVault.Head.Position))
                    if needsReload(LMG_NAME) then reloadWeapon(LMG_NAME) end
 
                    lmg:Activate()
                    repeat
                        if needsReload(LMG_NAME) then
                            lmg:Deactivate()
                            reloadWeapon(LMG_NAME)
                            lmg:Activate()
                        end
                        task.wait(0.1)
                    until not targetVault:FindFirstChild("Humanoid") or targetVault.Humanoid.Health <= 0 or not targetVault.Parent
                    lmg:Deactivate()
 
                    print("Vault broken! Collecting cash 30 studs...")
                    task.wait(0.5)
                    collectCash(30)
                end
            end
        else
            print("No active vaults found. Hopping to a new server instantly...")
            serverHop()
        end
 
        task.wait(0.1)
    end
end
 
-- Start the script
task.spawn(startAttack)