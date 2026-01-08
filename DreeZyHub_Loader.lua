-- DreeZyHub_Loader.lua
-- Interface Moderna "Voidware Style" (Roxo/Dark)
-- Universal Hub

local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- ==========================================
-- EXECUTOR COMPATIBILITY (POLYFILLS)
-- ==========================================
if not getgenv then
    getgenv = function() return _G end
end

if not setclipboard then
    setclipboard = function(data) print("Clipboard unsupported: "..tostring(data)) end
end

if not Drawing then
    warn("Drawing API não encontrada. ESP Linhas/Box não funcionará.")
end

-- ==========================================
-- SECURITY: EXECUTION GUARD
-- ==========================================
if getgenv().DreeZyHubLoaded then
    warn("DreeZy-HUB já está carregado!")
    return
end
getgenv().DreeZyHubLoaded = true

-- Limpar flag ao destruir
CoreGui.ChildRemoved:Connect(function(child)
    if child.Name == "DreeZyVoidware" then
        getgenv().DreeZyHubLoaded = false
    end
end)

-- ==========================================
-- GLOBAL CONFIG INITIALIZATION
-- ==========================================
if not getgenv().AimbotInput then getgenv().AimbotInput = "RightClick" end
if not getgenv().AimbotFOV then getgenv().AimbotFOV = 100 end
if not getgenv().AimbotEasing then getgenv().AimbotEasing = 1 end
if getgenv().TeamCheck == nil then getgenv().TeamCheck = false end
if getgenv().LegitMode == nil then getgenv().LegitMode = false end
if getgenv().KillAuraEnabled == nil then getgenv().KillAuraEnabled = false end
if getgenv().ESPHealth == nil then getgenv().ESPHealth = false end
if getgenv().ESPEnabled == nil then getgenv().ESPEnabled = false end
if getgenv().ESPNames == nil then getgenv().ESPNames = false end
if getgenv().ESPTracers == nil then getgenv().ESPTracers = false end
if not getgenv().UnlockMouseKey then getgenv().UnlockMouseKey = Enum.KeyCode.P end

-- ==========================================
-- MODULE BUNDLING (INTERNAL)
-- ==========================================
-- NOTE: Executor failed to load external modules. 
-- Bundling Logic internally to ensure stability.

