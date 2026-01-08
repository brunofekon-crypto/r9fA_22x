-- Modules/Utility.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Utility = {}

-- [0] MOUSE UNLOCKER CORE
Utility.MouseUnlocker = (function()
    local MouseUnlocker = {}
    
    -- "Modal Trick" Button setup
    local modalButton = Instance.new("TextButton")
    modalButton.Name = "MouseForceModal"
    modalButton.Text = ""
    modalButton.BackgroundTransparency = 1
    modalButton.Modal = true 
    modalButton.Visible = false
    
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
    if playerGui then
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "MouseUnlockGui"
        screenGui.ResetOnSpawn = false
        screenGui.IgnoreGuiInset = true
        screenGui.DisplayOrder = 999999 
        screenGui.Parent = game:GetService("CoreGui")
        modalButton.Parent = screenGui
    end

    local isUnlocked = false
    local connection = nil
    
    function MouseUnlocker:SetUnlocked(unlocked)
        isUnlocked = unlocked
        if unlocked then
            if not connection then
                RunService:BindToRenderStep("DreeZyMouseUnlock", Enum.RenderPriority.Camera.Value + 10000, function()
                    local rightClick = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                    if not rightClick then
                        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                        UserInputService.MouseIconEnabled = true 
                        if modalButton then modalButton.Visible = true end
                    else
                         if modalButton then modalButton.Visible = false end
                    end
                end)
            end
            connection = true 
        else
            if connection then
                RunService:UnbindFromRenderStep("DreeZyMouseUnlock")
                connection = nil
            end
            if modalButton then modalButton.Visible = false end
        end
    end
    function MouseUnlocker:IsUnlocked() return isUnlocked end
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        local binding = getgenv().IsBindingKey
        if (input.KeyCode == getgenv().UnlockMouseKey) and (not binding) then
             MouseUnlocker:SetUnlocked(not isUnlocked)
        end
    end)
    return MouseUnlocker
end)()

-- [1] RESPAWN CORE
Utility.RespawnCore = (function()
    local RespawnCore = {}
    local player = Players.LocalPlayer
    local isEnabled = false
    local lastCFrame = nil

    function RespawnCore:SetEnabled(enabled)
        isEnabled = enabled
        if not enabled then lastCFrame = nil end
    end
    function RespawnCore:IsEnabled() return isEnabled end
    function RespawnCore:GetLastPosition() return lastCFrame end

    local function onCharacterAdded(character)
        local humanoid = character:WaitForChild("Humanoid")
        local root = character:WaitForChild("HumanoidRootPart")

        if lastCFrame and isEnabled then
            task.spawn(function()
                task.wait(0.2)
                local startTime = os.clock()
                while os.clock() - startTime < 1.5 do
                    if root and root.Parent and humanoid.Health > 0 then
                        root.CFrame = lastCFrame
                        root.Velocity = Vector3.new(0,0,0)
                        root.RotVelocity = Vector3.new(0,0,0)
                    else
                        break
                    end
                    task.wait(0.05)
                end
                lastCFrame = nil
                if RespawnCore.OnRespawned then RespawnCore.OnRespawned:Fire() end
            end)
        end

        humanoid.Died:Connect(function()
            if root and isEnabled then
                lastCFrame = root.CFrame
                if RespawnCore.OnDeath then RespawnCore.OnDeath:Fire() end
            end
        end)
    end

    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then onCharacterAdded(player.Character) end

    RespawnCore.OnDeath = Instance.new("BindableEvent")
    RespawnCore.OnRespawned = Instance.new("BindableEvent")
    return RespawnCore
end)()

return Utility
