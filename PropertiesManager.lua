-- PropertiesManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/PropertiesManager.lua

local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)
local PropertiesManager = {}

-- ... (tabel-tabel ENUM_OPTIONS, PROPERTY_CATEGORIES, PROPERTY_TYPES tetap sama)
local ENUM_OPTIONS = {
	Face = {"Right", "Top", "Back", "Left", "Bottom", "Front"},
	EmissionDirection = {"Right", "Top", "Back", "Left", "Bottom", "Front"},
	Orientation = {"FacingCamera", "FacingCameraWorldUp", "VelocityParallel"},
	TextureMode = {"Stretch", "Wrap", "Static"},
	RollOffMode = {"Inverse", "Linear", "LinearSquare", "InverseTapered"}
}
local PROPERTY_CATEGORIES = {
	{ Name = "General", Properties = {"ComponentType", "Lane", "Enabled", "TimeScale"} },
	{ Name = "Appearance", Properties = {"Color", "Texture", "LightEmission", "LightInfluence", "Transparency", "Size", "Squash", "ZOffset", "FaceCamera", "Orientation"} },
	{ Name = "Emission", Properties = {"Rate", "Lifetime", "Speed", "SpreadAngle", "EmissionDirection"} },
	{ Name = "Motion", Properties = {"Acceleration", "Drag", "Rotation", "RotSpeed"} },
	{ Name = "Shape & Behavior", Properties = {"Width0", "Width1", "WidthScale", "CurveSize0", "CurveSize1", "Segments", "Attachment0Offset", "Attachment1Offset", "StartPosition", "EndPosition"} },
	{ Name = "Light", Properties = {"Brightness", "Range", "Angle", "Face", "Shadows"} },
	{ Name = "Sound", Properties = {"SoundId", "Volume", "PlaybackSpeed", "Looped", "TimePosition", "RollOffMode", "RollOffMinDistance", "RollOffMaxDistance"} },
	{ Name = "Texture Control", Properties = {"TextureLength", "TextureMode", "TextureSpeed"} },
	{ Name = "Trail", Properties = {"MinLength", "MaxLength"} }
}
local PROPERTY_TYPES = {
	Color = "Color3", Acceleration = "Vector3", Attachment0Offset = "Vector3", Attachment1Offset = "Vector3", StartPosition = "Vector3", EndPosition = "Vector3",
	Size = "NumberSequence", Transparency = "NumberSequence", Squash = "NumberSequence", WidthScale = "NumberSequence",
	Lifetime = "NumberRange", Speed = "NumberRange", Rotation = "NumberRange", RotSpeed = "NumberRange",
	Face = "Enum", EmissionDirection = "Enum", Orientation = "Enum", TextureMode = "Enum", RollOffMode = "Enum"
}


function PropertiesManager.clear(panel)
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("UILayout") then continue end
		child:Destroy()
	end
	panel.CanvasSize = UDim2.new(0, 0, 0, 0)
end

-- ... (semua fungsi create...Input tetap sama)
local function createPropertyUI(panel, name, layoutOrder, isSequence)
	local height = isSequence and 45 or 25
	local propFrame = Instance.new("Frame")
	propFrame.LayoutOrder = layoutOrder
	propFrame.Size = UDim2.new(1, -10, 0, height)
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
local function styleInput(textbox, isValid)
	local theme = Config.Theme
	if isValid then
		textbox.BorderColor3 = theme.ButtonAccent
		textbox.BackgroundColor3 = theme.Button
	else
		textbox.BorderColor3 = theme.AccentDestructive
		textbox.BackgroundColor3 = Color3.fromRGB(theme.AccentDestructive.r * 0.2, theme.AccentDestructive.g * 0.2, theme.AccentDestructive.b * 0.2)
	end
end
local function styleGenericInput(textbox)
	local theme = Config.Theme
	textbox.BackgroundColor3 = theme.Button
	textbox.TextColor3 = theme.Text
	textbox.Font = theme.Font
	textbox.TextSize = theme.FontSize
	textbox.BorderSizePixel = 1
	textbox.BorderColor3 = theme.ButtonAccent
