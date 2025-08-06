-- AutoJoiner with Exact Brainrot Matching and JSON Parsing
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

-- Configuration
local WEBSOCKET_URL = "wss://cd9df660-ee00-4af8-ba05-5112f2b5f870-00-xh16qzp1xfp5.janeway.replit.dev/"
local HOP_INTERVAL = 2 -- seconds between hops
local RECONNECT_DELAY = 5
local MAX_RETRIES = 3

-- State
local player = Players.LocalPlayer or Players:GetPlayers()[1]
local socket = nil
local isRunning = false
local isPaused = false
local lastHopTime = 0
local activeJobId = nil
local selectedMpsRange = "1M-3M"
local connectionAttempts = 0
local selectedBrainrots = {}

-- Brainrot options (exact matches only)
local brainrotOptions = {
    "Chicleteira Bicicleteira",
    "Pot Hotspot",
    "Graipuss Medussi",
    "Los Combinasionas",
    "La Grande Combinasion",
    "Garama and Madundung",
}

-- Wait for player GUI
repeat task.wait() until player and player:FindFirstChild("PlayerGui")
local playerGui = player:WaitForChild("PlayerGui")

-- Main GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoJoinerGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 550)
frame.Position = UDim2.new(0.5, -150, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- Draggable Logic
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- Rainbow Title
local rainbowColors = {
    Color3.fromRGB(255, 0, 0),
    Color3.fromRGB(255, 127, 0),
    Color3.fromRGB(255, 255, 0),
    Color3.fromRGB(0, 255, 0),
    Color3.fromRGB(0, 0, 255),
    Color3.fromRGB(75, 0, 130),
    Color3.fromRGB(148, 0, 211)
}

local titleContainer = Instance.new("Frame")
titleContainer.Size = UDim2.new(1, -40, 0, 40)
titleContainer.Position = UDim2.new(0, 20, 0, 15)
titleContainer.BackgroundTransparency = 1
titleContainer.Parent = frame

local titleText = "AutoJoiner"
local charLabels = {}

for i = 1, #titleText do
    local charLabel = Instance.new("TextLabel")
    charLabel.Size = UDim2.new(0, 18, 1, 0)
    charLabel.Position = UDim2.new(0, (i-1)*18, 0, 0)
    charLabel.BackgroundTransparency = 1
    charLabel.Text = titleText:sub(i,i)
    charLabel.TextColor3 = rainbowColors[(i-1) % #rainbowColors + 1]
    charLabel.Font = Enum.Font.GothamBold
    charLabel.TextSize = 22
    charLabel.TextXAlignment = Enum.TextXAlignment.Left
    charLabel.Parent = titleContainer
    table.insert(charLabels, charLabel)
end

-- Rainbow animation
local waveOffset = 0
coroutine.wrap(function()
    while true do
        for i, label in ipairs(charLabels) do
            label.TextColor3 = rainbowColors[(i + waveOffset) % #rainbowColors + 1]
        end
        waveOffset = (waveOffset + 1) % (#rainbowColors * 2)
        task.wait(0.05)
    end
end)()

-- Tab System
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, -40, 0, 30)
tabFrame.Position = UDim2.new(0, 20, 0, 60)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = frame

local mainTab = Instance.new("TextButton")
mainTab.Size = UDim2.new(0.5, -5, 1, 0)
mainTab.Position = UDim2.new(0, 0, 0, 0)
mainTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
mainTab.BorderSizePixel = 0
mainTab.Text = "Main"
mainTab.TextColor3 = Color3.fromRGB(255, 255, 255)
mainTab.Font = Enum.Font.GothamBold
mainTab.TextSize = 14
mainTab.Parent = tabFrame

local filtersTab = Instance.new("TextButton")
filtersTab.Size = UDim2.new(0.5, -5, 1, 0)
filtersTab.Position = UDim2.new(0.5, 5, 0, 0)
filtersTab.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
filtersTab.BorderSizePixel = 0
filtersTab.Text = "Filters"
filtersTab.TextColor3 = Color3.fromRGB(200, 200, 200)
filtersTab.Font = Enum.Font.GothamBold
filtersTab.TextSize = 14
filtersTab.Parent = tabFrame

-- Content Frames
local mainContent = Instance.new("Frame")
mainContent.Size = UDim2.new(1, -40, 0, 430)
mainContent.Position = UDim2.new(0, 20, 0, 95)
mainContent.BackgroundTransparency = 1
mainContent.Visible = true
mainContent.Parent = frame

local filtersContent = Instance.new("Frame")
filtersContent.Size = UDim2.new(1, -40, 0, 430)
filtersContent.Position = UDim2.new(0, 20, 0, 95)
filtersContent.BackgroundTransparency = 1
filtersContent.Visible = false
filtersContent.Parent = frame

-- Tab switching
mainTab.MouseButton1Click:Connect(function()
    mainContent.Visible = true
    filtersContent.Visible = false
    mainTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    filtersTab.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    filtersTab.TextColor3 = Color3.fromRGB(200, 200, 200)
end)

filtersTab.MouseButton1Click:Connect(function()
    mainContent.Visible = false
    filtersContent.Visible = true
    mainTab.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    filtersTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    mainTab.TextColor3 = Color3.fromRGB(200, 200, 200)
    filtersTab.TextColor3 = Color3.fromRGB(255, 255, 255)
end)

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Disconnected"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainContent

-- Server Info Label
local serverInfoLabel = Instance.new("TextLabel")
serverInfoLabel.Size = UDim2.new(1, 0, 0, 20)
serverInfoLabel.Position = UDim2.new(0, 0, 0, 25)
serverInfoLabel.BackgroundTransparency = 1
serverInfoLabel.Text = "Server: None"
serverInfoLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
serverInfoLabel.Font = Enum.Font.Gotham
serverInfoLabel.TextSize = 14
serverInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
serverInfoLabel.Parent = mainContent

-- MPS Dropdown
local mpsLabel = Instance.new("TextLabel")
mpsLabel.Size = UDim2.new(1, 0, 0, 20)
mpsLabel.Position = UDim2.new(0, 0, 0, 50)
mpsLabel.BackgroundTransparency = 1
mpsLabel.Text = "Select MPS Range:"
mpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
mpsLabel.Font = Enum.Font.GothamBold
mpsLabel.TextSize = 18
mpsLabel.TextXAlignment = Enum.TextXAlignment.Left
mpsLabel.Parent = mainContent

local mpsDropdown = Instance.new("TextButton")
mpsDropdown.Size = UDim2.new(1, 0, 0, 40)
mpsDropdown.Position = UDim2.new(0, 0, 0, 75)
mpsDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
mpsDropdown.BorderSizePixel = 0
mpsDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
mpsDropdown.Font = Enum.Font.GothamBold
mpsDropdown.TextSize = 18
mpsDropdown.Text = "1M-3M ▼"
mpsDropdown.AutoButtonColor = false
mpsDropdown.Parent = mainContent

local mpsOptionsFrame = Instance.new("Frame")
mpsOptionsFrame.Size = UDim2.new(1, 0, 0, 0)
mpsOptionsFrame.Position = UDim2.new(0, 0, 0, 115)
mpsOptionsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
mpsOptionsFrame.BorderSizePixel = 0
mpsOptionsFrame.ClipsDescendants = true
mpsOptionsFrame.ZIndex = 2
mpsOptionsFrame.Parent = mainContent

local mpsRanges = {"1M-3M", "3M-5M", "5M-9.9M", "10M+"}
local isMpsDropdownOpen = false

local function toggleMpsDropdown()
    if isMpsDropdownOpen then
        mpsOptionsFrame:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        mpsDropdown.Text = selectedMpsRange.." ▼"
    else
        mpsOptionsFrame:TweenSize(UDim2.new(1, 0, 0, #mpsRanges * 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        mpsDropdown.Text = selectedMpsRange.." ▲"
    end
    isMpsDropdownOpen = not isMpsDropdownOpen
end

mpsDropdown.MouseButton1Click:Connect(toggleMpsDropdown)

for i, range in ipairs(mpsRanges) do
    local option = Instance.new("TextButton")
    option.Size = UDim2.new(1, 0, 0, 40)
    option.Position = UDim2.new(0, 0, 0, (i-1)*40)
    option.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    option.BorderSizePixel = 0
    option.Text = range
    option.TextColor3 = Color3.fromRGB(255, 255, 255)
    option.Font = Enum.Font.GothamBold
    option.TextSize = 18
    option.AutoButtonColor = false
    option.ZIndex = 3
    option.Parent = mpsOptionsFrame
    
    option.MouseButton1Click:Connect(function()
        selectedMpsRange = range
        toggleMpsDropdown()
        statusLabel.Text = "Status: Filter set to "..range
        statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    end)
end

-- Brainrot Filter UI
local brainrotLabel = Instance.new("TextLabel")
brainrotLabel.Size = UDim2.new(1, 0, 0, 20)
brainrotLabel.Position = UDim2.new(0, 0, 0, 0)
brainrotLabel.BackgroundTransparency = 1
brainrotLabel.Text = "Select Brainrots:"
brainrotLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
brainrotLabel.Font = Enum.Font.GothamBold
brainrotLabel.TextSize = 18
brainrotLabel.TextXAlignment = Enum.TextXAlignment.Left
brainrotLabel.Parent = filtersContent

local brainrotDropdown = Instance.new("TextButton")
brainrotDropdown.Size = UDim2.new(1, 0, 0, 40)
brainrotDropdown.Position = UDim2.new(0, 0, 0, 25)
brainrotDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
brainrotDropdown.BorderSizePixel = 0
brainrotDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
brainrotDropdown.Font = Enum.Font.GothamBold
brainrotDropdown.TextSize = 18
brainrotDropdown.Text = "Select Brainrots ▼"
brainrotDropdown.AutoButtonColor = false
brainrotDropdown.Parent = filtersContent

local brainrotOptionsFrame = Instance.new("Frame")
brainrotOptionsFrame.Size = UDim2.new(1, 0, 0, 0)
brainrotOptionsFrame.Position = UDim2.new(0, 0, 0, 65)
brainrotOptionsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
brainrotOptionsFrame.BorderSizePixel = 0
brainrotOptionsFrame.ClipsDescendants = true
brainrotOptionsFrame.ZIndex = 2
brainrotOptionsFrame.Parent = filtersContent

local isBrainrotDropdownOpen = false

local function toggleBrainrotDropdown()
    if isBrainrotDropdownOpen then
        brainrotOptionsFrame:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        brainrotDropdown.Text = #selectedBrainrots > 0 and ("Selected: "..#selectedBrainrots.." ▼") or "Select Brainrots ▼"
    else
        brainrotOptionsFrame:TweenSize(UDim2.new(1, 0, 0, #brainrotOptions * 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        brainrotDropdown.Text = #selectedBrainrots > 0 and ("Selected: "..#selectedBrainrots.." ▲") or "Select Brainrots ▲"
    end
    isBrainrotDropdownOpen = not isBrainrotDropdownOpen
end

brainrotDropdown.MouseButton1Click:Connect(toggleBrainrotDropdown)

for i, brainrot in ipairs(brainrotOptions) do
    local optionFrame = Instance.new("Frame")
    optionFrame.Size = UDim2.new(1, 0, 0, 40)
    optionFrame.Position = UDim2.new(0, 0, 0, (i-1)*40)
    optionFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    optionFrame.BorderSizePixel = 0
    optionFrame.ZIndex = 3
    optionFrame.Parent = brainrotOptionsFrame
    
    local checkbox = Instance.new("Frame")
    checkbox.Size = UDim2.new(0, 20, 0, 20)
    checkbox.Position = UDim2.new(0, 10, 0.5, -10)
    checkbox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    checkbox.BorderSizePixel = 0
    checkbox.ZIndex = 4
    checkbox.Parent = optionFrame
    
    local checkmark = Instance.new("TextLabel")
    checkmark.Size = UDim2.new(1, 0, 1, 0)
    checkmark.Position = UDim2.new(0, 0, 0, 0)
    checkmark.BackgroundTransparency = 1
    checkmark.Text = "✓"
    checkmark.TextColor3 = Color3.fromRGB(0, 255, 0)
    checkmark.Font = Enum.Font.GothamBold
    checkmark.TextSize = 18
    checkmark.Visible = false
    checkmark.ZIndex = 5
    checkmark.Parent = checkbox
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 40, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = brainrot
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.Gotham
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 4
    label.Parent = optionFrame
    
    for _, selected in ipairs(selectedBrainrots) do
        if selected == brainrot then
            checkmark.Visible = true
            checkbox.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            break
        end
    end
    
    optionFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local isSelected = checkmark.Visible
            checkmark.Visible = not isSelected
            
            if checkmark.Visible then
                checkbox.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                table.insert(selectedBrainrots, brainrot)
            else
                checkbox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                for i, selected in ipairs(selectedBrainrots) do
                    if selected == brainrot then
                        table.remove(selectedBrainrots, i)
                        break
                    end
                end
            end
            
            brainrotDropdown.Text = #selectedBrainrots > 0 and ("Selected: "..#selectedBrainrots.." ▼") or "Select Brainrots ▼"
        end
    end)
end

-- Control Buttons
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, 0, 0, 40)
startBtn.Position = UDim2.new(0, 0, 0, 160)
startBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
startBtn.BorderSizePixel = 0
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 20
startBtn.Text = "Start"
startBtn.AutoButtonColor = false
startBtn.Parent = mainContent

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(1, 0, 0, 40)
stopBtn.Position = UDim2.new(0, 0, 0, 210)
stopBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
stopBtn.BorderSizePixel = 0
stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 20
stopBtn.Text = "Stop"
stopBtn.AutoButtonColor = false
stopBtn.Parent = mainContent

local resumeBtn = Instance.new("TextButton")
resumeBtn.Size = UDim2.new(1, 0, 0, 40)
resumeBtn.Position = UDim2.new(0, 0, 0, 260)
resumeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
resumeBtn.BorderSizePixel = 0
resumeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resumeBtn.Font = Enum.Font.GothamBold
resumeBtn.TextSize = 20
resumeBtn.Text = "Resume"
resumeBtn.AutoButtonColor = false
resumeBtn.Parent = mainContent

-- Minimize Button
local minimizeBtn = Instance.new("ImageButton")
minimizeBtn.Size = UDim2.new(0, 40, 0, 40)
minimizeBtn.Position = UDim2.new(1, -40, 0, 0)
minimizeBtn.BackgroundTransparency = 1
minimizeBtn.Image = "rbxassetid://2398054"
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = frame

local minimizedImage = Instance.new("ImageButton")
minimizedImage.Size = UDim2.new(0, 40, 0, 40)
minimizedImage.Position = UDim2.new(0, 20, 0, 20)
minimizedImage.BackgroundTransparency = 1
minimizedImage.Image = "rbxassetid://2398054"
minimizedImage.Visible = false
minimizedImage.Parent = screenGui

minimizeBtn.MouseButton1Click:Connect(function()
    frame.Visible = false
    minimizedImage.Visible = true
end)

minimizedImage.MouseButton1Click:Connect(function()
    frame.Visible = true
    minimizedImage.Visible = false
end)

-- WebSocket Functions
local function isExactBrainrotMatch(serverName)
    if not serverName or #selectedBrainrots == 0 then
        return false
    end
    
    local normalizedServer = string.lower(serverName)
    
    for _, brainrot in ipairs(selectedBrainrots) do
        if string.lower(brainrot) == normalizedServer then
            return true
        end
    end
    
    return false
end

local function attemptTeleport(jobId, serverName)
    if not isRunning or isPaused then return false end
    
    local currentTime = os.time()
    if currentTime - lastHopTime < HOP_INTERVAL then
        task.wait(HOP_INTERVAL - (currentTime - lastHopTime))
    end
    
    lastHopTime = os.time()
    activeJobId = jobId
    serverInfoLabel.Text = "Server: "..(jobId and string.sub(jobId, 1, 8).."..." or "None")
    
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
    end)
    
    if not success then
        warn("Teleport failed:", err)
        statusLabel.Text = "Status: Failed - Retrying"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return false
    end
    
    return true
end

local function handleWebSocketMessage(message)
    if isPaused then return end
    
    print("[WebSocket] Raw message:", message)
    
    -- Parse JSON message
    local success, data = pcall(function()
        return HttpService:JSONDecode(message)
    end)
    
    if not success then
        statusLabel.Text = "Status: Invalid JSON"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        print("[ERROR] Failed to parse JSON:", message)
        return
    end
    
    -- Validate required fields
    if not (data.jobId and data.serverName and data.moneyPerSec) then
        statusLabel.Text = "Status: Missing data in JSON"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        print("[ERROR] Missing required fields in JSON:", data)
        return
    end
    
    -- Extract MPS value
    local mps_value = data.moneyPerSec:match("([%d%.]+)M")
    local mps_number = tonumber(mps_value)
    
    if not mps_number then
        statusLabel.Text = "Status: Invalid MPS value"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        print("[ERROR] Invalid MPS value:", data.moneyPerSec)
        return
    end
    
    -- Apply filters
    local shouldJoin = false
    local isBrainrotMatch = isExactBrainrotMatch(data.serverName)
    
    -- Priority 1: Exact brainrot match
    if isBrainrotMatch then
        shouldJoin = true
        statusLabel.Text = string.format("[BRAINROT] Joining %s", string.sub(data.jobId, 1, 8))
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
    -- Priority 2: MPS filter
    else
        if selectedMpsRange == "1M-3M" then
            shouldJoin = (mps_number >= 1 and mps_number <= 3)
        elseif selectedMpsRange == "3M-5M" then
            shouldJoin = (mps_number > 3 and mps_number <= 5)
        elseif selectedMpsRange == "5M-9.9M" then
            shouldJoin = (mps_number > 5 and mps_number <= 9.9)
        elseif selectedMpsRange == "10M+" then
            shouldJoin = (mps_number >= 10)
        end
        
        if shouldJoin then
            statusLabel.Text = string.format("Joining %s (%.1fM/s)", string.sub(data.jobId, 1, 8), mps_number)
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            statusLabel.Text = string.format("Skipping %s (%.1fM/s)", string.sub(data.jobId, 1, 8), mps_number)
            statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        end
    end
    
    if shouldJoin then
        attemptTeleport(data.jobId, data.serverName)
    end
    
    print(string.format(
        "Server: %s | MPS: %.1f | BrainrotMatch: %s | Action: %s",
        data.serverName,
        mps_number,
        isBrainrotMatch and "YES" or "NO",
        shouldJoin and "JOINING" or "SKIPPING"
    ))
end

local function connectWebSocket()
    if not isRunning then return end
    
    connectionAttempts = connectionAttempts + 1
    statusLabel.Text = string.format("Connecting (%d/%d)...", connectionAttempts, MAX_RETRIES)
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    
    if socket then
        pcall(function() socket:Close() end)
        socket = nil
    end
    
    local success, err = pcall(function()
        socket = WebSocket.connect(WEBSOCKET_URL)
        
        socket.OnMessage:Connect(handleWebSocketMessage)
        
        socket.OnClose:Connect(function()
            if isRunning and not isPaused and connectionAttempts < MAX_RETRIES then
                task.wait(RECONNECT_DELAY)
                connectWebSocket()
            end
        end)
        
        connectionAttempts = 0
        statusLabel.Text = "Status: Connected"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end)
    
    if not success then
        print("[ERROR] Connection failed:", err)
        if connectionAttempts < MAX_RETRIES then
            task.wait(RECONNECT_DELAY)
            connectWebSocket()
        else
            statusLabel.Text = "Status: Connection failed"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            isRunning = false
        end
    end
end

-- Control Handlers
startBtn.MouseButton1Click:Connect(function()
    if isRunning then return end
    isRunning = true
    isPaused = false
    connectionAttempts = 0
    connectWebSocket()
end)

stopBtn.MouseButton1Click:Connect(function()
    if not isRunning then return end
    isRunning = false
    isPaused = false
    if socket then
        pcall(function() socket:Close() end)
        socket = nil
    end
    statusLabel.Text = "Status: Stopped"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
end)

resumeBtn.MouseButton1Click:Connect(function()
    if not isRunning or not isPaused then return end
    isPaused = false
    statusLabel.Text = "Status: Resumed"
    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
end)

-- Debugging
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.F5 then
        print("\n=== DEBUG INFO ===")
        print("WebSocket URL:", WEBSOCKET_URL)
        print("Connected:", socket and "Yes" or "No")
        print("Running:", isRunning and "Yes" or "No")
        print("Paused:", isPaused and "Yes" or "No")
        print("Last Job ID:", activeJobId or "None")
        print("Selected MPS:", selectedMpsRange)
        print("Selected Brainrots:", #selectedBrainrots > 0 and table.concat(selectedBrainrots, ", ") or "None")
        print("Connection Attempts:", connectionAttempts)
        print("=========================")
    end
end)

-- Cleanup
player.AncestryChanged:Connect(function(_, parent)
    if not parent and socket then
        pcall(function() socket:Close() end)
    end
end)

