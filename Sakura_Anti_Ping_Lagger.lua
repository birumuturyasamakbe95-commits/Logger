-- Sakura Anti Ping Lagger / Anti Lagger
-- Catches small+big lag packs · safe (no re-hook on block) · refresh counter @300

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COLORS = {
    bg = Color3.fromRGB(14, 14, 16),
    disabled = Color3.fromRGB(38, 38, 44),
    accent = Color3.fromRGB(255, 60, 80),
    accentBright = Color3.fromRGB(255, 100, 120),
    text = Color3.fromRGB(238, 238, 242),
    white = Color3.fromRGB(255, 255, 255),
    black = Color3.fromRGB(0, 0, 0),
}

local FONT = Enum.Font.GothamBlack
local DISCORD = "discord.gg/sakuraduels"

local MIN_ARRAY = 6
local MIN_DICT = 6
local MIN_STRING = 4000
local REFRESH_EVERY = 300
local MAX_BLOCKS_PER_FRAME = 60

local _frameBlocks = 0

local Blocker = {
    enabled = false,
    blockedCount = 0,
    sessionBlocked = 0,
    refreshCount = 0,
    hooked = false,
    _wrapped = false,
}

local function nc(fn)
    if type(newcclosure) == "function" then
        local ok, c = pcall(newcclosure, fn)
        if ok and c then return c end
    end
    return fn
end

local LAG_REMOTE_NAMES = {
    SetPlayerBlockList = true,
    UpdatePlayerBlockList = true,
    SetBlockList = true,
    UpdateBlockList = true,
}

local function isLagRemote(inst)
    if typeof(inst) ~= "Instance" then return false end
    local ok, name = pcall(function() return inst.Name end)
    if not ok or type(name) ~= "string" then return false end
    if LAG_REMOTE_NAMES[name] then return true end
    local lower = string.lower(name)
    if string.find(lower, "blocklist", 1, true) then return true end
    if string.find(lower, "block_list", 1, true) then return true end
    return false
end

local function isLagPayload(...)
    local n = select("#", ...)
    if n < 1 then return false end
    local limit = n < 4 and n or 4
    for i = 1, limit do
        local a = select(i, ...)
        local t = type(a)
        if t == "table" then
            local len = #a
            if len >= MIN_ARRAY then
                return true
            end
            if len > 0 then
                local nested = 0
                local peek = len < 8 and len or 8
                for j = 1, peek do
                    local v = rawget(a, j)
                    if type(v) == "table" then
                        nested = nested + 1
                        if nested >= 2 then return true end
                        if #v >= MIN_ARRAY then return true end
                    end
                end
                if nested >= 1 and len >= 3 then return true end
            else
                local c = 0
                for _ in pairs(a) do
                    c = c + 1
                    if c >= MIN_DICT then return true end
                end
            end
        elseif t == "string" and #a >= MIN_STRING then
            return true
        end
    end
    return false
end

local function shouldBlock(self, ...)
    if not Blocker.enabled then return false end
    if _frameBlocks >= MAX_BLOCKS_PER_FRAME then return false end
    if not isLagRemote(self) then return false end
    return isLagPayload(...)
end

local function onBlocked()
    _frameBlocks = _frameBlocks + 1
    local n = Blocker.blockedCount + 1
    if n >= REFRESH_EVERY then
        Blocker.blockedCount = 0
        Blocker.refreshCount = Blocker.refreshCount + 1
    else
        Blocker.blockedCount = n
    end
    Blocker.sessionBlocked = Blocker.sessionBlocked + 1
end

RunService.Heartbeat:Connect(function()
    _frameBlocks = 0
end)

local function installNamecall()
    if Blocker.hooked then return true end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        warn("[Anti Ping Lagger] hookmetamethod missing")
        return false
    end
    local ok, err = pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", nc(function(self, ...)
            if Blocker.enabled then
                local method = getnamecallmethod()
                if method == "FireServer" or method == "fireserver" then
                    if shouldBlock(self, ...) then
                        onBlocked()
                        return
                    end
                end
            end
            return old(self, ...)
        end))
        Blocker.hooked = true
    end)
    if not ok then
        warn("[Anti Ping Lagger] hook failed:", err)
    end
    return Blocker.hooked
end

local function tryWrapRemote()
    pcall(function()
        if type(hookfunction) ~= "function" then return end
        local rrs = game:FindFirstChild("RobloxReplicatedStorage")
        if not rrs then return end
        for _, name in ipairs({
            "SetPlayerBlockList",
            "UpdatePlayerBlockList",
            "SetBlockList",
            "UpdateBlockList",
        }) do
            local remote = rrs:FindFirstChild(name)
            if remote and remote:IsA("RemoteEvent") then
                if not remote:GetAttribute("__SakuraAPLWrapped") then
                    local oldFire
                    oldFire = hookfunction(remote.FireServer, nc(function(self, ...)
                        if Blocker.enabled and isLagPayload(...) then
                            if _frameBlocks < MAX_BLOCKS_PER_FRAME then
                                onBlocked()
                            end
                            return
                        end
                        return oldFire(self, ...)
                    end))
                    pcall(function() remote:SetAttribute("__SakuraAPLWrapped", true) end)
                end
            end
        end
        Blocker._wrapped = true
    end)
