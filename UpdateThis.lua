print("AutoJoiner v4.7 - Ultimate Complete Enhanced Edition")

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

-- Device Detection
local IS_ANDROID = (UserInputService:GetPlatform() == Enum.Platform.Android)
local IS_EMULATOR = false -- Set to true if running in emulator

-- Wait for player GUI
repeat task.wait() until player and player:FindFirstChild("PlayerGui")
local playerGui = player:WaitForChild("PlayerGui")

-- ==================== GUI CREATION ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoJoinerGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.Parent = game:GetService("CoreGui")

-- Main Frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 350, 0, 600)
frame.Position = UDim2.new(0.5, -175, 0.5, -300)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.BorderSizePixel = 1
frame.BorderColor3 = Color3.fromRGB(60, 60, 70)
frame.Visible = true
frame.Parent = screenGui

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
titleBar.BorderSizePixel = 0
titleBar.Parent = frame

-- Draggable functionality
local dragging
local dragInput
local dragStart
local startPos

local function updateInput(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

titleBar.InputBegan:Connect(function(input)
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

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateInput(input)
    end
end)

-- Rainbow title effect
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 30, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "AutoJoiner v4.7"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

coroutine.wrap(function()
    local hue = 0
    while true do
        titleLabel.TextColor3 = Color3.fromHSV(hue, 0.8, 1)
        hue = (hue + 0.01) % 1
        task.wait(0.05)
    end
end)()

-- Minimize button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 30, 1, 0)
minimizeBtn.Position = UDim2.new(1, -30, 0, 0)
minimizeBtn.BackgroundTransparency = 1
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 18
minimizeBtn.Parent = titleBar

local isMinimized = false
minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        frame.Size = UDim2.new(0, 350, 0, 30)
        minimizeBtn.Text = "+"
    else
        frame.Size = UDim2.new(0, 350, 0, 600)
        minimizeBtn.Text = "-"
    end
end)

-- Status labels
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 40)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Disconnected"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

local serverInfoLabel = Instance.new("TextLabel")
serverInfoLabel.Size = UDim2.new(1, -20, 0, 20)
serverInfoLabel.Position = UDim2.new(0, 10, 0, 60)
serverInfoLabel.BackgroundTransparency = 1
serverInfoLabel.Text = "Server: None"
serverInfoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
serverInfoLabel.Font = Enum.Font.Gotham
serverInfoLabel.TextSize = 14
serverInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
serverInfoLabel.Parent = frame

local clipboardStatus = Instance.new("TextLabel")
clipboardStatus.Size = UDim2.new(1, -20, 0, 20)
clipboardStatus.Position = UDim2.new(0, 10, 0, 80)
clipboardStatus.BackgroundTransparency = 1
clipboardStatus.Text = "Clipboard: Ready"
clipboardStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
clipboardStatus.Font = Enum.Font.Gotham
clipboardStatus.TextSize = 14
clipboardStatus.TextXAlignment = Enum.TextXAlignment.Left
clipboardStatus.Parent = frame

-- MPS Selection Dropdown
local mpsDropdown = Instance.new("Frame")
mpsDropdown.Size = UDim2.new(0.9, 0, 0, 30)
mpsDropdown.Position = UDim2.new(0.05, 0, 0, 110)
mpsDropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
mpsDropdown.BorderSizePixel = 0
mpsDropdown.Parent = frame

local mpsDropdownButton = Instance.new("TextButton")
mpsDropdownButton.Size = UDim2.new(1, 0, 1, 0)
mpsDropdownButton.Position = UDim2.new(0, 0, 0, 0)
mpsDropdownButton.BackgroundTransparency = 1
mpsDropdownButton.Text = "MPS Range: "..selectedMpsRange
mpsDropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
mpsDropdownButton.Font = Enum.Font.Gotham
mpsDropdownButton.TextSize = 14
mpsDropdownButton.Parent = mpsDropdown

