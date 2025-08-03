-- AutoJoiner with Perfect BrainRot Detection
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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
local selectedBrainRot = "Any"
local connectionAttempts = 0
local currentTab = "AutoJoiner"

-- Enhanced BrainRot Detection
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

local titleText = "AutoJoiner"
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
tabContentContainer.Size = UDim2.new(1, -40, 0, 450)
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
othersTitle.Text = "Other Utilities"
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

-- Create a ScrollingFrame to contain the options
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

-- Auto-Load Toggle
local autoLoadLabel = Instance.new("TextLabel")
autoLoadLabel.Size = UDim2.new(1, 0, 0, 20)
autoLoadLabel.Position = UDim2.new(0, 0, 0, 310)
autoLoadLabel.BackgroundTransparency = 1
autoLoadLabel.Text = "Auto-Load Script:"
autoLoadLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
autoLoadLabel.Font = Enum.Font.GothamBold
autoLoadLabel.TextSize = 18
autoLoadLabel.TextXAlignment = Enum.TextXAlignment.Left
autoLoadLabel.Parent = othersTab

local autoLoadToggle = Instance.new("TextButton")
autoLoadToggle.Size = UDim2.new(1, 0, 0, 40)
autoLoadToggle.Position = UDim2.new(0, 0, 0, 335)
autoLoadToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
autoLoadToggle.BorderSizePixel = 0
autoLoadToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
autoLoadToggle.Font = Enum.Font.GothamBold
autoLoadToggle.TextSize = 18
autoLoadToggle.Text = "OFF"
autoLoadToggle.AutoButtonColor = false
autoLoadToggle.Parent = othersTab

-- Settings Management
local function saveSettings()
    local settings = {
        mpsRange = selectedMpsRange,
        brainRot = selectedBrainRot,
        autoLoad = autoLoadToggle.Text == "ON"
    }
    
    pcall(function()
        writefile("AutoJoinerSettings.json", HttpService:JSONEncode(settings))
    end)
end

local function loadSettings()
    local success, savedSettings = pcall(function()
        return HttpService:JSONDecode(readfile("AutoJoinerSettings.json"))
    end)
    
    if success and savedSettings then
        selectedMpsRange = savedSettings.mpsRange or "1M-3M"
        selectedBrainRot = savedSettings.brainRot or "Any"
        if savedSettings.autoLoad then
            autoLoadToggle.Text = "ON"
            autoLoadToggle.TextColor3 = Color3.fromRGB(100, 255, 100)
            isRunning = true
            connectWebSocket()
        end
        
        -- Update dropdown displays
        mpsDropdown.Text = selectedMpsRange.."  ▼"
        brainRotDropdown.Text = selectedBrainRot.."  ▼"
    end
end

autoLoadToggle.MouseButton1Click:Connect(function()
    if autoLoadToggle.Text == "OFF" then
        autoLoadToggle.Text = "ON"
        autoLoadToggle.TextColor3 = Color3.fromRGB(100, 255, 100)
        isRunning = true
        connectWebSocket()
    else
        autoLoadToggle.Text = "OFF"
        autoLoadToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        isRunning = false
        if socket then
            pcall(function() socket:Close() end)
            socket = nil
        end
    end
    saveSettings()
end)

-- Tab Switching
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

-- WebSocket Functions
local function attemptTeleport(jobId)
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
    
    -- Extract data from JSON
    local jobId = data.jobId
    local serverName = data.serverName or "Unknown"
    local mpsText = data.moneyPerSec and data.moneyPerSec:match("([%d%.]+)M")
    
    -- Detect brainrot type using enhanced function
    local detectedBrainRot = detectBrainRot(serverName)
    
    -- Validate required fields
    if not jobId or not mpsText then
        statusLabel.Text = "Status: Missing data"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        print("[ERROR] Missing jobId or moneyPerSec in:", data)
        return
    end
    
    -- Convert MPS to number
    local mps = tonumber(mpsText)
    if not mps then
        statusLabel.Text = "Status: Invalid MPS value"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    -- Apply BrainRot filter first (if not set to "Any")
    local brainRotMatch = (selectedBrainRot == "Any") or (detectedBrainRot == selectedBrainRot)
    if not brainRotMatch then
        statusLabel.Text = string.format("Skipping %s (Not %s)", string.sub(jobId, 1, 8), selectedBrainRot)
        statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        print(string.format("Skipped server %s - Wanted %s, got %s", string.sub(jobId, 1, 8), selectedBrainRot, detectedBrainRot))
        return
    end
    
    -- Apply MPS filter (only if BrainRot matches)
    local shouldJoin = false
    local mpsMillions = mps
    
    if selectedMpsRange == "1M-3M" then
        shouldJoin = (mpsMillions >= 1 and mpsMillions <= 3)
    elseif selectedMpsRange == "3M-5M" then
        shouldJoin = (mpsMillions > 3 and mpsMillions <= 5)
    elseif selectedMpsRange == "5M+" then
        shouldJoin = (mpsMillions > 5)
    end
    
    -- Take action
    if shouldJoin then
        statusLabel.Text = string.format("Joining %s (%.1fM/s, %s)", string.sub(jobId, 1, 8), mpsMillions, detectedBrainRot)
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        attemptTeleport(jobId)
    else
        statusLabel.Text = string.format("Skipping %s (%.1fM/s, %s)", string.sub(jobId, 1, 8), mpsMillions, detectedBrainRot)
        statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
    end
    
    print(string.format("Parsed - JobID: %s | Server: %s | MPS: %.1fM | BrainRot: %s | Action: %s",
        jobId, serverName, mpsMillions, detectedBrainRot, shouldJoin and "Joining" or "Skipping"))
end

local function connectWebSocket()
    if not isRunning then return end
    
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
        print("Selected BrainRot:", selectedBrainRot)
        print("Auto-Load:", autoLoadToggle.Text)
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

-- Auto-execute functionality
local function autoExecute()
    if autoLoadToggle.Text == "ON" then
        isRunning = true
        connectWebSocket()
    end
end

-- Run auto-execute after a short delay to ensure everything is loaded
task.delay(1, autoExecute)