-- [MODULE: UTILITY]
local Utility = (function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    
    local Utility = {}

    -- Mouse Unlocker
    Utility.MouseUnlocker = (function()
        local MouseUnlocker = {}
        local modalButton = Instance.new("TextButton")
        modalButton.Name = "MouseForceModal"
        modalButton.Text = ""
        modalButton.BackgroundTransparency = 1
        modalButton.Modal = true 
        modalButton.Visible = false
        
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
        if playerGui then
            local screenGui = Instance.new("ScreenGui")
            screenGui.Name = "MouseUnlockGui"; screenGui.ResetOnSpawn = false; screenGui.IgnoreGuiInset = true; screenGui.DisplayOrder = 999999; screenGui.Parent = game:GetService("CoreGui")
            modalButton.Parent = screenGui
        end
    
        local isUnlocked = false
        local connection = nil
        function MouseUnlocker:SetUnlocked(unlocked)
            isUnlocked = unlocked
            if unlocked then
                if not connection then
                    RunService:BindToRenderStep("DreeZyMouseUnlock", Enum.RenderPriority.Camera.Value + 10000, function()
                        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
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
                if connection then RunService:UnbindFromRenderStep("DreeZyMouseUnlock"); connection = nil end
                if modalButton then modalButton.Visible = false end
            end
        end
        function MouseUnlocker:IsUnlocked() return isUnlocked end
        UserInputService.InputBegan:Connect(function(input)
            if (input.KeyCode == getgenv().UnlockMouseKey) and (not getgenv().IsBindingKey) then MouseUnlocker:SetUnlocked(not isUnlocked) end
        end)
        return MouseUnlocker
    end)()

    -- Respawn Core
    Utility.RespawnCore = (function()
        local RespawnCore = {}
        local player = Players.LocalPlayer
        local isEnabled = false
        local lastCFrame = nil
        function RespawnCore:SetEnabled(enabled) isEnabled = enabled; if not enabled then lastCFrame = nil end end
        function RespawnCore:IsEnabled() return isEnabled end
        local function onCharacterAdded(character)
            local root = character:WaitForChild("HumanoidRootPart")
            if lastCFrame and isEnabled then
                task.spawn(function()
                    task.wait(0.2)
                    local st = os.clock()
                    while os.clock() - st < 1.5 do
                        if root and root.Parent then root.CFrame = lastCFrame; root.Velocity = Vector3.zero else break end
                        task.wait(0.05)
                    end
                    lastCFrame = nil
                end)
            end
            character:WaitForChild("Humanoid").Died:Connect(function() if isEnabled and root then lastCFrame = root.CFrame end end)
        end
        player.CharacterAdded:Connect(onCharacterAdded)
        if player.Character then onCharacterAdded(player.Character) end
        return RespawnCore
    end)()

    return Utility
end)()

-- [MODULE: COMBAT]
local Combat = (function()
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Combat = {}

    Combat.AimbotCore = (function()
        local AimbotCore = {}
        local player = Players.LocalPlayer
        local mouse = player:GetMouse()
        local camera = workspace.CurrentCamera
        workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() camera = workspace.CurrentCamera end)
        if not getgenv().AimbotFOV then getgenv().AimbotFOV = 100 end
        local isEnabled, isActive, fovCircle, isDrawingApiAvailable = false, false, nil, false
        pcall(function() if Drawing then fovCircle = Drawing.new("Circle"); fovCircle.Visible = false; fovCircle.Thickness = 2; fovCircle.Color = Color3.new(1,1,1); fovCircle.Transparency = 0.5; fovCircle.Filled = false; isDrawingApiAvailable = true end end)

        local currentLegitPart = nil
        local currentTargetChar = nil
        
        local function getLegitPart(char)
            if not char then return nil end
            if currentTargetChar ~= char then
                currentTargetChar = char
                currentLegitPart = nil
            end
            if currentLegitPart and char:FindFirstChild(currentLegitPart.Name) then 
                return currentLegitPart 
            end
            
            local parts = {"HumanoidRootPart", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Head"}
            local available = {}
            for _, name in pairs(parts) do
                local p = char:FindFirstChild(name)
                if p then table.insert(available, p) end
            end
            
            if #available > 0 then
                -- 40% Head, 60% Random Body
                if math.random() > 0.6 then
                    currentLegitPart = char:FindFirstChild("Head") or available[math.random(#available)]
                else
                    currentLegitPart = available[math.random(#available)]
                end
            else
                currentLegitPart = char:FindFirstChild("Head")
            end
            return currentLegitPart
        end

        local function isTargetVisible(targetPart, char)
            local cp = camera.CFrame.Position
            local _, onscreen = camera:WorldToViewportPoint(targetPart.Position)
            if onscreen then
                 local ray = Ray.new(cp, targetPart.Position - cp)
                 local hit = workspace:FindPartOnRayWithIgnoreList(ray, player.Character:GetDescendants())
                 return hit and hit:IsDescendantOf(char)
            end
            return false
        end

        local function isSameTeam(target)
            if not getgenv().TeamCheck then return false end
            if player.Team and target.Team then return player.Team == target.Team end
            if player.TeamColor and target.TeamColor then return player.TeamColor == target.TeamColor end
            return false
        end

        local function updateFOVCircle()
            if not fovCircle or not isDrawingApiAvailable then return end
            fovCircle.Visible = isEnabled
            fovCircle.Position = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
            fovCircle.Radius = getgenv().AimbotFOV or 100
        end

        local function findNearestTarget()
            local nearest, dist = nil, math.huge
            for _, v in pairs(Players:GetPlayers()) do
                if v ~= player and not isSameTeam(v) and v.Character and v.Character:FindFirstChild("Head") and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
                    local head = v.Character.Head
                    local vp, onScreen = camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local d = (Vector2.new(vp.X, vp.Y) - Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)).Magnitude
                        if d <= (getgenv().AimbotFOV or 100) then
                            local realDist = (mouse.Hit.Position - head.Position).Magnitude
                            if realDist < dist and isTargetVisible(head, v.Character) then nearest = v; dist = realDist end
                        end
                    end
                end
            end
            return nearest
        end

        function AimbotCore:SetEnabled(v) isEnabled = v; if not v then isActive = false end; updateFOVCircle() end
        function AimbotCore:SetFOV(v) getgenv().AimbotFOV = math.clamp(v, 20, 500); updateFOVCircle() end
        function AimbotCore:GetFOV() return getgenv().AimbotFOV or 100 end
        function AimbotCore:IsEnabled() return isEnabled end

        mouse.Button2Down:Connect(function() if isEnabled and getgenv().AimbotInput == "RightClick" then isActive = true end end)
        mouse.Button2Up:Connect(function() if isEnabled and getgenv().AimbotInput == "RightClick" then isActive = false end end)
        
        -- Logic Loop
        local currentTarget = nil
        task.spawn(function() while true do if isEnabled then currentTarget = findNearestTarget() else currentTarget = nil end; task.wait(0.1) end end)
        
        -- Render Loop
        RunService.RenderStepped:Connect(function()
            if isActive and isEnabled and currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("Head") then
                local targetInst = currentTarget.Character.Head 
                
                if getgenv().LegitMode then
                    targetInst = getLegitPart(currentTarget.Character) or targetInst
                end

                if targetInst then
                    camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, targetInst.Position), getgenv().AimbotEasing or 1)
                end
            end
            if isEnabled then updateFOVCircle() elseif fovCircle then fovCircle.Visible = false end
        end)
        return AimbotCore
    end)()

    Combat.KillAuraCore = (function()
        local KillAura = {}
        local player = Players.LocalPlayer
        local isEnabled = false
        local function findNearest()
           local target, dist = nil, math.huge
           local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
           if not myRoot then return nil end
           for _, v in pairs(Players:GetPlayers()) do
               if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
                   if not (getgenv().TeamCheck and v.Team == player.Team) then
                       local d = (v.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude
                       if d < dist then dist = d; target = v end
                   end
               end
           end
           return target
        end
        local current = nil
        RunService.Heartbeat:Connect(function()
            if not isEnabled then current=nil; return end
            if current and (not current.Character or not current.Character:FindFirstChild("Humanoid") or current.Character.Humanoid.Health<=0) then current = nil end
            if not current then current = findNearest() end
            if current and current.Character and current.Character:FindFirstChild("HumanoidRootPart") and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = current.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,4)
            end
        end)
        function KillAura:SetEnabled(v) isEnabled = v; if getgenv then getgenv().KillAuraEnabled = v end end
        function KillAura:IsEnabled() return isEnabled end
        return KillAura
    end)()

    return Combat
end)()

-- [MODULE: VISUALS]
local Visuals = (function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Visuals = {}

    Visuals.HeadESP = (function()
        local HeadESP = {}
        local Config = {HeadSize=5, Disabled=true}
        function HeadESP:SetEnabled(v) Config.Disabled = not v end
        function HeadESP:IsEnabled() return not Config.Disabled end
        function HeadESP:SetHeadSize(v) Config.HeadSize = v end
        function HeadESP:GetHeadSize() return Config.HeadSize end
        RunService.RenderStepped:Connect(function()
            if not Config.Disabled then
                for _, v in pairs(Players:GetPlayers()) do
                    if v ~= Players.LocalPlayer and v.Character and v.Character:FindFirstChild("Head") then
                        v.Character.Head.Size = Vector3.new(Config.HeadSize, Config.HeadSize, Config.HeadSize)
                        v.Character.Head.CanCollide = false
                        v.Character.Head.Transparency = 0.5
                        v.Character.Head.BrickColor = BrickColor.new("Red")
                        v.Character.Head.Material = Enum.Material.Neon
                    end
                end
            end
        end)
        return HeadESP
    end)()

    Visuals.ESPCore = (function()
        if not Drawing then return {} end
        local ESPCore = {}
        local isEnabled = false
        local drawings = {} 

        local function isSameTeam(target)
            local p = Players.LocalPlayer
            if not getgenv().TeamCheck then return false end
            if p.Team and target.Team then return p.Team == target.Team end
            if p.TeamColor and target.TeamColor then return p.TeamColor == target.TeamColor end
            return false
        end

        local function createDrawings(p)
            drawings[p] = {
                Box = Drawing.new("Square"), 
                Name = Drawing.new("Text"), 
                Line = Drawing.new("Line"),
                HealthBack = Drawing.new("Square"),
                HealthBar = Drawing.new("Square")
            }
            local d = drawings[p]
            -- Box
            d.Box.Visible=false; d.Box.Color=Color3.new(1,1,1); d.Box.Thickness=1; d.Box.Filled=false
            -- Name
            d.Name.Visible=false; d.Name.Color=Color3.new(1,1,1); d.Name.Size=14; d.Name.Center=true; d.Name.Outline=true
            -- Tracer
            d.Line.Visible=false; d.Line.Color=Color3.new(1,1,1); d.Line.Thickness=1
            -- Health
            d.HealthBack.Visible=false; d.HealthBack.Color=Color3.new(0,0,0); d.HealthBack.Filled=true; d.HealthBack.Transparency=1
            d.HealthBar.Visible=false; d.HealthBar.Color=Color3.new(0,1,0); d.HealthBar.Filled=true; d.HealthBar.Transparency=1
        end

        local function removeDrawings(p)
            if drawings[p] then 
                for _, obj in pairs(drawings[p]) do obj:Remove() end
                drawings[p] = nil 
            end
        end
        Players.PlayerRemoving:Connect(function(p) removeDrawings(p) end)
        
        RunService.RenderStepped:Connect(function()
            if not isEnabled then 
                for _, d in pairs(drawings) do 
                    for _, obj in pairs(d) do obj.Visible=false end 
                end 
                return 
            end

            for _, p in pairs(Players:GetPlayers()) do
                if p ~= Players.LocalPlayer then
                     -- Check existence
                     if not drawings[p] then createDrawings(p) end
                     local d = drawings[p]
                     
                     local shouldShow = false
                     local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                     local hum = p.Character and p.Character:FindFirstChild("Humanoid")

                     if root and hum and hum.Health > 0 then
                         if not isSameTeam(p) then
                            local pos, vis = workspace.CurrentCamera:WorldToViewportPoint(root.Position)
                            if vis then
                                shouldShow = true
                                local headPos = workspace.CurrentCamera:WorldToViewportPoint(root.Position + Vector3.new(0,2,0))
                                local legPos = workspace.CurrentCamera:WorldToViewportPoint(root.Position - Vector3.new(0,3,0))
                                local h = (headPos.Y - legPos.Y) * -1
                                local w = h * 0.6
                                
                                -- Box
                                d.Box.Visible = true
                                d.Box.Size = Vector2.new(w, h)
                                d.Box.Position = Vector2.new(pos.X - w/2, headPos.Y)

                                -- Name
                                if getgenv().ESPNames then 
                                    d.Name.Visible = true; d.Name.Text = p.Name; d.Name.Position = Vector2.new(pos.X, headPos.Y - 16) 
                                else d.Name.Visible = false end

                                -- Tracer
                                if getgenv().ESPTracers then 
                                    d.Line.Visible = true; d.Line.From = Vector2.new(workspace.CurrentCamera.ViewportSize.X/2, workspace.CurrentCamera.ViewportSize.Y); d.Line.To = Vector2.new(pos.X, pos.Y) 
                                else d.Line.Visible = false end

                                -- Health Bar
                                if getgenv().ESPHealth then
                                    d.HealthBack.Visible = true
                                    d.HealthBack.Size = Vector2.new(2, h)
                                    d.HealthBack.Position = Vector2.new((pos.X - w/2) - 5, headPos.Y)
                                    
                                    d.HealthBar.Visible = true
                                    local healthY = h * (hum.Health / hum.MaxHealth)
                                    d.HealthBar.Size = Vector2.new(2, healthY)
                                    d.HealthBar.Position = Vector2.new((pos.X - w/2) - 5, headPos.Y + (h - healthY))
                                    d.HealthBar.Color = Color3.fromHSV((hum.Health/hum.MaxHealth)*0.3, 1, 1) -- Green to Red
                                else
                                    d.HealthBack.Visible = false; d.HealthBar.Visible = false
                                end
                            end
                         end
                     end

                     if not shouldShow then
                        for _, obj in pairs(d) do obj.Visible = false end
                     end
                elseif drawings[p] then
                    for _, obj in pairs(drawings[p]) do obj.Visible=false end
                end
            end
        end)
        function ESPCore:SetEnabled(v) isEnabled = v; if not v then for _, d in pairs(drawings) do for _, obj in pairs(d) do obj.Visible=false end end end end
        function ESPCore:IsEnabled() return isEnabled end
        return ESPCore
    end)()
    
    return Visuals
end)()

-- [MODULE: UI]
-- [MODULE: UI]
local UI = (function()
    local UI = {}
    local VoidLib = {}
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    
    function VoidLib:CreateWindow()
         local Themes = {Background=Color3.fromRGB(17,17,20), Accent=Color3.fromHex("#B507E0")}
         
         local SG = Instance.new("ScreenGui"); SG.Parent = game:GetService("CoreGui"); SG.Name = "DreeZyVoidware"; SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
         local Main = Instance.new("Frame"); Main.Size = UDim2.new(0,650,0,480); Main.Position = UDim2.new(0.5,-325,0.5,-240); Main.BackgroundColor3 = Themes.Background; Main.Parent = SG;
         Instance.new("UICorner", Main).CornerRadius = UDim.new(0,10)
         
         -- Make Draggable
         local dragging, dragInput, dragStart, startPos
         local function update(input)
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
         end
         Main.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = Main.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
            end
         end)
         Main.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
         UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then update(input) end end)

         -- Tabs
         local TabHolder = Instance.new("Frame", Main); TabHolder.Size = UDim2.new(0,150,1,0); TabHolder.BackgroundColor3 = Color3.fromRGB(25,25,30)
         Instance.new("UICorner", TabHolder).CornerRadius = UDim.new(0,10)
         local Content = Instance.new("Frame", Main); Content.Size = UDim2.new(1,-150,1,0); Content.Position = UDim2.new(0,150,0,0); Content.BackgroundTransparency=1
         local List = Instance.new("UIListLayout", TabHolder); List.Padding = UDim.new(0,5); List.HorizontalAlignment = Enum.HorizontalAlignment.Center
         
         -- Padding for TabHolder
         local TP = Instance.new("UIPadding", TabHolder); TP.PaddingTop=UDim.new(0,10)

         local Window = {Tabs={}}
         function Window:Tab(name)
             local Btn = Instance.new("TextButton", TabHolder); Btn.Size = UDim2.new(0.9,0,0,40); Btn.Text = name; Btn.TextColor3 = Color3.new(0.7,0.7,0.7); Btn.BackgroundTransparency=1; Btn.Font=Enum.Font.GothamBold; Btn.TextSize=14
             local Page = Instance.new("ScrollingFrame", Content); Page.Size = UDim2.new(1,0,1,0); Page.Visible=false; Page.BackgroundTransparency=1; Page.ScrollBarThickness=2; Page.ScrollBarImageColor3=Themes.Accent
             Instance.new("UIListLayout", Page).Padding = UDim.new(0,5); Instance.new("UIPadding", Page).PaddingLeft=UDim.new(0,10); Instance.new("UIPadding", Page).PaddingTop=UDim.new(0,10)
             
             Btn.MouseButton1Click:Connect(function() 
                 for _,t in pairs(Window.Tabs) do 
                    t.Page.Visible=false
                    TweenService:Create(t.Btn, TweenInfo.new(0.3), {TextColor3=Color3.new(0.7,0.7,0.7)}):Play()
                 end
                 Page.Visible=true
                 TweenService:Create(Btn, TweenInfo.new(0.3), {TextColor3=Themes.Accent}):Play()
             end)
             
             if #Window.Tabs==0 then 
                Page.Visible=true 
                Btn.TextColor3 = Themes.Accent
             end
             table.insert(Window.Tabs, {Page=Page, Btn=Btn})
             
             local TabObj = {}
             function TabObj:Group(txt)
                 local Grp = Instance.new("Frame", Page); Grp.Size = UDim2.new(0.95,0,0,0); Grp.AutomaticSize = Enum.AutomaticSize.Y; Grp.BackgroundColor3 = Color3.fromRGB(30,30,35)
                 Instance.new("UICorner", Grp)
                 local GrpLabel = Instance.new("TextLabel", Grp); GrpLabel.Text=txt; GrpLabel.Size=UDim2.new(1,0,0,30); GrpLabel.BackgroundTransparency=1; GrpLabel.TextColor3=Themes.Accent; GrpLabel.Font=Enum.Font.GothamBold; GrpLabel.TextSize=14
                 local GrpLayout = Instance.new("UIListLayout", Grp); GrpLayout.Padding = UDim.new(0,5); GrpLayout.SortOrder = Enum.SortOrder.LayoutOrder
                 Instance.new("UIPadding", Grp).PaddingLeft=UDim.new(0,10); Instance.new("UIPadding", Grp).PaddingTop=UDim.new(0,5); Instance.new("UIPadding", Grp).PaddingBottom=UDim.new(0,10)

                 local GObj = {}
                 function GObj:Toggle(t, def, cb)
                     local Fr = Instance.new("Frame", Grp); Fr.Size = UDim2.new(1,0,0,30); Fr.BackgroundTransparency=1
                     local Tb = Instance.new("TextButton", Fr); Tb.Size = UDim2.new(0,40,0,20); Tb.Position = UDim2.new(1,-50,0,5); Tb.BackgroundColor3 = def and Themes.Accent or Color3.new(0.2,0.2,0.2); Tb.Text=""
                     Instance.new("UICorner", Tb).CornerRadius = UDim.new(1,0)
                     local Circle = Instance.new("Frame", Tb); Circle.Size=UDim2.new(0,16,0,16); Circle.Position=def and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2); Circle.BackgroundColor3=Color3.new(1,1,1); Instance.new("UICorner", Circle).CornerRadius=UDim.new(1,0)
                     
                     local Lbl = Instance.new("TextLabel", Fr); Lbl.Text = t; Lbl.Size = UDim2.new(1,-60,1,0); Lbl.Position = UDim2.new(0,0,0,0); Lbl.TextColor3 = Color3.new(1,1,1); Lbl.BackgroundTransparency=1; Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Font = Enum.Font.Gotham
                     
                     Tb.MouseButton1Click:Connect(function() 
                         def = not def
                         pcall(cb, def) 
                         TweenService:Create(Tb, TweenInfo.new(0.3), {BackgroundColor3 = def and Themes.Accent or Color3.new(0.2,0.2,0.2)}):Play()
                         TweenService:Create(Circle, TweenInfo.new(0.3), {Position = def and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)}):Play()
                     end)
                     return Tb 
                 end
                 function GObj:Slider(t, min, max, def, cb)
                     local Fr = Instance.new("Frame", Grp); Fr.Size = UDim2.new(1,0,0,50); Fr.BackgroundTransparency=1
                     local Sl = Instance.new("TextButton", Fr); Sl.Size=UDim2.new(1,-20,0,10); Sl.Position=UDim2.new(0,0,0,30); Sl.BackgroundColor3=Color3.new(0.2,0.2,0.2); Sl.Text=""
                     Instance.new("UICorner", Sl).CornerRadius=UDim.new(1,0)
                     
                     local Fill = Instance.new("Frame", Sl); Fill.Size=UDim2.new((def-min)/(max-min),0,1,0); Fill.BackgroundColor3=Themes.Accent
                     Instance.new("UICorner", Fill).CornerRadius=UDim.new(1,0)
                     
                     local Lbl = Instance.new("TextLabel", Fr); Lbl.Text = t .. ": " .. def; Lbl.Size = UDim2.new(1,-20,0,20); Lbl.Position = UDim2.new(0,0,0,5); Lbl.BackgroundTransparency=1; Lbl.TextColor3=Color3.new(1,1,1); Lbl.TextXAlignment=Enum.TextXAlignment.Left; Lbl.Font=Enum.Font.Gotham
                     
                     Sl.MouseButton1Down:Connect(function()
                         local m = game:GetService("Players").LocalPlayer:GetMouse()
                         local move = m.Move:Connect(function()
                             local p = math.clamp((m.X - Sl.AbsolutePosition.X)/Sl.AbsoluteSize.X,0,1)
                             local v = math.floor(min + (max-min)*p)
                             TweenService:Create(Fill, TweenInfo.new(0.1), {Size = UDim2.new(p,0,1,0)}):Play()
                             Lbl.Text = t..": "..v
                             pcall(cb, v)
                         end)
                         game:GetService("UserInputService").InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then move:Disconnect() end end)
                     end)
                 end
                 function GObj:Bind(t, key, cb)
                     local Fr = Instance.new("Frame", Grp); Fr.Size = UDim2.new(1,0,0,30); Fr.BackgroundTransparency=1
                     local Lbl = Instance.new("TextLabel", Fr); Lbl.Text = t; Lbl.Size = UDim2.new(1,-100,1,0); Lbl.Position = UDim2.new(0,0,0,0); Lbl.BackgroundTransparency=1; Lbl.TextColor3 = Color3.new(1,1,1); Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Font = Enum.Font.Gotham
                     
                     local B = Instance.new("TextButton", Fr); B.Text = key.Name; B.Size = UDim2.new(0,80,0,24); B.Position = UDim2.new(1,-90,0,3); B.BackgroundColor3 = Color3.new(0.2,0.2,0.2); B.TextColor3=Color3.new(1,1,1)
                     Instance.new("UICorner", B).CornerRadius = UDim.new(0,4)
                     
                     B.MouseButton1Click:Connect(function()
                         B.Text = "..."; local c; c = game:GetService("UserInputService").InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Keyboard then pcall(cb, i.KeyCode); B.Text = i.KeyCode.Name; c:Disconnect() end end)
                     end)
                 end
                 function GObj:Button(t, cb)
                    local B = Instance.new("TextButton", Grp); B.Text = t; B.Size = UDim2.new(1,-20,0,30); B.BackgroundColor3 = Color3.fromRGB(40,40,45); B.TextColor3=Color3.new(1,1,1); B.Font=Enum.Font.Gotham
                    Instance.new("UICorner", B).CornerRadius = UDim.new(0,4)
                    B.MouseButton1Click:Connect(function() 
                        TweenService:Create(B, TweenInfo.new(0.1), {BackgroundColor3=Themes.Accent}):Play()
                        task.wait(0.1)
                        TweenService:Create(B, TweenInfo.new(0.3), {BackgroundColor3=Color3.fromRGB(40,40,45)}):Play()
                        cb() 
                    end)
                 end
                 return GObj
             end
             return TabObj
         end
         return Window, Main
    end
    UI.VoidLib = VoidLib
    return UI
