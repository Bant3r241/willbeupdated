-- AutoJoiner with Perfect BrainRot Detection (Final Fixed Version)
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
local isRunning = false -- Starts disabled
local isPaused = false
local lastHopTime = 0
local activeJobId = nil
local selectedMpsRange = "1M-3M"
local selectedBrainRot = "Any" -- Default filter setting
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

-- [Previous GUI setup code remains identical until loadSettings()]

local function loadSettings()
    local success, savedSettings = pcall(function()
        return HttpService:JSONDecode(readfile("AutoJoinerSettings.json"))
    end)
    
    if success and savedSettings then
        selectedMpsRange = savedSettings.mpsRange or "1M-3M"
        selectedBrainRot = savedSettings.brainRot or "Any" -- Force default if invalid
        autoLoadToggle.Text = savedSettings.autoLoad and "ON" or "OFF"
        autoLoadToggle.TextColor3 = savedSettings.autoLoad and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
        
        -- Update dropdown displays
        mpsDropdown.Text = selectedMpsRange.."  ▼"
        brainRotDropdown.Text = selectedBrainRot.."  ▼"
    else
        -- Fresh install defaults
        selectedBrainRot = "Any"
        autoLoadToggle.Text = "OFF"
        autoLoadToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        mpsDropdown.Text = "1M-3M  ▼"
        brainRotDropdown.Text = "Any  ▼"
    end
end

-- Updated WebSocket message handler
local function handleWebSocketMessage(message)
    if not isRunning then -- Critical: Ignore all messages when not running
        return
    end
    
    local success, data = pcall(function()
        return HttpService:JSONDecode(message)
    end)
    
    if not success then
        statusLabel.Text = "Status: Invalid JSON"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local jobId = data.jobId
    local serverName = data.serverName or "Unknown"
    local mpsText = data.moneyPerSec and data.moneyPerSec:match("([%d%.]+)M")
    
    if not jobId or not mpsText then
        statusLabel.Text = "Status: Missing data"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local mps = tonumber(mpsText)
    if not mps then
        statusLabel.Text = "Status: Invalid MPS value"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local detectedBrainRot = detectBrainRot(serverName)
    local brainRotMatch = (selectedBrainRot == "Any") or (detectedBrainRot == selectedBrainRot)
    
    if not brainRotMatch then
        statusLabel.Text = string.format("Skipping %s (Not %s)", string.sub(jobId, 1, 8), selectedBrainRot)
        statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        return
    end
    
    -- Rest of your filtering logic...
    local shouldJoin = false
    local mpsMillions = mps
    
    if selectedMpsRange == "1M-3M" then
        shouldJoin = (mpsMillions >= 1 and mpsMillions <= 3)
    elseif selectedMpsRange == "3M-5M" then
        shouldJoin = (mpsMillions > 3 and mpsMillions <= 5)
    elseif selectedMpsRange == "5M+" then
        shouldJoin = (mpsMillions > 5)
    end
    
    if shouldJoin then
        statusLabel.Text = string.format("Joining %s (%.1fM/s, %s)", string.sub(jobId, 1, 8), mpsMillions, detectedBrainRot)
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        attemptTeleport(jobId)
    else
        statusLabel.Text = string.format("Skipping %s (%.1fM/s, %s)", string.sub(jobId, 1, 8), mpsMillions, detectedBrainRot)
        statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
    end
end

-- [Rest of the original GUI and control code remains unchanged]

-- Initialize with safe defaults
loadSettings()
switchTab("AutoJoiner")

-- Debug output
print("Script initialized successfully")
print("Current BrainRot filter:", selectedBrainRot)
print("Auto-Load status:", autoLoadToggle.Text)

-- Cleanup
player.AncestryChanged:Connect(function(_, parent)
    if not parent and socket then
        pcall(function() socket:Close() end)
    end
end)

-- Only auto-execute if explicitly enabled
if autoLoadToggle.Text == "ON" then
    task.delay(1, function()
        isRunning = true
        connectWebSocket()
    end)
end