end
local function createGenericInput(parent, name, value, track)
	local valueType = typeof(value)
	local propInput = Instance.new("TextBox")
	propInput.Size = UDim2.new(0.6, 0, 1, 0)
	propInput.Position = UDim2.new(0.4, 0, 0, 0)
	propInput.Text = tostring(value)
	propInput.Parent = parent
	styleGenericInput(propInput)
	propInput.FocusLost:Connect(function(enterPressed)
		local originalValue = track:GetAttribute(name)
		local textValue = propInput.Text
		local newValue
		if valueType == "number" then
			newValue = tonumber(textValue)
			if not newValue then propInput.Text = tostring(originalValue); styleInput(propInput, false); return end
		elseif valueType == "boolean" then
			if textValue:lower() == "true" then newValue = true
			elseif textValue:lower() == "false" then newValue = false
			else propInput.Text = tostring(originalValue); styleInput(propInput, false); return end
		else
			newValue = textValue
		end
		styleInput(propInput, true)
		track:SetAttribute(name, newValue)
	end)
end
local function createEnumDropdown(parent, name, value, track)
	local theme = Config.Theme
	local options = ENUM_OPTIONS[name]
	if not options then return end
	local dropdownFrame = Instance.new("Frame")
	dropdownFrame.Size = UDim2.new(0.6, 0, 1, 0); dropdownFrame.Position = UDim2.new(0.4, 0, 0, 0); dropdownFrame.BackgroundTransparency = 1; dropdownFrame.Parent = parent; dropdownFrame.ZIndex = 2
	local mainButton = Instance.new("TextButton")
	mainButton.Size = UDim2.new(1, 0, 1, 0); mainButton.Text = tostring(value); mainButton.BackgroundColor3 = theme.Button; mainButton.TextColor3 = theme.Text; mainButton.Parent = dropdownFrame
	local optionsList = Instance.new("ScrollingFrame")
	optionsList.Size = UDim2.new(1, 0, 0, 100); optionsList.Position = UDim2.new(0, 0, 1, 0); optionsList.BackgroundColor3 = theme.Properties; optionsList.BorderSizePixel = 1; optionsList.BorderColor3 = theme.ButtonAccent; optionsList.Visible = false; optionsList.Parent = dropdownFrame; optionsList.ZIndex = 3
	local listLayout = Instance.new("UIListLayout"); listLayout.Parent = optionsList
	for _, option in ipairs(options) do
		local optionButton = Instance.new("TextButton")
		optionButton.Size = UDim2.new(1, 0, 0, 25); optionButton.Text = option; optionButton.BackgroundColor3 = theme.Button; optionButton.TextColor3 = theme.Text; optionButton.Parent = optionsList
		optionButton.MouseButton1Click:Connect(function() mainButton.Text = option; track:SetAttribute(name, option); optionsList.Visible = false end)
	end
	mainButton.MouseButton1Click:Connect(function() optionsList.Visible = not optionsList.Visible end)
end
local function createNumberRangeInput(parent, name, value, track)
	local parts = tostring(value):split(" "); local minVal, maxVal = parts[1] or "0", parts[2] or parts[1] or "0"
	local rangeFrame = Instance.new("Frame")
	rangeFrame.Size = UDim2.new(0.6, 0, 1, 0); rangeFrame.Position = UDim2.new(0.4, 0, 0, 0); rangeFrame.BackgroundTransparency = 1; rangeFrame.Parent = parent
	local layout = Instance.new("UIListLayout"); layout.FillDirection = Enum.FillDirection.Horizontal; layout.Parent = rangeFrame
	local function createRangeInput(val) local input = Instance.new("TextBox"); input.Size = UDim2.new(0.5, -2, 1, 0); input.Text = val; input.Parent = rangeFrame; styleGenericInput(input); return input end
	local minInput, maxInput = createRangeInput(minVal), createRangeInput(maxVal)
	local function onFocusLost() local minV, maxV = tonumber(minInput.Text), tonumber(maxInput.Text); if minV and maxV then styleInput(minInput, true); styleInput(maxInput, true); track:SetAttribute(name, string.format("%s %s", minV, maxV)) else styleInput(minInput, tonumber(minInput.Text) ~= nil); styleInput(maxInput, tonumber(maxInput.Text) ~= nil) end end
	minInput.FocusLost:Connect(onFocusLost); maxInput.FocusLost:Connect(onFocusLost)