end)()

-- Shortcuts
local VoidLib = UI.VoidLib
local AimbotCore = Combat.AimbotCore
local KillAuraCore = Combat.KillAuraCore
local HeadESP = Visuals.HeadESP
local ESPCore = Visuals.ESPCore
local RespawnCore = Utility.RespawnCore
local MouseUnlocker = Utility.MouseUnlocker

-- ==========================================
-- UI SETUP & LOGIC WIRING
-- ==========================================
local Win, MainFrame = VoidLib:CreateWindow()

-- Global Toggle Logic (Right Shift)
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
   if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
       MainFrame.Visible = not MainFrame.Visible
   end
end)

-- >>> TAB: COMBATE
local CombatTab = Win:Tab("Combate")

local AimbotGroup = CombatTab:Group("Aimbot Principal")
local aimbotDependents = {} 

AimbotGroup:Toggle("Ativar Aimbot", AimbotCore:IsEnabled(), function(v)
    AimbotCore:SetEnabled(v)
    -- Toggle visibility of dependents
    if v then
        task.wait(0.3) 
        for _, frame in pairs(aimbotDependents) do frame.Visible = true end
    else
        for _, frame in pairs(aimbotDependents) do frame.Visible = false end
    end
end)

local tCheck = AimbotGroup:Toggle("Ignorar Aliados", getgenv().TeamCheck, function(v)
    getgenv().TeamCheck = v
end)
table.insert(aimbotDependents, tCheck)

