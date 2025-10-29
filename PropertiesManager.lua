-- PropertiesManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/PropertiesManager.lua

local PropertiesManager = {}

-- Categorized list of all editable properties
local PROPERTY_CATEGORIES = {
	{
		Name = "General",
		Properties = {"ComponentType", "Lane", "Enabled", "TimeScale"}
	},
	{
		Name = "Appearance",
		Properties = {"Color", "Texture", "LightEmission", "LightInfluence", "Transparency", "Size", "Squash", "ZOffset", "FaceCamera", "Orientation"}
	},
	{
		Name = "Emission",
		Properties = {"Rate", "Lifetime", "Speed", "SpreadAngle", "EmissionDirection"}
	},
	{
		Name = "Motion",
		Properties = {"Acceleration", "Drag", "Rotation", "RotSpeed"}
	},
	{
		Name = "Shape & Behavior",
		Properties = {"Width0", "Width1", "WidthScale", "CurveSize0", "CurveSize1", "Segments", "Attachment0Offset", "Attachment1Offset", "StartPosition", "EndPosition"}
	},
	{
		Name = "Light",
		Properties = {"Brightness", "Range", "Angle", "Face", "Shadows"}
	},
	{
		Name = "Sound",
		Properties = {"SoundId", "Volume", "PlaybackSpeed", "Looped", "TimePosition", "RollOffMode", "RollOffMinDistance", "RollOffMaxDistance"}
	},
	{
		Name = "Texture Control",
		Properties = {"TextureLength", "TextureMode", "TextureSpeed"}
	},
	{
		Name = "Trail",
		Properties = {"MinLength", "MaxLength"}
	}
}


-- Map property names to their data types for handling input
local PROPERTY_TYPES = {
	Color = "Color3",
	Acceleration = "Vector3", Attachment0Offset = "Vector3", Attachment1Offset = "Vector3", StartPosition = "Vector3", EndPosition = "Vector3",
	Size = "NumberSequence", Transparency = "NumberSequence", Squash = "NumberSequence", WidthScale = "NumberSequence",
	Lifetime = "NumberRange", Speed = "NumberRange", Rotation = "NumberRange", RotSpeed = "NumberRange",
	Face = "Enum", EmissionDirection = "Enum", Orientation = "Enum", TextureMode = "Enum", RollOffMode = "Enum"
}


function PropertiesManager.clear(panel)
	for _, child in ipairs(panel:GetChildren()) do
		child:Destroy()
	end
end

-- Helper function to create a standard property frame and label
local function createPropertyUI(panel, name, layoutOrder)
	local propFrame = Instance.new("Frame")
	propFrame.LayoutOrder = layoutOrder
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

	return propFrame
end

-- Generic input handler for simple types (string, number, boolean, enums)
local function createGenericInput(parent, name, value, track)
	local valueType = typeof(value)
	local propInput = Instance.new("TextBox")
	propInput.Size = UDim2.new(0.6, 0, 1, 0)
	propInput.Position = UDim2.new(0.4, 0, 0, 0)
	propInput.Text = tostring(value)
	propInput.Parent = parent

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
		else -- String and Enum values are treated as strings
			newValue = textValue 
		end
		track:SetAttribute(name, newValue)
	end)
end

local function createColor3Input(parent, name, value, track)
	-- Safety check for nil value
	if not value or typeof(value) ~= "Color3" then
		value = Color3.new(1, 1, 1) -- Default to white
	end

	local colorFrame = Instance.new("Frame")
	colorFrame.Size = UDim2.new(0.6, 0, 1, 0)
	colorFrame.Position = UDim2.new(0.4, 0, 0, 0)
	colorFrame.BackgroundTransparency = 1
	colorFrame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Parent = colorFrame

	local function createColorInput(componentValue)
		local input = Instance.new("TextBox")
		input.Size = UDim2.new(0.33, -2, 1, 0)
		input.Text = tostring(math.floor(componentValue * 255))
		input.Parent = colorFrame
		return input
	end

	local r, g, b = createColorInput(value.r), createColorInput(value.g), createColorInput(value.b)

	local function onFocusLost()
		local rV, gV, bV = tonumber(r.Text), tonumber(g.Text), tonumber(b.Text)
		if rV and gV and bV and rV >= 0 and rV <= 255 and gV >= 0 and gV <= 255 and bV >= 0 and bV <= 255 then
			track:SetAttribute(name, Color3.fromRGB(rV, gV, bV))
		else
			local old = track:GetAttribute(name)
			if old and typeof(old) == "Color3" then
				r.Text, g.Text, b.Text = tostring(math.floor(old.r*255)), tostring(math.floor(old.g*255)), tostring(math.floor(old.b*255))
			end
		end
	end
	r.FocusLost:Connect(onFocusLost)
	g.FocusLost:Connect(onFocusLost)
	b.FocusLost:Connect(onFocusLost)
