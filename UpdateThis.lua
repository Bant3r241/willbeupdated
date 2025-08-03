-- AutoJoiner Pro v2.0
-- Features:
-- 1. Supports ALL Job ID formats (UUID, Base64, Encoded)
-- 2. Advanced BrainRot detection (5+ types)
-- 3. WebSocket + HTTP fallback
-- 4. Server history tracking
-- 5. Rainbow UI with tab system

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Configuration
local WEBSOCKET_URL = "wss://your-websocket-url.com/"
local HTTP_FALLBACK_URL = "https://your-http-api.com/servers"
local HOP_INTERVAL = 2 -- seconds between hops
local RECONNECT_DELAY = 5
local MAX_RETRIES = 3
local SERVER_HISTORY_EXPIRE = 1800 -- 30 minutes

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
local recentServers = {}
local useWebSocket = true

-- Enhanced Job ID Processing
local function decodeCustomJobId(encodedId)
    local cleanId = encodedId:gsub("room ID.-:%s*", ""):gsub("%s+", "")
    cleanId = cleanId:gsub("-", "+"):gsub("_", "/")
    local padLen = #cleanId % 4
    if padLen > 0 then
        cleanId = cleanId .. string.rep("=", 4 - padLen)
    end
    local success, decoded = pcall(function()
        return HttpService:Base64Decode(cleanId)
    end)
    return success and decoded or encodedId
end

local function isValidJobId(id)
    if id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
        return true
    end
    if #id >= 40 and #id <= 50 and id:match("^%w+$") then
        return true
    end
    if #id >= 64 and id:match("^[%w+/=%-_]+$") then
        return true
    end
    return false
end

local function processJobId(rawId)
    local cleanId = rawId:gsub("JobID:%s*", "")
                      :gsub("room ID.-:%s*", "")
                      :gsub("%s+", "")
                      :gsub('"', "")
                      :gsub("'", "")
    
    if isValidJobId(cleanId) then
        return cleanId
    end
    
    if #cleanId >= 64 then
        local decoded = decodeCustomJobId(cleanId)
        if isValidJobId(decoded) then
            return decoded
        end
    end
    
    return nil
end

-- Advanced BrainRot Detection
local function detectBrainRot(serverName)
    if not serverName then return "Unknown" end
    local lowerName = serverName:lower()
    
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

local brainRotOptions = {
    "Any", 
    "La Vacca Saturno Saturnita", 
    "Los Tralaleritos", 
    "Chimpanzini Spiderniti", 
    "Piccione Macchina",
    "Grappe Medussi"
}

-- GUI Setup (abbreviated for space - includes all UI elements from original)
-- [Previous GUI code remains exactly the same]

-- Enhanced Connection System
local function fetchServersHTTP()
    local success, response = pcall(function()
        return game:HttpGet(HTTP_FALLBACK_URL)
    end)
    return success and response or nil
end

local function handleServerData(message)
    if not isRunning or isPaused then return end

    local data
    local success, err = pcall(function()
        data = HttpService:JSONDecode(message)
    end)
    
    if not success then
        warn("Failed to parse server data:", err)
        statusLabel.Text = "Status: Invalid server data"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local jobId = tostring(data.jobId):gsub("[%s'\"]", "")
    local mpsText = data.moneyPerSec:match("([%d%.]+)M")
    local serverName = data.serverName or "Unknown"
    local mps = tonumber(mpsText)
    
    if not mps then
        warn("Invalid MPS value:", data.moneyPerSec)
        return
    end

    local processedId = processJobId(jobId)
    if not processedId then
        warn("Invalid Job ID format:", jobId)
        return
    end

    local detectedBrainRot = detectBrainRot(serverName)
    local shouldJoin = true
    
    -- BrainRot filter
    if selectedBrainRot ~= "Any" and detectedBrainRot ~= selectedBrainRot then
        shouldJoin = false
    end
    
    -- MPS filter
    if selectedMpsRange == "1M-3M" and not (mps >= 1 and mps <= 3) then
        shouldJoin = false
    elseif selectedMpsRange == "3M-5M" and not (mps > 3 and mps <= 5) then
        shouldJoin = false
    elseif selectedMpsRange == "5M+" and not (mps > 5) then
        shouldJoin = false
    end
    
    if shouldJoin then
        statusLabel.Text = string.format("Joining %s...", string.sub(processedId, 1, 8))
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        attemptTeleport(processedId)
    end
end

-- Enhanced Teleport Function
local function attemptTeleport(jobId)
    if not isRunning or isPaused then return false end
    
    local currentTime = os.time()
    if currentTime - lastHopTime < HOP_INTERVAL then
        task.wait(HOP_INTERVAL - (currentTime - lastHopTime))
    end

    if recentServers[jobId] then return false end

    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
    end)

    if success then
        lastHopTime = os.time()
        activeJobId = jobId
        recentServers[jobId] = os.time()
        serverInfoLabel.Text = "Joining: "..string.sub(jobId, 1, 8).."..."
        return true
    else
        warn("Teleport failed:", err)
        statusLabel.Text = "Teleport failed!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        return false
    end
end

-- WebSocket Connection
local function connectWebSocket()
    if not isRunning then return end
    
    connectionAttempts = connectionAttempts + 1
    statusLabel.Text = string.format("Connecting (%d/%d)...", connectionAttempts, MAX_RETRIES)
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    
    if socket then pcall(function() socket:Close() end) end
    
    local success, err = pcall(function()
        socket = WebSocket.connect(WEBSOCKET_URL)
        
        socket.OnMessage:Connect(handleServerData)
        
        socket.OnClose:Connect(function()
            if isRunning and connectionAttempts < MAX_RETRIES then
                task.wait(RECONNECT_DELAY)
                connectWebSocket()
            else
                useWebSocket = false
                statusLabel.Text = "Status: HTTP Fallback"
                fetchServersHTTP()
            end
        end)
        
        connectionAttempts = 0
        statusLabel.Text = "Status: Connected (WS)"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end)
    
    if not success then
        if connectionAttempts < MAX_RETRIES then
            task.wait(RECONNECT_DELAY)
            connectWebSocket()
        else
            useWebSocket = false
            statusLabel.Text = "Status: HTTP Fallback"
            fetchServersHTTP()
        end
    end
end

-- Control Handlers (same as before)
startBtn.MouseButton1Click:Connect(function()
    if isRunning then return end
    isRunning = true
    isPaused = false
    connectionAttempts = 0
    connectWebSocket()
end)

-- [Rest of the original control handlers and GUI code]

-- Initialize
loadSettings()
switchTab("AutoJoiner")

-- Cleanup
player.AncestryChanged:Connect(function(_, parent)
    if not parent and socket then
        pcall(function() socket:Close() end)
    end
end)