local legitT = AimbotGroup:Toggle("Modo Legit (Random Part)", getgenv().LegitMode, function(v)
    getgenv().LegitMode = v
end)
table.insert(aimbotDependents, legitT)

local fovS = AimbotGroup:Slider("Campo de Visão (FOV)", 20, 500, AimbotCore:GetFOV(), function(v)
    AimbotCore:SetFOV(v)
end)
table.insert(aimbotDependents, fovS)

local easingS = AimbotGroup:Slider("Suavização (Easing)", 1, 10, math.floor(getgenv().AimbotEasing * 10), function(v)
    getgenv().AimbotEasing = v / 10 
end)
table.insert(aimbotDependents, easingS)

-- Initialize visibility logic
local isAimbotEnabled = AimbotCore:IsEnabled()
for _, frame in pairs(aimbotDependents) do frame.Visible = isAimbotEnabled end

local KillAuraGroup = CombatTab:Group("Kill Aura")
KillAuraGroup:Toggle("Kill Player(s)", KillAuraCore:IsEnabled(), function(v)
    KillAuraCore:SetEnabled(v)
end)

-- >>> TAB: VISUAL
local VisualTab = Win:Tab("Visual")

local ESPGroup = VisualTab:Group("ESP Jogadores")
local espDependents = {} 