end

local function createVector3Input(parent, name, value, track)
	-- For Vector3, we expect a string attribute like "x,y,z"
	local parts = value:split(",")
	local x, y, z = parts[1] or "0", parts[2] or "0", parts[3] or "0"

	local vecFrame = Instance.new("Frame")
	vecFrame.Size = UDim2.new(0.6, 0, 1, 0)
	vecFrame.Position = UDim2.new(0.4, 0, 0, 0)
	vecFrame.BackgroundTransparency = 1
	vecFrame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Parent = vecFrame

	local function createVecInput(componentValue)
		local input = Instance.new("TextBox")
		input.Size = UDim2.new(0.33, -2, 1, 0)
		input.Text = componentValue
		input.Parent = vecFrame
		return input
	end

	local xInput, yInput, zInput = createVecInput(x), createVecInput(y), createVecInput(z)

	local function onFocusLost()
		local xV, yV, zV = tonumber(xInput.Text), tonumber(yInput.Text), tonumber(zInput.Text)
		if xV and yV and zV then
			track:SetAttribute(name, string.format("%s,%s,%s", xV, yV, zV))
		else
			local old = track:GetAttribute(name)
			local oldParts = old:split(",")
			xInput.Text, yInput.Text, zInput.Text = oldParts[1] or "0", oldParts[2] or "0", oldParts[3] or "0"
		end
	end
	xInput.FocusLost:Connect(onFocusLost)
	yInput.FocusLost:Connect(onFocusLost)
	zInput.FocusLost:Connect(onFocusLost)
end


function PropertiesManager.populate(panel, track, timelineManager)
	PropertiesManager.clear(panel)
	local attributes = track:GetAttributes()

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local layoutOrderCounter = 1

	for _, category in ipairs(PROPERTY_CATEGORIES) do
		local hasAnyPropertyInCategory = false
		for _, name in ipairs(category.Properties) do
			if attributes[name] ~= nil then
				hasAnyPropertyInCategory = true
				break
			end
		end

		if hasAnyPropertyInCategory then
			-- Create Category Header
			local header = Instance.new("TextLabel")
			header.LayoutOrder = layoutOrderCounter
			layoutOrderCounter += 1
			header.Size = UDim2.new(1, -10, 0, 20)
			header.Text = " " .. category.Name .. " "
			header.BackgroundColor3 = Color3.fromRGB(40,40,40)
			header.TextColor3 = Color3.fromRGB(200,200,200)
			header.Font = Enum.Font.SourceSansBold
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.Parent = panel

			-- Create Properties
			for _, name in ipairs(category.Properties) do
				if attributes[name] == nil then continue end
				local value = attributes[name]

				local propFrame = createPropertyUI(panel, name, layoutOrderCounter)
				layoutOrderCounter += 1

				local dataType = PROPERTY_TYPES[name] or typeof(value)

				if dataType == "Color3" then
					createColor3Input(propFrame, name, value, track)
				elseif dataType == "Vector3" then
					createVector3Input(propFrame, name, value, track)
				else 
					createGenericInput(propFrame, name, value, track)
				end
			end
		end
	end


	-- Add Delete Button
	local deleteButton = Instance.new("TextButton")
	deleteButton.Name = "DeleteTrackButton"
	deleteButton.LayoutOrder = layoutOrderCounter
	deleteButton.Size = UDim2.new(1, -10, 0, 30)
	deleteButton.Text = "Delete Track"
	deleteButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	deleteButton.Parent = panel

	deleteButton.MouseButton1Click:Connect(function()
		timelineManager:deleteSelectedTrack()
	end)
end

return PropertiesManager
