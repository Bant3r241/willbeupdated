-- AutoJoiner with Clipboard Support and Perfect JSON Parsing
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

-- Configuration
local WEBSOCKET_URL = "wss://cd9df660-ee00-4af8-ba05-5112f2b5f870-00-xh16qzp1xfp5.janeway.replit.dev/"
local HOP_INTERVAL = 2 -- seconds between hops
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
local lastServerUpdate = 0

-- Wait for player GUI
repeat task.wait() until player and player:FindFirstChild("PlayerGui")
local playerGui = player:WaitForChild("PlayerGui")

-- ==================== ENHANCED CLIPBOARD FUNCTIONS ====================

local function getClipboardText()
    local success, text = pcall(function()
        -- Try different clipboard access methods
        if readclipboard then
            return readclipboard()
        elseif toclipboard then
            return toclipboard()
        elseif TextService:GetStringAsync then
            return TextService:GetStringAsync("clipboard")
        end
        return ""
    end)
    return success and text or ""
end

local function setClipboardText(text)
    pcall(function()
        if writeclipboard then
            writeclipboard(text)
        elseif toclipboard then
            toclipboard(text)
        end
    end)
end

-- Enhanced Job ID validation with specific format checking
local function isValidJobId(jobId)
    if not jobId or type(jobId) ~= "string" then return false end
    
    -- Length checks (minimum 22, maximum configurable)
    if #jobId < 22 or #jobId > MAX_CLIPBOARD_LENGTH then 
        return false 
    end
    
    -- Character set validation (alphanumeric + special characters)
    if not jobId:find("^[%w+/=_-]+$") then
        return false
    end
    
    -- Additional pattern matching for Roblox Job IDs
    return jobId:match("[A-Za-z0-9+/][A-Za-z0-9+/][A-Za-z0-9+/][A-Za-z0-9+/]") ~= nil
end

-- ==================== PERFECT JSON PARSING ====================

local function safeJSONParse(jsonString)
    local success, result = pcall(HttpService.JSONDecode, HttpService, jsonString)
    if not success then
        -- Try to fix common JSON issues
        jsonString = jsonString:gsub("([^\\])'", "%1\"") -- Replace single quotes with double quotes
        jsonString = jsonString:gsub("\\'", "'") -- Handle escaped single quotes
        success, result = pcall(HttpService.JSONDecode, HttpService, jsonString)
    end
    return success and result or nil
end

-- ==================== GUI CREATION ====================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoJoinerGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
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
    charLabel.Font = Enum.Font.GothamBold
    charLabel.TextSize = 22
    charLabel.TextXAlignment = Enum.TextXAlignment.Left
    charLabel.Parent = titleContainer
    table.insert(charLabels, charLabel)
end

titleContainer.Size = UDim2.new(0, totalWidth, 0, 40)

-- Rainbow animation
local rainbowColors = {
    Color3.fromRGB(255, 0, 0),
    Color3.fromRGB(255, 127, 0),
    Color3.fromRGB(255, 255, 0),
    Color3.fromRGB(0, 255, 0),
    Color3.fromRGB(0, 0, 255),
    Color3.fromRGB(75, 0, 130),
    Color3.fromRGB(148, 0, 211)
}

local waveOffset = 0
local function startRainbowWave()
    while true do
        for i, label in ipairs(charLabels) do
            local colorIndex = (i + waveOffset) % #rainbowColors + 1
            label.TextColor3 = rainbowColors[colorIndex]
        end
        waveOffset = (waveOffset + 1) % (#rainbowColors * 2)
        task.wait(0.05)
    end
end
coroutine.wrap(startRainbowWave)()

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -40, 0, 20)
statusLabel.Position = UDim2.new(0, 20, 0, 60)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Disconnected"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

-- Server Info Label
local serverInfoLabel = Instance.new("TextLabel")
serverInfoLabel.Size = UDim2.new(1, -40, 0, 20)
serverInfoLabel.Position = UDim2.new(0, 20, 0, 85)
serverInfoLabel.BackgroundTransparency = 1
serverInfoLabel.Text = "Server: None"
serverInfoLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
serverInfoLabel.Font = Enum.Font.Gotham
serverInfoLabel.TextSize = 14
serverInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
serverInfoLabel.Parent = frame

