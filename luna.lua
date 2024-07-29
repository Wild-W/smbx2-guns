local guns = require "guns"
local blick = require "guns.blick"
local akky = require "guns.akky"

local gunList = {}
local currentGun

function onStart()
    local blickGun = guns.newGun(blick)
    blickGun:attach(player)
    gunList[#gunList+1] = blickGun

    local akkyGun = guns.newGun(akky)
    akkyGun:attach(player)
    gunList[#gunList+1] = akkyGun

    currentGun = 1
    gunList[1]:equip()
end

function onKeyboardPress(vkey)
    if vkey == VK_R then
        gunList[currentGun]:unequip()
        if gunList[currentGun + 1] == nil then
            currentGun = 1
        else
            currentGun = currentGun + 1
        end
        gunList[currentGun]:equip()
    end
end
