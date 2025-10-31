-- Config.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/Config.lua

local Config = {
	PIXELS_PER_SECOND = 200,
	SNAP_INTERVAL = 0.1,
	TOTAL_TIME = 30,
	TRACK_HEIGHT = 20,
	LANE_PADDING = 5,
	PLAYHEAD_SNAP_DISTANCE = 10, -- in pixels

	TrackColors = {
		Light = Color3.fromRGB(200, 180, 80),
		Sound = Color3.fromRGB(80, 180, 200),
		Particle = Color3.fromRGB(180, 80, 200),
		SpotLight = Color3.fromRGB(255, 255, 150),
		SurfaceLight = Color3.fromRGB(255, 200, 150),
		Beam = Color3.fromRGB(150, 255, 255),
		Trail = Color3.fromRGB(255, 150, 255)
	},

	GroupColors = {
		Red = Color3.fromRGB(217, 48, 37),
		Orange = Color3.fromRGB(235, 137, 49),
		Yellow = Color3.fromRGB(245, 225, 51),
		Green = Color3.fromRGB(63, 199, 84),
		Blue = Color3.fromRGB(48, 128, 242),
		Purple = Color3.fromRGB(142, 69, 219),
		Pink = Color3.fromRGB(217, 56, 141),
		Gray = Color3.fromRGB(128, 128, 128),
		None = Color3.fromRGB(50, 50, 50) -- Represents "no color"
	},

	Theme = {
		-- Studio Dark Theme Inspired Colors
		Background = Color3.fromRGB(40, 42, 45),
		TopBar = Color3.fromRGB(43, 45, 48),
		Timeline = Color3.fromRGB(35, 37, 40),
		Properties = Color3.fromRGB(48, 50, 53),
		ComponentLibrary = Color3.fromRGB(48, 50, 53),

		Button = Color3.fromRGB(68, 70, 74),
		ButtonHover = Color3.fromRGB(80, 82, 86),
		ButtonPressed = Color3.fromRGB(60, 62, 65),
		ButtonAccent = Color3.fromRGB(50, 52, 55), -- Used for borders
		ButtonDisabled = Color3.fromRGB(55, 57, 60),

		Text = Color3.fromRGB(220, 221, 222),
		TextDark = Color3.fromRGB(160, 162, 164),
		TextDisabled = Color3.fromRGB(120, 122, 124),

		Accent = Color3.fromRGB(0, 120, 215),
		AccentDestructive = Color3.fromRGB(231, 76, 60),

		Font = Enum.Font.SourceSans,
		FontSize = 14
	}
}

return Config