ESPGroup:Toggle("Ativar ESP (Box)", ESPCore:IsEnabled(), function(v)
    ESPCore:SetEnabled(v)
    if v then
        task.wait(0.3) 
        for _, frame in pairs(espDependents) do frame.Visible = true end
    else
        for _, frame in pairs(espDependents) do frame.Visible = false end
    end
end)

local nameT = ESPGroup:Toggle("Mostrar Nomes", getgenv().ESPNames, function(v)
    getgenv().ESPNames = v
end)
table.insert(espDependents, nameT)

local healthT = ESPGroup:Toggle("Barra de Vida", getgenv().ESPHealth, function(v)
    getgenv().ESPHealth = v
end)
table.insert(espDependents, healthT)

local tracerT = ESPGroup:Toggle("Linhas (Tracers)", getgenv().ESPTracers, function(v)
    getgenv().ESPTracers = v
end)
table.insert(espDependents, tracerT)

local isESPEnabled = ESPCore:IsEnabled()
for _, frame in pairs(espDependents) do frame.Visible = isESPEnabled end

local HeadGroup = VisualTab:Group("Cabeças (Headshot)")
HeadGroup:Toggle("Expandir Cabeças", HeadESP:IsEnabled(), function(v)
    HeadESP:SetEnabled(v)
end)
HeadGroup:Slider("Tamanho", 1, 20, HeadESP:GetHeadSize(), function(v)
    HeadESP:SetHeadSize(v)
end)

