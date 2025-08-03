print("AutoJoiner v3.6 - Complete Integration")

-- Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Configuration
local WEBSOCKET_URL = "wss://cd9df660-ee00-4af8-ba05-5112f2b5f870-00-xh16qzp1xfp5.janeway.replit.dev/"
local HOP_INTERVAL = 2.5 -- seconds between hops
local RECONNECT_DELAY = 5
local MAX_RETRIES = 3
local CHECK_INTERVAL = 0.3 -- Clipboard check interval
local MAX_CLIPBOARD_LENGTH = 200 -- Prevent excessively long strings
local MAX_PASTE_ATTEMPTS = 5 -- Max attempts to paste to Chilli Hub
local ELEMENT_WAIT_TIME = 0.5 -- Time between element detection attempts

-- Device Detection
local IS_ANDROID = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
local IS_EMULATOR = false

local function checkForEmulator()
    if IS_ANDROID then
        local emulatorKeywords = {"bluestacks", "memu", "nox", "ldplayer", "gameloop", "genymotion"}
        local deviceInfo = tostring(os.getenv("ANDROID_ROOT") or ""):lower()
        
        for _, keyword in ipairs(emulatorKeywords) do
            if deviceInfo:find(keyword) then
                IS_EMULATOR = true
                break
            end
        end
    end
    return IS_EMULATOR
end

-- State
local player = Players.LocalPlayer or Players:GetPlayers()[1]
local socket = nil
local isRunning = false
local isPaused = false
local lastHopTime = 0
local activeJobId = nil
local selectedMpsRange = "1M-3M"
local connectionAttempts = 0
local lastClipboard = ""
local AUTO_PASTE_ENABLED = true

-- Wait for player GUI
repeat task.wait() until player and player:FindFirstChild("PlayerGui")
local playerGui = player:WaitForChild("PlayerGui")

-- Helper Functions
local function isValidJobId(jobId)
    return jobId and type(jobId) == "string" and #jobId >= 22 and #jobId <= MAX_CLIPBOARD_LENGTH
end

-- Enhanced Clipboard Functions
local function updateClipboardStatus()
    local currentClip = readclipboard() or ""
    if currentClip == "" then
        clipboardStatus.Text = "Clipboard: Empty"
        clipboardStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
    elseif not isValidJobId(currentClip) then
        clipboardStatus.Text = "Clipboard: Invalid Job ID"
        clipboardStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        clipboardStatus.Text = "Clipboard: Valid Job ID"
        clipboardStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end

local function monitorClipboard()
    while AUTO_PASTE_ENABLED and isRunning do
        local currentClip = readclipboard() or ""
        updateClipboardStatus()

        if currentClip ~= lastClipboard and isValidJobId(currentClip) then
            lastClipboard = currentClip
            clipboardStatus.Text = "Processing Job ID..."
            clipboardStatus.TextColor3 = Color3.fromRGB(255, 255, 100)
            
            local success = joinChilliHub(currentClip)
            if success then
                clipboardStatus.Text = "Joined successfully!"
                clipboardStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
                writeclipboard("")
                lastClipboard = ""
            else
                clipboardStatus.Text = "Failed - Trying teleport"
                clipboardStatus.TextColor3 = Color3.fromRGB(255, 150, 100)
                attemptTeleport(currentClip)
            end
        end
        
        task.wait(CHECK_INTERVAL)
    end
end

local function findFirstMatchingElement(parent, className, matchFunction)
    for _, child in ipairs(parent:GetDescendants()) do
        if child:IsA(className) and matchFunction(child) then
            return child
        end
    end
    return nil
end

