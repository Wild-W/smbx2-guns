local memoize = require "memoize"

local guns = {}

guns.members = {}
guns.bullets = {}

guns.defaultcam1 = true

local function attach(gun, pl)
    if gun.attached then return end

    gun.player = pl
end

local function equip(gun)
    gun.equipped = true
    Misc.setCursor(gun.crosshairTexture,
        gun.crosshairTexture.width*0.5 + gun.crosshairOffsetX,
        gun.crosshairTexture.height*0.5 + gun.crosshairOffsetY)
end

local function unequip(gun)
    gun.equipped = false
    Misc.setCursor(false)
end

local function recoil(gun)
    local aimAngle = math.atan2(guns.cursorY - gun.player.y, guns.cursorX - gun.player.x)

    -- Calculate recoil relative to rotation
    local recoilXRotated = gun.recoilX * math.cos(aimAngle) * gun.direction - gun.recoilY * math.sin(aimAngle)
    local recoilYRotated = gun.recoilX * math.sin(aimAngle) * gun.direction + gun.recoilY * math.cos(aimAngle)

    gun.currentRecoilX = math.clamp(gun.currentRecoilX + recoilXRotated, 0, gun.maxRecoilX)
    gun.currentRecoilY = math.clamp(gun.currentRecoilY + recoilYRotated, 0, gun.maxRecoilY)

    local verticalComponent = math.sin(aimAngle)

    -- Apply less recoil rotation when aiming upwards
    local adjustedRecoilRotation = (verticalComponent < 0)
        and gun.recoilRotation * (1 + verticalComponent)
        or gun.recoilRotation

    gun.currentRecoilRotation = math.clamp(gun.currentRecoilRotation + adjustedRecoilRotation, 0, gun.maxRecoilRotation)
end

local function fireRaycast(gun)
    local bulletStart = vector(gun.player.x + gun.player.width*0.5, gun.player.y + gun.player.height*0.5)
    local bulletDirection = vector(math.cos(gun.angle), -math.sin(gun.angle))

    local bullet = guns.newBullet {
        start = bulletStart,
        direction = bulletDirection
    }

    bullet:fire()
end

local function shoot(gun)
    if gun.firingSound ~= nil then
        SFX.play(gun.firingSound)
    end

    gun.currentFlash = 1

    Defines.earthquake = Defines.earthquake + gun.screenshake
    gun:recoil()
    gun:fireRaycast()
end

local gunMT = {
    __index = {
        attach = attach,
        equip = equip,
        unequip = unequip,
        shoot = shoot,
        recoil = recoil,
        fireRaycast = fireRaycast
    }
}

function guns.newGun(params)
    local newId = #guns.members+1

    local gun = {
        id = newId,
        currentRecoilX = 0,
        currentRecoilY = 0,
        currentRecoilRotation = 0,
        equipped = false,
        currentFlash = 0,

        crosshairTexture = Graphics.loadImageResolved(params.crosshair),
        bodyTexture = Graphics.loadImageResolved(params.body),
        muzzleFlashTexture = Graphics.loadImageResolved(params.muzzleFlashTexture),
        firingSound = params.firingSound,
        --muzzleFlash = (params.muzzleFlash ~= nil)
            --and Shader.fromFile(params.muzzleFlash..".vert", params.muzzleFlash..".frag") or nil,

        bodyOffsetX = params.bodyOffsetX or 0,
        bodyOffsetY = params.bodyOffsetY or 0,
        crosshairOffsetX = params.crosshairOffsetX or 0,
        crosshairOffsetY = params.crosshairOffsetY or 0,
        screenshake = params.screenshake or 0,
        recoilX = params.recoilX or 0,
        recoilY = params.recoilY or 0,
        recoilXDecay = params.recoilXDecay or 0,
        recoilYDecay = params.recoilYDecay or 0,
        recoilRotationDecay = params.recoilRotationDecay or 0,
        recoilRotation = params.recoilRotation or 0,
        maxRecoilX = params.maxRecoilX or 0,
        maxRecoilRotation = params.maxRecoilRotation or 0,
        maxRecoilY = params.maxRecoilY or 0,
        bulletOffsetX = params.bulletOffsetX or 0,
        bulletOffsetY = params.bulletOffsetY or 0,
    }
    setmetatable(gun, gunMT)

    guns.members[newId] = gun
    return gun
end

local function destroy(bullet)
    guns.bullets[bullet.id] = nil
end

local function fire(bullet)
    

    bullet.fired = true
end

local bulletMT = {
    __index = {
        fire = fire,
        destroy = destroy
    }
}

local bulletId = 0
function guns.newBullet(params)
    local newId = bulletId
    bulletId = bulletId + 1

    local bullet = {
        id = newId,
        fired = false,

        start = params.start,
        direction = params.direction,
        colliders = params.colliders,

        linger = params.linger or 65
    }
    setmetatable(bullet, bulletMT)

    guns.bullets[newId] = bullet
    return bullet
end