end
local function createColor3Input(parent, name, value, track)
	if not value or typeof(value) ~= "Color3" then value = Color3.new(1,1,1) end
	local container = Instance.new("Frame"); container.Size = UDim2.new(0.6, 0, 1, 0); container.Position = UDim2.new(0.4, 0, 0, 0); container.BackgroundTransparency = 1; container.Parent = parent
	local colorButton = Instance.new("TextButton"); colorButton.Size = UDim2.new(1, 0, 1, 0); colorButton.Text = ""; colorButton.BackgroundColor3 = value; colorButton.Parent = container
	local pickerPopup = Instance.new("Frame"); pickerPopup.Size = UDim2.new(0, 150, 0, 180); pickerPopup.Position = UDim2.new(1, 5, 0, 0); pickerPopup.BackgroundColor3 = Config.Theme.TopBar; pickerPopup.BorderSizePixel = 1; pickerPopup.BorderColor3 = Config.Theme.ButtonAccent; pickerPopup.Visible = false; pickerPopup.ZIndex = 10; pickerPopup.Parent = container
	local h, s, v = value:ToHSV()
	local svPicker = Instance.new("ImageButton"); svPicker.Size = UDim2.new(1, -25, 0, 120); svPicker.Position = UDim2.new(0, 10, 0, 10); svPicker.BackgroundColor3 = Color3.fromHSV(h, 1, 1); svPicker.Parent = pickerPopup
	local svGradient = Instance.new("UIGradient"); svGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.new(0,0,0))}); svGradient.Rotation = 90; svGradient.Parent = svPicker
	local svGradient2 = Instance.new("UIGradient"); svGradient2.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,1,1,1)), ColorSequenceKeypoint.new(1, Color3.new(1,1,1))}); svGradient2.Parent = svPicker
	local svSelector = Instance.new("Frame"); svSelector.Size = UDim2.new(0, 5, 0, 5); svSelector.BackgroundColor3 = Color3.new(1,1,1); svSelector.BorderSizePixel = 1; svSelector.Position = UDim2.new(s, 0, 1-v, 0); svSelector.Parent = svPicker
	local hueSlider = Instance.new("ImageButton"); hueSlider.Size = UDim2.new(0, 15, 0, 120); hueSlider.Position = UDim2.new(1, -20, 0, 10); hueSlider.Parent = pickerPopup
	local hueGradient = Instance.new("UIGradient"); hueGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,0,0)), ColorSequenceKeypoint.new(0.16, Color3.new(1,1,0)), ColorSequenceKeypoint.new(0.33, Color3.new(0,1,0)), ColorSequenceKeypoint.new(0.5, Color3.new(0,1,1)), ColorSequenceKeypoint.new(0.66, Color3.new(0,0,1)), ColorSequenceKeypoint.new(0.83, Color3.new(1,0,1)), ColorSequenceKeypoint.new(1, Color3.new(1,0,0))}); hueGradient.Rotation = 90; hueGradient.Parent = hueSlider
	local hueSelector = Instance.new("Frame"); hueSelector.Size = UDim2.new(1, 4, 0, 3); hueSelector.Position = UDim2.new(0, -2, h, 0); hueSelector.BackgroundColor3 = Color3.new(1,1,1); hueSelector.BorderSizePixel = 1; hueSelector.Parent = hueSlider
	local function updateColor() local newColor = Color3.fromHSV(h, s, v); track:SetAttribute(name, newColor); colorButton.BackgroundColor3 = newColor; svPicker.BackgroundColor3 = Color3.fromHSV(h, 1, 1) end
	local function inputHandler(input, frame, selector) local pos = input.Position - frame.AbsolutePosition; local size = frame.AbsoluteSize; if frame == svPicker then s = math.clamp(pos.x / size.x, 0, 1); v = 1 - math.clamp(pos.y / size.y, 0, 1); selector.Position = UDim2.new(s, -2.5, 1-v, -2.5) else h = math.clamp(pos.y / size.y, 0, 1); selector.Position = UDim2.new(0, -2, h, -1.5) end; updateColor() end
	svPicker.InputBegan:Connect(function(input) inputHandler(input, svPicker, svSelector) end); svPicker.InputChanged:Connect(function(input) inputHandler(input, svPicker, svSelector) end); hueSlider.InputBegan:Connect(function(input) inputHandler(input, hueSlider, hueSelector) end); hueSlider.InputChanged:Connect(function(input) inputHandler(input, hueSlider, hueSelector) end)
	colorButton.MouseButton1Click:Connect(function() pickerPopup.Visible = not pickerPopup.Visible end)
