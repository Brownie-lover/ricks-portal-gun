--[[

    PORTAL GUN

    LocalScript

    Place in StarterPlayerScripts or execute as a LocalScript.

    FEATURES

    • No key/code required

    • Gun scale = 0.4

    • Coordinates mode


    • Player mode + player list below input

    • Scroll wheel shoots portal at cursor

    • Click OPEN PORTAL deploys using the selected mode

    • Walking through a destination portal teleports you

    • Original portal stays where you entered

    • A RETURN portal stays in the original spot you started from

    • Return portal sends you back to the original spot

    • Portals expire after 15 seconds

]]

local Players = game:GetService("Players")

local TweenService = game:GetService("TweenService")

local RunService = game:GetService("RunService")

local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local backpack = player:WaitForChild("Backpack")

local mouse = player:GetMouse()

--============================================================

-- SETTINGS

--============================================================

local GUN_SCALE = 0.4

local GUN_ASSET_ID = 1118298602

local GREEN = Color3.fromRGB(45, 255, 90)

local LIGHT_GREEN = Color3.fromRGB(150, 255, 170)

local BODY_COLOR = Color3.fromRGB(150, 150, 145)

local BODY_DARK = Color3.fromRGB(55, 57, 55)

local PORTAL_LIFETIME = 15

local PORTAL_DISTANCE = 7
local PORTAL_TELEPORT_COOLDOWN = 0.8
local portalTeleportLocked = false

local teleportMode = "Coordinates"

local currentGun

local mainGui

local menu

local status

local playerBox

local xBox

local yBox

local zBox

local currentPortal

local returnPortal

local flipPortalFacing

local portalConnections = {}

local playerListButtons = {}

local gunAnimationConnection

local coordinateConnection

--============================================================

-- CLEANUP CONNECTIONS

--============================================================

local function disconnectAll(list)

    for _, connection in ipairs(list) do

        if connection then

            connection:Disconnect()

        end

    end

    table.clear(list)

end

--============================================================

-- CHARACTER

--============================================================

local function getCharacter()

    return player.Character

end

local function getRoot(character)

    character = character or getCharacter()

    if not character then

        return nil

    end

    return character:FindFirstChild("HumanoidRootPart")

end

--============================================================

-- PORTAL TELEPORT / CAMERA

--============================================================

local cameraSnapId = "PortalCameraSnap"

local function teleportPlayerTo(targetCFrame)

    local character = getCharacter()

    local root = getRoot(character)

    if not root or not targetCFrame then

        return

    end

    root.CFrame = targetCFrame
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = false
    end

    local camera = workspace.CurrentCamera
    local desiredLook = targetCFrame.LookVector

    -- Shift-lock can overwrite the camera after the teleport, so force the
    -- camera to face the exit direction for a short moment after Roblox's
    -- normal camera update has run.
    pcall(function()
        RunService:UnbindFromRenderStep(cameraSnapId)
    end)

    if camera then
        RunService:BindToRenderStep(
            cameraSnapId,
            Enum.RenderPriority.Camera.Value + 1,
            function()
                local currentCamera = workspace.CurrentCamera
                if not currentCamera then
                    return
                end

                local cameraPosition = currentCamera.CFrame.Position
                currentCamera.CFrame = CFrame.lookAt(
                    cameraPosition,
                    cameraPosition + desiredLook
                )
            end
        )

        task.delay(0.25, function()
            pcall(function()
                RunService:UnbindFromRenderStep(cameraSnapId)
            end)

            local currentHumanoid = getCharacter() and
                getCharacter():FindFirstChildOfClass("Humanoid")

            if currentHumanoid then
                currentHumanoid.AutoRotate = true
            end
        end)
    else
        if humanoid then
            humanoid.AutoRotate = true
        end
    end
end

--============================================================

-- PORTAL CLEANUP

--============================================================

local function destroyPortal(portal)

    if not portal then

        return

    end

    if portal.Parent then

        portal:Destroy()

    end

end

local function clearPortalConnections()

    disconnectAll(portalConnections)

end

local function removeAllPortals()

    destroyPortal(currentPortal)
    destroyPortal(returnPortal)

    currentPortal = nil
    returnPortal = nil

    portalTeleportLocked = false

end

--============================================================

-- CREATE PART

--============================================================

local function makePart(parent, name, size, color, material, cframe)

    local part = Instance.new("Part")

    part.Name = name

    part.Size = size

    part.Color = color

    part.Material = material

    part.CFrame = cframe

    part.Anchored = true

    part.CanCollide = false

    part.CanTouch = false

    part.CanQuery = false

    part.CastShadow = false

    part.Parent = parent

    return part

end

--============================================================

-- PORTAL CREATOR

--============================================================

