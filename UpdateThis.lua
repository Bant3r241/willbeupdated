-- AutoJoiner with Clipboard Support - Ultimate Version
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
local player = Players.LocalPlayer
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

-- Enhanced player loading with timeout
local function waitForPlayer()
    local startTime = os.time()
    repeat 
        task.wait(0.5)
        player = Players.LocalPlayer
        if os.time() - startTime > 10 then
            warn("Player loading timeout reached")
            return false
        end
    until player and player:IsDescendantOf(game)
    return true
end

if not waitForPlayer() then
    error("Failed to initialize player")
end

local playerGui = player:WaitForChild("PlayerGui", 10) or error("PlayerGui not found")

-- ==================== ENHANCED UTILITY FUNCTIONS ====================

local function safeCall(func, errorHandler)
    local success, result = pcall(func)
    if not success then
        if errorHandler then
            errorHandler(result)
        else
            warn("Protected call failed:", result)
        end
    end
    return success, result
end

-- Improved clipboard handling with fallbacks
local function getClipboardText()
    for _, method in ipairs({
        function() return readclipboard and readclipboard() or "" end,
        function() return toclipboard and toclipboard() or "" end,
        function() return TextService.GetStringAsync and TextService:GetStringAsync("clipboard") or "" end
    }) do
        local success, result = safeCall(method)
        if success and result and type(result) == "string" then
            return result:gsub("%s+", "") -- Remove all whitespace
        end
    end
    return ""
end

local function setClipboardText(text)
    text = tostring(text)
    for _, method in ipairs({
        function() if writeclipboard then writeclipboard(text) end end,
        function() if toclipboard then toclipboard(text) end end
    }) do
        safeCall(method)
    end
end

-- Enhanced Job ID validation
local function isValidJobId(jobId)
    if not jobId or type(jobId) ~= "string" then return false end
    if #jobId < 22 or #jobId > MAX_CLIPBOARD_LENGTH then return false end
    
    -- More specific pattern matching for Roblox Job IDs
    return jobId:match("^[%w+/%-_=]+$") ~= nil and 
           not jobId:match("[^%w+/%-_=]") and
           jobId:match("[A-Za-z0-9+/][A-Za-z0-9+/][A-Za-z0-9+/][A-Za-z0-9+/]")
end

-- ==================== ADVANCED GUI CREATION ====================

-- Create main GUI container with better error handling
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoJoinerGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
screenGui.Enabled = true

-- Main frame with improved styling
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 580) -- Slightly larger
frame.Position = UDim2.new(0.5, -160, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.BorderSizePixel = 1
frame.BorderColor3 = Color3.fromRGB(60, 60, 80)
frame.Parent = screenGui

-- Enhanced draggable logic with bounds checking
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    local newPos = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
    
    -- Keep frame within screen bounds
    local absPos = frame.AbsolutePosition
    local absSize = frame.AbsoluteSize
    if absPos.X < 0 then
        newPos = UDim2.new(newPos.X.Scale, 0, newPos.Y.Scale, newPos.Y.Offset)
    elseif absPos.X + absSize.X > workspace.CurrentCamera.ViewportSize.X then
        newPos = UDim2.new(newPos.X.Scale, workspace.CurrentCamera.ViewportSize.X - absSize.X, newPos.Y.Scale, newPos.Y.Offset)
    end
    
    if absPos.Y < 0 then
        newPos = UDim2.new(newPos.X.Scale, newPos.X.Offset, newPos.Y.Scale, 0)
    elseif absPos.Y + absSize.Y > workspace.CurrentCamera.ViewportSize.Y then
        newPos = UDim2.new(newPos.X.Scale, newPos.X.Offset, newPos.Y.Scale, workspace.CurrentCamera.ViewportSize.Y - absSize.Y)
    end
    
    frame.Position = newPos
end

-- [Rest of the GUI creation code remains similar but with these improvements]

-- ==================== ENHANCED CORE FUNCTIONALITY ====================

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

-- Improved clipboard monitoring with cooldown
local clipboardCooldown = 0
local function monitorClipboard()
    print("🔄 Clipboard monitoring started")
    while AUTO_PASTE_ENABLED and isRunning do
        local now = os.time()
        if now - clipboardCooldown >= 1 then -- 1 second cooldown
            local currentClip = getClipboardText()
            currentClip = currentClip and currentClip:gsub("%s+", "") or ""
            
            if currentClip ~= lastClipboard and isValidJobId(currentClip) then
                clipboardCooldown = now
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

-- Enhanced teleport with better error recovery
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
    
    local success, err = safeCall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
    end, function(errorMsg)
        statusLabel.Text = "Teleport Error"
        statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        warn("Teleport failed:", errorMsg)
    end)
    
    return success
end

-- [Rest of the functions follow similar enhancement patterns]

-- ==================== ENHANCED INITIALIZATION ====================

-- Improved toggle key with debounce
local lastToggleTime = 0
UserInputService.InputBegan:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.RightShift and os.time() - lastToggleTime > 0.5 then
        lastToggleTime = os.time()
        screenGui.Enabled = not screenGui.Enabled
    end
end)

-- Initialize clipboard monitoring with error handling
coroutine.wrap(function()
    while true do
        safeCall(updateClipboardStatus)
        task.wait(0.5)
    end
end)()

-- Final GUI setup with validation
if not playerGui:IsDescendantOf(game) then
    warn("PlayerGui is not in game hierarchy")
else
    screenGui.Parent = playerGui
end

print("⚡ Ultimate AutoJoiner initialized! Press RightShift to toggle GUI")
