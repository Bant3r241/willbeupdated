print("AutoJoiner v4.0 - Ultimate Edition")

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

-- [Include all your GUI creation code here...]
-- Make sure to create all elements including:
-- - Rainbow title
-- - Status labels
-- - MPS dropdown
-- - Control buttons
-- - Clipboard status label

-- ==================== CORE FUNCTIONS ====================

local function isValidJobId(jobId)
    return jobId and type(jobId) == "string" 
           and #jobId >= 22 
           and #jobId <= MAX_CLIPBOARD_LENGTH
           and jobId:match("^[%w+/%-_=]+$") ~= nil
end

local function updateClipboardStatus()
    if not (clipboardStatus and clipboardStatus:IsA("TextLabel")) then
        warn("Clipboard status GUI element missing!")
        return false
    end

    local success, currentClip = pcall(function()
        return readclipboard() or ""
    end)
    
    if not success then
        clipboardStatus.Text = "Clipboard: Access Error"
        clipboardStatus.TextColor3 = Color3.fromRGB(255, 50, 50)
        return false
    end
    
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
    
    return true
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
    if not isValidJobId(jobId) then return false end

    local inputField, joinButton
    local attempts = 0
    
    while attempts < MAX_PASTE_ATTEMPTS do
        inputField = playerGui:FindFirstChild("JobIDInput", true) or
                   findFirstMatchingElement(playerGui, "TextBox", function(tb)
                       return (tb.PlaceholderText and tb.PlaceholderText:lower():find("job id")) or
                              (tb.Name:lower():find("job"))
                   end)
        
        joinButton = playerGui:FindFirstChild("JoinButton", true) or
                   findFirstMatchingElement(playerGui, "TextButton", function(btn)
                       return btn.Text and btn.Text:lower():find("join")
                   end)
        
        if inputField and joinButton then break end
        attempts += 1
        task.wait(ELEMENT_WAIT_TIME)
    end

    if not (inputField and joinButton) then return false end

    -- Paste with verification
    local pasteAttempts = 0
    while pasteAttempts < 3 do
        inputField.Text = jobId
        task.wait(0.2)
        if inputField.Text == jobId then break end
        pasteAttempts += 1
    end

    -- Click with verification
    for i = 1, 3 do
        joinButton:Fire("MouseButton1Click")
        task.wait(0.3)
        if joinButton.Text:lower():find("joining") then
            return true
        end
    end
    
    return false
end

local function attemptTeleport(jobId)
    if not isRunning or isPaused then return false end
    if not isValidJobId(jobId) then return false end
    
    local currentTime = os.time()
    if currentTime - lastHopTime < HOP_INTERVAL then
        local waitTime = HOP_INTERVAL - (currentTime - lastHopTime)
        statusLabel.Text = string.format("Waiting %.1fs...", waitTime)
        task.wait(waitTime)
    end
    
    lastHopTime = os.time()
    activeJobId = jobId
    
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
    end)
    
    if not success then
        warn("Teleport failed:", err)
        statusLabel.Text = "Status: Failed - Retrying"
        return false
    end
    
    return true
end

local function processJobId(jobId)
    pcall(function()
        clipboardStatus.Text = "Processing Job ID..."
        clipboardStatus.TextColor3 = Color3.fromRGB(255, 255, 100)
    end)
    
    local success = joinChilliHub(jobId)
    if not success then
        success = attemptTeleport(jobId)
    end
    
    pcall(function()
        if success then
            clipboardStatus.Text = "Joined successfully!"
            clipboardStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
            pcall(function() writeclipboard("") end)
            lastClipboard = ""
        else
            clipboardStatus.Text = "Failed to join"
            clipboardStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
end

local function monitorClipboard()
    print("Clipboard monitoring started")
    while AUTO_PASTE_ENABLED and isRunning do
        local success, currentClip = pcall(function()
            return (readclipboard() or ""):gsub("%s+", "")
        end)
        
        if success and currentClip ~= lastClipboard and isValidJobId(currentClip) then
            lastClipboard = currentClip
            processJobId(currentClip)
        end
        
        task.wait(CHECK_INTERVAL)
    end
end

-- ==================== WEB SOCKET FUNCTIONS ====================

local function handleWebSocketMessage(message)
    if isPaused then return end
    
    local success, data = pcall(HttpService.JSONDecode, HttpService, message)
    if not success then return end
    
    local jobId = data.jobId
    local mps = tonumber(data.moneyPerSec and data.moneyPerSec:match("([%d%.]+)M") or 0)
    
    if jobId and mps > 0 then
        processJobId(jobId)
    end
end

local function connectWebSocket()
    if not isRunning then return end
    
    connectionAttempts += 1
    statusLabel.Text = string.format("Connecting (%d/%d)...", connectionAttempts, MAX_RETRIES)
    
    if socket then pcall(socket.Close, socket) end
    
    local success, err = pcall(function()
        socket = WebSocket.connect(WEBSOCKET_URL)
        socket.OnMessage:Connect(handleWebSocketMessage)
        socket.OnClose:Connect(function()
            if isRunning and connectionAttempts < MAX_RETRIES then
                task.wait(RECONNECT_DELAY)
                connectWebSocket()
            end
        end)
        connectionAttempts = 0
        statusLabel.Text = "Status: Connected"
    end)
    
    if not success and connectionAttempts < MAX_RETRIES then
        task.wait(RECONNECT_DELAY)
        connectWebSocket()
    end
end

-- ==================== CONTROL HANDLERS ====================

startBtn.MouseButton1Click:Connect(function()
    if isRunning then return end
    isRunning = true
    isPaused = false
    statusLabel.Text = "Status: Starting..."
    connectWebSocket()
    if AUTO_PASTE_ENABLED then
        clipboardStatus.Text = "Clipboard: Monitoring"
        coroutine.wrap(monitorClipboard)()
    end
end)

stopBtn.MouseButton1Click:Connect(function()
    if not isRunning then return end
    isRunning = false
    if socket then pcall(socket.Close, socket) end
    statusLabel.Text = "Status: Stopped"
    clipboardStatus.Text = "Clipboard: Paused"
end)

resumeBtn.MouseButton1Click:Connect(function()
    if not isRunning or not isPaused then return end
    isPaused = false
    statusLabel.Text = "Status: Resumed"
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
    task.wait(1) -- Ensure GUI is ready
    print("AutoJoiner fully initialized!")
    if AUTO_PASTE_ENABLED then
        coroutine.wrap(monitorClipboard)()
    end
end)()

-- Debug command
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.F6 then
        local testID = "TNmMNbvB8tkUtxOVLRuP9ZNLItPPfpvHTHvB9tmCyLPVRRvQIHDVSZuBxLUBwjORqHPUSfNVNbkTuO3Y4xvPSAFN+HkUqHys"
        print("Testing with ID:", testID)
        attemptTeleport(testID)
    end
end)

print("✅ AutoJoiner ready!")