local function createPortal(position, facing, labelText, targetCFrame, isReturn)

    local model = Instance.new("Model")

    model.Name = isReturn and "ReturnPortal" or "DestinationPortal"

    model.Parent = workspace

    local portalCFrame = CFrame.lookAt(

        position,

        position + facing

    )

    -- Outer portal

    local portal = Instance.new("Part")

    portal.Name = isReturn and "RETURN" or "DESTINATION"

    portal.Size = Vector3.new(7, 10, 0.4)

    portal.CFrame = portalCFrame

    portal.Color = GREEN

    portal.Material = Enum.Material.Neon

    portal.Transparency = 0.25

    portal.Anchored = true

    portal.CanCollide = false

    portal.CanTouch = true

    portal.CanQuery = false

    portal.CastShadow = false

    portal.Parent = model

    local mesh = Instance.new("SpecialMesh")

    mesh.MeshType = Enum.MeshType.Sphere

    mesh.Scale = Vector3.new(0.55, 1, 0.07)

    mesh.Parent = portal

    -- Inner portal

    local inner = Instance.new("Part")

    inner.Name = "PortalCore"

    inner.Size = Vector3.new(6.2, 9.2, 0.15)

    inner.CFrame = portalCFrame * CFrame.new(0, 0, -0.12)

    inner.Color = LIGHT_GREEN

    inner.Material = Enum.Material.Neon

    inner.Transparency = 0.35

    inner.Anchored = true

    inner.CanCollide = false

    inner.CanTouch = false

    inner.CanQuery = false

    inner.CastShadow = false

    inner.Parent = model

    local innerMesh = Instance.new("SpecialMesh")

    innerMesh.MeshType = Enum.MeshType.Sphere

    innerMesh.Scale = Vector3.new(0.55, 1, 0.05)

    innerMesh.Parent = inner

    -- Light

    local light = Instance.new("PointLight")

    light.Color = GREEN

    light.Brightness = 8

    light.Range = 18

    light.Parent = portal

    -- Particles

    local attachment = Instance.new("Attachment")

    attachment.Parent = portal

    local particles = Instance.new("ParticleEmitter")

    particles.Color = ColorSequence.new({

        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 70)),

        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 255, 140)),

        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 180, 50))

    })

    particles.LightEmission = 1

    particles.LightInfluence = 0

    particles.Rate = 120

    particles.Lifetime = NumberRange.new(0.4, 1)

    particles.Speed = NumberRange.new(1, 4)

    particles.SpreadAngle = Vector2.new(180, 180)

    particles.Rotation = NumberRange.new(0, 360)

    particles.RotSpeed = NumberRange.new(-250, 250)

    particles.Size = NumberSequence.new({

        NumberSequenceKeypoint.new(0, 0.2),

        NumberSequenceKeypoint.new(0.5, 0.08),

        NumberSequenceKeypoint.new(1, 0)

    })

    particles.Parent = attachment

    -- Energy rings

    for i = 1, 4 do

        local ring = Instance.new("Part")

        ring.Name = "EnergyRing"

        ring.Shape = Enum.PartType.Cylinder

        ring.Size = Vector3.new(

            0.08,

            6 + i * 0.55,

            6 + i * 0.55

        )

        ring.CFrame =

            portalCFrame *

            CFrame.Angles(

                math.rad(90),

                0,

                math.rad(i * 45)

            )

        ring.Color = GREEN

        ring.Material = Enum.Material.Neon

        ring.Transparency = 0.3

        ring.Anchored = true

        ring.CanCollide = false

        ring.CanTouch = false

        ring.CanQuery = false

        ring.CastShadow = false

        ring.Parent = model

    end

    -- Label

    local billboard = Instance.new("BillboardGui")

    billboard.Name = "PortalLabel"

    billboard.Size = UDim2.fromOffset(280, 50)

    billboard.StudsOffset = Vector3.new(0, 6, 0)

    billboard.AlwaysOnTop = true

    billboard.Parent = portal

    local label = Instance.new("TextLabel")

    label.Size = UDim2.fromScale(1, 1)

    label.BackgroundTransparency = 1

    label.Text = labelText

    label.TextColor3 = GREEN

    label.TextStrokeTransparency = 0.3

    label.Font = Enum.Font.GothamBold

    label.TextSize = 20

    label.Parent = billboard

    -- Animation

    local startTime = os.clock()

    local animationConnection

    animationConnection = RunService.RenderStepped:Connect(function()

        if not model.Parent then

            animationConnection:Disconnect()

            return

        end

        local elapsed = os.clock() - startTime

        local pulse = 1 + math.sin(elapsed * 5) * 0.06

        portal.Size = Vector3.new(

            7 * pulse,

            10 * pulse,

            0.4

        )

        for i, object in ipairs(model:GetChildren()) do

            if object.Name == "EnergyRing" then

                object.CFrame =

                    portal.CFrame *

                    CFrame.Angles(

                        math.rad(90),

                        elapsed * (i * 0.8),

                        math.rad(i * 45)

                    )

            end

        end

    end)

    table.insert(portalConnections, animationConnection)

    --========================================================

    -- TELEPORT

    --========================================================

    local debounce = false

    local touchConnection

    touchConnection = portal.Touched:Connect(function(hit)

        if debounce or portalTeleportLocked then

            return

        end

        local character = getCharacter()

        local root = getRoot(character)

        if not character or not root then

            return

        end

        if not hit:IsDescendantOf(character) then

            return

        end

        debounce = true
        portalTeleportLocked = true

        -- RETURN PORTAL

        if isReturn then

            if targetCFrame then

                teleportPlayerTo(targetCFrame)

            end

            task.delay(PORTAL_TELEPORT_COOLDOWN, function()

                debounce = false
                portalTeleportLocked = false

            end)

            return

        end

        -- DESTINATION PORTAL

        if targetCFrame then

            root.CFrame = targetCFrame

            root.AssemblyLinearVelocity = Vector3.zero

            root.AssemblyAngularVelocity = Vector3.zero

            -- Keep the GO TO portal in the exact same spot, but flip its
            -- facing so it faces the other way after you walk out.
            flipPortalFacing(returnPortal)

        end

        task.delay(PORTAL_TELEPORT_COOLDOWN, function()

            debounce = false
            portalTeleportLocked = false

        end)

    end)

    table.insert(portalConnections, touchConnection)

    -- Auto delete

    task.delay(PORTAL_LIFETIME, function()

        if model.Parent then

            for _, object in ipairs(model:GetDescendants()) do

                if object:IsA("BasePart") then

                    TweenService:Create(

                        object,

                        TweenInfo.new(0.3),

                        {Transparency = 1}

                    ):Play()

                elseif object:IsA("ParticleEmitter") then

                    object.Enabled = false

                elseif object:IsA("PointLight") then

                    TweenService:Create(

                        object,

                        TweenInfo.new(0.3),

                        {Brightness = 0}

                    ):Play()

                end

            end

            task.wait(0.35)

            if model.Parent then

                model:Destroy()

            end

        end

    end)

    return model

end

--============================================================
-- PORTAL ORIENTATION
--============================================================

flipPortalFacing = function(portalModel)

    if not portalModel or not portalModel.Parent then
        return
    end

    local portalPart = portalModel:FindFirstChild("RETURN")
        or portalModel:FindFirstChild("DESTINATION")

    if not portalPart or not portalPart:IsA("BasePart") then
        return
    end

    local oldCFrame = portalPart.CFrame
    local newCFrame = oldCFrame * CFrame.Angles(0, math.rad(180), 0)

    for _, object in ipairs(portalModel:GetDescendants()) do

        if object:IsA("BasePart") then

            local relative = oldCFrame:ToObjectSpace(object.CFrame)
            object.CFrame = newCFrame * relative

        end

    end
end

--============================================================

-- AIM PORTAL AT CURSOR

--============================================================