-- >>> TAB: LOCAL PLAYER
local LocalTab = Win:Tab("Local")
local CharGroup = LocalTab:Group("Personagem")
CharGroup:Toggle("Respawn Onde Morreu", RespawnCore:IsEnabled(), function(v)
    RespawnCore:SetEnabled(v)
end)

local UtilityGroup = LocalTab:Group("Utilidades")
UtilityGroup:Bind("Tecla Soltar Cursor", getgenv().UnlockMouseKey, function(key)
    getgenv().UnlockMouseKey = key
end)
UtilityGroup:Button("Resetar Cursor (Emergência)", function()
    MouseUnlocker:SetUnlocked(true)
    task.wait(0.1)
    MouseUnlocker:SetUnlocked(false)
end)

-- >>> TAB: CONFIGURAÇÕES
local SettingsTab = Win:Tab("Configs")
local ManagerGroup = SettingsTab:Group("Gerenciamento")

local function Notify(msg)
    game:GetService("StarterGui"):SetCore("SendNotification", {Title="DreeZy HUB", Text=msg, Duration=3})
end

ManagerGroup:Button("Salvar Configurações", function()
    if writefile then
        local config = {
            aimbot = AimbotCore:IsEnabled(),
            teamCheck = getgenv().TeamCheck,
            legitMode = getgenv().LegitMode,
            killAura = KillAuraCore:IsEnabled(),
            fov = AimbotCore:GetFOV(),
            esp = ESPCore:IsEnabled(),
            espNames = getgenv().ESPNames,
            espTracers = getgenv().ESPTracers,
            espHealth = getgenv().ESPHealth,
            headEsp = HeadESP:IsEnabled(),
            headSize = HeadESP:GetHeadSize(),
            respawn = RespawnCore:IsEnabled(),
            unlockKey = getgenv().UnlockMouseKey.Name
        }
        writefile("DreeZy_Voidware.json", HttpService:JSONEncode(config))
        Notify("Configurações salvas!")
    else
        Notify("Executor não suporta writefile")
    end
end)

