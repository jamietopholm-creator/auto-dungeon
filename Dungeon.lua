-- ===================== DUNGEON: Auto Easy =====================
local DungeonTab = Window:AddTab('Dungeons', 'castle')
local DG_Left  = DungeonTab:AddLeftGroupbox('Easy Dungeon', 'door-open')
local DG_Right = DungeonTab:AddRightGroupbox('Automation', 'swords')

local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local RS = game:GetService('ReplicatedStorage')
local ToServer = RS:WaitForChild('Events'):WaitForChild('To_Server')

-- === State ===
local AutoJoinEasy = false
local AutoKillEasy = false

-- === Helpers ===
local function joinEasyDungeon()
    local args = {
        { Action = "_Enter_Dungeon", Name = "Dungeon_Easy" }
    }
    ToServer:FireServer(unpack(args))
    print("[Dungeon] Sent join Easy Dungeon")
end

local function getMobCFrame(m)
    if m:IsA("Model") then
        if m.PrimaryPart then return m.PrimaryPart.CFrame end
        local hrp = m:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.CFrame end
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("BasePart") then return d.CFrame end
        end
    elseif m:IsA("BasePart") then
        return m.CFrame
    end
    return nil
end

local function getMobId(m)
    local id
    pcall(function() id = m:GetAttribute("Id") end)
    return id or m.Name
end

local function instantTP(cf)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    hrp.CFrame = cf + Vector3.new(0, 3, 0) -- stay slightly above ground
end

local function pickNearestMob()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local nearest, dist = nil, math.huge
    for _, m in ipairs(workspace.Monsters:GetChildren()) do
        if m and m.Parent then
            local cf = getMobCFrame(m)
            if cf then
                local d = (hrp.Position - cf.Position).Magnitude
                if d < dist then
                    dist = d
                    nearest = m
                end
            end
        end
    end
    return nearest
end

-- === Loops ===
local function startAutoJoin()
    task.spawn(function()
        while AutoJoinEasy do
            joinEasyDungeon()
            task.wait(5) -- try every 5s
        end
    end)
end

local function startAutoKill()
    task.spawn(function()
        while AutoKillEasy do
            local mob = pickNearestMob()
            if mob then
                local cf, mobId = getMobCFrame(mob), getMobId(mob)
                if cf and mobId then
                    instantTP(cf)
                    -- attack until mob dies
                    while AutoKillEasy and mob and mob.Parent do
                        ToServer:FireServer({ Id = mobId, Action = "_Mouse_Click" })
                        task.wait(0.2) -- attack speed
                    end
                end
            else
                task.wait(0.5)
            end
        end
    end)
end

-- === UI ===
DG_Left:AddToggle('AutoJoinEasyDungeon', {
    Text = 'Auto Join Easy Dungeon',
    Default = false,
    Callback = function(on)
        AutoJoinEasy = on
        if on then startAutoJoin() end
    end,
})

DG_Right:AddToggle('AutoKillEasyDungeon', {
    Text = 'Auto Kill Easy Dungeon Mobs',
    Default = false,
    Callback = function(on)
        AutoKillEasy = on
        if on then startAutoKill() end
    end,
})