-- Builds an exit CFrame that always keeps the player standing upright.
-- CFrame.lookAt() breaks down (produces a tilted/garbage orientation) when
-- the look direction is parallel to world-up, which is exactly what
-- happens when a portal is shot onto the floor or ceiling (surface normal
-- = straight up/down). When that happens we fall back to a horizontal
-- facing direction instead, so you always pop out standing up straight.
local function computeExitCFrame(position, facing)

    local horizontal = Vector3.new(facing.X, 0, facing.Z)

    if horizontal.Magnitude < 0.05 then

        -- Facing is (near) straight up or down - no usable horizontal
        -- component. Fall back to the direction the player is currently
        -- facing so the exit still points somewhere sensible.
        local character = getCharacter()
        local root = getRoot(character)

        if root then
            local lookVector = root.CFrame.LookVector
            local rootHorizontal = Vector3.new(lookVector.X, 0, lookVector.Z)

            if rootHorizontal.Magnitude > 0.05 then
                horizontal = rootHorizontal
            else
                horizontal = Vector3.new(0, 0, -1)
            end
        else
            horizontal = Vector3.new(0, 0, -1)
        end

    end

    horizontal = horizontal.Unit

    return CFrame.lookAt(
        position,
        position + horizontal,
        Vector3.new(0, 1, 0)
    )
end

local function shootPortalAtCursor()

    local character = getCharacter()
    local root = getRoot(character)

    if not character or not root then
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    local mousePosition = UserInputService:GetMouseLocation()
    local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, currentGun}

    local result = workspace:Raycast(
        ray.Origin,
        ray.Direction * 1000,
        params
    )

    if not result then
        return
    end

    local hitPosition = result.Position
    local normal = result.Normal

    local portalPosition = hitPosition + normal * 0.25
    local facing = normal

    -- Create the second side of the portal directly in front of you.
    local entrancePosition =
        root.Position + root.CFrame.LookVector * PORTAL_DISTANCE

    local entranceFacing =
        -root.CFrame.LookVector

    local entrancePortalFacing =
        -root.CFrame.LookVector

    -- Each portal targets the OTHER portal.
    -- Exit orientation: face OUT of the portal, just like a real portal.
    -- Uses computeExitCFrame instead of a raw CFrame.lookAt so that a
    -- portal shot on the floor/ceiling (vertical facing) still spits you
    -- out standing upright instead of at a broken tilt.
    local destinationCFrame =
        computeExitCFrame(
            portalPosition + facing * 3,
            facing
        )

    -- When returning, face AWAY from the GO TO portal.
    -- entranceFacing is the portal's outward normal, so the exit direction
    -- is the opposite of that normal.
    local entranceCFrame =
        computeExitCFrame(
            entrancePosition - entranceFacing * 3,
            -entranceFacing
        )

    -- Remove the old portal pair.
    destroyPortal(currentPortal)
    destroyPortal(returnPortal)

    -- Destination portal -> sends you to the portal in front of you.
    currentPortal = createPortal(
        portalPosition,
        facing,
        "DESTINATION",
        entranceCFrame,
        false
    )

    -- Portal in front of you -> sends you to the destination portal.
    returnPortal = createPortal(
        entrancePosition,
        entrancePortalFacing,
        "GO TO PORTAL",
        destinationCFrame,
        true
    )
end

--============================================================

-- COORDINATE HUD

--============================================================

local function createCoordinateHUD(gui)

    local frame = Instance.new("Frame")

    frame.Size = UDim2.fromOffset(200, 88)

    frame.Position = UDim2.new(1, -225, 1, -175)

    frame.BackgroundColor3 = Color3.fromRGB(10, 14, 12)

    frame.BackgroundTransparency = 0.12

    frame.Visible = false

    frame.Parent = gui

    local corner = Instance.new("UICorner")

    corner.CornerRadius = UDim.new(0, 12)

    corner.Parent = frame

    local stroke = Instance.new("UIStroke")

    stroke.Color = GREEN

    stroke.Thickness = 1.5

    stroke.Parent = frame

    local title = Instance.new("TextLabel")

    title.Size = UDim2.new(1, -16, 0, 25)

    title.Position = UDim2.fromOffset(8, 5)

    title.BackgroundTransparency = 1

    title.Text = "CURRENT POSITION"

    title.TextColor3 = GREEN

    title.Font = Enum.Font.GothamBold

    title.TextSize = 12

    title.Parent = frame

    local label = Instance.new("TextLabel")

    label.Size = UDim2.new(1, -16, 0, 52)

    label.Position = UDim2.fromOffset(8, 30)

    label.BackgroundTransparency = 1

    label.TextColor3 = Color3.fromRGB(220, 255, 225)

    label.Font = Enum.Font.Code

    label.TextSize = 13

    label.TextXAlignment = Enum.TextXAlignment.Left

    label.TextYAlignment = Enum.TextYAlignment.Top

    label.Parent = frame

    return frame, label

end

--============================================================

-- MAIN GUI

--============================================================