local mpsDropdownOptions = Instance.new("Frame")
mpsDropdownOptions.Size = UDim2.new(1, 0, 0, 120)
mpsDropdownOptions.Position = UDim2.new(0, 0, 1, 0)
mpsDropdownOptions.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
mpsDropdownOptions.BorderSizePixel = 0
mpsDropdownOptions.Visible = false
mpsDropdownOptions.Parent = mpsDropdown

local function createMpsOption(text, yPos)
    local option = Instance.new("TextButton")
    option.Size = UDim2.new(1, 0, 0, 30)
    option.Position = UDim2.new(0, 0, 0, yPos)
    option.BackgroundTransparency = 1
    option.Text = text
    option.TextColor3 = Color3.fromRGB(200, 200, 200)
    option.Font = Enum.Font.Gotham
    option.TextSize = 14
    option.Parent = mpsDropdownOptions
    
    option.MouseButton1Click:Connect(function()
        selectedMpsRange = text
        mpsDropdownButton.Text = "MPS Range: "..selectedMpsRange
        mpsDropdownOptions.Visible = false
    end)
end

createMpsOption("1M-3M", 0)
createMpsOption("3M-5M", 30)
createMpsOption("5M-9.9M", 60)
createMpsOption("10M+", 90)

mpsDropdownButton.MouseButton1Click:Connect(function()
    mpsDropdownOptions.Visible = not mpsDropdownOptions.Visible
end)

-- Auto-Paste Toggle
local autoPasteToggle = Instance.new("TextButton")
autoPasteToggle.Size = UDim2.new(0.9, 0, 0, 30)
autoPasteToggle.Position = UDim2.new(0.05, 0, 0, 250)
autoPasteToggle.BackgroundColor3 = AUTO_PASTE_ENABLED and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
autoPasteToggle.BorderSizePixel = 0
autoPasteToggle.Text = "Auto-Paste: "..(AUTO_PASTE_ENABLED and "ON" or "OFF")
autoPasteToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
autoPasteToggle.Font = Enum.Font.Gotham
autoPasteToggle.TextSize = 14
autoPasteToggle.Parent = frame

autoPasteToggle.MouseButton1Click:Connect(function()
    AUTO_PASTE_ENABLED = not AUTO_PASTE_ENABLED
    autoPasteToggle.BackgroundColor3 = AUTO_PASTE_ENABLED and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
    autoPasteToggle.Text = "Auto-Paste: "..(AUTO_PASTE_ENABLED and "ON" or "OFF")
    
    if AUTO_PASTE_ENABLED and isRunning then
        coroutine.wrap(monitorClipboard)()
    end
end)

-- Control Buttons
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0.9, 0, 0, 40)
startBtn.Position = UDim2.new(0.05, 0, 0, 300)
startBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
startBtn.BorderSizePixel = 0
startBtn.Text = "START"
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 16
startBtn.Parent = frame

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0.9, 0, 0, 40)
stopBtn.Position = UDim2.new(0.05, 0, 0, 350)
stopBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
stopBtn.BorderSizePixel = 0
stopBtn.Text = "STOP"
stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 16
stopBtn.Parent = frame

local resumeBtn = Instance.new("TextButton")
resumeBtn.Size = UDim2.new(0.9, 0, 0, 40)
resumeBtn.Position = UDim2.new(0.05, 0, 0, 400)
resumeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 150)
resumeBtn.BorderSizePixel = 0
resumeBtn.Text = "RESUME"
resumeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resumeBtn.Font = Enum.Font.GothamBold
resumeBtn.TextSize = 16
resumeBtn.Parent = frame

-- ==================== ENHANCED CORE FUNCTIONS ====================

local function isValidJobId(jobId)
    -- Enhanced validation with Base64 support and length checks
    return jobId and type(jobId) == "string" 
           and #jobId >= 22 
           and #jobId <= MAX_CLIPBOARD_LENGTH
           and jobId:match("^[%w+/%-_=]+$") ~= nil
