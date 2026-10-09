Freecam = {
    active = false,
    locked = false, -- true while a photo tour drives the camera
    hideUi = false, -- true while a screenshot is being taken
}

local cam, pos, rot, fov

local CONTROL = {
    lookX = 1, lookY = 2,
    forward = 32, back = 33, left = 34, right = 35,
    up = 38, down = 44,          -- E / Q
    fast = 21, slow = 36,        -- SHIFT / CTRL
    zoomIn = 241, zoomOut = 242, -- mouse wheel
    photo = 24,                  -- left mouse
    exit = 194,                  -- BACKSPACE
    toggleHelp = 74,             -- H
}

local showHelp = true
local HELP = 'WASD move  Q/E down/up  SHIFT fast  CTRL slow~n~Wheel zoom  LMB photo  H hide help  BACKSPACE exit'

local function apply()
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    SetCamRot(cam, rot.x, rot.y, rot.z, 2)
    SetCamFov(cam, fov)
    SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)
end

local function handleInput()
    local cfg = Config.Freecam
    local dt = GetFrameTime()

    local mx = GetDisabledControlNormal(0, CONTROL.lookX)
    local my = GetDisabledControlNormal(0, CONTROL.lookY)
    local sens = cfg.sensitivity * (fov / cfg.fov)
    rot = vector3(math.max(-89.0, math.min(89.0, rot.x - my * sens)), 0.0, (rot.z - mx * sens) % 360.0)

    local speed = cfg.speed * dt
    if IsDisabledControlPressed(0, CONTROL.fast) then speed = speed * cfg.fastMultiplier end
    if IsDisabledControlPressed(0, CONTROL.slow) then speed = speed * cfg.slowMultiplier end

    local forward = Util.RotationToDirection(rot)
    local heading = math.rad(rot.z)
    local right = vector3(math.cos(heading), math.sin(heading), 0.0)
    local move = vector3(0.0, 0.0, 0.0)
    if IsDisabledControlPressed(0, CONTROL.forward) then move = move + forward end
    if IsDisabledControlPressed(0, CONTROL.back) then move = move - forward end
    if IsDisabledControlPressed(0, CONTROL.right) then move = move + right end
    if IsDisabledControlPressed(0, CONTROL.left) then move = move - right end
    if IsDisabledControlPressed(0, CONTROL.up) then move = move + vector3(0.0, 0.0, 1.0) end
    if IsDisabledControlPressed(0, CONTROL.down) then move = move - vector3(0.0, 0.0, 1.0) end
    pos = pos + move * speed

    if IsDisabledControlJustPressed(0, CONTROL.zoomIn) then fov = math.max(cfg.minFov, fov - 5.0) end
    if IsDisabledControlJustPressed(0, CONTROL.zoomOut) then fov = math.min(cfg.maxFov, fov + 5.0) end
    if IsDisabledControlJustPressed(0, CONTROL.toggleHelp) then showHelp = not showHelp end
    if IsDisabledControlJustPressed(0, CONTROL.photo) then
        CreateThread(function() Photo.Take('freecam') end)
    end
    if IsDisabledControlJustPressed(0, CONTROL.exit) then Freecam.Stop() end
end

local function loop()
    while Freecam.active do
        DisableAllControlActions(0)
        EnableControlAction(0, 245, true) -- chat
        EnableControlAction(0, 249, true) -- push to talk
        HideHudAndRadarThisFrame()

        if not Freecam.locked and not Freecam.hideUi then handleInput() end
        if Freecam.active then
            apply()
            if showHelp and not Freecam.hideUi and not Freecam.locked then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(HELP)
                EndTextCommandDisplayHelp(0, false, false, -1)
            end
        end
        Wait(0)
    end
end

function Freecam.Start(startPos, startRot)
    if Freecam.active then return end
    pos = startPos or GetGameplayCamCoord()
    rot = startRot or GetGameplayCamRot(2)
    fov = Config.Freecam.fov

    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, fov, false, 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    FreezeEntityPosition(PlayerPedId(), true)

    Freecam.active = true
    CreateThread(loop)
end

function Freecam.Stop()
    if not Freecam.active then return end
    Freecam.active = false
    Freecam.locked = false
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
    ClearFocus()
    FreezeEntityPosition(PlayerPedId(), false)
end

function Freecam.Toggle()
    if Freecam.active then Freecam.Stop() else Freecam.Start() end
end

function Freecam.SetView(newPos, newRot, newFov)
    pos, rot = newPos, newRot
    if newFov then fov = newFov end
    if cam then apply() end
end

function Freecam.GetView()
    return pos, rot, fov
end