local function createGUI()

    local gui = Instance.new("ScreenGui")

    gui.Name = "PortalGunGUI"

    gui.ResetOnSpawn = false

    gui.IgnoreGuiInset = true

    gui.Parent = player:WaitForChild("PlayerGui")

    mainGui = gui

    local main = Instance.new("Frame")

    main.Name = "PortalMenu"

    main.Size = UDim2.fromOffset(390, 410)

    main.Position = UDim2.fromScale(0.5, 0.5)

    main.AnchorPoint = Vector2.new(0.5, 0.5)

    main.BackgroundColor3 = Color3.fromRGB(12, 15, 18)

    main.BackgroundTransparency = 0.04

    main.Visible = false

    main.Parent = gui

    menu = main

    local previousMouseBehavior = Enum.MouseBehavior.Default

    menu:GetPropertyChangedSignal("Visible"):Connect(function()

        if menu.Visible then

            previousMouseBehavior = UserInputService.MouseBehavior

            UserInputService.MouseBehavior = Enum.MouseBehavior.Default

            UserInputService.MouseIconEnabled = true

        else

            UserInputService.MouseBehavior = previousMouseBehavior

        end

    end)

    local corner = Instance.new("UICorner")

    corner.CornerRadius = UDim.new(0, 16)

    corner.Parent = main

    local stroke = Instance.new("UIStroke")

    stroke.Color = GREEN

    stroke.Thickness = 2

    stroke.Parent = main

    -- Title

    local title = Instance.new("TextLabel")

    title.Size = UDim2.new(1, -60, 0, 45)

    title.Position = UDim2.fromOffset(15, 10)

    title.BackgroundTransparency = 1

    title.Text = "PORTAL GUN"

    title.TextColor3 = Color3.fromRGB(220, 255, 230)

    title.Font = Enum.Font.GothamBold

    title.TextSize = 25

    title.Parent = main

    -- Close

    local close = Instance.new("TextButton")

    close.Size = UDim2.fromOffset(32, 32)

    close.Position = UDim2.new(1, -43, 0, 12)

    close.BackgroundTransparency = 1

    close.Text = "×"

    close.TextColor3 = Color3.fromRGB(170, 180, 175)

    close.Font = Enum.Font.GothamBold

    close.TextSize = 28

    close.Parent = main

    close.MouseButton1Click:Connect(function()

        main.Visible = false

    end)

    -- Remove Portals (sits above the panel, not clipped since main
    -- doesn't clip descendants, so it shows/hides with the menu)

    local removeButton = Instance.new("TextButton")

    removeButton.Name = "RemovePortalsButton"

    removeButton.Size = UDim2.fromOffset(200, 40)

    removeButton.AnchorPoint = Vector2.new(0.5, 1)

    removeButton.Position = UDim2.new(0.5, 0, 0, -14)

    removeButton.BackgroundColor3 = Color3.fromRGB(150, 35, 35)

    removeButton.Text = "REMOVE PORTALS"

    removeButton.TextColor3 = Color3.fromRGB(255, 235, 235)

    removeButton.Font = Enum.Font.GothamBold

    removeButton.TextSize = 15

    removeButton.AutoButtonColor = false

    removeButton.Parent = main

    local removeCorner = Instance.new("UICorner")

    removeCorner.CornerRadius = UDim.new(0, 10)

    removeCorner.Parent = removeButton

    local removeStroke = Instance.new("UIStroke")

    removeStroke.Color = Color3.fromRGB(255, 120, 120)

    removeStroke.Thickness = 1.5

    removeStroke.Parent = removeButton

    removeButton.MouseButton1Click:Connect(function()

        removeAllPortals()

    end)

    local subtitle = Instance.new("TextLabel")

    subtitle.Size = UDim2.new(1, -30, 0, 25)

    subtitle.Position = UDim2.fromOffset(15, 48)

    subtitle.BackgroundTransparency = 1

    subtitle.Text = "Choose a destination"

    subtitle.TextColor3 = Color3.fromRGB(130, 160, 140)

    subtitle.Font = Enum.Font.Gotham

    subtitle.TextSize = 14

    subtitle.Parent = main

    --========================================================

    -- MODE BUTTONS

    --========================================================

    local modes = {}

    local function makeModeButton(text, x)

        local button = Instance.new("TextButton")

        button.Size = UDim2.fromOffset(110, 32)

        button.Position = UDim2.fromOffset(x, 75)

        button.BackgroundColor3 = Color3.fromRGB(24, 29, 32)

        button.Text = text

        button.TextColor3 = Color3.fromRGB(170, 190, 180)

        button.Font = Enum.Font.GothamBold

        button.TextSize = 11

        button.AutoButtonColor = false

        button.Parent = main

        local c = Instance.new("UICorner")

        c.CornerRadius = UDim.new(0, 8)

        c.Parent = button

        return button

    end

    modes.Coordinates = makeModeButton("COORDINATES", 80)

    modes.Player = makeModeButton("PLAYER", 200)

    --========================================================

    -- FIELD CREATOR

    --========================================================

    local function makeField(name, placeholder, position, size)

        local box = Instance.new("TextBox")

        box.Name = name

        box.Size = size or UDim2.fromOffset(105, 50)

        box.Position = position

        box.BackgroundColor3 = Color3.fromRGB(24, 29, 32)

        box.TextColor3 = Color3.fromRGB(235, 255, 240)

        box.PlaceholderColor3 = Color3.fromRGB(100, 120, 105)

        box.PlaceholderText = placeholder

        box.Text = ""

        box.Font = Enum.Font.GothamMedium

        box.TextSize = 17

        box.ClearTextOnFocus = false

        box.Parent = main

        local c = Instance.new("UICorner")

        c.CornerRadius = UDim.new(0, 10)

        c.Parent = box

        local s = Instance.new("UIStroke")

        s.Color = Color3.fromRGB(55, 90, 65)

        s.Thickness = 1

        s.Parent = box

        return box

    end

    xBox = makeField(

        "X",

        "X",

        UDim2.fromOffset(20, 120)

    )

    yBox = makeField(

        "Y",

        "Y",

        UDim2.fromOffset(142, 120)

    )

    zBox = makeField(

        "Z",

        "Z",

        UDim2.fromOffset(264, 120)

    )

    playerBox = makeField(

        "PlayerName",

        "Username / Display Name",

        UDim2.fromOffset(30, 120),

        UDim2.fromOffset(330, 50)

    )

    playerBox.Visible = false

    --========================================================

    -- PLAYER LIST

    --========================================================

    local playerList = Instance.new("ScrollingFrame")

    playerList.Name = "PlayerList"

    playerList.Size = UDim2.fromOffset(330, 82)

    playerList.Position = UDim2.fromOffset(30, 178)

    playerList.BackgroundColor3 = Color3.fromRGB(18, 23, 25)

    playerList.BorderSizePixel = 0

    playerList.ScrollBarThickness = 4

    playerList.Visible = false

    playerList.CanvasSize = UDim2.new()

    playerList.Parent = main

    local listLayout = Instance.new("UIListLayout")

    listLayout.Padding = UDim.new(0, 3)

    listLayout.Parent = playerList

    local listPadding = Instance.new("UIPadding")

    listPadding.PaddingTop = UDim.new(0, 4)

    listPadding.PaddingLeft = UDim.new(0, 4)

    listPadding.PaddingRight = UDim.new(0, 4)

    listPadding.Parent = playerList

    local playerListUpdateConnection

    local function getPlayerCoordsText(p)

        local character = p.Character

        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not root then

            return "no character"

        end

        local pos = root.Position

        return string.format(

            "X: %d  Y: %d  Z: %d",

            math.floor(pos.X + 0.5),

            math.floor(pos.Y + 0.5),

            math.floor(pos.Z + 0.5)

        )

    end

    local function refreshPlayerList()

        for _, child in ipairs(playerList:GetChildren()) do

            if child:IsA("TextButton") then

                child:Destroy()

            end

        end

        table.clear(playerListButtons)

        for _, p in ipairs(Players:GetPlayers()) do

            if p ~= player then

                local button = Instance.new("TextButton")

                button.Size = UDim2.new(1, -8, 0, 40)

                button.BackgroundColor3 = Color3.fromRGB(27, 35, 32)

                button.TextColor3 = Color3.fromRGB(220, 255, 225)

                button.Font = Enum.Font.Gotham

                button.TextSize = 13

                button.TextWrapped = true

                button.TextXAlignment = Enum.TextXAlignment.Left

                button.Text =

                    "  " .. p.DisplayName .. "  @" .. p.Name ..

                    "\n  " .. getPlayerCoordsText(p)

                button.AutoButtonColor = false

                button.Parent = playerList

                local c = Instance.new("UICorner")

                c.CornerRadius = UDim.new(0, 6)

                c.Parent = button

                button.MouseButton1Click:Connect(function()

                    playerBox.Text = p.Name

                end)

                playerListButtons[button] = p

            end

        end

        task.defer(function()

            playerList.CanvasSize = UDim2.fromOffset(

                0,

                listLayout.AbsoluteContentSize.Y + 8

            )

        end)

    end

    local function startPlayerListUpdates()

        if playerListUpdateConnection then

            return

        end

        playerListUpdateConnection = RunService.Heartbeat:Connect(function()

            for button, p in pairs(playerListButtons) do

                if button.Parent and p.Parent then

                    button.Text =

                        "  " .. p.DisplayName .. "  @" .. p.Name ..

                        "\n  " .. getPlayerCoordsText(p)

                end

            end

        end)

    end

    local function stopPlayerListUpdates()

        if playerListUpdateConnection then

            playerListUpdateConnection:Disconnect()

            playerListUpdateConnection = nil

        end

    end

    Players.PlayerAdded:Connect(refreshPlayerList)

    Players.PlayerRemoving:Connect(refreshPlayerList)

    --========================================================

    -- DEPLOY BUTTON

    --========================================================

    local deployButton = Instance.new("TextButton")

    deployButton.Size = UDim2.new(1, -60, 0, 55)

    deployButton.Position = UDim2.fromOffset(30, 275)

    deployButton.BackgroundColor3 = Color3.fromRGB(25, 150, 65)

    deployButton.Text = "OPEN PORTAL"

    deployButton.TextColor3 = Color3.fromRGB(235, 255, 240)

    deployButton.Font = Enum.Font.GothamBold

    deployButton.TextSize = 17

    deployButton.AutoButtonColor = false

    deployButton.Parent = main

    local deployCorner = Instance.new("UICorner")

    deployCorner.CornerRadius = UDim.new(0, 12)

    deployCorner.Parent = deployButton

    --========================================================

    -- STATUS

    --========================================================

    status = Instance.new("TextLabel")

    status.Size = UDim2.new(1, -60, 0, 50)

    status.Position = UDim2.fromOffset(30, 340)

    status.BackgroundTransparency = 1

    status.Text = "Enter coordinates or choose a player."

    status.TextColor3 = Color3.fromRGB(110, 140, 120)

    status.Font = Enum.Font.Gotham

    status.TextSize = 13

    status.TextWrapped = true

    status.Parent = main

    --========================================================

    -- MODE SWITCHING

    --========================================================

    local function updateMode(mode)

        teleportMode = mode

        local coordinates = mode == "Coordinates"

        local playerMode = mode == "Player"

        xBox.Visible = coordinates

        yBox.Visible = coordinates

        zBox.Visible = coordinates


        playerBox.Visible = playerMode

        playerList.Visible = playerMode

        modes.Coordinates.BackgroundColor3 =

            coordinates

            and Color3.fromRGB(25, 150, 65)

            or Color3.fromRGB(24, 29, 32)

        modes.Player.BackgroundColor3 =

            playerMode

            and Color3.fromRGB(25, 150, 65)

            or Color3.fromRGB(24, 29, 32)

        if coordinates then

            subtitle.Text = "Enter destination coordinates"

            status.Text = "Enter X, Y and Z"

        else

            subtitle.Text = "Choose a player"

            status.Text = "Select a player below"

            refreshPlayerList()

            startPlayerListUpdates()

        end

        if not playerMode then

            stopPlayerListUpdates()

        end

    end

    modes.Coordinates.MouseButton1Click:Connect(function()

        updateMode("Coordinates")

    end)

    modes.Player.MouseButton1Click:Connect(function()

        updateMode("Player")

    end)

    --========================================================

    -- DEPLOY

    --========================================================

    deployButton.MouseButton1Click:Connect(function()

        local character = getCharacter()

        local root = getRoot(character)

        if not root then

            return

        end

        -- COORDINATES

        if teleportMode == "Coordinates" then

            local x = tonumber(xBox.Text)

            local y = tonumber(yBox.Text)

            local z = tonumber(zBox.Text)

            if not x or not y or not z then

                status.Text = "Invalid coordinates."

                status.TextColor3 = Color3.fromRGB(255, 100, 100)

                return

            end

            local target =

                Vector3.new(x, y, z) +

                Vector3.new(0, 4, 0)

            local destinationFacing = Vector3.new(0, 0, -1)

            -- Create a GO TO PORTAL in front of you, just like middle-click.
            local entrancePosition =
                root.Position + root.CFrame.LookVector * PORTAL_DISTANCE

            local entranceFacing =
                -root.CFrame.LookVector

            local entrancePortalFacing =
                -root.CFrame.LookVector

            -- Each portal targets the OTHER portal.
            -- Face outward from each portal when you come through it.
            local destinationCFrame =
                CFrame.lookAt(
                    target + destinationFacing * 3,
                    target + destinationFacing * 4
                ) * CFrame.Angles(0, math.rad(180), 0)

            local entranceCFrame =
                CFrame.lookAt(
                    entrancePosition + entranceFacing * 3,
                    entrancePosition + entranceFacing * 4
                ) * CFrame.Angles(0, math.rad(180), 0)

            -- Remove the old portal pair.
            destroyPortal(currentPortal)
            destroyPortal(returnPortal)

            -- Destination portal -> sends you back to the GO TO PORTAL.
            currentPortal = createPortal(
                target,
                destinationFacing,
                "DESTINATION",
                entranceCFrame,
                false
            )

            -- GO TO PORTAL -> sends you to the coordinate destination.
            returnPortal = createPortal(
                entrancePosition,
                entrancePortalFacing,
                "GO TO PORTAL",
                destinationCFrame,
                true
            )

            status.Text = string.format(

                "Portal → %.1f, %.1f, %.1f",

                x, y, z

            )

            status.TextColor3 = GREEN

            main.Visible = false

        -- PLAYER

        elseif teleportMode == "Player" then

            local name = playerBox.Text:match("^%s*(.-)%s*$")

            if name == "" then

                status.Text = "Enter a player."

                status.TextColor3 =

                    Color3.fromRGB(255, 100, 100)

                return

            end

            local target

            -- Username

            for _, p in ipairs(Players:GetPlayers()) do

                if string.lower(p.Name) == string.lower(name) then

                    target = p

                    break

                end

            end

            -- Display name

            if not target then

                for _, p in ipairs(Players:GetPlayers()) do

                    if string.lower(p.DisplayName) ==

                        string.lower(name) then

                        target = p

                        break

                    end

                end

            end

            if not target then

                status.Text = "Player not found."

                status.TextColor3 =

                    Color3.fromRGB(255, 100, 100)

                return

            end

            if target == player then

                status.Text = "You cannot target yourself."

                status.TextColor3 =

                    Color3.fromRGB(255, 100, 100)

                return

            end

            local targetRoot = getRoot(target.Character)

            if not targetRoot then

                status.Text = "Player is not spawned."

                status.TextColor3 =

                    Color3.fromRGB(255, 100, 100)

                return

            end

            -- Save the original spot and create a two-way portal pair.
            -- The GO TO PORTAL stays exactly where you started, while the
            -- destination portal is placed at the selected player's position.

            local entrancePosition =
                root.Position + root.CFrame.LookVector * PORTAL_DISTANCE

            local entranceFacing =
                -root.CFrame.LookVector

            local entrancePortalFacing =
                -root.CFrame.LookVector

            local destinationPosition = targetRoot.Position
            local destinationFacing = targetRoot.CFrame.LookVector

            local destinationCFrame =
                CFrame.lookAt(
                    destinationPosition + destinationFacing * 3,
                    destinationPosition + destinationFacing * 4
                ) * CFrame.Angles(0, math.rad(180), 0)

            local entranceCFrame =
                CFrame.lookAt(
                    entrancePosition + entranceFacing * 3,
                    entrancePosition + entranceFacing * 4
                ) * CFrame.Angles(0, math.rad(180), 0)

            destroyPortal(currentPortal)
            destroyPortal(returnPortal)

            currentPortal = createPortal(
                destinationPosition,
                destinationFacing,
                "DESTINATION → " .. target.Name,
                entranceCFrame,
                false
            )

            returnPortal = createPortal(
                entrancePosition,
                entrancePortalFacing,
                "GO TO " .. target.Name,
                destinationCFrame,
                true
            )

            status.Text = "Portal → " .. target.Name

            status.TextColor3 = GREEN

            main.Visible = false

        end

    end)

    updateMode("Coordinates")

    --========================================================

    -- COORDINATE HUD

    --========================================================

    local coordinateFrame, coordinateLabel =

        createCoordinateHUD(gui)

    -- Save My Coords - sits directly above the position HUD, fills the
    -- X/Y/Z fields with the player's current (rounded) position so you
    -- don't have to type numbers in manually.

    local saveCoordsButton = Instance.new("TextButton")

    saveCoordsButton.Name = "SaveMyCoordsButton"

    saveCoordsButton.Size = UDim2.fromOffset(200, 34)

    saveCoordsButton.Position = UDim2.new(1, -225, 1, -217)

    saveCoordsButton.BackgroundColor3 = Color3.fromRGB(20, 45, 28)

    saveCoordsButton.Text = "SAVE MY COORDS"

    saveCoordsButton.TextColor3 = GREEN

    saveCoordsButton.Font = Enum.Font.GothamBold

    saveCoordsButton.TextSize = 13

    saveCoordsButton.AutoButtonColor = false

    saveCoordsButton.Visible = false

    saveCoordsButton.Parent = gui

    local saveCoordsCorner = Instance.new("UICorner")

    saveCoordsCorner.CornerRadius = UDim.new(0, 10)

    saveCoordsCorner.Parent = saveCoordsButton

    local saveCoordsStroke = Instance.new("UIStroke")

    saveCoordsStroke.Color = GREEN

    saveCoordsStroke.Thickness = 1.5

    saveCoordsStroke.Parent = saveCoordsButton

    saveCoordsButton.MouseButton1Click:Connect(function()

        local root = getRoot()

        if not root then
            return
        end

        local pos = root.Position

        xBox.Text = tostring(math.floor(pos.X + 0.5))
        yBox.Text = tostring(math.floor(pos.Y + 0.5))
        zBox.Text = tostring(math.floor(pos.Z + 0.5))

        updateMode("Coordinates")
        menu.Visible = true

    end)

    local function startHUD()

        if coordinateConnection then

            coordinateConnection:Disconnect()

        end

        coordinateFrame.Visible = true

        saveCoordsButton.Visible = true

        coordinateConnection =

            RunService.RenderStepped:Connect(function()

                local root = getRoot()

                if not root then

                    return

                end

                local p = root.Position

                coordinateLabel.Text = string.format(

                    "X: %.1f\nY: %.1f\nZ: %.1f",

                    p.X,

                    p.Y,

                    p.Z

                )

            end)

    end

    local function stopHUD()

        coordinateFrame.Visible = false

        saveCoordsButton.Visible = false

        if coordinateConnection then

            coordinateConnection:Disconnect()

            coordinateConnection = nil

        end

        stopPlayerListUpdates()

    end

    return gui, main, startHUD, stopHUD

end

--============================================================

-- PORTAL GUN

--============================================================

-- Tries to load a real gun model from the Roblox catalog (GUN_ASSET_ID).
-- Returns the handle/core/coreLight it found, or nil if the load failed
-- or the asset had no usable parts - in which case the caller falls back
-- to the hand-built part-by-part gun below.
local function loadGunAssetParts(tool)

    local InsertService = game:GetService("InsertService")

    local ok, container = pcall(function()

        return InsertService:LoadAsset(GUN_ASSET_ID)

    end)

    if not ok or not container then

        warn("Portal Gun: failed to load asset " .. tostring(GUN_ASSET_ID))

        return nil

    end

    -- LoadAsset always wraps the result in a Model; look inside for a Tool

    local innerTool = container:FindFirstChildOfClass("Tool")

    local source = innerTool or container

    local parts = {}

    for _, descendant in ipairs(source:GetDescendants()) do

        if descendant:IsA("BasePart") then

            table.insert(parts, descendant)

        end

    end

    if #parts == 0 and source:IsA("BasePart") then

        table.insert(parts, source)

    end

    if #parts == 0 then

        warn("Portal Gun: asset " .. tostring(GUN_ASSET_ID) .. " has no parts")

        container:Destroy()

        return nil

    end

    -- Prefer a part literally named "Handle"; otherwise use the first part

    local handle

    for _, part in ipairs(parts) do

        if part.Name == "Handle" then

            handle = part

            break

        end

    end

    handle = handle or parts[1]

    handle.Name = "Handle"

    for _, part in ipairs(parts) do

        part.Anchored = false

        part.CanCollide = false

        part.CanTouch = false

        part.CanQuery = false

        part.Massless = true

        part.CastShadow = false

        part.Parent = tool

        if part ~= handle then

            local weld = Instance.new("WeldConstraint")

            weld.Part0 = handle

            weld.Part1 = part

            weld.Parent = part

        end

    end

    -- If the asset was already a Tool with its own grip, keep it

    if innerTool and innerTool.Grip ~= CFrame.new() then

        tool.Grip = innerTool.Grip

    end

    -- Optional: reuse a part named "PortalCore"/"Core" for the pulse glow

    local core =

        source:FindFirstChild("PortalCore", true) or

        source:FindFirstChild("Core", true)

    local coreLight = core and core:FindFirstChildOfClass("PointLight")

    if core and not coreLight then

        coreLight = Instance.new("PointLight")

        coreLight.Color = GREEN

        coreLight.Brightness = 3

        coreLight.Range = 7

        coreLight.Parent = core

    end

    container:Destroy()

    return handle, core, coreLight

end

local function createPortalGun(startHUD, stopHUD)

    local tool = Instance.new("Tool")

    tool.Name = "Portal Gun"

    tool.RequiresHandle = true

    tool.CanBeDropped = false

    tool.ToolTip =

        "LMB = Menu | MMB = Shoot Portal"

    local handle, core, coreLight = loadGunAssetParts(tool)

    local usingCustomAsset = handle ~= nil

    if not usingCustomAsset then

    --========================================================

    -- HANDLE

    --========================================================

    handle = Instance.new("Part")

    handle.Name = "Handle"

    handle.Size = Vector3.new(0.72, 2.35, 0.72)

    handle.Color = BODY_DARK

    handle.Material = Enum.Material.SmoothPlastic

    handle.CanCollide = false

    handle.CanTouch = false

    handle.CanQuery = false

    handle.Massless = true

    handle.CastShadow = false

    handle.Parent = tool

    -- Corrected hold rotation

    tool.Grip =

        CFrame.new(0, -0.05, -0.15) *

        CFrame.Angles(

            math.rad(0),

            math.rad(90),

            math.rad(0)

        )

    --========================================================

    -- BODY

    --========================================================

    local function addPart(name, size, color, offset, rotation)

        local part = Instance.new("Part")

        part.Name = name

        part.Size = size

        part.Color = color

        part.Material = Enum.Material.SmoothPlastic

        part.CanCollide = false

        part.CanTouch = false

        part.CanQuery = false

        part.Massless = true

        part.CastShadow = false

        part.CFrame =

            handle.CFrame *

            CFrame.new(offset) *

            (rotation or CFrame.new())

        part.Parent = tool

        local weld = Instance.new("WeldConstraint")

        weld.Part0 = handle

        weld.Part1 = part

        weld.Parent = part

        return part

    end

    addPart(

        "MainBody",

        Vector3.new(3.6, 0.75, 2.1),

        BODY_COLOR,

        Vector3.new(-1.55, 1.4, 0)

    )

    addPart(

        "BottomBody",

        Vector3.new(3.25, 0.18, 1.8),

        Color3.fromRGB(90, 92, 90),

        Vector3.new(-1.55, 0.97, 0)

    )

    addPart(

        "FrontPanel",

        Vector3.new(0.15, 0.62, 1.75),

        Color3.fromRGB(65, 67, 65),

        Vector3.new(-3.37, 1.4, 0)

    )

    -- Green emitters

    for i = -1, 1 do

        local emitter = Instance.new("Part")

        emitter.Name = "GreenEmitter"

        emitter.Shape = Enum.PartType.Cylinder

        emitter.Size = Vector3.new(0.16, 0.43, 0.43)

        emitter.Color = GREEN

        emitter.Material = Enum.Material.Neon

        emitter.CanCollide = false

        emitter.CanTouch = false

        emitter.CanQuery = false

        emitter.Massless = true

        emitter.CastShadow = false

        emitter.CFrame =

            handle.CFrame *

            CFrame.new(-3.46, 1.4, i * 0.55) *

            CFrame.Angles(0, math.rad(90), 0)

        emitter.Parent = tool

        local weld = Instance.new("WeldConstraint")

        weld.Part0 = handle

        weld.Part1 = emitter

        weld.Parent = emitter

        local light = Instance.new("PointLight")

        light.Color = GREEN

        light.Brightness = 1.5

        light.Range = 4

        light.Parent = emitter

    end

    addPart(

        "TopPlate",

        Vector3.new(2.9, 0.12, 1.75),

        Color3.fromRGB(170, 170, 165),

        Vector3.new(-1.4, 1.83, 0)

    )

    local redPanel = addPart(

        "RedPanel",

        Vector3.new(0.9, 0.08, 0.62),

        Color3.fromRGB(210, 45, 45),

        Vector3.new(-0.65, 1.93, 0)

    )

    redPanel.Material = Enum.Material.Neon

    local redLight = Instance.new("PointLight")

    redLight.Color = Color3.fromRGB(255, 40, 40)

    redLight.Brightness = 0.5

    redLight.Range = 3

    redLight.Parent = redPanel

    --========================================================

    -- CHAMBER

    --========================================================

    local chamber = Instance.new("Part")

    chamber.Name = "Chamber"

    chamber.Shape = Enum.PartType.Cylinder

    chamber.Size = Vector3.new(0.35, 1.05, 1.05)

    chamber.Color = Color3.fromRGB(190, 190, 185)

    chamber.Material = Enum.Material.SmoothPlastic

    chamber.CanCollide = false

    chamber.CanTouch = false

    chamber.CanQuery = false

    chamber.Massless = true

    chamber.CastShadow = false

    chamber.CFrame =

        handle.CFrame *

        CFrame.new(-2.2, 2.2, 0) *

        CFrame.Angles(0, 0, math.rad(90))

    chamber.Parent = tool

    local chamberWeld = Instance.new("WeldConstraint")

    chamberWeld.Part0 = handle

    chamberWeld.Part1 = chamber

    chamberWeld.Parent = chamber

    core = Instance.new("Part")

    core.Name = "PortalCore"

    core.Shape = Enum.PartType.Ball

    core.Size = Vector3.new(0.65, 0.85, 0.65)

    core.Color = GREEN

    core.Material = Enum.Material.Neon

    core.Transparency = 0.08

    core.CanCollide = false

    core.CanTouch = false

    core.CanQuery = false

    core.Massless = true

    core.CastShadow = false

    core.CFrame =

        handle.CFrame *

        CFrame.new(-2.2, 2.97, 0)

    core.Parent = tool

    local coreWeld = Instance.new("WeldConstraint")

    coreWeld.Part0 = handle

    coreWeld.Part1 = core

    coreWeld.Parent = core

    coreLight = Instance.new("PointLight")

    coreLight.Color = GREEN

    coreLight.Brightness = 3

    coreLight.Range = 7

    coreLight.Parent = core

    --========================================================

    -- GRIP

    --========================================================

    addPart(

        "GripBottom",

        Vector3.new(0.82, 0.65, 0.82),

        Color3.fromRGB(48, 50, 48),

        Vector3.new(0.35, -1, 0),

        CFrame.Angles(0, 0, math.rad(-18))

    )

    addPart(

        "GripTop",

        Vector3.new(0.85, 0.75, 0.85),

        BODY_DARK,

        Vector3.new(-0.4, 0.8, 0),

        CFrame.Angles(0, 0, math.rad(-18))

    )

    addPart(

        "GripInsert",

        Vector3.new(0.5, 1.7, 0.75),

        Color3.fromRGB(35, 37, 35),

        Vector3.new(0.02, 0, -0.38),

        CFrame.Angles(0, 0, math.rad(-18))

    )

    addPart(

        "GripLight",

        Vector3.new(0.08, 1.1, 0.2),

        GREEN,

        Vector3.new(-0.35, 0.1, -0.43),

        CFrame.Angles(0, 0, math.rad(-18))

    )

    --========================================================

    -- SCALE GUN

    --========================================================

    if GUN_SCALE ~= 1 then

        local originalCFrame = handle.CFrame

        local parts = {}

        for _, object in ipairs(tool:GetChildren()) do

            if object:IsA("BasePart") then

                table.insert(parts, object)

            end

        end

        for _, part in ipairs(parts) do

            local relative =

                originalCFrame:ToObjectSpace(

                    part.CFrame

                )

            local position = relative.Position

            local rotation = relative - position

            part.Size *= GUN_SCALE

            part.CFrame =

                originalCFrame *

                CFrame.new(position * GUN_SCALE) *

                rotation

        end

    end -- not usingCustomAsset

    local coreBaseSize = core and core.Size

    --========================================================

    -- EQUIPPED

    --========================================================

    tool.Equipped:Connect(function()

        startHUD()

        if gunAnimationConnection then

            gunAnimationConnection:Disconnect()

        end

        gunAnimationConnection =

            RunService.RenderStepped:Connect(function()

                if not core or not core.Parent then

                    return

                end

                local pulse =

                    1 +

                    math.sin(os.clock() * 5) *

                    0.12

                core.Size =

                    coreBaseSize * pulse

                if coreLight then

                    coreLight.Brightness =

                        3 +

                        math.sin(os.clock() * 5)

                end

            end)

    end)

    tool.Unequipped:Connect(function()

        stopHUD()

        if gunAnimationConnection then

            gunAnimationConnection:Disconnect()

            gunAnimationConnection = nil

        end

        if menu then

            menu.Visible = false

        end

    end)

    --========================================================

    -- LEFT CLICK = MENU

    --========================================================

    tool.Activated:Connect(function()

        if menu then

            menu.Visible = not menu.Visible

        end

    end)

    --========================================================

    -- MIDDLE CLICK = SHOOT AT CURSOR

    --========================================================

    tool.Equipped:Connect(function()

        local middleConnection

        middleConnection =

            UserInputService.InputBegan:Connect(function(input, processed)

                if processed then

                    return

                end

                if input.UserInputType ==

                    Enum.UserInputType.MouseButton3 then

                    if currentGun == tool then

                        shootPortalAtCursor()

                    end

                elseif input.KeyCode == Enum.KeyCode.X then

                    if currentGun == tool then

                        removeAllPortals()

                    end

                end

            end)

        tool.Unequipped:Connect(function()

            if middleConnection then

                middleConnection:Disconnect()

                middleConnection = nil

            end

        end)

    end)

    tool.Parent = backpack

    return tool

end

--============================================================

-- SETUP

--============================================================

local function setup()

    if currentGun then

        currentGun:Destroy()

        currentGun = nil

    end

    local old = backpack:FindFirstChild("Portal Gun")

    if old then

        old:Destroy()

    end

    local character = getCharacter()

    if character then

        local equipped = character:FindFirstChild("Portal Gun")

        if equipped then

            equipped:Destroy()

        end

    end

    if not mainGui then

        local _, _, startHUD, stopHUD = createGUI()

        currentGun =

            createPortalGun(

                startHUD,

                stopHUD

            )

    else

        local coordinateFrame = mainGui:FindFirstChild("CurrentCoordinates")

        currentGun =

            createPortalGun(

                function() end,

                function() end

            )

    end

end

--============================================================

-- RESPAWN

--============================================================

player.CharacterAdded:Connect(function()

    destroyPortal(currentPortal)

    destroyPortal(returnPortal)

    currentPortal = nil

    returnPortal = nil

    clearPortalConnections()

    task.wait(1)

    setup()

end)

--============================================================

-- START

--============================================================

local _, _, startHUD, stopHUD = createGUI()

currentGun =

    createPortalGun(

        startHUD,

        stopHUD

    )
