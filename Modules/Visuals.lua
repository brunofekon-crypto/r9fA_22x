-- Modules/Visuals.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Visuals = {}

-- [3] HEAD ESP
Visuals.HeadESP = (function()
    local HeadESP = {}
    local player = Players.LocalPlayer

    local Config = { HeadSize = 5, Disabled = true }
    local originalProperties = {}

    function HeadESP:RestoreHeads()
        for head, props in pairs(originalProperties) do
            if head and head.Parent then
                pcall(function()
                    head.Size = props.Size
                    head.Transparency = props.Transparency
                    head.BrickColor = props.BrickColor
                    head.Material = props.Material
                    head.CanCollide = props.CanCollide
                    head.Massless = props.Massless
                end)
            end
        end
        originalProperties = {}
    end

    function HeadESP:SetEnabled(enabled) 
        Config.Disabled = not enabled
        if not enabled then self:RestoreHeads() end
    end
    function HeadESP:IsEnabled() return not Config.Disabled end
    function HeadESP:SetHeadSize(size) Config.HeadSize = size end
    function HeadESP:GetHeadSize() return Config.HeadSize end

    RunService.RenderStepped:Connect(function()
        if not Config.Disabled then
            for i, v in next, Players:GetPlayers() do
                if v.Name ~= player.Name then
                    pcall(function()
                        if v.Character and v.Character:FindFirstChild("Head") then
                            local head = v.Character.Head
                            if not originalProperties[head] then
                                originalProperties[head] = {
                                    Size = head.Size; Transparency = head.Transparency; BrickColor = head.BrickColor;
                                    Material = head.Material; CanCollide = head.CanCollide; Massless = head.Massless
                                }
                            end
                            head.Size = Vector3.new(Config.HeadSize, Config.HeadSize, Config.HeadSize)
                            head.Transparency = 0.5
                            head.BrickColor = BrickColor.new("Red")
                            head.Material = Enum.Material.Neon
                            head.CanCollide = false
                            head.Massless = true
                        end
                    end)
                end
            end
        end
    end)
    return HeadESP
end)()