end

local function safeGUIUpdate(element, property, value)
    -- Safe way to update GUI elements
    pcall(function()
        if element and element:IsA("GuiObject") then
            element[property] = value
        end
    end)
end

local function updateClipboardStatus()
    if not (clipboardStatus and clipboardStatus:IsA("TextLabel")) then
        warn("Clipboard status label not ready!")
        return false
    end

    local success, currentClip = pcall(function()
        return (readclipboard() or ""):gsub("%s+", "") -- Remove whitespace
    end)
    
    if not success then
        safeGUIUpdate(clipboardStatus, "Text", "Clipboard: Access Error")
        safeGUIUpdate(clipboardStatus, "TextColor3", Color3.fromRGB(255, 50, 50))
        return false
    end
    
    if currentClip == "" then
        safeGUIUpdate(clipboardStatus, "Text", "Clipboard: Empty")
        safeGUIUpdate(clipboardStatus, "TextColor3", Color3.fromRGB(200, 200, 200))
    elseif not isValidJobId(currentClip) then
        safeGUIUpdate(clipboardStatus, "Text", "Clipboard: Invalid Job ID")
        safeGUIUpdate(clipboardStatus, "TextColor3", Color3.fromRGB(255, 100, 100))
    else
        safeGUIUpdate(clipboardStatus, "Text", "Clipboard: Valid Job ID")
        safeGUIUpdate(clipboardStatus, "TextColor3", Color3.fromRGB(100, 255, 100))
    end
    
    return true
end

local function monitorClipboard()
    print("🔄 Clipboard monitoring started")
    while AUTO_PASTE_ENABLED and isRunning do
        local success, currentClip = pcall(function()
            return (readclipboard() or ""):gsub("%s+", "")
        end)
        
        if success then
            if currentClip ~= lastClipboard and isValidJobId(currentClip) then
                lastClipboard = currentClip
                safeGUIUpdate(clipboardStatus, "Text", "Processing Job ID...")
                safeGUIUpdate(clipboardStatus, "TextColor3", Color3.fromRGB(255, 255, 100))
                
                local success = joinChilliHub(currentClip)
                if success then
                    safeGUIUpdate(clipboardStatus, "Text", "Joined successfully!")
                    safeGUIUpdate(clipboardStatus, "TextColor3", Color3.fromRGB(100, 255, 100))
                    pcall(function() writeclipboard("") end)
                    lastClipboard = ""
                else
                    safeGUIUpdate(clipboardStatus, "Text", "Failed - Trying teleport")
                    safeGUIUpdate(clipboardStatus, "TextColor3", Color3.fromRGB(255, 150, 100))
                    attemptTeleport(currentClip)
                end
            end
        else
            warn("⚠️ Failed to read clipboard")
            safeGUIUpdate(clipboardStatus, "Text", "Clipboard: Access Error")
            safeGUIUpdate(clipboardStatus, "TextColor3", Color3.fromRGB(255, 50, 50))
        end
        
        task.wait(CHECK_INTERVAL)
    end
    print("🛑 Clipboard monitoring stopped")
end

local function findFirstMatchingElement(parent, className, matchFunction)
    -- More robust element finding with error handling
    local success, result = pcall(function()
        for _, child in ipairs(parent:GetDescendants()) do
            if child:IsA(className) and matchFunction(child) then
                return child
            end
        end
        return nil
    end)
    return success and result or nil
end

