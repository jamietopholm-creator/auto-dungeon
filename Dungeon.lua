-- Dungeon.lua (loads via your main bridge)
getgenv().MY_SCRIPT = getgenv().MY_SCRIPT or {}

getgenv().MY_SCRIPT.Register(function(Window)
    local ToServer = getgenv().MY_SCRIPT.ToServer
    local H = getgenv().MY_SCRIPT.Helpers or {}

    -- Fallback helpers
    H.getMonsterCFrame = H.getMonsterCFrame or function(m)
        if m:IsA("Model") then
            if m.PrimaryPart then return m.PrimaryPart.CFrame end
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if hrp and hrp:IsA("BasePart") then return hrp.CFrame end
            for _, d in ipairs(m:GetDescendants()) do
                if d:IsA("BasePart") then return d.CFrame end
            end
        elseif m:IsA("BasePart") then
            return m.CFrame
        end
        return nil
    end

    H.getMonsterId = H.getMonsterId or function(m)
        local id; pcall(function() id = m:GetAttribute("Id") end)
        return id or m.Name
    end

    H.instantTP = H.instantTP or function(cf)
        local lp = game:GetService("Players").LocalPlayer
        local char = lp.Character or lp.CharacterAdded:Wait()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(function()
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        local behind = cf.LookVector * -1
        hrp.CFrame = cf + (behind * 1)
    end

    -- ===== UI =====
    local DungeonTab = Window:AddTab("Dungeons", "castle")
    local DG_Left  = DungeonTab:AddLeftGroupbox("Join Dungeons", "door-open")
    local DG_Right = DungeonTab:AddRightGroupbox("Automation", "swords")

    -- ===== State =====
    local AutoKill = false
    local AttackDelay  = 0.20
    local TPStickDelay = 0.08
    local NextMobDelay = 0.05
    local JoinRetry    = 5.0

    -- ===== Helpers =====
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local function getMonstersFolder()
        local w = workspace
        local debris = w:FindFirstChild("Debris")
        local mons = debris and debris:FindFirstChild("Monsters")
        if mons then return mons end
        return w:FindFirstChild("Monsters")
    end

    local function pickNearestMob()
        local folder = getMonstersFolder()
        if not folder then return nil end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end

        local best, bestDist = nil, math.huge
        for _, m in ipairs(folder:GetChildren()) do
            if m and m.Parent then
                local cf = H.getMonsterCFrame(m)
                if cf then
                    local d = (hrp.Position - cf.Position).Magnitude
                    if d < bestDist then
                        best, bestDist = m, d
                    end
                end
            end
        end
        return best
    end

    local function joinDungeon(name)
        -- IMPORTANT: use args + unpack so FireServer receives the inner table
        local args = {
            {
                Action = "_Enter_Dungeon",
                Name   = name,
            }
        }
        ToServer:FireServer(unpack(args))
        print("[Dungeon] Join request →", name)
    end

    -- ===== Loops =====
    local function startAutoJoin(stateRef, name)
        task.spawn(function()
            while stateRef.active do
                joinDungeon(name)
                task.wait(JoinRetry)
            end
        end)
    end

    local function startAutoKill()
        task.spawn(function()
            while AutoKill do
                local mob = pickNearestMob()
                if mob then
                    local cf, mobId = H.getMonsterCFrame(mob), H.getMonsterId(mob)
                    if cf and mobId then
                        H.instantTP(cf)
                        -- stick to this mob until it despawns
                        while AutoKill and mob and mob.Parent do
                            ToServer:FireServer({ Id = mobId, Action = "_Mouse_Click" })
                            task.wait(AttackDelay)
                            local cf2 = H.getMonsterCFrame(mob)
                            if cf2 then
                                H.instantTP(cf2)
                                task.wait(TPStickDelay)
                            else
                                break
                            end
                        end
                        -- small delay before locking onto the next mob
                        task.wait(NextMobDelay)
                    else
                        task.wait(0.15)
                    end
                else
                    -- likely waiting for waves/start
                    task.wait(0.4)
                end
            end
        end)
    end

    -- ===== Auto Join toggles (Easy → Nightmare) =====
    local joins = {
        { key="DG_AutoJoinEasy",      text="Auto Join Easy Dungeon",      name="Dungeon_Easy" },
        { key="DG_AutoJoinMedium",    text="Auto Join Medium Dungeon",    name="Dungeon_Medium" },
        { key="DG_AutoJoinHard",      text="Auto Join Hard Dungeon",      name="Dungeon_Hard" },
        { key="DG_AutoJoinInsane",    text="Auto Join Insane Dungeon",    name="Dungeon_Insane" },
        { key="DG_AutoJoinCrazy",     text="Auto Join Crazy Dungeon",     name="Dungeon_Crazy" },
        { key="DG_AutoJoinNightmare", text="Auto Join Nightmare Dungeon", name="Dungeon_Nightmare" },
    }

    for _, j in ipairs(joins) do
        j.state = { active=false }
        DG_Left:AddToggle(j.key, {
            Text = j.text,
            Default = false,
            Callback = function(on)
                j.state.active = on
                if on then startAutoJoin(j.state, j.name) end
            end,
        })
    end

    -- Manual join buttons
    for _, j in ipairs(joins) do
        DG_Left:AddButton({
            Text = "Join "..j.name,
            Func = function() joinDungeon(j.name) end,
        })
    end

    -- ===== Kill toggles/sliders =====
    DG_Right:AddToggle("DG_AutoKill", {
        Text = "Auto Kill Mobs (TP → nearest)",
        Default = false,
        Callback = function(on)
            AutoKill = on
            if on then startAutoKill() end
        end,
    })

    DG_Right:AddSlider("DG_AttackDelay", {
        Text = "Attack Speed (s)",
        Default = AttackDelay,
        Min = 0.01, Max = 0.50, Rounding = 2,
        Callback = function(v) AttackDelay = v end,
    })

    DG_Right:AddSlider("DG_TPStickDelay", {
        Text = "TP Stick (s)",
        Default = TPStickDelay,
        Min = 0.01, Max = 0.30, Rounding = 2,
        Callback = function(v) TPStickDelay = v end,
    })

    DG_Right:AddSlider("DG_NextMobDelay", {
        Text = "Next Mob Delay (s)",
        Default = NextMobDelay,
        Min = 0.01, Max = 0.50, Rounding = 2,
        Callback = function(v) NextMobDelay = v end,
    })

    DG_Left:AddSlider("DG_JoinRetry", {
        Text = "Join Retry (s)",
        Default = JoinRetry,
        Min = 2.0, Max = 15.0, Rounding = 1,
        Callback = function(v) JoinRetry = v end,
    })
end)
