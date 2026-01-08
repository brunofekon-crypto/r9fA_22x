-- Modules/Combat.lua
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Combat = {}

-- [2] AIMBOT CORE
Combat.AimbotCore = (function()
    local AimbotCore = {}
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    local camera = workspace.CurrentCamera

    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        camera = workspace.CurrentCamera
    end)

    if not getgenv().AimbotFOV then getgenv().AimbotFOV = 100 end

    local isEnabled = false
    local isActive = false
    local fovCircle = nil
    local isDrawingApiAvailable = false

    pcall(function()
        if Drawing then
            fovCircle = Drawing.new("Circle")
            fovCircle.Visible = false
            fovCircle.Thickness = 2
            fovCircle.Color = Color3.fromRGB(255, 255, 255)
            fovCircle.Transparency = 0.5
            fovCircle.Filled = false
            isDrawingApiAvailable = true
        end
    end)

    local function isTargetVisible(targetPart, character)
        local cameraPos = camera.CFrame.Position
        local _, onscreen = camera:WorldToViewportPoint(targetPart.Position)
        if onscreen then
            local ray = Ray.new(cameraPos, targetPart.Position - cameraPos)
            local hitPart = workspace:FindPartOnRayWithIgnoreList(ray, player.Character:GetDescendants())
            if hitPart and hitPart:IsDescendantOf(character) then return true else return false end
        else
            return false
        end
    end

    local function isSameTeam(targetPlayer)
        if not getgenv().TeamCheck then return false end
        if player.Team and targetPlayer.Team then return player.Team == targetPlayer.Team end
        if player.TeamColor and targetPlayer.TeamColor then return player.TeamColor == targetPlayer.TeamColor end
        return false
    end

    local function isTargetInFOV(targetPart)
        local viewportPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then return false end
        local viewportSize = camera.ViewportSize
        local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        local targetPos = Vector2.new(viewportPoint.X, viewportPoint.Y)
        local distance = (targetPos - screenCenter).Magnitude
        local fov = getgenv().AimbotFOV or 100
        return distance <= fov
    end

    local function updateFOVCircle()
        if not fovCircle or not isDrawingApiAvailable then return end
        local viewportSize = camera.ViewportSize
        local fov = getgenv().AimbotFOV or 100
        fovCircle.Visible = isEnabled
        fovCircle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        fovCircle.Radius = fov
    end

    local function findNearestTarget()
        local nearestTarget = nil
        local nearestDistance = math.huge
        for _, targetPlayer in pairs(Players:GetPlayers()) do
            if targetPlayer ~= player then
                pcall(function()
                    local shouldTarget = true
                    if isSameTeam(targetPlayer) then shouldTarget = false end
                    if shouldTarget and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head") and targetPlayer.Character:FindFirstChild("Humanoid") then
                        if not isTargetInFOV(targetPlayer.Character.Head) then return end
                        local distance = (mouse.Hit.Position - targetPlayer.Character.PrimaryPart.Position).magnitude
                        if distance < nearestDistance then
                            if isTargetVisible(targetPlayer.Character.Head, targetPlayer.Character) and targetPlayer.Character.Humanoid.Health > 0 then
                                nearestTarget = targetPlayer
                                nearestDistance = distance
                            end
                        end
                    end
                end)
            end
        end
        return nearestTarget
    end

    function AimbotCore:SetEnabled(enabled)
        isEnabled = enabled
        if not enabled then isActive = false end
        updateFOVCircle()
    end
    function AimbotCore:SetFOV(fov)
        getgenv().AimbotFOV = math.clamp(fov, 20, 500)
        updateFOVCircle()
    end
    function AimbotCore:GetFOV() return getgenv().AimbotFOV or 100 end
    function AimbotCore:IsEnabled() return isEnabled end

    mouse.Button2Down:Connect(function() if isEnabled and getgenv().AimbotInput == "RightClick" then isActive = true end end)
    mouse.Button2Up:Connect(function() if isEnabled and getgenv().AimbotInput == "RightClick" then isActive = false end end)
    mouse.Button1Down:Connect(function() if isEnabled and getgenv().AimbotInput == "LeftClick" then isActive = true end end)
    mouse.Button1Up:Connect(function() if isEnabled and getgenv().AimbotInput == "LeftClick" then isActive = false end end)
    mouse.KeyDown:Connect(function(key) if isEnabled and key == getgenv().AimbotInput:lower() then isActive = true end end)
    mouse.KeyUp:Connect(function(key) if isEnabled and key == getgenv().AimbotInput:lower() then isActive = false end end)

    local currentTarget = nil
    task.spawn(function()
        while true do
            if isEnabled then currentTarget = findNearestTarget() else currentTarget = nil end
            task.wait(0.1)
        end
    end)

    -- Logic for Legit Mode Target Selection
    local activeTargetPart = "Head"
    local lastLockedTarget = nil
    local bodyParts = {
        "Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", 
        "Left Arm", "Right Arm", "Left Leg", "Right Leg",
        "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"
    }

    local function getRandomPart(char)
        if not char then return "Head" end
        -- 40% Chance for Head, 60% Chance for Random Part
        if math.random() <= 0.4 then 
            return "Head" 
        end

        local possible = {}
        for _, name in pairs(bodyParts) do
            if char:FindFirstChild(name) then
                table.insert(possible, name)
            end
        end
        
        if #possible > 0 then
            return possible[math.random(1, #possible)]
        else
            return "Head"
        end
    end

    RunService.RenderStepped:Connect(function()
        if isActive and isEnabled and currentTarget then
            -- Check if target changed to reset part
            if currentTarget ~= lastLockedTarget then
                lastLockedTarget = currentTarget
                if getgenv().LegitMode then
                    activeTargetPart = getRandomPart(currentTarget.Character)
                else
                    activeTargetPart = "Head"
                end
            end

            if currentTarget.Character then
                -- Fallback if the specific part is missing (e.g. lost limb)
                local targetInst = currentTarget.Character:FindFirstChild(activeTargetPart)
                if not targetInst then 
                    targetInst = currentTarget.Character:FindFirstChild("Head") 
                end

                if targetInst then
                    local humanoid = currentTarget.Character:FindFirstChild("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                         local currentCFrame = camera.CFrame
                         local easing = getgenv().AimbotEasing or 1
                         camera.CFrame = currentCFrame:Lerp(CFrame.new(currentCFrame.Position, targetInst.Position), easing)
                    else
                        currentTarget = nil
                        lastLockedTarget = nil
                    end
                end
            end
        else
            lastLockedTarget = nil
        end
    end)

    RunService.RenderStepped:Connect(function()
        if isEnabled then updateFOVCircle() elseif fovCircle and isDrawingApiAvailable then fovCircle.Visible = false end
    end)

    if getgenv then
        local lastFOV = getgenv().AimbotFOV or 100
        task.spawn(function()
            while task.wait(0.1) do
                local currentFOV = getgenv().AimbotFOV or 100
                if currentFOV ~= lastFOV then
                    lastFOV = currentFOV
                    updateFOVCircle()
                end
            end
        end)
    end
    updateFOVCircle()
    return AimbotCore
end)()

-- [2.5] KILL AURA CORE
Combat.KillAuraCore = (function()
    local KillAura = {}
    local player = Players.LocalPlayer
    local isEnabled = false

    local function isSameTeam(targetPlayer)
        if not getgenv().TeamCheck then return false end
        if player.Team and targetPlayer.Team then return player.Team == targetPlayer.Team end
        if player.TeamColor and targetPlayer.TeamColor then return player.TeamColor == targetPlayer.TeamColor end
        return false
    end

    local function findNearestTarget()
        local nearestTarget = nil
        local nearestDistance = math.huge
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end

        for _, targetPlayer in pairs(Players:GetPlayers()) do
            if targetPlayer ~= player and not isSameTeam(targetPlayer) then
                local char = targetPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                    local dist = (char.HumanoidRootPart.Position - myRoot.Position).Magnitude
                    if dist < nearestDistance then
                        nearestDistance = dist
                        nearestTarget = targetPlayer
                    end
                end
            end
        end
        return nearestTarget
    end

    local currentTarget = nil

    RunService.Heartbeat:Connect(function()
        if not isEnabled then 
            currentTarget = nil
            return 
        end

        -- Validate current target
        if currentTarget then
            local char = currentTarget.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then
                currentTarget = nil -- Target died or invalid, allow switch
            end
        end

        -- Find new target if none
        if not currentTarget then
            currentTarget = findNearestTarget()
        end

        -- Teleport Logic
        if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("HumanoidRootPart") then
             if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local targetRoot = currentTarget.Character.HumanoidRootPart
                -- Teleport behind (+4 studs Z relative to target)
                local newCFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
                player.Character.HumanoidRootPart.CFrame = newCFrame
             end
        end
    end)

    function KillAura:SetEnabled(enabled)
        isEnabled = enabled
        if getgenv then getgenv().KillAuraEnabled = enabled end
    end
    function KillAura:IsEnabled() return isEnabled end
    if getgenv then isEnabled = getgenv().KillAuraEnabled or false else isEnabled = false end

    return KillAura
end)()

return Combat
