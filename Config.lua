-- Config.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/Config.lua

local Config = {
	-- Timeline Settings
	PIXELS_PER_SECOND = 200,
	SNAP_INTERVAL = 0.1,
	TOTAL_TIME = 30,
	TRACK_HEIGHT = 20,
	LANE_PADDING = 5,

	-- UI Styling
	styles = {
		-- Base Colors
		BaseColor = Color3.fromRGB(31, 31, 31),
		BackgroundColor = Color3.fromRGB(41, 41, 41),
		PrimaryColor = Color3.fromRGB(0, 120, 215),
		TextColor = Color3.fromRGB(220, 220, 220),
		MutedTextColor = Color3.fromRGB(150, 150, 150),
		BorderColor = Color3.fromRGB(60, 60, 60),

		-- Default Button Style
		DefaultButton = {
			BackgroundColor3 = Color3.fromRGB(60, 60, 60),
			TextColor3 = Color3.fromRGB(220, 220, 220),
			Font = Enum.Font.SourceSans,
			TextSize = 14,
			BorderSizePixel = 0,
			UICorner = 4,
			HoverColor = Color3.fromRGB(70, 70, 70),
			PressedColor = Color3.fromRGB(50, 50, 50),
		},

		-- Primary Button Style (e.g., for 'Export')
		PrimaryButton = {
			BackgroundColor3 = Color3.fromRGB(0, 120, 215),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.SourceSans,
			TextSize = 14,
			BorderSizePixel = 0,
			UICorner = 4,
			HoverColor = Color3.fromRGB(20, 140, 235),
			PressedColor = Color3.fromRGB(0, 100, 195),
		},

		-- Panel Styles
		DefaultPanel = {
			BackgroundColor3 = Color3.fromRGB(45, 45, 45),
			BorderSizePixel = 1,
			BorderColor3 = Color3.fromRGB(60, 60, 60),
			UICorner = 6,
		},

		-- Frame Styles
		DefaultFrame = {
			BackgroundColor3 = Color3.fromRGB(31, 31, 31),
			BorderSizePixel = 0,
		}
	}
}

return Config