end

function Blocker.start()
    Blocker.enabled = true
    installNamecall()
    tryWrapRemote()
end

function Blocker.stop()
    Blocker.enabled = false
end

function Blocker.toggle()
    if Blocker.enabled then Blocker.stop() else Blocker.start() end
    return Blocker.enabled
end

function Blocker.resetStats()
    Blocker.blockedCount = 0
    Blocker.sessionBlocked = 0
    Blocker.refreshCount = 0
end

pcall(installNamecall)
task.defer(function()
    task.wait(0.3)
    pcall(tryWrapRemote)
end)

pcall(function()
    local rrs = game:FindFirstChild("RobloxReplicatedStorage")
    if rrs then
        rrs.ChildAdded:Connect(function(ch)
            if LAG_REMOTE_NAMES[ch.Name] then
                task.defer(tryWrapRemote)
            end
        end)
    end
end)


-- === Head Billboard Discord (K7 style) ===
local headBillboard = nil
local DISCORD_URL = "https://discord.gg/sakuraduels"

local function createHeadBillboard()
    if headBillboard and headBillboard.Parent then return end
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "SakuraDiscordBillboard"
    bb.Size = UDim2.new(0, 220, 0, 40)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBlack
    label.Text = DISCORD_URL
    label.TextColor3 = Color3.fromRGB(255, 70, 70)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextSize = 16
    label.TextScaled = false
    label.Parent = bb

    headBillboard = bb
end

local function removeHeadBillboard()
    if headBillboard then
        pcall(function() headBillboard:Destroy() end)
        headBillboard = nil
    end
end

player.CharacterAdded:Connect(function(char)
    headBillboard = nil
    task.wait(0.5)
    if Blocker.enabled then
        pcall(createHeadBillboard)
    end
end)

-- ========== UI ==========
pcall(function()
    for _, n in ipairs({ "SakuraAntiAntiLoseUI", "SakuraAntiPingLaggerUI", "AntiPingLaggerUI" }) do
        local old = playerGui:FindFirstChild(n)
        if old then old:Destroy() end
    end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SakuraAntiPingLaggerUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true

screenGui.Parent = playerGui



local main = Instance.new("Frame")
main.Name = "MainFrame"
main.Size = UDim2.new(0, 250, 0, 128)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Parent = screenGui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local mainGrad = Instance.new("UIGradient")
mainGrad.Color = ColorSequence.new(COLORS.bg, Color3.fromRGB(28, 10, 12))
mainGrad.Rotation = 135
mainGrad.Parent = main

local borderFrame = Instance.new("Frame")
borderFrame.Size = UDim2.new(1, 2, 1, 2)
borderFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
borderFrame.AnchorPoint = Vector2.new(0.5, 0.5)
borderFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
borderFrame.BorderSizePixel = 0
borderFrame.ZIndex = 0
borderFrame.Parent = main
Instance.new("UICorner", borderFrame).CornerRadius = UDim.new(0, 11)

local borderGrad = Instance.new("UIGradient")
borderGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(40, 10, 15)),
    ColorSequenceKeypoint.new(0.25, Color3.fromRGB(180, 40, 55)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 90, 110)),
    ColorSequenceKeypoint.new(0.75, Color3.fromRGB(180, 40, 55)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(40, 10, 15)),
})
borderGrad.Parent = borderFrame

local innerMask = Instance.new("Frame")
innerMask.Size = UDim2.new(1, -2, 1, -2)
innerMask.Position = UDim2.new(0.5, 0, 0.5, 0)
innerMask.AnchorPoint = Vector2.new(0.5, 0.5)
innerMask.BackgroundColor3 = COLORS.bg
innerMask.BorderSizePixel = 0
innerMask.ZIndex = 1
innerMask.Parent = main
Instance.new("UICorner", innerMask).CornerRadius = UDim.new(0, 9)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -36, 0, 26)
title.Position = UDim2.new(0, 0, 0, 2)
title.BackgroundTransparency = 1
title.Font = FONT
title.Text = "Anti Ping Lagger"
title.TextColor3 = COLORS.text
title.TextSize = 14
title.ZIndex = 3
title.Parent = main

local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 26, 0, 26)
hideBtn.Position = UDim2.new(1, -30, 0, 4)
hideBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 24)
hideBtn.BorderSizePixel = 0
hideBtn.Text = "−"
hideBtn.TextColor3 = COLORS.white
hideBtn.Font = FONT
hideBtn.TextSize = 16
hideBtn.AutoButtonColor = false
hideBtn.ZIndex = 6
hideBtn.Parent = main
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 6)

