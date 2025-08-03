print("AutoJoiner v3.5 - Complete Integration")

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

-- Wait for player GUI
repeat task.wait() until player and player:FindFirstChild("PlayerGui")
local playerGui = player:WaitForChild("PlayerGui")

-- Helper Functions
local function isValidJobId(jobId)
    return jobId and type(jobId) == "string" and #jobId >= 22 and #jobId <= MAX_CLIPBOARD_LENGTH
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
    
    -- Enhanced element finding with multiple strategies
    while attempts < MAX_PASTE_ATTEMPTS do
        -- Find input field with multiple methods
        inputField = playerGui:FindFirstChild("JobIDInput", true) or
                   playerGui:FindFirstChild("JobIdInput", true) or
                   playerGui:FindFirstChild("Job-ID Input", true) or
                   playerGui:FindFirstChild("JobID", true) or
                   findFirstMatchingElement(playerGui, "TextBox", function(tb)
                       return (tb.PlaceholderText and tb.PlaceholderText:lower():find("job id")) or
                              (tb.Name:lower():find("job"))
                   end)
        
        -- Find join button with multiple methods
        joinButton = playerGui:FindFirstChild("Join Job-ID", true) or
                   playerGui:FindFirstChild("JoinButton", true) or
                   playerGui:FindFirstChild("JoinBtn", true) or
                   playerGui:FindFirstChild("Join", true) or
                   findFirstMatchingElement(playerGui, "TextButton", function(btn)
                       return btn.Text and btn.Text:lower():find("join")
                   end)
        
        if inputField and joinButton then
            print("Found Chilli Hub elements:")
            print("Input Field:", inputField:GetFullName())
            print("Join Button:", joinButton:GetFullName())
            break
        end
        
        attempts = attempts + 1
        warn(string.format("Attempt %d/%d - Missing elements", attempts, MAX_PASTE_ATTEMPTS))
        task.wait(ELEMENT_WAIT_TIME)
    end

    if not inputField then
        warn("Failed to find input field after", MAX_PASTE_ATTEMPTS, "attempts")
        return false
    end

    if not joinButton then
        warn("Failed to find join button after", MAX_PASTE_ATTEMPTS, "attempts")
        return false
    end

    -- Enhanced pasting with verification
    local pasteAttempts = 0
    local pasteSuccess = false
    
    while pasteAttempts < 3 and not pasteSuccess do
        print(string.format("Paste attempt %d/3...", pasteAttempts + 1))
        inputField.Text = jobId
        task.wait(0.3)
        
        if inputField.Text == jobId then
            pasteSuccess = true
            print("Paste verified successfully!")
        else
            warn("Paste verification failed! Field contains:", inputField.Text)
            pasteAttempts = pasteAttempts + 1
        end
    end

    if not pasteSuccess then
        warn("Failed to paste Job ID after 3 attempts")
        return false
    end

    -- Enhanced button clicking with verification
    print("Clicking join button...")
    for i = 1, 3 do  -- Try multiple clicks
        if joinButton:IsA("TextButton") then
            local originalText = joinButton.Text
            joinButton.Text = "Joining..."
            joinButton:Fire("MouseButton1Click")
            task.wait(0.2)
            
            if joinButton.Text ~= originalText then
                print("Join button click successful!")
                return true
            end
        end
        task.wait(0.3)
    end
    
    warn("Failed to verify join button click")
    return false
end

-- Clipboard Monitor
local function monitorClipboard()
    while AUTO_PASTE_ENABLED and isRunning do
        local currentClip = readclipboard() or ""
        
        if currentClip ~= lastClipboard and isValidJobId(currentClip) then
            lastClipboard = currentClip
            print("New Job ID detected:", string.sub(currentClip, 1, 8).."...")
            
            local success = joinChilliHub(currentClip)
            if success then
                print("Successfully joined via Chilli Hub!")
                writeclipboard("")  -- Clear clipboard after success
                lastClipboard = ""
            else
                warn("Failed to join via Chilli Hub, attempting direct teleport...")
                attemptTeleport(currentClip)
            end
        end
        
        task.wait(CHECK_INTERVAL)
    end
end