local function joinChilliHub(jobId)
    if not isValidJobId(jobId) then 
        warn("Invalid Job ID format")
        return false 
    end

    print("Attempting to join Chilli Hub with Job ID:", string.sub(jobId, 1, 8).."...")
    
    local inputField, joinButton
    local attempts = 0
    
    while attempts < MAX_PASTE_ATTEMPTS do
        inputField = playerGui:FindFirstChild("JobIDInput", true) or
                   playerGui:FindFirstChild("JobIdInput", true) or
                   playerGui:FindFirstChild("Job-ID Input", true) or
                   playerGui:FindFirstChild("JobID", true) or
                   findFirstMatchingElement(playerGui, "TextBox", function(tb)
                       return (tb.PlaceholderText and tb.PlaceholderText:lower():find("job id")) or
                              (tb.Name:lower():find("job"))
                   end)
        
        joinButton = playerGui:FindFirstChild("Join Job-ID", true) or
                   playerGui:FindFirstChild("JoinButton", true) or
                   playerGui:FindFirstChild("JoinBtn", true) or
                   playerGui:FindFirstChild("Join", true) or
                   findFirstMatchingElement(playerGui, "TextButton", function(btn)
                       return btn.Text and btn.Text:lower():find("join")
                   end)
        
        if inputField and joinButton then
            print("Found Chilli Hub elements")
            break
        end
        
        attempts += 1
        warn("Attempt", attempts, "/", MAX_PASTE_ATTEMPTS, "- Missing elements")
        task.wait(ELEMENT_WAIT_TIME)
    end

    if not inputField or not joinButton then
        warn("Failed to find required elements")
        return false
    end

    -- Enhanced pasting with verification
    local pasteAttempts = 0
    local pasteSuccess = false
    
    while pasteAttempts < 3 and not pasteSuccess do
        inputField.Text = jobId
        task.wait(0.3)
        
        if inputField.Text == jobId then
            pasteSuccess = true
        else
            pasteAttempts += 1
        end
    end

    if not pasteSuccess then
        warn("Failed to paste Job ID")
        return false
    end

    -- Enhanced button clicking with verification
    for i = 1, 3 do
        if joinButton:IsA("TextButton") then
            local originalText = joinButton.Text
            joinButton.Text = "Joining..."
            joinButton:Fire("MouseButton1Click")
            task.wait(0.2)
            
            if joinButton.Text ~= originalText then
                return true
            end
        end
        task.wait(0.3)
    end
    
    warn("Failed to verify join button click")
    return false
end

-- GUI Creation
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoJoinerGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 350, 0, 600)
frame.Position = UDim2.new(0.5, -175, 0.5, -300)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.BorderSizePixel = 1
frame.BorderColor3 = Color3.fromRGB(60, 60, 70)
frame.Visible = true
frame.Parent = screenGui

-- Draggable Logic
local dragging, dragInput, dragStart, startPos

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
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Rainbow Title Animation
local rainbowColors = {
    Color3.fromRGB(255, 0, 0),    -- Red
    Color3.fromRGB(255, 127, 0),  -- Orange
    Color3.fromRGB(255, 255, 0),  -- Yellow
    Color3.fromRGB(0, 255, 0),    -- Green
    Color3.fromRGB(0, 0, 255),    -- Blue
    Color3.fromRGB(75, 0, 130),   -- Indigo
    Color3.fromRGB(148, 0, 211)   -- Violet
}

local titleContainer = Instance.new("Frame")
titleContainer.Size = UDim2.new(1, -40, 0, 50)
titleContainer.Position = UDim2.new(0, 20, 0, 15)
titleContainer.BackgroundTransparency = 1
titleContainer.Parent = frame

local titleText = "AUTO JOINER"
local charLabels = {}