local function getCursorScenePosition()
    local sceneX, sceneY
    local screenX, screenY = Misc.getCursorPosition()
    local cursorPosition = {
        x = screenX,
        y = screenY
    }

    if player2 ~= nil and camera2 ~= nil and Colliders.collide(
        Colliders.Box(camera2.renderX, camera2.renderY, camera2.width, camera2.height), cursorPosition)
    then
        sceneX = camera2.x + (screenX - camera2.renderX)
        sceneY = camera2.y + (screenY - camera2.renderY)
    elseif guns.defaultcam1 or Colliders.collide(
        Colliders.Box(camera.renderX, camera.renderY, camera.width, camera.height), cursorPosition)
    then
        sceneX = camera.x + (screenX - camera.renderX)
        sceneY = camera.y + (screenY - camera.renderY)
    end

    return sceneX, sceneY
end

local getIsoTriangleVertices = memoize(function (centerX, centerY, baseLength, height, isPointingUpwards)
    local x_c, y_c = centerX, centerY
    local halfBase = baseLength / 2
    local apexY = isPointingUpwards and (y_c + height) or (y_c - height)
    return {
        x_c - halfBase, y_c,
        x_c + halfBase, y_c,
        x_c, apexY
    }
end)

function guns.onDraw()
    for _, gun in ipairs(guns.members) do
        if gun.player == nil or not gun.equipped then goto continue end

        Graphics.drawBox {
            type = RTYPE_IMAGE,
            texture = gun.bodyTexture,
            x = gun.totalX,
            y = gun.totalY,
            priority = -20,
            rotation = gun.currentTotalRotation,
            sceneCoords = true,
            height = gun.bodyTexture.height * gun.direction,
            centered = true
        }

        if gun.currentFlash == 0 then goto continue end

        Graphics.drawBox {
            type = RTYPE_IMAGE,
            texture = gun.muzzleFlashTexture,
            x = gun.totalX,
            y = gun.totalY,
            priority = -19,
            rotation = gun.currentTotalRotation,
            sceneCoords = true,
            height = gun.muzzleFlashTexture.height * gun.direction,
            centered = true
        }

        ::continue::
    end

    for _, bullet in pairs(guns.bullets) do
        if not bullet.fired then goto continue end

        ::continue::
    end
end

function guns.onTick()
    for _, gun in ipairs(guns.members) do
        if gun.player == nil or not gun.equipped then goto continue end

        guns.cursorX, guns.cursorY = getCursorScenePosition()

        gun.currentRotation = math.atan2(guns.cursorY - gun.player.y, guns.cursorX - gun.player.x)
        gun.direction = (guns.cursorX < gun.player.x + gun.player.width*0.5) and -1 or 1

        gun.currentRecoilX = math.clamp(gun.currentRecoilX - gun.recoilX * gun.recoilXDecay, 0, gun.maxRecoilX)
        gun.currentRecoilY = math.clamp(gun.currentRecoilY - gun.recoilY * gun.recoilYDecay, 0, gun.maxRecoilY)
        gun.currentRecoilRotation = math.clamp(
            gun.currentRecoilRotation - gun.recoilRotation * gun.recoilRotationDecay,
            0, gun.maxRecoilRotation)

        gun.player.direction = gun.direction

        gun.pivotX = gun.player.x + gun.player.width * 0.5 + gun.direction + gun.bodyOffsetX * gun.direction
        gun.pivotY = gun.player.y + gun.player.height * 0.5 - gun.direction + gun.bodyOffsetY * gun.direction

        local dx = guns.cursorX - gun.pivotX
        local dy = guns.cursorY - gun.pivotY
        local distance = math.sqrt(dx * dx + dy * dy)
        gun.angle = math.atan2(dy, dx)

        local clampedDistance = math.clamp(distance, 0, 30)

        local clampedX = clampedDistance * math.cos(gun.angle)
        local clampedY = clampedDistance * math.sin(gun.angle)

        gun.currentTotalRotation = (gun.currentRotation - gun.currentRecoilRotation * gun.direction) * 180 / math.pi
        gun.totalX = gun.pivotX + clampedX - gun.currentRecoilX * gun.direction
        gun.totalY = gun.pivotY + clampedY - gun.currentRecoilY

        gun.currentFlash = math.max(0, gun.currentFlash * 0.5 - 1/65)

        ::continue::
    end

    for _, bullet in pairs(guns.bullets) do
        if not bullet.fired then goto continue end

        bullet.linger = bullet.linger - 1
        if bullet.linger <= 0 then
            bullet:destroy()
        end

        ::continue::
    end
end

function guns.onMouseButtonEvent(mouseButton, state)
    for _, gun in ipairs(guns.members) do
        if gun.player == nil or not gun.equipped or Misc.isPaused() then goto continue end

        if mouseButton == 0 and state == KEYS_PRESSED then
            gun:shoot()
        end

        ::continue::
    end
end

function guns.onInitAPI()
    registerEvent(guns, "onDraw")
    registerEvent(guns, "onTick")
    registerEvent(guns, "onMouseButtonEvent")
end

return guns