ManagerGroup:Button("Carregar Configurações", function()
    if isfile and isfile("DreeZy_Voidware.json") then
        local config = HttpService:JSONDecode(readfile("DreeZy_Voidware.json"))
        if config then
            -- Safely update values
            pcall(function()
                AimbotCore:SetEnabled(config.aimbot)
                getgenv().TeamCheck = config.teamCheck
                getgenv().LegitMode = config.legitMode or false
                KillAuraCore:SetEnabled(config.killAura or false)
                AimbotCore:SetFOV(config.fov)
                ESPCore:SetEnabled(config.esp)
                getgenv().ESPNames = config.espNames or false
                getgenv().ESPTracers = config.espTracers or false
                getgenv().ESPHealth = config.espHealth or false
                HeadESP:SetEnabled(config.headEsp)
                HeadESP:SetHeadSize(config.headSize)
                RespawnCore:SetEnabled(config.respawn)
                if config.unlockKey then getgenv().UnlockMouseKey = Enum.KeyCode[config.unlockKey] end
            end)
            Notify("Configurações carregadas!")
        end
    else
        Notify("Nenhum save encontrado")
    end
end)

local InfoGroup = SettingsTab:Group("Informações")
InfoGroup:Button("Criado por DreeZy", function() setclipboard("DreeZy") end)

Notify("DreeZy Voidware V2 Carregado!")
Notify("Use [Right Shift] para abrir/fechar o Menu!")