-- Clipboard Status Label
local clipboardStatus = Instance.new("TextLabel")
clipboardStatus.Size = UDim2.new(1, -40, 0, 20)
clipboardStatus.Position = UDim2.new(0, 20, 0, 110)
clipboardStatus.BackgroundTransparency = 1
clipboardStatus.Text = "Clipboard: Ready"
clipboardStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
clipboardStatus.Font = Enum.Font.Gotham
clipboardStatus.TextSize = 14
clipboardStatus.TextXAlignment = Enum.TextXAlignment.Left
clipboardStatus.Parent = frame

-- Auto-Paste Toggle
local autoPasteToggle = Instance.new("TextButton")
autoPasteToggle.Size = UDim2.new(1, -40, 0, 30)
autoPasteToggle.Position = UDim2.new(0, 20, 0, 135)
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
end)

-- MPS Dropdown System
local mpsLabel = Instance.new("TextLabel")
mpsLabel.Size = UDim2.new(1, -40, 0, 20)
mpsLabel.Position = UDim2.new(0, 20, 0, 170)
mpsLabel.BackgroundTransparency = 1
mpsLabel.Text = "Select MPS Range:"
mpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
mpsLabel.Font = Enum.Font.GothamBold
mpsLabel.TextSize = 18
mpsLabel.TextXAlignment = Enum.TextXAlignment.Left
mpsLabel.Parent = frame

local mpsDropdown = Instance.new("TextButton")
mpsDropdown.Size = UDim2.new(1, -40, 0, 40)
mpsDropdown.Position = UDim2.new(0, 20, 0, 195)
mpsDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
mpsDropdown.BorderSizePixel = 0
mpsDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
mpsDropdown.Font = Enum.Font.GothamBold
mpsDropdown.TextSize = 18
mpsDropdown.Text = "1M-3M  ▼"
mpsDropdown.AutoButtonColor = false
mpsDropdown.Parent = frame

local optionsFrame = Instance.new("Frame")
optionsFrame.Size = UDim2.new(1, -40, 0, 0)
optionsFrame.Position = UDim2.new(0, 20, 0, 235)
optionsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
optionsFrame.BorderSizePixel = 0
optionsFrame.ClipsDescendants = true
optionsFrame.ZIndex = 2
optionsFrame.Parent = frame

local mpsRanges = {"1M-3M", "3M-5M", "5M-9.9M", "10M+"}
local isDropdownOpen = false

