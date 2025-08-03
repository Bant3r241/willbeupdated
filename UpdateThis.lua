-- AutoJoiner with Perfect BrainRot Detection + Encoded Job ID Support
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Configuration
local WEBSOCKET_URL = "wss://cd9df660-ee00-4af8-ba05-5112f2b5f870-00-xh16qzp1xfp5.janeway.replit.dev/"
local HTTP_FALLBACK_URL = "https://your-http-fallback-api.com/servers" -- Replace with your HTTP endpoint
local HOP_INTERVAL = 2 -- seconds between hops
local RECONNECT_DELAY = 5
local MAX_RETRIES = 3
local SERVER_HISTORY_EXPIRE = 1800 -- 30 minutes in seconds

-- State
local player = Players.LocalPlayer or Players:GetPlayers()[1]
local socket = nil
local isRunning = false
local isPaused = false
local lastHopTime = 0
local activeJobId = nil
local selectedMpsRange = "1M-3M"
local selectedBrainRot = "Any"
local connectionAttempts = 0
local currentTab = "AutoJoiner"
local recentServers = {} -- Tracks joined servers to prevent duplicates
local useWebSocket = true -- Fallback to HTTP if WebSocket fails

-- =================================================================
-- Enhanced Encoded Job ID Support System
-- =================================================================

local function decodeCustomJobId(encodedId)
    -- Clean common prefixes/suffixes
    local cleanId = encodedId:gsub("room ID.-:%s*", ""):gsub("%s+", "")
    
    -- URL-safe Base64 adjustments
    cleanId = cleanId:gsub("-", "+"):gsub("_", "/")
    
    -- Base64 requires length divisible by 4
    local padLen = #cleanId % 4
    if padLen > 0 then
        cleanId = cleanId .. string.rep("=", 4 - padLen)
    end
    
    -- Attempt decoding
    local success, decoded = pcall(function()
        return HttpService:Base64Decode(cleanId)
    end)
    
    return success and decoded or encodedId -- Fallback to original if decoding fails
end

local function isValidJobId(id)
    -- Standard Roblox UUID format (8-4-4-4-12 hex digits)
    if id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
        return true
    end
    
    -- Standard Roblox alphanumeric IDs (40-50 chars)
    if #id >= 40 and #id <= 50 and id:match("^%w+$") then
        return true
    end
    
    -- Custom encoded IDs (longer with symbols)
    if #id >= 64 and id:match("^[%w+/=%-_]+$") then
        return true
    end
    
    return false
end

local function processJobId(rawId)
    -- First clean the ID of common prefixes/suffixes
    local cleanId = rawId:gsub("JobID:%s*", "")
                      :gsub("room ID.-:%s*", "")
                      :gsub("%s+", "")
                      :gsub('"', "")
                      :gsub("'", "")
    
    -- Check if it's already valid
    if isValidJobId(cleanId) then
        return cleanId
    end
    
    -- Attempt decoding if it looks encoded
    if #cleanId >= 64 then
        local decoded = decodeCustomJobId(cleanId)
        if isValidJobId(decoded) then
            return decoded
        end
    end
    
    return nil -- Invalid ID
end

-- =================================================================
-- Enhanced BrainRot Detection
-- =================================================================

local function detectBrainRot(serverName)
    if not serverName or serverName == "Unknown" then return "Unknown" end
    
    local lowerName = serverName:lower()
    
    -- Detection patterns for all known brainrot types
    if string.find(lowerName, "vacca") or string.find(lowerName, "saturno") then
        return "La Vacca Saturno Saturnita"
    elseif string.find(lowerName, "tralaleritos") then
        return "Los Tralaleritos"
    elseif string.find(lowerName, "chimpanzini") or string.find(lowerName, "spiderniti") then
        return "Chimpanzini Spiderniti"
    elseif string.find(lowerName, "piccione") or string.find(lowerName, "macchina") then
        return "Piccione Macchina"
    elseif string.find(lowerName, "grappe") or string.find(lowerName, "medussi") then
        return "Grappe Medussi"
    end
    
    return "Unknown"
end