end
local function createVector3Input(parent, name, value, track)
	local parts = value:split(","); local x, y, z = parts[1] or "0", parts[2] or "0", parts[3] or "0"
	local vecFrame = Instance.new("Frame"); vecFrame.Size = UDim2.new(0.6, 0, 1, 0); vecFrame.Position = UDim2.new(0.4, 0, 0, 0); vecFrame.BackgroundTransparency = 1; vecFrame.Parent = parent
	local layout = Instance.new("UIListLayout"); layout.FillDirection = Enum.FillDirection.Horizontal; layout.Parent = vecFrame
	local function createVecInput(componentValue) local input = Instance.new("TextBox"); input.Size = UDim2.new(0.33, -2, 1, 0); input.Text = componentValue; input.Parent = vecFrame; styleGenericInput(input); return input end
	local xInput, yInput, zInput = createVecInput(x), createVecInput(y), createVecInput(z)
	local function onFocusLost() local xV, yV, zV = tonumber(xInput.Text), tonumber(yInput.Text), tonumber(zInput.Text); if xV and yV and zV then styleInput(xInput, true); styleInput(yInput, true); styleInput(zInput, true); track:SetAttribute(name, string.format("%s,%s,%s", xV, yV, zV)) else styleInput(xInput, tonumber(xInput.Text) ~= nil); styleInput(yInput, tonumber(yInput.Text) ~= nil); styleInput(zInput, tonumber(zInput.Text) ~= nil) end end
	xInput.FocusLost:Connect(onFocusLost); yInput.FocusLost:Connect(onFocusLost); zInput.FocusLost:Connect(onFocusLost)
end
local function createColorSequenceInput(parent, name, value, track)
	local container = Instance.new("Frame"); container.Size = UDim2.new(0.6, 0, 1, 0); container.Position = UDim2.new(0.4, 0, 0, 0); container.BackgroundTransparency = 1; container.Parent = parent
	local propInput = Instance.new("TextBox"); propInput.Size = UDim2.new(1, 0, 0.5, -2); propInput.Text = tostring(value); propInput.Parent = container; styleGenericInput(propInput)
	local preview = Instance.new("Frame"); preview.Size = UDim2.new(1, 0, 0.5, -2); preview.Position = UDim2.new(0, 0, 0.5, 2); preview.BackgroundColor3 = Color3.fromRGB(20, 20, 20); preview.Parent = container
	local gradient = Instance.new("UIGradient"); gradient.Parent = preview
	local function updatePreview() pcall(function() local seq = Utils.parseColorSequence(propInput.Text); if seq then gradient.Color = seq; styleInput(propInput, true) else styleInput(propInput, false) end end) end
	propInput.FocusLost:Connect(function() track:SetAttribute(name, propInput.Text); updatePreview() end); updatePreview()
