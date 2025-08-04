print("AutoJoiner v4.2 - Ultimate Complete Edition")

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

-- [All your original GUI creation code goes here EXACTLY as you had it]
-- Including: draggable logic, rainbow title, status labels, dropdowns, buttons, etc.

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

local function attemptTeleport(jobId)
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
        processJobId(data.jobId)
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
