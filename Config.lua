-- Config.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/Config.lua

local Config = {
	PIXELS_PER_SECOND = 200,
	SNAP_INTERVAL = 0.1,
	TOTAL_TIME = 30,
	TRACK_HEIGHT = 20,
	LANE_PADDING = 5,

	TrackColors = {
		Light = Color3.fromRGB(200, 180, 80),
		Sound = Color3.fromRGB(80, 180, 200),
		Particle = Color3.fromRGB(180, 80, 200)
	}
}

return Config
