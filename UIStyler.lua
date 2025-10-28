-- UIStyler.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/UIStyler.lua

local Config = require(script.Parent.Config)

local UIStyler = {}

function UIStyler.applyStyle(instance, styleName)
	local style = Config.styles[styleName]
	if not style then
		warn("Style not found: " .. styleName)
		return
	end

	for property, value in pairs(style) do
		if property == "UICorner" then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, value)
			corner.Parent = instance
			-- Ignore custom style properties that are not real instance properties
		elseif property ~= "HoverColor" and property ~= "PressedColor" then
			instance[property] = value
		end
	end
end

function UIStyler.styleButton(button, styleName)
	styleName = styleName or "DefaultButton"
	UIStyler.applyStyle(button, styleName)

	-- Add hover and press effects
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Config.styles[styleName].HoverColor or button.BackgroundColor3:Lerp(Color3.new(1,1,1), 0.1)
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Config.styles[styleName].BackgroundColor3
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = Config.styles[styleName].PressedColor or button.BackgroundColor3:Lerp(Color3.new(0,0,0), 0.1)
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundColor3 = Config.styles[styleName].HoverColor or button.BackgroundColor3
	end)
end

function UIStyler.stylePanel(panel, styleName)
	styleName = styleName or "DefaultPanel"
	UIStyler.applyStyle(panel, styleName)
end

function UIStyler.styleFrame(frame, styleName)
	styleName = styleName or "DefaultFrame"
	UIStyler.applyStyle(frame, styleName)
end

return UIStyler