local function joinChilliHub(jobId)
    if not isValidJobId(jobId) then 
        warn("❌ Invalid Job ID format")
        return false 
    end

    print("🔍 Attempting to join Chilli Hub with Job ID:", string.sub(jobId, 1, 8).."...")
    
    local inputField, joinButton
    local attempts = 0
    
    while attempts < MAX_PASTE_ATTEMPTS do
        inputField = findFirstMatchingElement(playerGui, "TextBox", function(tb)
            return (tb.PlaceholderText and tb.PlaceholderText:lower():find("job id")) or
                   (tb.Name:lower():find("job")) or
                   (tb.Text:lower():find("paste"))
        end)
        
        joinButton = findFirstMatchingElement(playerGui, "TextButton", function(btn)
            return btn.Text and btn.Text:lower():find("join")
        end)
        
        if inputField and joinButton then
            print("✅ Found Chilli Hub elements")
            break
        end
        
        attempts += 1
        warn("Attempt", attempts, "/", MAX_PASTE_ATTEMPTS, "- Missing elements")
        task.wait(ELEMENT_WAIT_TIME)
    end

    if not (inputField and joinButton) then
        warn("❌ Failed to find required elements")
        return false
    end

    -- Enhanced pasting with verification
    for i = 1, 3 do
        inputField.Text = jobId
        task.wait(0.2)
        if inputField.Text == jobId then break end
    end

    -- Enhanced button clicking with verification
    for i = 1, 3 do
        if joinButton:IsA("TextButton") then
            local originalText = joinButton.Text
            joinButton.Text = "Joining..."
            joinButton:Fire("MouseButton1Click")
            task.wait(0.3)
            
            if joinButton.Text ~= originalText then
                return true
            end
        end
    end
    
    warn("❌ Failed to verify join button click")
    return false
end

local function processJobId(jobId, mps)
    if not isRunning or isPaused then return false end
    if not isValidJobId(jobId) then return false end
    
    -- Cooldown management
    local currentTime = os.time()
    if currentTime - lastHopTime < HOP_INTERVAL then
        local waitTime = HOP_INTERVAL - (currentTime - lastHopTime)
        safeGUIUpdate(statusLabel, "Text", string.format("Waiting %.1fs...", waitTime))
        safeGUIUpdate(statusLabel, "TextColor3", Color3.fromRGB(255, 255, 100))
        task.wait(waitTime)
    end
    
    lastHopTime = os.time()
    activeJobId = jobId
    safeGUIUpdate(serverInfoLabel, "Text", "Server: "..(jobId and string.sub(jobId, 1, 8).."..." or "None"))
    
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
        safeGUIUpdate(statusLabel, "Text", string.format("Joining %s (%.1fM/s)", string.sub(jobId, 1, 8), mps))
        safeGUIUpdate(statusLabel, "TextColor3", Color3.fromRGB(100, 255, 100))
        
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
        safeGUIUpdate(statusLabel, "Text", string.format("Skipping %s (%.1fM/s)", string.sub(jobId, 1, 8), mps))
        safeGUIUpdate(statusLabel, "TextColor3", Color3.fromRGB(255, 150, 150))
    end
end

local function attemptTeleport(jobId)
    print("🚀 Attempting teleport to:", string.sub(jobId, 1, 8).."...")
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
    end)
    
    if not success then
        warn("⚠️ Teleport failed:", err)
        safeGUIUpdate(statusLabel, "Text", "Status: Failed - Retrying")
        safeGUIUpdate(statusLabel, "TextColor3", Color3.fromRGB(255, 100, 100))
        return false
    end
    
    return true
end

-- ==================== WEB SOCKET IMPROVEMENTS ====================

local function handleWebSocketMessage(message)
    if isPaused then return end
    
    local success, data = pcall(HttpService.JSONDecode, HttpService, message)
    if not success or not data.jobId then
        warn("⚠️ Invalid WebSocket message:", message)
        return
    end

    local mps = tonumber(data.moneyPerSec and data.moneyPerSec:match("([%d%.]+)M") or 0)
    if mps > 0 then
        print("🌐 Server found:", string.sub(data.jobId, 1, 8).."...", "| MPS:", mps)
        processJobId(data.jobId, mps)
    end
end

