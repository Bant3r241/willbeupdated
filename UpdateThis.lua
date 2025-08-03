print("Script is executing!") -- Debug check

-- AutoJoiner v3.0 - Krnl Optimized Version
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

-- Configuration (Krnl-specific)
local WEBSOCKET_URL = "wss://cd9df660-ee00-4af8-ba05-5112f2b5f870-00-xh16qzp1xfp5.janeway.replit.dev/"
local HOP_INTERVAL = 2.5 -- seconds between hops
local RECONNECT_DELAY = 5
local MAX_RETRIES = 3
local MAX_UNAUTHORIZED_ATTEMPTS = 3
local CHILLI_HUB_INPUT_NAME = "JobID" -- Chilli Hub input field
local CHILLI_HUB_JOIN_NAME = "Join Job-ID" -- Chilli Hub join button
local CHECK_INTERVAL = 0.3 -- Clipboard check interval

-- State
local player = Players.LocalPlayer or Players:GetPlayers()[1]
local socket = nil
local isRunning = false
local isPaused = false
local lastHopTime = 0
local activeJobId = nil
local selectedMpsRange = "1M-3M"
local connectionAttempts = 0
local unauthorizedAttempts = 0
local AUTO_PASTE_ENABLED = true

-- Wait for player GUI
repeat task.wait() until player and player:FindFirstChild("PlayerGui")
local playerGui = player:WaitForChild("PlayerGui")

-- Helper Functions (Krnl-optimized)
local function isValidJobId(jobId)
    return jobId and type(jobId) == "string" and #jobId >= 22 and #jobId <= 200
end

local function extractUuidFromJobId(jobId)
    if not isValidJobId(jobId) then return nil end
    
    local success, decoded = pcall(function()
        return HttpService:Base64Decode(jobId)
    end)
    
    return success and decoded and #decoded >= 16 and decoded:sub(1, 16) or nil
end

