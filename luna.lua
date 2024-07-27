local guns = require "guns"
local blick = require "guns.blick"

function onStart()
    gun = guns.newGun(blick)
    gun:attach(player)
    gun:equip()
end