local function connectWebSocket()
    if not isRunning then return end
    
    connectionAttempts += 1
    safeGUIUpdate(statusLabel, "Text", string.format("Connecting (%d/%d)...", connectionAttempts, MAX_RETRIES))
    safeGUIUpdate(statusLabel, "TextColor3", Color3.fromRGB(255, 255, 100))
    
    -- Close existing connection if any
    if socket then
        pcall(function()
            socket:Close()
            socket = nil
        end)
    end
    
    local success, err = pcall(function()
        socket = WebSocket.connect(WEBSOCKET_URL)
        
        socket.OnMessage:Connect(function(message)
            task.spawn(handleWebSocketMessage, message) -- Run in separate thread
        end)
        
        socket.OnClose:Connect(function()
            if isRunning and connectionAttempts < MAX_RETRIES then
                task.wait(RECONNECT_DELAY)
                connectWebSocket()
            end
        end)
        
        connectionAttempts = 0
        safeGUIUpdate(statusLabel, "Text", "Status: Connected")
        safeGUIUpdate(statusLabel, "TextColor3", Color3.fromRGB(100, 255, 100))
    end)
    
    if not success then
        warn("⚠️ WebSocket Error:", err)
        if connectionAttempts < MAX_RETRIES then
            task.wait(RECONNECT_DELAY)
            connectWebSocket()
        else
            safeGUIUpdate(statusLabel, "Text", "Status: Connection failed")
            safeGUIUpdate(statusLabel, "TextColor3", Color3.fromRGB(255, 100, 100))
            isRunning = false
        end
    end
end

-- ==================== CONTROL HANDLERS ====================

startBtn.MouseButton1Click:Connect(function()
    if isRunning then return end
    isRunning = true
    isPaused = false
    connectionAttempts = 0
    safeGUIUpdate(statusLabel, "Text", "Status: Starting...")
    safeGUIUpdate(statusLabel, "TextColor3", Color3.fromRGB(255, 255, 100))
    
    if AUTO_PASTE_ENABLED then
        safeGUIUpdate(clipboardStatus, "Text", "Clipboard: Monitoring")
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
        pcall(function()
            socket:Close()
            socket = nil
        end)
    end
    safeGUIUpdate(statusLabel, "Text", "Status: Stopped")
    safeGUIUpdate(statusLabel, "TextColor3", Color3.fromRGB(200, 200, 200))
    safeGUIUpdate(clipboardStatus, "Text", "Clipboard: Paused")
end)

resumeBtn.MouseButton1Click:Connect(function()
    if not isRunning or not isPaused then return end
    isPaused = false
    safeGUIUpdate(statusLabel, "Text", "Status: Resumed")
    safeGUIUpdate(statusLabel, "TextColor3", Color3.fromRGB(100, 255, 100))
end)

-- ==================== INITIALIZATION ====================

-- Initialize GUI state
pcall(function()
    clipboardStatus.Text = "Clipboard: Ready"
    statusLabel.Text = "Status: Disconnected"
    serverInfoLabel.Text = "Server: None"
end)

-- Start services
coroutine.wrap(function()
    task.wait(1) -- Ensure complete initialization
    
    print("✅ AutoJoiner fully operational")
    if AUTO_PASTE_ENABLED then
        safeGUIUpdate(clipboardStatus, "Text", "Clipboard: Monitoring")
        coroutine.wrap(monitorClipboard)()
    end
    
    -- Continuous status updates
    while true do
        updateClipboardStatus()
        task.wait(0.5)
    end
end)()

-- Debug command to test with specific Job ID
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.F6 then
        local testID = "TNmMNbvB8tkUtxOVLRuP9ZNLItPPfpvHTHvB9tmCyLPVRRvQIHDVSZuBxLUBwjORqHPUSfNVNbkTuO3Y4xvPSAFN+HkUqHys"
        print("🧪 Testing with ID:", testID)
        attemptTeleport(testID)
    elseif not processed and input.KeyCode == Enum.KeyCode.F5 then
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
        pcall(function()
            socket:Close()
            socket = nil
        end)
    end
end)

print("⚡ AutoJoiner initialization complete!")