-- Complete list of all detectable brainrot types
local brainRotOptions = {
    "Any", 
    "La Vacca Saturno Saturnita", 
    "Los Tralaleritos", 
    "Chimpanzini Spiderniti", 
    "Piccione Macchina",
    "Grappe Medussi"
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
frame.Size = UDim2.new(0, 300, 0, 500) -- Reduced height
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

-- Rainbow Title Animation
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

local titleText = "AutoJoiner Pro"
local charLabels = {}
local charWidth = 18
local totalWidth = #titleText * charWidth

for i = 1, #titleText do
    local charLabel = Instance.new("TextLabel")
    charLabel.Size = UDim2.new(0, charWidth, 1, 0)
    charLabel.Position = UDim2.new(0, (i-1)*charWidth, 0, 0)
    charLabel.BackgroundTransparency = 1
    charLabel.Text = titleText:sub(i,i)
    charLabel.TextColor3 = rainbowColors[(i-1) % #rainbowColors + 1]
    charLabel.Font = Enum.Font.GothamBold
    charLabel.TextSize = 22
    charLabel.TextXAlignment = Enum.TextXAlignment.Left
    charLabel.Parent = titleContainer
    table.insert(charLabels, charLabel)
end

titleContainer.Size = UDim2.new(0, totalWidth, 0, 40)

local waveSpeed = 0.5
local waveOffset = 0

local function startAdvancedRainbowWave()
    while true do
        for i, label in ipairs(charLabels) do
            local colorIndex = (i + waveOffset) % #rainbowColors + 1
            label.TextColor3 = rainbowColors[colorIndex]
        end
        waveOffset = (waveOffset + 1) % (#rainbowColors * 2)
        task.wait(waveSpeed / 10)
    end
end

coroutine.wrap(startAdvancedRainbowWave)()

-- Tab System
local tabButtons = {}
local tabContents = {}

local tabsContainer = Instance.new("Frame")
tabsContainer.Size = UDim2.new(1, -40, 0, 30)
tabsContainer.Position = UDim2.new(0, 20, 0, 60)
tabsContainer.BackgroundTransparency = 1
tabsContainer.Parent = frame

local autoJoinerTabBtn = Instance.new("TextButton")
autoJoinerTabBtn.Size = UDim2.new(0.5, -5, 1, 0)
autoJoinerTabBtn.Position = UDim2.new(0, 0, 0, 0)
autoJoinerTabBtn.BackgroundColor3 = Color3.fromRGB(90, 0, 90)
autoJoinerTabBtn.BorderSizePixel = 0
autoJoinerTabBtn.Text = "AutoJoiner"
autoJoinerTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoJoinerTabBtn.Font = Enum.Font.GothamBold
autoJoinerTabBtn.TextSize = 14
autoJoinerTabBtn.AutoButtonColor = false
autoJoinerTabBtn.Parent = tabsContainer
table.insert(tabButtons, autoJoinerTabBtn)

local othersTabBtn = Instance.new("TextButton")
othersTabBtn.Size = UDim2.new(0.5, -5, 1, 0)
othersTabBtn.Position = UDim2.new(0.5, 5, 0, 0)
othersTabBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
othersTabBtn.BorderSizePixel = 0
othersTabBtn.Text = "Others"
othersTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
othersTabBtn.Font = Enum.Font.GothamBold
othersTabBtn.TextSize = 14
othersTabBtn.AutoButtonColor = false
othersTabBtn.Parent = tabsContainer
table.insert(tabButtons, othersTabBtn)

local tabContentContainer = Instance.new("Frame")
tabContentContainer.Size = UDim2.new(1, -40, 0, 410) -- Adjusted height
tabContentContainer.Position = UDim2.new(0, 20, 0, 95)
tabContentContainer.BackgroundTransparency = 1
tabContentContainer.ClipsDescendants = true
tabContentContainer.Parent = frame

-- AutoJoiner Tab Content
local autoJoinerTab = Instance.new("Frame")
autoJoinerTab.Size = UDim2.new(1, 0, 1, 0)
autoJoinerTab.BackgroundTransparency = 1
autoJoinerTab.Parent = tabContentContainer
tabContents["AutoJoiner"] = autoJoinerTab

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Disconnected"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = autoJoinerTab

local serverInfoLabel = Instance.new("TextLabel")
serverInfoLabel.Size = UDim2.new(1, 0, 0, 20)
serverInfoLabel.Position = UDim2.new(0, 0, 0, 25)
serverInfoLabel.BackgroundTransparency = 1
serverInfoLabel.Text = "Server: None"
serverInfoLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
serverInfoLabel.Font = Enum.Font.Gotham
serverInfoLabel.TextSize = 14
serverInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
serverInfoLabel.Parent = autoJoinerTab

local mpsLabel = Instance.new("TextLabel")
mpsLabel.Size = UDim2.new(1, 0, 0, 20)
mpsLabel.Position = UDim2.new(0, 0, 0, 50)
mpsLabel.BackgroundTransparency = 1
mpsLabel.Text = "Select MPS Range:"
mpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
mpsLabel.Font = Enum.Font.GothamBold
mpsLabel.TextSize = 18
mpsLabel.TextXAlignment = Enum.TextXAlignment.Left
mpsLabel.Parent = autoJoinerTab

local mpsDropdown = Instance.new("TextButton")
mpsDropdown.Size = UDim2.new(1, 0, 0, 40)
mpsDropdown.Position = UDim2.new(0, 0, 0, 75)
mpsDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
mpsDropdown.BorderSizePixel = 0
mpsDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
mpsDropdown.Font = Enum.Font.GothamBold
mpsDropdown.TextSize = 18
mpsDropdown.Text = "1M-3M  ▼"
mpsDropdown.AutoButtonColor = false
mpsDropdown.Parent = autoJoinerTab

local mpsOptionsFrame = Instance.new("Frame")
mpsOptionsFrame.Size = UDim2.new(1, 0, 0, 0)
mpsOptionsFrame.Position = UDim2.new(0, 0, 0, 115)
mpsOptionsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
mpsOptionsFrame.BorderSizePixel = 0
mpsOptionsFrame.ClipsDescendants = true
mpsOptionsFrame.ZIndex = 2
mpsOptionsFrame.Parent = autoJoinerTab

local mpsRanges = {"1M-3M", "3M-5M", "5M+"}
local isMpsDropdownOpen = false

local function toggleMpsDropdown()
    if isMpsDropdownOpen then
        mpsOptionsFrame:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        mpsDropdown.Text = selectedMpsRange.."  ▼"
    else
        mpsOptionsFrame:TweenSize(UDim2.new(1, 0, 0, #mpsRanges * 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        mpsDropdown.Text = selectedMpsRange.."  ▲"
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
startBtn.Parent = autoJoinerTab

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
stopBtn.Parent = autoJoinerTab

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
resumeBtn.Parent = autoJoinerTab

-- Others Tab Content
local othersTab = Instance.new("Frame")
othersTab.Size = UDim2.new(1, 0, 1, 0)
othersTab.BackgroundTransparency = 1
othersTab.Visible = false
othersTab.Parent = tabContentContainer
tabContents["Others"] = othersTab

local othersTitle = Instance.new("TextLabel")
othersTitle.Size = UDim2.new(1, 0, 0, 30)
othersTitle.Position = UDim2.new(0, 0, 0, 0)
othersTitle.BackgroundTransparency = 1
othersTitle.TextColor3 = Color3.fromRGB(90, 0, 90)
othersTitle.Font = Enum.Font.GothamBold
othersTitle.TextSize = 22
othersTitle.TextXAlignment = Enum.TextXAlignment.Left
othersTitle.Parent = othersTab

local rejoinBtn = Instance.new("TextButton")
rejoinBtn.Size = UDim2.new(1, 0, 0, 40)
rejoinBtn.Position = UDim2.new(0, 0, 0, 40)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
rejoinBtn.BorderSizePixel = 0
rejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rejoinBtn.Font = Enum.Font.GothamBold
rejoinBtn.TextSize = 18
rejoinBtn.Text = "Rejoin Server"
rejoinBtn.AutoButtonColor = false
rejoinBtn.Parent = othersTab

rejoinBtn.MouseButton1Click:Connect(function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
end)

local serverHopBtn = Instance.new("TextButton")
serverHopBtn.Size = UDim2.new(1, 0, 0, 40)
serverHopBtn.Position = UDim2.new(0, 0, 0, 90)
serverHopBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
serverHopBtn.BorderSizePixel = 0
serverHopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
serverHopBtn.Font = Enum.Font.GothamBold
serverHopBtn.TextSize = 18
serverHopBtn.Text = "Server Hop"
serverHopBtn.AutoButtonColor = false
serverHopBtn.Parent = othersTab

serverHopBtn.MouseButton1Click:Connect(function()
    TeleportService:Teleport(game.PlaceId, player)
end)

local fpsBoostBtn = Instance.new("TextButton")
fpsBoostBtn.Size = UDim2.new(1, 0, 0, 40)
fpsBoostBtn.Position = UDim2.new(0, 0, 0, 140)
fpsBoostBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
fpsBoostBtn.BorderSizePixel = 0
fpsBoostBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
fpsBoostBtn.Font = Enum.Font.GothamBold
fpsBoostBtn.TextSize = 18
fpsBoostBtn.Text = "Toggle FPS Boost"
fpsBoostBtn.AutoButtonColor = false
fpsBoostBtn.Parent = othersTab

local fpsBoostEnabled = false
fpsBoostBtn.MouseButton1Click:Connect(function()
    fpsBoostEnabled = not fpsBoostEnabled
    if fpsBoostEnabled then
        settings().Rendering.QualityLevel = 1
        fpsBoostBtn.Text = "FPS Boost: ON"
        fpsBoostBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
    else
        settings().Rendering.QualityLevel = 10
        fpsBoostBtn.Text = "FPS Boost: OFF"
        fpsBoostBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end)

-- BrainRot Filter System
local brainRotLabel = Instance.new("TextLabel")
brainRotLabel.Size = UDim2.new(1, 0, 0, 20)
brainRotLabel.Position = UDim2.new(0, 0, 0, 190)
brainRotLabel.BackgroundTransparency = 1
brainRotLabel.Text = "BrainRot Filter:"
brainRotLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
brainRotLabel.Font = Enum.Font.GothamBold
brainRotLabel.TextSize = 18
brainRotLabel.TextXAlignment = Enum.TextXAlignment.Left
brainRotLabel.Parent = othersTab

local brainRotDropdown = Instance.new("TextButton")
brainRotDropdown.Size = UDim2.new(1, 0, 0, 40)
brainRotDropdown.Position = UDim2.new(0, 0, 0, 215)
brainRotDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
brainRotDropdown.BorderSizePixel = 0
brainRotDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
brainRotDropdown.Font = Enum.Font.GothamBold
brainRotDropdown.TextSize = 18
brainRotDropdown.Text = "Any  ▼"
brainRotDropdown.AutoButtonColor = false
brainRotDropdown.Parent = othersTab

local brainRotOptionsFrame = Instance.new("Frame")
brainRotOptionsFrame.Size = UDim2.new(1, 0, 0, 0)
brainRotOptionsFrame.Position = UDim2.new(0, 0, 0, 255)
brainRotOptionsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
brainRotOptionsFrame.BorderSizePixel = 0
brainRotOptionsFrame.ClipsDescendants = true
brainRotOptionsFrame.ZIndex = 2
brainRotOptionsFrame.Parent = othersTab

local brainRotScrollingFrame = Instance.new("ScrollingFrame")
brainRotScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
brainRotScrollingFrame.Position = UDim2.new(0, 0, 0, 0)
brainRotScrollingFrame.BackgroundTransparency = 1
brainRotScrollingFrame.ScrollBarThickness = 6
brainRotScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, #brainRotOptions * 40)
brainRotScrollingFrame.Parent = brainRotOptionsFrame

local isBrainRotDropdownOpen = false

local function toggleBrainRotDropdown()
    if isBrainRotDropdownOpen then
        brainRotOptionsFrame:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        brainRotDropdown.Text = selectedBrainRot.."  ▼"
    else
        brainRotOptionsFrame:TweenSize(UDim2.new(1, 0, 0, math.min(#brainRotOptions * 40, 200)), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        brainRotDropdown.Text = selectedBrainRot.."  ▲"
    end
    isBrainRotDropdownOpen = not isBrainRotDropdownOpen
end

brainRotDropdown.MouseButton1Click:Connect(toggleBrainRotDropdown)

for i, brainRot in ipairs(brainRotOptions) do
    local option = Instance.new("TextButton")
    option.Size = UDim2.new(1, 0, 0, 40)
    option.Position = UDim2.new(0, 0, 0, (i-1)*40)
    option.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    option.BorderSizePixel = 0
    option.Text = brainRot
    option.TextColor3 = Color3.fromRGB(255, 255, 255)
    option.Font = Enum.Font.GothamBold
    option.TextSize = 18
    option.AutoButtonColor = false
    option.ZIndex = 3
    option.Parent = brainRotScrollingFrame
    
    option.MouseButton1Click:Connect(function()
        selectedBrainRot = brainRot
        toggleBrainRotDropdown()
    end)
end

-- Settings Management (Simplified without auto-load)
local function saveSettings()
    local settings = {
        mpsRange = selectedMpsRange,
        brainRot = selectedBrainRot
    }
    
    pcall(function()
        writefile("AutoJoinerSettings.json", HttpService:JSONEncode(settings))
    end)
end

local function loadSettings()
    -- Set defaults first
    selectedMpsRange = "1M-3M"
    selectedBrainRot = "Any"
    
    -- Try to load saved settings
    local success, savedSettings = pcall(function()
        return HttpService:JSONDecode(readfile("AutoJoinerSettings.json"))
    end)
    
    if success and savedSettings then
        if savedSettings.mpsRange and table.find({"1M-3M", "3M-5M", "5M+"}, savedSettings.mpsRange) then
            selectedMpsRange = savedSettings.mpsRange
        end
        
        if savedSettings.brainRot and table.find(brainRotOptions, savedSettings.brainRot) then
            selectedBrainRot = savedSettings.brainRot
        end
    end
    
    -- Update UI
    mpsDropdown.Text = selectedMpsRange.."  ▼"
    brainRotDropdown.Text = selectedBrainRot.."  ▼"
end

-- =================================================================
-- Enhanced Connection System with WebSocket/HTTP Fallback
-- =================================================================

local function fetchServersHTTP()
    local success, response = pcall(function()
        return game:HttpGet(HTTP_FALLBACK_URL)
    end)
    
    if success then
        return response
    else
        warn("HTTP Fallback failed:", response)
        return nil
    end
end

local function handleServerData(message)
    if not isRunning or isPaused then
        print("[DEBUG] Ignoring message - script not running")
        return
    end

    print("[SERVER] Processing:", message)

    -- Safely parse JSON with error handling
    local data
    local success, err = pcall(function()
        data = HttpService:JSONDecode(message)
    end)
    
    if not success or type(data) ~= "table" then
        warn("[ERROR] Failed to parse server data:", err)
        statusLabel.Text = "Status: Invalid server data"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    -- Validate required fields with type checking
    if type(data.jobId) ~= "string" or type(data.moneyPerSec) ~= "string" then
        warn("[ERROR] Missing or invalid jobId/moneyPerSec")
        return
    end

    -- Clean and extract data
    local jobId = tostring(data.jobId):gsub("[%s'\"]", "") -- Remove whitespace/quotes
    local mpsText = data.moneyPerSec:match("([%d%.]+)M")
    local serverName = data.serverName or "Unknown"
    
    -- Convert MPS to number
    local mps = tonumber(mpsText)
    if not mps then
        warn("[ERROR] Invalid MPS value:", data.moneyPerSec)
        return
    end

    -- Process Job ID (supports encoded IDs)
    local processedId = processJobId(jobId)
    if not processedId then
        warn("[ERROR] Invalid Job ID format:", jobId)
        return
    end

    -- Detect brainrot type
    local detectedBrainRot = detectBrainRot(serverName)
    
    -- Apply filters
    local shouldJoin = true
    
    -- BrainRot filter
    if selectedBrainRot ~= "Any" and detectedBrainRot ~= selectedBrainRot then
        print(string.format("[FILTER] Skipping %s (BrainRot: wanted %s, got %s)", 
              string.sub(processedId, 1, 8), selectedBrainRot, detectedBrainRot))
        shouldJoin = false
    end
    
    -- MPS filter
    if selectedMpsRange == "1M-3M" and not (mps >= 1 and mps <= 3) then
        print(string.format("[FILTER] Skipping %s (MPS: %.1f not in 1M-3M)", 
              string.sub(processedId, 1, 8), mps))
        shouldJoin = false
    elseif selectedMpsRange == "3M-5M" and not (mps > 3 and mps <= 5) then
        print(string.format("[FILTER] Skipping %s (MPS: %.1f not in 3M-5M)", 
              string.sub(processedId, 1, 8), mps))
        shouldJoin = false
    elseif selectedMpsRange == "5M+" and not (mps > 5) then
        print(string.format("[FILTER] Skipping %s (MPS: %.1f not >5M)", 
              string.sub(processedId, 1, 8), mps))
        shouldJoin = false
    end
    
    -- Take action
    if shouldJoin then
        print(string.format("[JOINING] %s (%.1fM/s %s)", 
              string.sub(processedId, 1, 8), mps, detectedBrainRot))
        statusLabel.Text = string.format("Joining %s...", string.sub(processedId, 1, 8))
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        attemptTeleport(processedId)
    else
        print(string.format("[FILTERED] %s (%.1fM/s %s)", 
              string.sub(processedId, 1, 8), mps, detectedBrainRot))
    end
end

-- =================================================================
-- Enhanced Teleport Function with Encoded ID Support
-- =================================================================

local function attemptTeleport(jobId)
    if not isRunning or isPaused then 
        print("[DEBUG] Teleport blocked - script not running or paused")
        return false 
    end
    
    -- Cooldown check (2-second delay between hops)
    local currentTime = os.time()
    if currentTime - lastHopTime < HOP_INTERVAL then
        local waitTime = HOP_INTERVAL - (currentTime - lastHopTime)
        print(string.format("[TELEPORT] Waiting %.1fs cooldown", waitTime))
        task.wait(waitTime)
    end

    -- Skip if server was joined recently (30-minute memory)
    if recentServers[jobId] then
        print("[TELEPORT] Skipping recently joined server:", string.sub(jobId, 1, 8))
        return false
    end

    -- Attempt teleport with error handling
    print("[TELEPORT] Attempting to join:", string.sub(jobId, 1, 8))
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
    end)

    if success then
        -- Update state on success
        lastHopTime = os.time()
        activeJobId = jobId
        recentServers[jobId] = os.time()
        serverInfoLabel.Text = "Joining: "..string.sub(jobId, 1, 8).."..."
        print("[SUCCESS] Teleport initiated to", string.sub(jobId, 1, 8))
        return true
    else
        warn("[ERROR] Teleport failed:", err)
        statusLabel.Text = "Teleport failed!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        return false
    end
end

-- =================================================================
-- WebSocket Connection Management
-- =================================================================

local function connectWebSocket()
    if not isRunning then return end
    
    print("[WEBSOCKET] Attempting connection...")
    connectionAttempts = connectionAttempts + 1
    statusLabel.Text = string.format("Connecting (%d/%d)...", connectionAttempts, MAX_RETRIES)
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    
    -- Close existing connection
    if socket then
        pcall(function() socket:Close() end)
        socket = nil
    end
    
    local success, err = pcall(function()
        socket = WebSocket.connect(WEBSOCKET_URL)
        
        print("[WEBSOCKET] Connection established")
        
        socket.OnMessage:Connect(function(message)
            print("[WEBSOCKET] Received message")
            handleServerData(message)
        end)
        
        socket.OnClose:Connect(function()
            print("[WEBSOCKET] Connection closed")
            if isRunning and not isPaused and connectionAttempts < MAX_RETRIES then
                task.wait(RECONNECT_DELAY)
                connectWebSocket()
            elseif isRunning then
                useWebSocket = false
                statusLabel.Text = "Status: Switching to HTTP"
                task.wait(2)
                fetchServersHTTP()
            end
        end)
        
        connectionAttempts = 0
        useWebSocket = true
        statusLabel.Text = "Status: Connected (WS)"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end)
    
    if not success then
        warn("[WEBSOCKET] Connection failed:", err)
        if connectionAttempts < MAX_RETRIES then
            task.wait(RECONNECT_DELAY)
            connectWebSocket()
        else
            useWebSocket = false
            statusLabel.Text = "Status: Using HTTP Fallback"
            task.wait(2)
            fetchServersHTTP()
        end
    end
end

-- =================================================================
-- Control Handlers
-- =================================================================

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

-- =================================================================
-- Server History Cleanup
-- =================================================================

task.spawn(function()
    while true do
        task.wait(300) -- Clean every 5 minutes
        local currentTime = os.time()
        for id, time in pairs(recentServers) do
            if currentTime - time > SERVER_HISTORY_EXPIRE then
                recentServers[id] = nil
            end
        end
    end
end)

-- =================================================================
-- Tab Switching
-- =================================================================

local function switchTab(tabName)
    currentTab = tabName
    for name, tab in pairs(tabContents) do
        tab.Visible = (name == tabName)
    end
    
    for _, btn in ipairs(tabButtons) do
        if btn.Text == tabName then
            btn.BackgroundColor3 = Color3.fromRGB(90, 0, 90)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
end

autoJoinerTabBtn.MouseButton1Click:Connect(function() switchTab("AutoJoiner") end)
othersTabBtn.MouseButton1Click:Connect(function() switchTab("Others") end)

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
        print("Selected BrainRot:", selectedBrainRot)
        print("Connection Attempts:", connectionAttempts)
        print("Current Tab:", currentTab)
        print("=========================")
    end
end)

-- Initialize
loadSettings()
switchTab("AutoJoiner")

-- Cleanup
player.AncestryChanged:Connect(function(_, parent)
    if not parent and socket then
        pcall(function() socket:Close() end)
    end
end)