for i = 1, #titleText do
    local charLabel = Instance.new("TextLabel")
    charLabel.Size = UDim2.new(0, 20, 1, 0)
    charLabel.Position = UDim2.new(0, (i-1)*20, 0, 0)
    charLabel.BackgroundTransparency = 1
    charLabel.Text = titleText:sub(i,i)
    charLabel.TextColor3 = rainbowColors[(i-1) % #rainbowColors + 1]
    charLabel.Font = Enum.Font.GothamBlack
    charLabel.TextSize = 24
    charLabel.TextXAlignment = Enum.TextXAlignment.Left
    charLabel.Parent = titleContainer
    table.insert(charLabels, charLabel)
end

coroutine.wrap(function()
    local waveOffset = 0
    while true do
        for i, label in ipairs(charLabels) do
            label.TextColor3 = rainbowColors[(i + waveOffset) % #rainbowColors + 1]
        end
        waveOffset = (waveOffset + 1) % (#rainbowColors * 2)
        task.wait(0.05)
    end
end)()

-- Status Labels
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -40, 0, 20)
statusLabel.Position = UDim2.new(0, 20, 0, 80)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Disconnected"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

local serverInfoLabel = Instance.new("TextLabel")
serverInfoLabel.Size = UDim2.new(1, -40, 0, 20)
serverInfoLabel.Position = UDim2.new(0, 20, 0, 105)
serverInfoLabel.BackgroundTransparency = 1
serverInfoLabel.Text = "Server: None"
serverInfoLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
serverInfoLabel.Font = Enum.Font.GothamMedium
serverInfoLabel.TextSize = 14
serverInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
serverInfoLabel.Parent = frame

-- Clipboard Status Label
local clipboardStatus = Instance.new("TextLabel")
clipboardStatus.Size = UDim2.new(1, -40, 0, 20)
clipboardStatus.Position = UDim2.new(0, 20, 0, 130)
clipboardStatus.BackgroundTransparency = 1
clipboardStatus.Text = "Clipboard: Ready"
clipboardStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
clipboardStatus.Font = Enum.Font.GothamMedium
clipboardStatus.TextSize = 14
clipboardStatus.TextXAlignment = Enum.TextXAlignment.Left
clipboardStatus.Parent = frame

-- Device Info Label
local deviceLabel = Instance.new("TextLabel")
deviceLabel.Size = UDim2.new(1, -40, 0, 20)
deviceLabel.Position = UDim2.new(0, 20, 0, 155)
deviceLabel.BackgroundTransparency = 1
deviceLabel.Text = "Device: "..(IS_ANDROID and "Android" or "Desktop")..(IS_EMULATOR and " (Emulator)" or "")
deviceLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
deviceLabel.Font = Enum.Font.GothamMedium
deviceLabel.TextSize = 14
deviceLabel.TextXAlignment = Enum.TextXAlignment.Left
deviceLabel.Parent = frame

-- MPS Dropdown System
local mpsLabel = Instance.new("TextLabel")
mpsLabel.Size = UDim2.new(1, -40, 0, 20)
mpsLabel.Position = UDim2.new(0, 20, 0, 180)
mpsLabel.BackgroundTransparency = 1
mpsLabel.Text = "Select MPS Range:"
mpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
mpsLabel.Font = Enum.Font.GothamBold
mpsLabel.TextSize = 16
mpsLabel.TextXAlignment = Enum.TextXAlignment.Left
mpsLabel.Parent = frame

local mpsDropdown = Instance.new("TextButton")
mpsDropdown.Size = UDim2.new(1, -40, 0, 35)
mpsDropdown.Position = UDim2.new(0, 20, 0, 205)
mpsDropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
mpsDropdown.BorderSizePixel = 1
mpsDropdown.BorderColor3 = Color3.fromRGB(80, 80, 90)
mpsDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
mpsDropdown.Font = Enum.Font.GothamBold
mpsDropdown.TextSize = 16
mpsDropdown.Text = "1M-3M ▼"
mpsDropdown.AutoButtonColor = false
mpsDropdown.Parent = frame

local optionsFrame = Instance.new("Frame")
optionsFrame.Size = UDim2.new(1, -40, 0, 0)
optionsFrame.Position = UDim2.new(0, 20, 0, 240)
optionsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
optionsFrame.BorderSizePixel = 1
optionsFrame.BorderColor3 = Color3.fromRGB(70, 70, 80)
optionsFrame.ClipsDescendants = true
optionsFrame.ZIndex = 2
optionsFrame.Parent = frame

local mpsRanges = {"1M-3M", "3M-5M", "5M-9.9M", "10M+"}
local isDropdownOpen = false

local function toggleDropdown()
    if isDropdownOpen then
        optionsFrame:TweenSize(UDim2.new(1, -40, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        mpsDropdown.Text = selectedMpsRange.." ▼"
    else
        optionsFrame:TweenSize(UDim2.new(1, -40, 0, #mpsRanges * 35), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        mpsDropdown.Text = selectedMpsRange.." ▲"
    end
    isDropdownOpen = not isDropdownOpen
end

mpsDropdown.MouseButton1Click:Connect(toggleDropdown)

for i, range in ipairs(mpsRanges) do
    local option = Instance.new("TextButton")
    option.Size = UDim2.new(1, 0, 0, 35)
    option.Position = UDim2.new(0, 0, 0, (i-1)*35)
    option.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    option.BorderSizePixel = 0
    option.Text = range
    option.TextColor3 = Color3.fromRGB(255, 255, 255)
    option.Font = Enum.Font.GothamBold
    option.TextSize = 16
    option.AutoButtonColor = false
    option.ZIndex = 3
    option.Parent = optionsFrame
    
    option.MouseButton1Click:Connect(function()
        selectedMpsRange = range
        toggleDropdown()
        statusLabel.Text = "Status: Filter set to "..range
        statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    end)
end

-- Auto-Paste Toggle
local pasteToggle = Instance.new("TextButton")
pasteToggle.Size = UDim2.new(1, -40, 0, 35)
pasteToggle.Position = UDim2.new(0, 20, 0, 370)
pasteToggle.BackgroundColor3 = AUTO_PASTE_ENABLED and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(120, 0, 0)
pasteToggle.BorderSizePixel = 1
pasteToggle.BorderColor3 = AUTO_PASTE_ENABLED and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
pasteToggle.Text = AUTO_PASTE_ENABLED and "AUTO-PASTE: ON" or "AUTO-PASTE: OFF"
pasteToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
pasteToggle.Font = Enum.Font.GothamBold
pasteToggle.TextSize = 16
pasteToggle.AutoButtonColor = false
pasteToggle.Parent = frame

pasteToggle.MouseButton1Click:Connect(function()
    AUTO_PASTE_ENABLED = not AUTO_PASTE_ENABLED
    pasteToggle.BackgroundColor3 = AUTO_PASTE_ENABLED and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(120, 0, 0)
    pasteToggle.BorderColor3 = AUTO_PASTE_ENABLED and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    pasteToggle.Text = AUTO_PASTE_ENABLED and "AUTO-PASTE: ON" or "AUTO-PASTE: OFF"
    clipboardStatus.Text = AUTO_PASTE_ENABLED and "Clipboard: Monitoring" or "Clipboard: Paused"
    
    if AUTO_PASTE_ENABLED and isRunning then
        coroutine.wrap(monitorClipboard)()
    end
end)

-- Control Buttons
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, -40, 0, 40)
startBtn.Position = UDim2.new(0, 20, 0, 420)
startBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
startBtn.BorderSizePixel = 1
startBtn.BorderColor3 = Color3.fromRGB(90, 90, 100)
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 18
startBtn.Text = "START"
startBtn.AutoButtonColor = false
startBtn.Parent = frame

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(1, -40, 0, 40)
stopBtn.Position = UDim2.new(0, 20, 0, 470)
stopBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
stopBtn.BorderSizePixel = 1
stopBtn.BorderColor3 = Color3.fromRGB(90, 90, 100)
stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 18
stopBtn.Text = "STOP"
stopBtn.AutoButtonColor = false
stopBtn.Parent = frame

local resumeBtn = Instance.new("TextButton")
resumeBtn.Size = UDim2.new(1, -40, 0, 40)
resumeBtn.Position = UDim2.new(0, 20, 0, 520)
resumeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
resumeBtn.BorderSizePixel = 1
resumeBtn.BorderColor3 = Color3.fromRGB(90, 90, 100)
resumeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resumeBtn.Font = Enum.Font.GothamBold
resumeBtn.TextSize = 18
resumeBtn.Text = "RESUME"
resumeBtn.AutoButtonColor = false
resumeBtn.Parent = frame

-- Minimize Button
local minimizeBtn = Instance.new("ImageButton")
minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
minimizeBtn.Position = UDim2.new(1, -35, 0, 5)
minimizeBtn.BackgroundTransparency = 1
minimizeBtn.Image = "rbxassetid://3926305904"
minimizeBtn.ImageRectOffset = Vector2.new(284, 4)
minimizeBtn.ImageRectSize = Vector2.new(24, 24)
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = frame

local minimizedImage = Instance.new("ImageButton")
minimizedImage.Size = UDim2.new(0, 40, 0, 40)
minimizedImage.Position = UDim2.new(0, 20, 0, 20)
minimizedImage.BackgroundTransparency = 1
minimizedImage.Image = "rbxassetid://3926305904"
minimizedImage.ImageRectOffset = Vector2.new(284, 4)
minimizedImage.ImageRectSize = Vector2.new(24, 24)
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

-- Teleport Functions
local function attemptTeleport(jobId)
    if not isRunning or isPaused then return false end
    if not isValidJobId(jobId) then return false end
    
    local currentTime = os.time()
    if currentTime - lastHopTime < HOP_INTERVAL then
        local waitTime = HOP_INTERVAL - (currentTime - lastHopTime)
        statusLabel.Text = string.format("Waiting %.1fs...", waitTime)
        statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
        task.wait(waitTime)
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

-- WebSocket Functions
local function handleWebSocketMessage(message)
    if isPaused then return end
    
    print("[WebSocket] Raw message:", message)
    
    local success, data = pcall(HttpService.JSONDecode, HttpService, message)
    
    if not success then
        statusLabel.Text = "Status: Invalid JSON"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        print("[ERROR] Failed to parse JSON:", message)
        return
    end
    
    local jobId = data.jobId
    local serverName = data.serverName
    local mpsText = data.moneyPerSec and data.moneyPerSec:match("([%d%.]+)M")
    
    if not jobId or not mpsText then
        statusLabel.Text = "Status: Missing data"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        print("[ERROR] Missing jobId or moneyPerSec in:", data)
        return
    end
    
    local mps = tonumber(mpsText)
    if not mps then
        statusLabel.Text = "Status: Invalid MPS value"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local shouldJoin = false
    local useChilliHub = false

    if selectedMpsRange == "1M-3M" then
        shouldJoin = (mps >= 1 and mps <= 3)
    elseif selectedMpsRange == "3M-5M" then
        shouldJoin = (mps > 3 and mps <= 5)
    elseif selectedMpsRange == "5M-9.9M" then
        shouldJoin = (mps > 5 and mps <= 9.9)
    elseif selectedMpsRange == "10M+" then
        shouldJoin = (mps >= 10)
        useChilliHub = true
    end
    
    if shouldJoin then
        statusLabel.Text = string.format("Joining %s (%.1fM/s)", string.sub(jobId, 1, 8), mps)
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        if useChilliHub then
            if joinChilliHub(jobId) then
                print("Using Chilli Hub to join 10M+ server")
            else
                attemptTeleport(jobId)
            end
        else
            attemptTeleport(jobId)
        end
    else
        statusLabel.Text = string.format("Skipping %s (%.1fM/s)", string.sub(jobId, 1, 8), mps)
        statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
    end
end

local function connectWebSocket()
    if not isRunning then return end
    
    connectionAttempts += 1
    statusLabel.Text = string.format("Connecting (%d/%d)...", connectionAttempts, MAX_RETRIES)
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    
    if socket then
        pcall(socket.Close, socket)
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
    statusLabel.Text = "Status: Starting..."
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    
    if AUTO_PASTE_ENABLED then
        clipboardStatus.Text = "Clipboard: Monitoring"
    end
    
    connectWebSocket()
    
    if AUTO_PASTE_ENABLED then
        coroutine.wrap(monitorClipboard)()
    end
end)

stopBtn.MouseButton1Click:Connect(function()
    if not isRunning then return end
    isRunning = false
    isPaused = false
    if socket then
        pcall(socket.Close, socket)
        socket = nil
    end
    statusLabel.Text = "Status: Stopped"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    clipboardStatus.Text = "Clipboard: Paused"
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
        print("Running on:", IS_ANDROID and "Android" or "Desktop", IS_EMULATOR and "(Emulator)" or "(Real Device)")
        print("WebSocket URL:", WEBSOCKET_URL)
        print("Connected:", socket and "Yes" or "No")
        print("Running:", isRunning and "Yes" or "No")
        print("Paused:", isPaused and "Yes" or "No")
        print("Last Job ID:", activeJobId or "None")
        print("Selected MPS:", selectedMpsRange)
        print("Connection Attempts:", connectionAttempts)
        print("Auto-Paste:", AUTO_PASTE_ENABLED and "ON" or "OFF")
        print("=========================")
    end
end)

-- Cleanup
player.AncestryChanged:Connect(function(_, parent)
    if not parent and socket then
        pcall(socket.Close, socket)
    end
end)

-- Final GUI visibility check
task.spawn(function()
    task.wait(2)
    if not frame.Visible then
        frame.Visible = true
    end
end)

-- Initialize
checkForEmulator()
print("AutoJoiner initialized!")
print("Running on:", IS_ANDROID and "Android" or "Desktop", IS_EMULATOR and "(Emulator)" or "(Real Device)")

-- Start clipboard monitoring
coroutine.wrap(function()
    while true do
        updateClipboardStatus()
        task.wait(0.3)
    end
end)()

if AUTO_PASTE_ENABLED then
    coroutine.wrap(function()
        task.wait(1)
        monitorClipboard()
    end)()
end