-- GUI Creation
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
    frame.Size = UDim2.new(0, 350, 0, 600) -- Slightly wider for better layout
    frame.Position = UDim2.new(0.5, -175, 0.5, -300) -- Centered
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 1
    frame.BorderColor3 = Color3.fromRGB(60, 60, 70)
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
    titleContainer.Size = UDim2.new(1, -40, 0, 50)
    titleContainer.Position = UDim2.new(0, 20, 0, 15)
    titleContainer.BackgroundTransparency = 1
    titleContainer.Parent = frame

    local titleText = "AUTO JOINER"
    local charLabels = {}
    local charWidth = 20
    local totalWidth = #titleText * charWidth

    for i = 1, #titleText do
        local charLabel = Instance.new("TextLabel")
        charLabel.Size = UDim2.new(0, charWidth, 1, 0)
        charLabel.Position = UDim2.new(0, (i-1)*charWidth, 0, 0)
        charLabel.BackgroundTransparency = 1
        charLabel.Text = titleText:sub(i,i)
        charLabel.TextColor3 = rainbowColors[(i-1) % #rainbowColors + 1]
        charLabel.Font = Enum.Font.GothamBlack
        charLabel.TextSize = 24
        charLabel.TextXAlignment = Enum.TextXAlignment.Left
        charLabel.Parent = titleContainer
        table.insert(charLabels, charLabel)
    end

    titleContainer.Size = UDim2.new(0, totalWidth, 0, 50)

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

    -- MPS Dropdown System
    local mpsLabel = Instance.new("TextLabel")
    mpsLabel.Size = UDim2.new(1, -40, 0, 20)
    mpsLabel.Position = UDim2.new(0, 20, 0, 160)
    mpsLabel.BackgroundTransparency = 1
    mpsLabel.Text = "Select MPS Range:"
    mpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    mpsLabel.Font = Enum.Font.GothamBold
    mpsLabel.TextSize = 16
    mpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    mpsLabel.Parent = frame

    local mpsDropdown = Instance.new("TextButton")
    mpsDropdown.Size = UDim2.new(1, -40, 0, 35)
    mpsDropdown.Position = UDim2.new(0, 20, 0, 185)
    mpsDropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    mpsDropdown.BorderSizePixel = 1
    mpsDropdown.BorderColor3 = Color3.fromRGB(80, 80, 90)
    mpsDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    mpsDropdown.Font = Enum.Font.GothamBold
    mpsDropdown.TextSize = 16
    mpsDropdown.Text = "1M-3M  ▼"
    mpsDropdown.AutoButtonColor = false
    mpsDropdown.Parent = frame

    local optionsFrame = Instance.new("Frame")
    optionsFrame.Size = UDim2.new(1, -40, 0, 0)
    optionsFrame.Position = UDim2.new(0, 20, 0, 220)
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
            mpsDropdown.Text = selectedMpsRange.."  ▼"
        else
            optionsFrame:TweenSize(UDim2.new(1, -40, 0, #mpsRanges * 35), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
            mpsDropdown.Text = selectedMpsRange.."  ▲"
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
end

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
    local serverName = data.serverName
    local mpsText = data.moneyPerSec and data.moneyPerSec:match("([%d%.]+)M")
    
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
    
    -- Apply MPS filter
    local shouldJoin = false
    local useChilliHub = false
    local mpsMillions = mps -- Already in millions

    if selectedMpsRange == "1M-3M" then
        shouldJoin = (mpsMillions >= 1 and mpsMillions <= 3)
    elseif selectedMpsRange == "3M-5M" then
        shouldJoin = (mpsMillions > 3 and mpsMillions <= 5)
    elseif selectedMpsRange == "5M-9.9M" then
        shouldJoin = (mpsMillions > 5 and mpsMillions <= 9.9)
    elseif selectedMpsRange == "10M+" then
        shouldJoin = (mpsMillions >= 10)
        useChilliHub = true -- Use Chilli Hub for 10M+ servers
    end
    
    -- Take action
    if shouldJoin then
        statusLabel.Text = string.format("Joining %s (%.1fM/s)", string.sub(jobId, 1, 8), mpsMillions)
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        if useChilliHub then
            if joinChilliHub(jobId) then
                print("Using Chilli Hub to join 10M+ server")
            else
                -- Fallback to normal teleport if Chilli Hub fails
                attemptTeleport(jobId)
            end
        else
            attemptTeleport(jobId)
        end
    else
        statusLabel.Text = string.format("Skipping %s (%.1fM/s)", string.sub(jobId, 1, 8), mpsMillions)
        statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
    end
    
    print(string.format("Parsed - JobID: %s | Server: %s | MPS: %.1fM | Action: %s | Method: %s",
        jobId, serverName or "N/A", mpsMillions, shouldJoin and "Joining" or "Skipping",
        useChilliHub and "Chilli Hub" or "Direct Teleport"))
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

-- Final GUI visibility check
task.spawn(function()
    task.wait(2)
    if not frame.Visible then
        warn("Emergency GUI recovery activating!")
        frame.Visible = true
        screenGui.Enabled = true
        frame.Position = UDim2.new(0.5, -175, 0.5, -300) -- Center if off-screen
    end
end)

-- Start clipboard monitoring if enabled
if AUTO_PASTE_ENABLED then
    coroutine.wrap(monitorClipboard)()
end

print("AutoJoiner fully initialized with all features!")
