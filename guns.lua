local memoize = require "memoize"
local textplus = require "textplus"

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
    gun.recoilTime = gun.recoilTime + 1

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

    local totalRecoil
    if gun.recoilAmplitude == 0 then
        totalRecoil = adjustedRecoilRotation
    else
        local sineWaveRecoil = gun.recoilAmplitude * math.sin(gun.recoilTime * gun.recoilFrequency)
        totalRecoil = (adjustedRecoilRotation + sineWaveRecoil) * (1 - 0.1 * gun.stabilityRate)
    end

    gun.currentRecoilRotation = math.clamp(
        gun.currentRecoilRotation + totalRecoil,
        -gun.maxRecoilRotation,
        gun.maxRecoilRotation
    ) * 0.95
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

    if gun.ammo ~= -1 then
        gun.ammo = gun.ammo - 1
    end

    if gun.fireRate ~= -1 then
        gun.timeTillNextFire = gun.fireRate
    end

    gun.currentFlash = 1

    Defines.earthquake = Defines.earthquake + gun.screenshake
    gun:recoil()
end

local function reload(gun, amount)
    if gun.reloadSound ~= nil then
        SFX.play(gun.reloadSound)
    end

    gun.currentReloadTime = gun.reloadTime
    gun.nextReloadAmount = amount or gun.ammoCapacity
end

local gunMT = {
    __index = {
        attach = attach,
        equip = equip,
        unequip = unequip,
        shoot = shoot,
        recoil = recoil,
        fireRaycast = fireRaycast,
        reload = reload,
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
        currentReloadTime = 0,
        ammo = params.ammoCapacity or -1,
        timeTillNextFire = 0,
        recoilTime = 0,

        crosshairTexture = Graphics.loadImageResolved(params.crosshair),
        bodyTexture = Graphics.loadImageResolved(params.body),
        muzzleFlashTexture = Graphics.loadImageResolved(params.muzzleFlashTexture),
        firingSound = params.firingSound,
        reloadSound = params.reloadSound,
        reloadTexture = (params.reloadTexture ~= nil) and Graphics.loadImageResolved(params.reloadTexture) or nil,
        --muzzleFlash = (params.muzzleFlash ~= nil)
            --and Shader.fromFile(params.muzzleFlash..".vert", params.muzzleFlash..".frag") or nil,

        fireRate = params.fireRate or -1,
        automatic = params.automatic or false,
        autoReload = params.autoReload or false,
        reloadTime = params.reloadTime or 0,
        ammoCapacity = params.ammoCapacity or -1,
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
        recoilAmplitude = params.recoilAmplitude or 0,
        recoilFrequency = params.recoilFrequency or 0,
        stabilityRate = params.stabilityRate or 1
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
    local halfBase = baseLength / 2
    local apexY = isPointingUpwards and (centerY + height) or (centerY - height)
    return {
        centerX - halfBase, centerY,
        centerX + halfBase, centerY,
        centerX, apexY
    }
end)

function guns.onDraw()
    for id, gun in ipairs(guns.members) do

        textplus.print {
            x = 0,
            y = (id-1)*70,
            text = "<size 7>" .. tostring(gun.ammo).."/"..tostring(gun.ammoCapacity) .. "</size>"
        }

        if gun.player == nil or not gun.equipped then goto continue end

        local bodyTexture
        if gun.currentReloadTime == 0 or gun.reloadTexture == nil then
            bodyTexture = gun.bodyTexture
        else
            bodyTexture = gun.reloadTexture
        end

        Graphics.drawBox {
            type = RTYPE_IMAGE,
            texture = bodyTexture,
            x = gun.totalX,
            y = gun.totalY,
            priority = -20,
            rotation = gun.currentTotalRotation,
            sceneCoords = true,
            height = gun.bodyTexture.height * gun.direction,
            centered = true
        }

        if gun.currentFlash == 0 then goto continue end

        local angle = gun.currentTotalRotation * math.pi / 180

        Graphics.drawBox {
            type = RTYPE_IMAGE,
            texture = gun.muzzleFlashTexture,
            x = gun.totalX + gun.bulletOffsetX * math.cos(angle) - gun.bulletOffsetY * -gun.direction * math.sin(angle),
            y = gun.totalY + gun.bulletOffsetX * math.sin(angle) + gun.bulletOffsetY * -gun.direction * math.cos(angle),
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

        if gun.currentRecoilRotation > 0 then
            gun.currentRecoilRotation = math.max(0, gun.currentRecoilRotation - gun.recoilRotation * gun.recoilRotationDecay)
        elseif gun.currentRecoilRotation < 0 then
            gun.currentRecoilRotation = math.min(0, gun.currentRecoilRotation + gun.recoilRotation * gun.recoilRotationDecay)
        end

        gun.player.direction = gun.direction

        gun.pivotX = gun.player.x + gun.player.width * 0.5 + gun.direction + gun.bodyOffsetX * gun.direction
        gun.pivotY = gun.player.y + gun.player.height * 0.5 - gun.direction + gun.bodyOffsetY

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

        if gun.currentReloadTime == 1 then
            gun.ammo = gun.nextReloadAmount
        end
        gun.currentReloadTime = math.max(0, gun.currentReloadTime - 1)

        if gun.ammo == 0 and gun.autoReload and gun.currentReloadTime == 0 then
            gun:reload()
        end

        gun.timeTillNextFire = math.max(0, gun.timeTillNextFire - 1)

        if mem(0x00B2D6CC, FIELD_BOOL) then
            if gun.automatic and gun.timeTillNextFire == 0 and gun.ammo ~= 0 and gun.currentReloadTime == 0 then
                gun:shoot()
            end
        else
            gun.recoilTime = math.max(0, gun.recoilTime - gun.stabilityRate)
        end

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
        if gun.player == nil or not gun.equipped or Misc.isPaused() or gun.currentReloadTime > 0 then goto continue end

        if state == KEYS_PRESSED then
            if mouseButton == 0 then
                if gun.timeTillNextFire > 0 or gun.ammo == 0 then goto continue end
                gun:shoot()
            elseif mouseButton == 1 then
                if gun.ammoCapacity == -1 or gun.ammo == gun.ammoCapacity then goto continue end
                gun:reload()
            end
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