end
local function createNumberSequenceInput(parent, name, value, track)
	local container = Instance.new("Frame"); container.Size = UDim2.new(0.6, 0, 1, 0); container.Position = UDim2.new(0.4, 0, 0, 0); container.BackgroundTransparency = 1; container.Parent = parent
	local propInput = Instance.new("TextBox"); propInput.Size = UDim2.new(1, 0, 0.5, -2); propInput.Text = tostring(value); propInput.Parent = container; styleGenericInput(propInput)
	local preview = Instance.new("Frame"); preview.Size = UDim2.new(1, 0, 0.5, -2); preview.Position = UDim2.new(0, 0, 0.5, 2); preview.BackgroundColor3 = Color3.fromRGB(20, 20, 20); preview.Parent = container
	local gradient = Instance.new("UIGradient"); gradient.Parent = preview
	local function updatePreview() pcall(function() local seq = Utils.parseNumberSequence(propInput.Text); if seq then local keypoints = {}; local maxValue = 0; for _, kp in ipairs(seq.Keypoints) do if kp.Value > maxValue then maxValue = kp.Value end end; maxValue = math.max(maxValue, 1); for _, kp in ipairs(seq.Keypoints) do local gray = kp.Value / maxValue; table.insert(keypoints, ColorSequenceKeypoint.new(kp.Time, Color3.new(gray, gray, gray))) end; gradient.Color = ColorSequence.new(keypoints); styleInput(propInput, true) else styleInput(propInput, false) end end) end
	propInput.FocusLost:Connect(function() track:SetAttribute(name, propInput.Text); updatePreview() end); updatePreview()
end


function PropertiesManager.populate(panel, selectedTracks, timelineManager)
	PropertiesManager.clear(panel)

	-- Count the number of selected tracks
	local selectionCount = 0
	local firstTrack = nil
	for track, _ in pairs(selectedTracks) do
		selectionCount += 1
		if not firstTrack then firstTrack = track end
	end

	-- If not exactly one track is selected, do nothing.
	if selectionCount ~= 1 then
		return
	end

	local track = firstTrack
	local attributes = track:GetAttributes()
	local componentType = attributes.ComponentType

	local layout = panel:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 5)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = panel
	end

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
			local header = Instance.new("TextLabel")
			header.LayoutOrder = layoutOrderCounter; layoutOrderCounter += 1
			header.Size = UDim2.new(1, -10, 0, 20); header.Text = " " .. category.Name .. " "; header.BackgroundColor3 = Color3.fromRGB(40,40,40); header.TextColor3 = Color3.fromRGB(200,200,200); header.Font = Enum.Font.SourceSansBold; header.TextXAlignment = Enum.TextXAlignment.Left; header.Parent = panel

			for _, name in ipairs(category.Properties) do
				if attributes[name] == nil then continue end
				local value = attributes[name]
				local isSequence = (name == "Size" or name == "Transparency" or name == "Squash" or name == "WidthScale")
				local isColorSequence = (name == "Color" and (componentType == "Particle" or componentType == "Beam" or componentType == "Trail"))
				local propFrame = createPropertyUI(panel, name, layoutOrderCounter, isSequence or isColorSequence)
				layoutOrderCounter += 1
				local dataType = PROPERTY_TYPES[name] or typeof(value)

				if isColorSequence then createColorSequenceInput(propFrame, name, value, track)
				elseif dataType == "NumberSequence" then createNumberSequenceInput(propFrame, name, value, track)
				elseif dataType == "Color3" then createColor3Input(propFrame, name, value, track)
				elseif dataType == "Vector3" then createVector3Input(propFrame, name, value, track)
				elseif dataType == "Enum" then createEnumDropdown(propFrame, name, value, track)
				elseif dataType == "NumberRange" then createNumberRangeInput(propFrame, name, value, track)
				else createGenericInput(propFrame, name, value, track) end
			end
		end
	end

	local deleteButton = Instance.new("TextButton")
	deleteButton.Name = "DeleteTrackButton"
	deleteButton.LayoutOrder = layoutOrderCounter
	deleteButton.Size = UDim2.new(1, -10, 0, 30)
	deleteButton.Text = "Delete Track"
	deleteButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	deleteButton.Parent = panel

	deleteButton.MouseButton1Click:Connect(function()
		timelineManager:deleteSelectedTracks()
	end)

	task.wait()
	panel.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
end

return PropertiesManager
