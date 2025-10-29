-- PropertiesManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/PropertiesManager.lua

local PropertiesManager = {}

local PROPERTY_ORDER = {
	"ComponentType", "Lane", "Enabled",
	"Brightness", "Color", "Range",
	"SoundId", "Volume", "PlaybackSpeed"
}

function PropertiesManager.populate(panel, track)
	-- Clear previous properties
	for _, child in ipairs(panel:GetChildren()) do
		child:Destroy()
	end

	local attributes = track:GetAttributes()

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	for i, name in ipairs(PROPERTY_ORDER) do
		if attributes[name] == nil then continue end
		local value = attributes[name]

		local propFrame = Instance.new("Frame")
		propFrame.LayoutOrder = i
		propFrame.Size = UDim2.new(1, -10, 0, 25)
		propFrame.BackgroundTransparency = 1
		propFrame.Parent = panel

		local propLabel = Instance.new("TextLabel")
		propLabel.Size = UDim2.new(0.4, 0, 1, 0)
		propLabel.BackgroundTransparency = 1
		propLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		propLabel.Text = name
		propLabel.TextXAlignment = Enum.TextXAlignment.Left
		propLabel.Parent = propFrame

		local valueType = typeof(value)

		if valueType == "string" or valueType == "number" or valueType == "boolean" then
			local propInput = Instance.new("TextBox")
			propInput.Size = UDim2.new(0.6, 0, 1, 0)
			propInput.Position = UDim2.new(0.4, 0, 0, 0)
			propInput.Text = tostring(value)
			propInput.Parent = propFrame

			propInput.FocusLost:Connect(function(enterPressed)
				local originalValue = track:GetAttribute(name)
				local textValue = propInput.Text
				local newValue
				if valueType == "number" then
					newValue = tonumber(textValue)
					if not newValue then propInput.Text = tostring(originalValue); return end
				elseif valueType == "boolean" then
					if textValue:lower() == "true" then newValue = true
					elseif textValue:lower() == "false" then newValue = false
					else propInput.Text = tostring(originalValue); return end
				else newValue = textValue end
				track:SetAttribute(name, newValue)
			end)
		elseif valueType == "Color3" then
			local colorFrame = Instance.new("Frame")
			-- [Full Color3 editor logic from previous implementation]
			colorFrame.Size = UDim2.new(0.6, 0, 1, 0)
			colorFrame.Position = UDim2.new(0.4, 0, 0, 0)
			colorFrame.BackgroundTransparency = 1
			colorFrame.Parent = propFrame

			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.Parent = colorFrame

			local function createColorInput(componentName, componentValue)
				local input = Instance.new("TextBox")
				input.Size = UDim2.new(0.33, -2, 1, 0)
				input.Text = tostring(math.floor(componentValue * 255))
				input.Parent = colorFrame
				return input
			end

			local r, g, b = createColorInput("R", value.r), createColorInput("G", value.g), createColorInput("B", value.b)

			local function onFocusLost(enterPressed)
				local rV, gV, bV = tonumber(r.Text), tonumber(g.Text), tonumber(b.Text)
				if rV and gV and bV and rV >= 0 and rV <= 255 and gV >= 0 and gV <= 255 and bV >= 0 and bV <= 255 then
					track:SetAttribute(name, Color3.fromRGB(rV, gV, bV))
				else
					local old = track:GetAttribute(name)
					r.Text = tostring(math.floor(old.r * 255))
					g.Text = tostring(math.floor(old.g * 255))
					b.Text = tostring(math.floor(old.b * 255))
				end
			end

			r.FocusLost:Connect(onFocusLost)
			g.FocusLost:Connect(onFocusLost)
			b.FocusLost:Connect(onFocusLost)
		end
	end
end

return PropertiesManager