-- GUI Creation with Krnl fixes
do
    -- First remove any existing GUI
    pcall(function()
        if game:GetService("CoreGui"):FindFirstChild("AutoJoinerGUI") then
            game:GetService("CoreGui").AutoJoinerGUI:Destroy()
        end
    end)

    -- Create fresh GUI in CoreGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoJoinerGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999
    screenGui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 600)
    frame.Position = UDim2.new(0.5, -150, 0.3, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BorderSizePixel = 0
    frame.Visible = true
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
        Color3.fromRGB(255, 0, 0),    -- Red
        Color3.fromRGB(255, 127, 0),  -- Orange
        Color3.fromRGB(255, 255, 0),  -- Yellow
        Color3.fromRGB(0, 255, 0),    -- Green
        Color3.fromRGB(0, 0, 255),    -- Blue
        Color3.fromRGB(75, 0, 130),   -- Indigo
        Color3.fromRGB(148, 0, 211)   -- Violet
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

    -- Status Labels
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

    -- MPS Dropdown System
    local mpsLabel = Instance.new("TextLabel")
    mpsLabel.Size = UDim2.new(1, -40, 0, 20)
    mpsLabel.Position = UDim2.new(0, 20, 0, 110)
    mpsLabel.BackgroundTransparency = 1
    mpsLabel.Text = "Select MPS Range:"
    mpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    mpsLabel.Font = Enum.Font.GothamBold
    mpsLabel.TextSize = 18
    mpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    mpsLabel.Parent = frame

    local mpsDropdown = Instance.new("TextButton")
    mpsDropdown.Size = UDim2.new(1, -40, 0, 40)
    mpsDropdown.Position = UDim2.new(0, 20, 0, 135)
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
    optionsFrame.Position = UDim2.new(0, 20, 0, 175)
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

    -- Control Buttons
    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(1, -40, 0, 40)
    startBtn.Position = UDim2.new(0, 20, 0, 320)
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
    stopBtn.Position = UDim2.new(0, 20, 0, 370)
    stopBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    stopBtn.BorderSizePixel = 0
    stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 20
    stopBtn.Text = "Stop"
    stopBtn.AutoButtonColor = false
    stopBtn.Parent = frame

    local resumeBtn = Instance.new("TextButton")
    resumeBtn.Size = UDim2.new(1, -40, 0, 40)
    resumeBtn.Position = UDim2.new(0, 20, 0, 420)
    resumeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    resumeBtn.BorderSizePixel = 0
    resumeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    resumeBtn.Font = Enum.Font.GothamBold
    resumeBtn.TextSize = 20
    resumeBtn.Text = "Resume"
    resumeBtn.AutoButtonColor = false
    resumeBtn.Parent = frame

    -- Chilli Hub Auto-Join Section
    local pasteFrame = Instance.new("Frame")
    pasteFrame.Size = UDim2.new(1, -40, 0, 80)
    pasteFrame.Position = UDim2.new(0, 20, 0, 470)
    pasteFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    pasteFrame.BorderSizePixel = 0
    pasteFrame.Parent = frame

    local pasteTitle = Instance.new("TextLabel")
    pasteTitle.Size = UDim2.new(1, 0, 0, 20)
    pasteTitle.Position = UDim2.new(0, 0, 0, 0)
    pasteTitle.BackgroundTransparency = 1
    pasteTitle.Text = "Chilli Hub Auto-Join"
    pasteTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    pasteTitle.Font = Enum.Font.GothamBold
    pasteTitle.TextSize = 16
    pasteTitle.Parent = pasteFrame

    local pasteStatus = Instance.new("TextLabel")
    pasteStatus.Size = UDim2.new(1, 0, 0, 20)
    pasteStatus.Position = UDim2.new(0, 0, 0, 25)
    pasteStatus.BackgroundTransparency = 1
    pasteStatus.Text = "Status: Ready"
    pasteStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
    pasteStatus.Font = Enum.Font.Gotham
    pasteStatus.TextSize = 14
    pasteStatus.Parent = pasteFrame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(1, 0, 0, 30)
    toggleButton.Position = UDim2.new(0, 0, 0, 50)
    toggleButton.BackgroundColor3 = AUTO_PASTE_ENABLED and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(120, 0, 0)
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = AUTO_PASTE_ENABLED and "AUTO-JOIN: ON" or "AUTO-JOIN: OFF"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 16
    toggleButton.AutoButtonColor = false
    toggleButton.Parent = pasteFrame

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

    -- Emergency GUI visibility check
    task.spawn(function()
        task.wait(1)
        if not frame.Visible then
            warn("GUI not visible - forcing visibility")
            screenGui.Enabled = true
            frame.Visible = true
        end
        print("GUI should be visible now at:", frame.AbsolutePosition)
    end)
end

-- Chilli Hub Functions (Krnl-compatible)
local function findChilliElements()
    local inputField, joinButton
    
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if not inputField and gui:IsA("TextBox") then
            if gui.Name == CHILLI_HUB_INPUT_NAME or string.find(gui.Name:lower(), "jobid") then
                inputField = gui
            end
        end
        
        if not joinButton and gui:IsA("TextButton") then
            if gui.Name == CHILLI_HUB_JOIN_NAME or string.find(gui.Text:lower(), "join job") then
                joinButton = gui
            end
        end
        
        if inputField and joinButton then break end
    end
    
    return inputField, joinButton
end

local function runAutoJoin()
    local lastClipboard = ""
    
    while AUTO_PASTE_ENABLED do
        task.wait(CHECK_INTERVAL)
        
        local currentClip = readclipboard() or ""
        
        if currentClip == lastClipboard or not isValidJobId(currentClip) then
            if currentClip ~= lastClipboard then
                pasteStatus.Text = "Status: Invalid Job ID"
                pasteStatus.TextColor3 = Color3.fromRGB(255, 150, 150)
                lastClipboard = currentClip
            end
            goto continue
        end
        
        lastClipboard = currentClip
        pasteStatus.Text = "Status: Processing..."
        pasteStatus.TextColor3 = Color3.fromRGB(255, 255, 100)
        
        local inputField, joinButton = findChilliElements()
        
        if not inputField then
            pasteStatus.Text = "Status: Input not found"
            pasteStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
            goto continue
        end
        
        if not joinButton then
            pasteStatus.Text = "Status: Join button not found"
            pasteStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
            goto continue
        end
        
        pcall(function()
            inputField.Text = currentClip
            pasteStatus.Text = "Status: Pasted Job ID"
            pasteStatus.TextColor3 = Color3.fromRGB(150, 255, 150)
            
            task.wait(0.2)
            
            joinButton:Fire("MouseButton1Click")
            pasteStatus.Text = "Status: Joined server!"
            pasteStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            task.wait(2)
        end)
        
        ::continue::
    end
end

toggleButton.MouseButton1Click:Connect(function()
    AUTO_PASTE_ENABLED = not AUTO_PASTE_ENABLED
    toggleButton.Text = AUTO_PASTE_ENABLED and "AUTO-JOIN: ON" or "AUTO-JOIN: OFF"
    toggleButton.BackgroundColor3 = AUTO_PASTE_ENABLED and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(120, 0, 0)
    
    if AUTO_PASTE_ENABLED then
        coroutine.wrap(runAutoJoin)()
    else
        pasteStatus.Text = "Status: Paused"
        pasteStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
end)

-- Teleport Functions
local function attemptTeleport(jobId, isHighValue)
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
    
    local teleportId = jobId
    local method = "Full"
    local attemptCount = 1
    
    if not isHighValue then
        local uuid = extractUuidFromJobId(jobId)
        if uuid then
            teleportId = uuid
            method = "UUID"
        else
            statusLabel.Text = "Status: Failed to extract UUID"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return false
        end
    end
    
    serverInfoLabel.Text = string.format("Server: %s... [%s]", string.sub(jobId, 1, 8), method)
    
    while attemptCount <= 2 do
        local success, result = pcall(function()
            return TeleportService:TeleportToPlaceInstance(game.PlaceId, teleportId, player)
        end)
        
        if success and result == true then
            statusLabel.Text = string.format("Joined %s...", string.sub(jobId, 1, 8))
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            unauthorizedAttempts = 0
            return true
        end
        
        if not success then
            local err = tostring(result)
            
            if string.find(err, "Unauthorized") then
                unauthorizedAttempts = unauthorizedAttempts + 1
                if unauthorizedAttempts >= MAX_UNAUTHORIZED_ATTEMPTS then
                    statusLabel.Text = "Status: Too many fails - Paused"
                    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                    isPaused = true
                    return false
                end
                
                statusLabel.Text = string.format("Retry %d/%d...", unauthorizedAttempts, MAX_UNAUTHORIZED_ATTEMPTS)
                statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
                
                if method == "UUID" and attemptCount == 1 then
                    teleportId = jobId
                    method = "Full"
                    statusLabel.Text = statusLabel.Text .. " (Trying Full ID)"
                end
                
                task.wait(1)
            else
                statusLabel.Text = "Status: Error - " .. string.sub(err, 1, 30)
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                return false
            end
        end
        
        attemptCount = attemptCount + 1
    end
    
    return false
end

-- WebSocket Functions (Krnl-compatible)
local function handleWebSocketMessage(message)
    if isPaused then return end
    
    local success, data = pcall(function()
        return HttpService:JSONDecode(message)
    end)
    
    if not success then
        statusLabel.Text = "Status: Invalid JSON"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local jobId = data.jobId
    local mpsText = data.moneyPerSec and data.moneyPerSec:match("([%d%.]+)M")
    local mps = tonumber(mpsText) or 0
    
    if not jobId or not mpsText then
        statusLabel.Text = "Status: Missing data"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local isHighValue = (mps >= 10)
    local shouldJoin = false
    local actionText = "Skipping"
    
    if selectedMpsRange == "1M-3M" and mps >= 1 and mps <= 3 then
        shouldJoin = true
        actionText = "Joining [UUID]"
    elseif selectedMpsRange == "3M-5M" and mps > 3 and mps <= 5 then
        shouldJoin = true
        actionText = "Joining [UUID]"
    elseif selectedMpsRange == "5M-9.9M" and mps > 5 and mps <= 9.9 then
        shouldJoin = true
        actionText = "Joining [UUID]"
    elseif selectedMpsRange == "10M+" and mps >= 10 then
        shouldJoin = true
        actionText = "Joining [Full]"
    end
    
    if shouldJoin then
        statusLabel.Text = string.format("%s %s (%.1fM/s)", actionText, string.sub(jobId, 1, 8), mps)
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        attemptTeleport(jobId, isHighValue)
    else
        statusLabel.Text = string.format("Skipping %s (%.1fM/s)", string.sub(jobId, 1, 8), mps)
        statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
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
        -- Krnl-specific WebSocket connection
        socket = websocket.connect(WEBSOCKET_URL)
        
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
    if AUTO_PASTE_ENABLED then
        coroutine.wrap(runAutoJoin)()
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
        print("WebSocket:", socket and "Connected" or "Disconnected")
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
        pcall(function() socket:Close() end)
    end
end)

-- Start auto-join if enabled
if AUTO_PASTE_ENABLED then
    coroutine.wrap(runAutoJoin)()
end

-- Final GUI visibility check
task.spawn(function()
    task.wait(2)
    if not frame.Visible then
        warn("Emergency GUI recovery activating!")
        frame.Visible = true
        screenGui.Enabled = true
        frame.Position = UDim2.new(0.5, -150, 0.5, -150) -- Center if off-screen
    end
end)

print("AutoJoiner fully initialized!")
