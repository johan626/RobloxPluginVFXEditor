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
		Particle = Color3.fromRGB(180, 80, 200),
		SpotLight = Color3.fromRGB(255, 255, 150),
		SurfaceLight = Color3.fromRGB(255, 200, 150),
		Beam = Color3.fromRGB(150, 255, 255),
		Trail = Color3.fromRGB(255, 150, 255)
	}
}

return Config