local function toggleDropdown()
    if isDropdownOpen then
        optionsFrame:TweenSize(UDim2.new(1, -40, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        mpsDropdown.Text = selectedMpsRange.."  ▼"
    else
        optionsFrame:TweenSize(UDim2.new(1, -40, 0, #mpsRanges * 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        mpsDropdown.Text = selectedMpsRange.."  ▲"
    end
    isDropdownOpen = not isDropdownOpen
end

mpsDropdown.MouseButton1Click:Connect(toggleDropdown)

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
    option.Parent = optionsFrame
    
    option.MouseButton1Click:Connect(function()
        selectedMpsRange = range
        toggleDropdown()
        statusLabel.Text = "Status: Filter set to "..range
        statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    end)
end

-- Manual Input Section
local manualInput = Instance.new("TextBox")
manualInput.Size = UDim2.new(1, -40, 0, 30)
manualInput.Position = UDim2.new(0, 20, 0, 380)
manualInput.PlaceholderText = "Enter Job ID manually"
manualInput.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
manualInput.TextColor3 = Color3.fromRGB(255, 255, 255)
manualInput.Font = Enum.Font.Gotham
manualInput.TextSize = 14
manualInput.Parent = frame

local manualJoinBtn = Instance.new("TextButton")
manualJoinBtn.Size = UDim2.new(1, -40, 0, 30)
manualJoinBtn.Position = UDim2.new(0, 20, 0, 420)
manualJoinBtn.Text = "JOIN MANUALLY"
manualJoinBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 150)
manualJoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
manualJoinBtn.Font = Enum.Font.GothamBold
manualJoinBtn.TextSize = 14
manualJoinBtn.Parent = frame

-- Control Buttons
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, -40, 0, 40)
startBtn.Position = UDim2.new(0, 20, 0, 460)
startBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
startBtn.BorderSizePixel = 0
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 20
startBtn.Text = "Start"
startBtn.AutoButtonColor = false
startBtn.Parent = frame

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(1, -40, 0, 40)
stopBtn.Position = UDim2.new(0, 20, 0, 510)
stopBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
stopBtn.BorderSizePixel = 0
stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 20
stopBtn.Text = "Stop"
stopBtn.AutoButtonColor = false
stopBtn.Parent = frame

-- ==================== ENHANCED CLIPBOARD MONITORING ====================

local function updateClipboardStatus()
    local currentClip = getClipboardText()
    currentClip = currentClip and currentClip:gsub("%s+", "") or ""
    
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
    print("🔄 Clipboard monitoring started")
    while AUTO_PASTE_ENABLED and isRunning do
        local currentClip = getClipboardText()
        currentClip = currentClip and currentClip:gsub("%s+", "") or "" -- Remove whitespace
        
        -- Extra validation specific to your format
        if currentClip ~= lastClipboard and isValidJobId(currentClip) then
            if currentClip:find("^[%w+/=_-]+$") then -- Additional pattern check
                print("📋 Valid Job ID detected:", currentClip:sub(1, 8).."..."..currentClip:sub(-4))
                lastClipboard = currentClip
                clipboardStatus.Text = "Processing Job ID..."
                clipboardStatus.TextColor3 = Color3.fromRGB(255, 255, 100)
                
                local success = attemptTeleport(currentClip)
                if success then
                    clipboardStatus.Text = "Joined successfully!"
                    clipboardStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
                    setClipboardText("")
                    lastClipboard = ""
                else
                    clipboardStatus.Text = "Failed to join"
                    clipboardStatus.TextColor3 = Color3.fromRGB(255, 150, 100)
                end
            end
        end
        task.wait(CHECK_INTERVAL)
    end
    print("🛑 Clipboard monitoring stopped")
end

-- ==================== ENHANCED WEB SOCKET FUNCTIONS ====================

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
    
    -- Truncate for display but keep full ID for teleport
    local displayId = #jobId > 12 and (jobId:sub(1, 8).."..."..jobId:sub(-4)) or jobId
    serverInfoLabel.Text = "Server: "..displayId
    
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
    
    local data = safeJSONParse(message)
    if not data or not data.jobId then
        statusLabel.Text = "Status: Invalid JSON"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end

    local mps = tonumber(data.moneyPerSec and data.moneyPerSec:match("([%d%.]+)M") or 0)
    if mps > 0 then
        processJobId(data.jobId, mps)
    end
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
            if isRunning and connectionAttempts < MAX_RETRIES then
                task.wait(RECONNECT_DELAY)
                connectWebSocket()
            end
        end)
        
        connectionAttempts = 0
        statusLabel.Text = "Status: Connected"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end)
    
    if not success then
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

-- ==================== CONTROL HANDLERS ====================

startBtn.MouseButton1Click:Connect(function()
    if isRunning then return end
    isRunning = true
    isPaused = false
    connectionAttempts = 0
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
        pcall(function() socket:Close() end)
        socket = nil
    end
    statusLabel.Text = "Status: Stopped"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
end)

manualJoinBtn.MouseButton1Click:Connect(function()
    local jobId = manualInput.Text:gsub("%s+", "")
    if isValidJobId(jobId) then
        clipboardStatus.Text = "Processing Manual Job ID..."
        clipboardStatus.TextColor3 = Color3.fromRGB(255, 255, 100)
        
        local success = attemptTeleport(jobId)
        if success then
            clipboardStatus.Text = "Joined successfully!"
            clipboardStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
            manualInput.Text = ""
        else
            clipboardStatus.Text = "Failed to join"
            clipboardStatus.TextColor3 = Color3.fromRGB(255, 150, 100)
        end
    else
        clipboardStatus.Text = "Invalid Manual Job ID"
        clipboardStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

-- Initialize
coroutine.wrap(function()
    while true do
        updateClipboardStatus()
        task.wait(0.5)
    end
end)()

print("⚡ AutoJoiner with Clipboard Support and Perfect JSON Parsing initialized!")
print("Testing Job ID validation:")
print(isValidJobId("TpDC0bPR8xuUa8NVLxSS5VtOItFOfpPITHvB8RFWYLPVW4mPKfETQDtPhfUAGDjUqHPUSfNVNbkTuO3Y4xvPSAFN+HkUqHys")) -- Should return true
