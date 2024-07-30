local npcManager = require "npcManager"
local guns = require "guns"

local cappaNPC = {}

---@type NPCConfig
local cappaNPCSettings = {
	id = NPC_ID,

	gfxheight = 2,
	gfxwidth = 20,

	width = 20,
	height = 2,

	frames = 1,
	framestyle = 1,
	framespeed = 8,
	speed = 0,

	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,

	nohurt=true,
	nogravity = true,
	noblockcollision = true,
	nofireball = true,
	noiceball = true,
	noyoshi= true,
	nowaterphysics = true,

	jumphurt = true,
	spinjumpsafe = false,
	harmlessgrab = false,
	harmlessthrown = false,

	ignorethrownnpcs = true,
	luahandlesspeed = true,

	grabside = false,
	grabtop = false,
	staticdirection = true,

	priority = -45,
}

npcManager.setNpcSettings(cappaNPCSettings)
npcManager.registerHarmTypes(NPC_ID,
	{
		HARM_TYPE_PROJECTILE_USED,
		HARM_TYPE_HELD,
		HARM_TYPE_OFFSCREEN,
        HARM_TYPE_LAVA
	},
	{
		[HARM_TYPE_PROJECTILE_USED] = 10,
		[HARM_TYPE_HELD] = 10,
		[HARM_TYPE_OFFSCREEN] = 10,
        [HARM_TYPE_LAVA] = 13
	}
);

guns.registerBulletNPC(NPC_ID)

return cappaNPC