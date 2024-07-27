local guns = {}

guns.members = {}
guns.bullets = {}

guns.defaultcam1 = true

local function tmemoize(func)
    return setmetatable({}, {
        __index = function(self, k)
            local v = func(k)
            self[k] = v
            return v
        end
    })
end

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
    local aimAngle = math.atan2(guns.cursorY - gun.player.y, guns.cursorX - gun.player.x)

    local bulletStart = vector(gun.player.x + gun.player.width*0.5, gun.player.y + gun.player.height*0.5)
    local bulletDirection = vector(math.cos(aimAngle), -math.sin(aimAngle))

    local bullet = guns.newBullet {
        start = bulletStart,
        direction = bulletDirection,
        colliders = Block.get()
    }

    bullet:fire()
end

local function shoot(gun)
    if gun.firingSound ~= nil then
        SFX.play(gun.firingSound)
    end

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

        crosshairTexture = Graphics.loadImageResolved(params.crosshair),
        bodyTexture = Graphics.loadImageResolved(params.body),
        firingSound = params.firingSound,

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
    local isColliding, intersection = Colliders.raycast(bullet.start, bullet.direction, bullet.colliders)
    if isColliding then
        bullet.stop = intersection
    else
        bullet.stop = bullet.start * 5
    end

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

function guns.onDraw()
    for _, gun in ipairs(guns.members) do
        if gun.player == nil or not gun.equipped then goto continue end

        local pivotX = gun.player.x + gun.player.width * 0.5 + gun.direction + gun.bodyOffsetX * gun.direction
        local pivotY = gun.player.y + gun.player.height * 0.5 - gun.direction + gun.bodyOffsetY * gun.direction

        local dx = guns.cursorX - pivotX
        local dy = guns.cursorY - pivotY
        local distance = math.sqrt(dx * dx + dy * dy)
        local angle = math.atan2(dy, dx)

        local clampedDistance = math.clamp(distance, 0, 30)

        local clampedX = clampedDistance * math.cos(angle)
        local clampedY = clampedDistance * math.sin(angle)

        Graphics.drawBox {
            type = RTYPE_IMAGE,
            texture = gun.bodyTexture,
            x = pivotX + clampedX - gun.currentRecoilX * gun.direction,
            y = pivotY + clampedY - gun.currentRecoilY,
            priority = -20,
            rotation = (gun.currentRotation - gun.currentRecoilRotation * gun.direction) * 180 / math.pi,
            sceneCoords = true,
            height = gun.bodyTexture.height * gun.direction,
            centered = true
        }

        ::continue::
    end

    for _, bullet in pairs(guns.bullets) do
        if not bullet.fired then goto continue end

        Graphics.drawLine {
            start = bullet.start,
            stop = bullet.stop,
            color = Color.yellow,
            sceneCoords = true,
        }

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
        if gun.player == nil or not gun.equipped then goto continue end

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