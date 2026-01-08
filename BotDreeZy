local BotCore = {}
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local currentTargetName = nil
local isEnabled = false
local loopConnection = nil
local lastPathTime = 0
local currentPath = nil
local currentWaypoints = nil
local currentWaypointIndex = 0

-- Configuration
local Config = {
    MinDistance = 10,
    MaxDistance = 20,
    TeleportDistance = 120,
    PathUpdateInterval = 0.5,
    RaycastDistance = 5,
    StuckThreshold = 2
}

local function getRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(char)
    return char and char:FindFirstChild("Humanoid")
end

-- Raycast Obstacle Detection
local function CheckObstacle(rootPart)
    local checkDir = rootPart.CFrame.LookVector
    local rayOrigin = rootPart.Position
    local rayDirection = checkDir * Config.RaycastDistance
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if result then
        -- Obstacle detected
        return true, result
    end
    return false, nil
end

local function MoveTo(position)
    local char = LocalPlayer.Character
    local hum = getHumanoid(char)
    if hum then
        hum:MoveTo(position)
    end
end

local function UpdateBot()
    if not isEnabled or not currentTargetName then return end
    
    local targetPlr = Players:FindFirstChild(currentTargetName)
    if not targetPlr or not targetPlr.Character then return end
    
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = getRoot(myChar)
    local targetRoot = getRoot(targetPlr.Character)
    local myHum = getHumanoid(myChar)
    
    if not myRoot or not targetRoot or not myHum then return end
    
    local dist = (myRoot.Position - targetRoot.Position).Magnitude
    
    -- 1. Teleport if too far
    if dist > Config.TeleportDistance then
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 5)
        return
    end
    
    -- 2. Follow Logic
    if dist > Config.MaxDistance then
        -- Calculate goal: Behind player
        local goalDetails = targetRoot.CFrame * CFrame.new(0, 0, 10) -- 10 studs behind
        local goalPos = goalDetails.Position
        
        -- Pathfinding
        if tick() - lastPathTime > Config.PathUpdateInterval then
            lastPathTime = tick()
            
            local path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true,
                AgentJumpHeight = 10,
                WaypointSpacing = 4
            })
            
            local success, errorMessage = pcall(function()
                path:ComputeAsync(myRoot.Position, goalPos)
            end)
            
            if success and path.Status == Enum.PathStatus.Success then
                currentWaypoints = path:GetWaypoints()
                currentWaypointIndex = 2 -- Skip current pos
            else
                currentWaypoints = nil
                -- Fallback to direct move if path fails
                MoveTo(goalPos)
            end
        end
        
        if currentWaypoints and currentWaypointIndex <= #currentWaypoints then
            local waypoint = currentWaypoints[currentWaypointIndex]
            
            -- Simple Raycast Check for walls in front
            local isBlocked, hit = CheckObstacle(myRoot)
            if isBlocked then
                myHum.Jump = true
            end
            
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                myHum.Jump = true
            end
            
            myHum:MoveTo(waypoint.Position)
            
            -- Check if reached waypoint
            if (myRoot.Position - waypoint.Position).Magnitude < 4 then
                currentWaypointIndex = currentWaypointIndex + 1
            end
        else
            -- Direct move fallback
             MoveTo(goalPos)
        end
        
    elseif dist < Config.MinDistance then
        -- Stop moving if too close
        myHum:MoveTo(myRoot.Position)
    end
end

function BotCore:SetTarget(name)
    currentTargetName = name
end

function BotCore:SetEnabled(state)
    isEnabled = state
    if state then
        if not loopConnection then
            loopConnection = RunService.Heartbeat:Connect(UpdateBot)
        end
    else
        if loopConnection then
            loopConnection:Disconnect()
            loopConnection = nil
        end
        -- Stop movement
        local char = LocalPlayer.Character
        if char and getHumanoid(char) then
            getHumanoid(char):MoveTo(char.HumanoidRootPart.Position)
        end
    end
end

return BotCore