-- [4] ESP CORE
Visuals.ESPCore = (function()
    if not Drawing then return {} end
    local LocalPlayer = Players.LocalPlayer
    local ESPCore = {}
    local isEnabled = false

    local drawingPool = {Boxes = {}, NameTags = {}, HealthBars = {}, Tracers = {}}
    local playerDrawings = {}

    local function GetDrawingFromPool(type)
        local pool
        if type == "Square" then pool = drawingPool.Boxes
        elseif type == "Text" then pool = drawingPool.NameTags
        elseif type == "HealthBar" then pool = drawingPool.HealthBars
        elseif type == "Line" then pool = drawingPool.Tracers end
        
        if pool and #pool > 0 then return table.remove(pool) end
        
        local drawType = (type == "HealthBar") and "Square" or type
        local drawing = Drawing.new(drawType)
        drawing.Visible = false
        drawing.Transparency = 1
        if type == "Square" then
            drawing.Color = Color3.new(1, 1, 1)
            drawing.Thickness = 2
            drawing.Filled = false
        elseif type == "Text" then
            drawing.Center = true
            drawing.Outline = true
            drawing.OutlineColor = Color3.new(0, 0, 0)
            drawing.Size = 14
        elseif type == "HealthBar" then
            drawing.Filled = true
            drawing.Thickness = 0 -- No outline for the bar itself
            drawing.Transparency = 0.6
        elseif type == "Line" then
            drawing.Thickness = 1.5
            drawing.Transparency = 1
        end
        return drawing
    end

    local function ReturnDrawingToPool(type, drawing)
        if not drawing then return end
        drawing.Visible = false
        local pool
        if type == "Square" then pool = drawingPool.Boxes
        elseif type == "Text" then pool = drawingPool.NameTags
        elseif type == "HealthBar" then pool = drawingPool.HealthBars
        elseif type == "Line" then pool = drawingPool.Tracers end
        
        if pool then table.insert(pool, drawing) end
    end

    local function GetTeamColor(player)
        if player.TeamColor then return player.TeamColor.Color end
        if player.Team and player.Team.TeamColor then return player.Team.TeamColor.Color end
        return Color3.fromRGB(255, 255, 255)
    end

    local function CreateDrawings(playerName)
        if playerDrawings[playerName] then return playerDrawings[playerName] end
        local drawings = {
            Box = GetDrawingFromPool("Square"), 
            NameTag = GetDrawingFromPool("Text"),
            HealthBg = GetDrawingFromPool("HealthBar"),
            HealthFg = GetDrawingFromPool("HealthBar"),
            Tracer = GetDrawingFromPool("Line")
        }
        playerDrawings[playerName] = drawings
        return drawings
    end

    local function RemoveDrawings(playerName)
        local drawings = playerDrawings[playerName]
        if drawings then
            if drawings.Box then ReturnDrawingToPool("Square", drawings.Box) end
            if drawings.NameTag then ReturnDrawingToPool("Text", drawings.NameTag) end
            if drawings.HealthBg then ReturnDrawingToPool("HealthBar", drawings.HealthBg) end
            if drawings.HealthFg then ReturnDrawingToPool("HealthBar", drawings.HealthFg) end
            if drawings.Tracer then ReturnDrawingToPool("Line", drawings.Tracer) end
            playerDrawings[playerName] = nil
        end
    end

    local function UpdateESP()
        if not isEnabled then
            for _, drawings in pairs(playerDrawings) do 
                drawings.Box.Visible = false
                drawings.NameTag.Visible = false
                drawings.HealthBg.Visible = false
                drawings.HealthFg.Visible = false
                drawings.Tracer.Visible = false
            end
            return
        end
        local camera = workspace.CurrentCamera
        if not camera then return end

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local character = player.Character
                local drawings = playerDrawings[player.Name]
                if character then
                    local root = character:FindFirstChild("HumanoidRootPart")
                    local head = character:FindFirstChild("Head")
                    local humanoid = character:FindFirstChild("Humanoid")
                    if root and head and (not humanoid or humanoid.Health > 0) then
                        if not drawings then drawings = CreateDrawings(player.Name) end
                        local rootPos, rootVis = camera:WorldToViewportPoint(root.Position)
                        if rootVis then
                            local headPos, _ = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                            local legPos, _ = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                            local boxHeight = math.abs(headPos.Y - legPos.Y)
                            local boxWidth = boxHeight * 0.6
                            local boxPos = Vector2.new(rootPos.X - boxWidth/2, headPos.Y)
                            local color = GetTeamColor(player)
                            
                            drawings.Box.Visible = true; drawings.Box.Color = color; drawings.Box.Size = Vector2.new(boxWidth, boxHeight); drawings.Box.Position = boxPos
                            if getgenv().ESPNames then
                                drawings.NameTag.Visible = true; drawings.NameTag.Text = player.Name; drawings.NameTag.Color = color; drawings.NameTag.Position = Vector2.new(rootPos.X, headPos.Y - 18)
                            else
                                drawings.NameTag.Visible = false
                            end
                            
                            if getgenv().ESPHealth then
                                local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                                local barWidth = 3
                                local barOffset = 4
                                local barFullHeight = boxHeight
                                local barHeight = barFullHeight * healthPercent
                                local barLostHeight = barFullHeight - barHeight
                                
                                drawings.HealthBg.Visible = barLostHeight > 1 
                                drawings.HealthBg.Color = Color3.fromRGB(255, 0, 0)
                                drawings.HealthBg.Size = Vector2.new(barWidth, barLostHeight)
                                drawings.HealthBg.Position = Vector2.new(boxPos.X + boxWidth + barOffset, boxPos.Y)
                                
                                drawings.HealthFg.Visible = barHeight > 1
                                drawings.HealthFg.Color = Color3.fromRGB(0, 255, 0)
                                drawings.HealthFg.Size = Vector2.new(barWidth, barHeight)
                                drawings.HealthFg.Position = Vector2.new(boxPos.X + boxWidth + barOffset, (boxPos.Y + boxHeight) - barHeight)
                            else
                                drawings.HealthBg.Visible = false
                                drawings.HealthFg.Visible = false
                            end

                            if getgenv().ESPTracers then
                                drawings.Tracer.Visible = true
                                drawings.Tracer.Color = color
                                drawings.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y) -- Bottom Center
                                drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y) -- To RootPart
                            else
                                drawings.Tracer.Visible = false
                            end

                        else
                            if drawings then 
                                drawings.Box.Visible = false; drawings.NameTag.Visible = false 
                                drawings.HealthBg.Visible = false; drawings.HealthFg.Visible = false
                                drawings.Tracer.Visible = false
                            end
                        end
                    else
                        if drawings then 
                            drawings.Box.Visible = false; drawings.NameTag.Visible = false 
                            drawings.HealthBg.Visible = false; drawings.HealthFg.Visible = false
                            drawings.Tracer.Visible = false
                        end
                    end
                else
                    if drawings then 
                        drawings.Box.Visible = false; drawings.NameTag.Visible = false 
                        drawings.HealthBg.Visible = false; drawings.HealthFg.Visible = false
                        drawings.Tracer.Visible = false
                    end
                end
            end
        end
    end

    function ESPCore:SetEnabled(enabled)
        isEnabled = enabled
        if getgenv then getgenv().ESPEnabled = enabled end
        if not enabled then for player, _ in pairs(playerDrawings) do RemoveDrawings(player) end end
    end
    function ESPCore:IsEnabled() return isEnabled end
    if getgenv then isEnabled = getgenv().ESPEnabled or false else isEnabled = false end
    Players.PlayerRemoving:Connect(function(player) RemoveDrawings(player.Name) end)
    RunService.RenderStepped:Connect(UpdateESP)
    return ESPCore
end)()

return Visuals