-- Discord line (sakuraduels)
local discordLbl = Instance.new("TextLabel")
discordLbl.Size = UDim2.new(1, -8, 0, 14)
discordLbl.Position = UDim2.new(0, 4, 0, 24)
discordLbl.BackgroundTransparency = 1
discordLbl.Font = Enum.Font.GothamMedium
discordLbl.Text = DISCORD
discordLbl.TextColor3 = Color3.fromRGB(255, 100, 120)
discordLbl.TextSize = 11
discordLbl.ZIndex = 3
discordLbl.Parent = main

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, -20, 0, 34)
toggle.Position = UDim2.new(0, 10, 0, 44)
toggle.BackgroundColor3 = COLORS.disabled
toggle.BorderSizePixel = 0
toggle.Text = ""
toggle.AutoButtonColor = false
toggle.ZIndex = 3
toggle.Parent = main
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)

local toggleGrad = Instance.new("UIGradient")
toggleGrad.Color = ColorSequence.new(COLORS.disabled, Color3.fromRGB(48, 48, 54))
toggleGrad.Rotation = 135
toggleGrad.Parent = toggle

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(120, 40, 50)
toggleStroke.Thickness = 1.66
toggleStroke.Parent = toggle

local toggleLabel = Instance.new("TextLabel")
toggleLabel.Size = UDim2.new(1, 0, 1, 0)
toggleLabel.BackgroundTransparency = 1
toggleLabel.Font = FONT
toggleLabel.Text = "DISABLED"
toggleLabel.TextColor3 = COLORS.white
toggleLabel.TextSize = 14
toggleLabel.ZIndex = 5
toggleLabel.Parent = toggle

-- Only block stats (no empty fluff)
local stats = Instance.new("TextLabel")
stats.Size = UDim2.new(1, -16, 0, 18)
stats.Position = UDim2.new(0, 8, 1, -22)
stats.BackgroundTransparency = 1
stats.Font = Enum.Font.GothamMedium
stats.Text = "block: 0"
stats.TextColor3 = Color3.fromRGB(180, 180, 190)
stats.TextSize = 12
stats.TextXAlignment = Enum.TextXAlignment.Left
stats.ZIndex = 3
stats.Parent = main

local reopen = Instance.new("TextButton")
reopen.Name = "ReopenBtn"
reopen.Size = UDim2.new(0, 150, 0, 32)
reopen.Position = UDim2.new(0.5, -75, 1, -70)
reopen.BackgroundColor3 = COLORS.bg
reopen.BorderSizePixel = 0
reopen.Text = "Anti Lagger"
reopen.TextColor3 = COLORS.accentBright
reopen.Font = FONT
reopen.TextSize = 12
reopen.Visible = false
reopen.ZIndex = 10
reopen.Parent = screenGui
Instance.new("UICorner", reopen).CornerRadius = UDim.new(0, 8)
local reopenStroke = Instance.new("UIStroke")
reopenStroke.Color = COLORS.accent
reopenStroke.Thickness = 1.4
reopenStroke.Parent = reopen

local guiOpen = true
local function setGuiOpen(state)
    guiOpen = state == true
    main.Visible = guiOpen
    reopen.Visible = not guiOpen
end

hideBtn.MouseButton1Click:Connect(function() setGuiOpen(false) end)
reopen.MouseButton1Click:Connect(function() setGuiOpen(true) end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.P then
        setGuiOpen(not guiOpen)
    end
end)

local active = false
local _lastStat, _lastRefresh = -1, -1

RunService.RenderStepped:Connect(function(dt)
    borderGrad.Rotation = (borderGrad.Rotation + (active and 160 or 60) * dt) % 360
    local n = Blocker.blockedCount
    local r = Blocker.refreshCount
    if (n ~= _lastStat or r ~= _lastRefresh) and stats and stats.Parent then
        _lastStat = n
        _lastRefresh = r
        if r > 0 then
            stats.Text = string.format("block: %d  |  refresh: %d", n, r)
        else
            stats.Text = string.format("block: %d", n)
        end
    end
end)

local function setActive(state)
    active = state
    if state then
        toggle.BackgroundColor3 = COLORS.accentBright
        toggleGrad.Color = ColorSequence.new(COLORS.accent, COLORS.accentBright)
        toggleGrad.Rotation = 0
        toggleStroke.Color = COLORS.accentBright
        toggleLabel.Text = "BLOCKING"
        toggleLabel.TextColor3 = COLORS.black
        Blocker.start()
        pcall(createHeadBillboard)
    else
        toggle.BackgroundColor3 = COLORS.disabled
        toggleGrad.Color = ColorSequence.new(COLORS.disabled, Color3.fromRGB(48, 48, 54))
        toggleGrad.Rotation = 135
        toggleStroke.Color = Color3.fromRGB(120, 40, 50)
        toggleLabel.Text = "DISABLED"
        toggleLabel.TextColor3 = COLORS.white
        Blocker.stop()
        pcall(removeHeadBillboard)
    end
end

toggle.MouseButton1Click:Connect(function()
    setActive(not active)
end)

local dragging, dragStart, startPos = false, nil, nil
main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

do
    local d, ds, sp = false, nil, nil
    reopen.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            d, ds, sp = true, input.Position, reopen.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if d and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - ds
            reopen.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            d = false
        end
    end)
end

_G.SakuraAntiPingLagger = Blocker
_G.SakuraAntiLagger = Blocker
print("[Anti Ping Lagger] " .. DISCORD)
