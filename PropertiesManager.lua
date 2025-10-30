-- PropertiesManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/PropertiesManager.lua

local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)
local GradientEditor = require(script.Parent.GradientEditor)
local PropertiesManager = {}

-- Module-level table to keep track of active gradient editors for cleanup
local activeGradientEditors = {}

-- Constant to represent a mixed value state
local MIXED_VALUE = { isMixed = true }

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
	{ Name = "Trail", Properties = {"MinLength", "MaxLength"} }
}
local PROPERTY_TYPES = {
	Color = "Color3", Acceleration = "Vector3", Attachment0Offset = "Vector3", Attachment1Offset = "Vector3", StartPosition = "Vector3", EndPosition = "Vector3",
	Size = "NumberSequence", Transparency = "NumberSequence", Squash = "NumberSequence", WidthScale = "NumberSequence",
	Lifetime = "NumberRange", Speed = "NumberRange", Rotation = "NumberRange", RotSpeed = "NumberRange",
	Face = "Enum", EmissionDirection = "Enum", Orientation = "Enum", TextureMode = "Enum", RollOffMode = "Enum"
}

-- Creates a single undo/redo action for updating a property across multiple tracks.
local function createMultiTrackUpdateAction(tracks, propertyName, newValue, historyManager)
	local originalValues = {}
	for _, track in ipairs(tracks) do
		table.insert(originalValues, {track = track, value = track:GetAttribute(propertyName)})
	end

	local action = {
		execute = function()
			for _, track in ipairs(tracks) do
				track:SetAttribute(propertyName, newValue)
			end
		end,
		undo = function()
			for _, data in ipairs(originalValues) do
				data.track:SetAttribute(propertyName, data.value)
			end
		end
	}
	historyManager:registerAction(action)
end

function PropertiesManager.clear(panel)
	-- Clean up any active gradient editors to prevent memory leaks
	for _, editor in ipairs(activeGradientEditors) do
		editor:destroy()
	end
	activeGradientEditors = {}

	-- Destroy all UI elements in the panel
	for _, child in ipairs(panel:GetChildren()) do
		if not child:IsA("UILayout") then
			child:Destroy()
		end
	end
	panel.CanvasSize = UDim2.new(0, 0, 0, 0)
end

local function createPropertyUI(panel, name, layoutOrder, isSequence)
	local height = isSequence and 80 or 25
	local propFrame = Instance.new("Frame")
	propFrame.LayoutOrder = layoutOrder
	propFrame.Size = UDim2.new(1, -10, 0, height)
	propFrame.BackgroundTransparency = 1
	propFrame.Parent = panel

	local propLabel = Instance.new("TextLabel")
	propLabel.Size = UDim2.new(0.4, 0, 0, 25)
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

local function createGenericInput(parent, name, value, tracks, historyManager)
	local valueType = typeof(tracks[1]:GetAttribute(name))
	local propInput = Instance.new("TextBox")
	propInput.Size = UDim2.new(0.6, 0, 1, 0); propInput.Position = UDim2.new(0.4, 0, 0, 0); styleGenericInput(propInput); propInput.Parent = parent
	if value == MIXED_VALUE then propInput.PlaceholderText = "<Mixed>" else propInput.Text = tostring(value) end
	propInput.FocusLost:Connect(function(enterPressed)
		if not enterPressed or propInput.Text == "" then return end
		local textValue = propInput.Text; local newValue
		if valueType == "number" then newValue = tonumber(textValue); if not newValue then styleInput(propInput, false); return end
		elseif valueType == "boolean" then if textValue:lower() == "true" then newValue = true elseif textValue:lower() == "false" then newValue = false else styleInput(propInput, false); return end
		else newValue = textValue end
		styleInput(propInput, true)
		createMultiTrackUpdateAction(tracks, name, newValue, historyManager)
	end)
end

local function createEnumDropdown(parent, name, value, tracks, historyManager)
	local theme = Config.Theme; local options = ENUM_OPTIONS[name]; if not options then return end
	local dropdownFrame = Instance.new("Frame"); dropdownFrame.Size = UDim2.new(0.6, 0, 1, 0); dropdownFrame.Position = UDim2.new(0.4, 0, 0, 0); dropdownFrame.BackgroundTransparency = 1; dropdownFrame.Parent = parent; dropdownFrame.ZIndex = 2
	local mainButton = Instance.new("TextButton"); mainButton.Size = UDim2.new(1, 0, 1, 0); mainButton.BackgroundColor3 = theme.Button; mainButton.TextColor3 = theme.Text; mainButton.Parent = dropdownFrame
	if value == MIXED_VALUE then mainButton.Text = "<Mixed>" else mainButton.Text = tostring(value) end
	local optionsList = Instance.new("ScrollingFrame"); optionsList.Size = UDim2.new(1, 0, 0, 100); optionsList.Position = UDim2.new(0, 0, 1, 0); optionsList.BackgroundColor3 = theme.Properties; optionsList.BorderSizePixel = 1; optionsList.BorderColor3 = theme.ButtonAccent; optionsList.Visible = false; optionsList.Parent = dropdownFrame; optionsList.ZIndex = 3
	local listLayout = Instance.new("UIListLayout"); listLayout.Parent = optionsList
	for _, option in ipairs(options) do
		local optionButton = Instance.new("TextButton"); optionButton.Size = UDim2.new(1, 0, 0, 25); optionButton.Text = option; optionButton.BackgroundColor3 = theme.Button; optionButton.TextColor3 = theme.Text; optionButton.Parent = optionsList
		optionButton.MouseButton1Click:Connect(function() mainButton.Text = option; optionsList.Visible = false; createMultiTrackUpdateAction(tracks, name, option, historyManager) end)
	end
	mainButton.MouseButton1Click:Connect(function() optionsList.Visible = not optionsList.Visible end)
end

local function createNumberRangeInput(parent, name, value, tracks, historyManager)
	local rangeFrame = Instance.new("Frame"); rangeFrame.Size = UDim2.new(0.6, 0, 1, 0); rangeFrame.Position = UDim2.new(0.4, 0, 0, 0); rangeFrame.BackgroundTransparency = 1; rangeFrame.Parent = parent
	local layout = Instance.new("UIListLayout"); layout.FillDirection = Enum.FillDirection.Horizontal; layout.Parent = rangeFrame
	local function createRangeInput() local input = Instance.new("TextBox"); input.Size = UDim2.new(0.5, -2, 1, 0); input.Parent = rangeFrame; styleGenericInput(input); return input end
	local minInput, maxInput = createRangeInput(), createRangeInput()
	if value == MIXED_VALUE then minInput.PlaceholderText = "<Mixed>"; maxInput.PlaceholderText = "<Mixed>" else local parts = tostring(value):split(" "); minInput.Text = parts[1] or "0"; maxInput.Text = parts[2] or parts[1] or "0" end
	local function onFocusLost() if minInput.Text == "" or maxInput.Text == "" then return end; local minV, maxV = tonumber(minInput.Text), tonumber(maxInput.Text); if minV and maxV then styleInput(minInput, true); styleInput(maxInput, true); createMultiTrackUpdateAction(tracks, name, string.format("%s %s", minV, maxV), historyManager) else styleInput(minInput, tonumber(minInput.Text) ~= nil); styleInput(maxInput, tonumber(maxInput.Text) ~= nil) end end
	minInput.FocusLost:Connect(onFocusLost); maxInput.FocusLost:Connect(onFocusLost)
end

local function createColor3Input(parent, name, value, tracks, historyManager)
	local container = Instance.new("Frame"); container.Size = UDim2.new(0.6, 0, 1, 0); container.Position = UDim2.new(0.4, 0, 0, 0); container.BackgroundTransparency = 1; container.Parent = parent
	local colorButton = Instance.new("TextButton"); colorButton.Size = UDim2.new(1, 0, 1, 0); colorButton.Parent = container
	if value == MIXED_VALUE then colorButton.Text = "<Mixed>"; colorButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80) else colorButton.Text = ""; colorButton.BackgroundColor3 = value end
	local pickerPopup = Instance.new("Frame"); pickerPopup.Size = UDim2.new(0, 150, 0, 180); pickerPopup.Position = UDim2.new(1, 5, 0, 0); pickerPopup.BackgroundColor3 = Config.Theme.TopBar; pickerPopup.BorderSizePixel = 1; pickerPopup.BorderColor3 = Config.Theme.ButtonAccent; pickerPopup.Visible = false; pickerPopup.ZIndex = 10; pickerPopup.Parent = container
	local h, s, v = (value ~= MIXED_VALUE and value or Color3.new(1,1,1)):ToHSV()
	local svPicker = Instance.new("ImageButton"); svPicker.Size = UDim2.new(1, -25, 0, 120); svPicker.Position = UDim2.new(0, 10, 0, 10); svPicker.BackgroundColor3 = Color3.fromHSV(h, 1, 1); svPicker.Parent = pickerPopup
	local svGradient = Instance.new("UIGradient"); svGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.new(0,0,0))}); svGradient.Rotation = 90; svGradient.Parent = svPicker
	local svGradient2 = Instance.new("UIGradient"); svGradient2.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,1,1,1)), ColorSequenceKeypoint.new(1, Color3.new(1,1,1))}); svGradient2.Parent = svPicker
	local svSelector = Instance.new("Frame"); svSelector.Size = UDim2.new(0, 5, 0, 5); svSelector.BackgroundColor3 = Color3.new(1,1,1); svSelector.BorderSizePixel = 1; svSelector.Position = UDim2.new(s, -2.5, 1-v, -2.5); svSelector.Parent = svPicker
	local hueSlider = Instance.new("ImageButton"); hueSlider.Size = UDim2.new(0, 15, 0, 120); hueSlider.Position = UDim2.new(1, -20, 0, 10); hueSlider.Parent = pickerPopup
	local hueGradient = Instance.new("UIGradient"); hueGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,0,0)), ColorSequenceKeypoint.new(0.16, Color3.new(1,1,0)), ColorSequenceKeypoint.new(0.33, Color3.new(0,1,0)), ColorSequenceKeypoint.new(0.5, Color3.new(0,1,1)), ColorSequenceKeypoint.new(0.66, Color3.new(0,0,1)), ColorSequenceKeypoint.new(0.83, Color3.new(1,0,1)), ColorSequenceKeypoint.new(1, Color3.new(1,0,0))}); hueGradient.Rotation = 90; hueGradient.Parent = hueSlider
	local hueSelector = Instance.new("Frame"); hueSelector.Size = UDim2.new(1, 4, 0, 3); hueSelector.Position = UDim2.new(0, -2, h, -1.5); hueSelector.BackgroundColor3 = Color3.new(1,1,1); hueSelector.BorderSizePixel = 1; hueSelector.Parent = hueSlider
	local function updateColor(isFinished) local newColor = Color3.fromHSV(h, s, v); colorButton.BackgroundColor3 = newColor; colorButton.Text = ""; svPicker.BackgroundColor3 = Color3.fromHSV(h, 1, 1); if isFinished then createMultiTrackUpdateAction(tracks, name, newColor, historyManager) end end
	local function inputHandler(input, frame, selector, isFinished) local pos = input.Position - frame.AbsolutePosition; local size = frame.AbsoluteSize; if frame == svPicker then s = math.clamp(pos.x / size.x, 0, 1); v = 1 - math.clamp(pos.y / size.y, 0, 1); selector.Position = UDim2.new(s, -2.5, 1-v, -2.5) else h = math.clamp(pos.y / size.y, 0, 1); selector.Position = UDim2.new(0, -2, h, -1.5) end; updateColor(isFinished) end
	svPicker.InputBegan:Connect(function(i) inputHandler(i, svPicker, svSelector, false) end); svPicker.InputChanged:Connect(function(i) inputHandler(i, svPicker, svSelector, false) end); svPicker.InputEnded:Connect(function(i) inputHandler(i, svPicker, svSelector, true) end)
	hueSlider.InputBegan:Connect(function(i) inputHandler(i, hueSlider, hueSelector, false) end); hueSlider.InputChanged:Connect(function(i) inputHandler(i, hueSlider, hueSelector, false) end); hueSlider.InputEnded:Connect(function(i) inputHandler(i, hueSlider, hueSelector, true) end)
	colorButton.MouseButton1Click:Connect(function() pickerPopup.Visible = not pickerPopup.Visible end)
end

local function createVector3Input(parent, name, value, tracks, historyManager)
	local vecFrame = Instance.new("Frame"); vecFrame.Size = UDim2.new(0.6, 0, 1, 0); vecFrame.Position = UDim2.new(0.4, 0, 0, 0); vecFrame.BackgroundTransparency = 1; vecFrame.Parent = parent
	local layout = Instance.new("UIListLayout"); layout.FillDirection = Enum.FillDirection.Horizontal; layout.Parent = vecFrame
	local function createVecInput() local input = Instance.new("TextBox"); input.Size = UDim2.new(0.33, -2, 1, 0); input.Parent = vecFrame; styleGenericInput(input); return input end
	local xInput, yInput, zInput = createVecInput(), createVecInput(), createVecInput()
	if value == MIXED_VALUE then xInput.PlaceholderText, yInput.PlaceholderText, zInput.PlaceholderText = "<X>", "<Y>", "<Z>" else local parts = value:split(","); xInput.Text, yInput.Text, zInput.Text = parts[1] or "0", parts[2] or "0", parts[3] or "0" end
	local function onFocusLost() if xInput.Text == "" or yInput.Text == "" or zInput.Text == "" then return end; local xV,yV,zV = tonumber(xInput.Text), tonumber(yInput.Text), tonumber(zInput.Text); if xV and yV and zV then styleInput(xInput,true); styleInput(yInput,true); styleInput(zInput,true); createMultiTrackUpdateAction(tracks, name, string.format("%s,%s,%s", xV,yV,zV), historyManager) else styleInput(xInput, tonumber(xInput.Text) ~= nil); styleInput(yInput, tonumber(yInput.Text) ~= nil); styleInput(zInput, tonumber(zInput.Text) ~= nil) end end
	xInput.FocusLost:Connect(onFocusLost); yInput.FocusLost:Connect(onFocusLost); zInput.FocusLost:Connect(onFocusLost)
end

local function createSequenceInput(parent, name, value, tracks, historyManager, sequenceType)
	local container = Instance.new("Frame"); container.Name = "GradientEditorContainer"; container.Size = UDim2.new(0.6, 0, 1, 0); container.Position = UDim2.new(0.4, 0, 0, 0); container.BackgroundTransparency = 1; container.Parent = parent
	local sequenceString = (value ~= MIXED_VALUE) and tostring(value) or (sequenceType == "Color" and "0,1,1,1;1,0,0,0" or "0,1;1,0")
	if value == MIXED_VALUE then
		local mixedLabel = Instance.new("TextLabel"); mixedLabel.Size = UDim2.new(1, 0, 0, 15); mixedLabel.Position = UDim2.new(0, 0, 0, -15); mixedLabel.BackgroundTransparency = 1; mixedLabel.TextColor3 = Color3.fromRGB(200, 200, 100); mixedLabel.Text = "Mixed Values - editing will override all."; mixedLabel.Font = Enum.Font.SourceSansItalic; mixedLabel.TextSize = 12; mixedLabel.Parent = container
	end
	local editor = GradientEditor.create(container, sequenceString, sequenceType)
	table.insert(activeGradientEditors, editor) -- Track for cleanup
	editor.SequenceChanged:Connect(function(newSequenceString) createMultiTrackUpdateAction(tracks, name, newSequenceString, historyManager) end)
end

function PropertiesManager.populate(panel, selectedTracks, timelineManager)
	PropertiesManager.clear(panel)
	local tracks = {}
	for track in pairs(selectedTracks) do table.insert(tracks, track) end
	if #tracks == 0 then return end

	local commonAttributes = {}
	local firstTrackAttributes = tracks[1]:GetAttributes()
	for name, value in pairs(firstTrackAttributes) do
		local isCommon = true
		for i = 2, #tracks do if tracks[i]:GetAttribute(name) == nil then isCommon = false; break end end
		if isCommon then commonAttributes[name] = value end
	end

	for name, _ in pairs(commonAttributes) do
		local firstValue = tracks[1]:GetAttribute(name)
		for i = 2, #tracks do if tracks[i]:GetAttribute(name) ~= firstValue then commonAttributes[name] = MIXED_VALUE; break end end
	end

	if commonAttributes.ComponentType == MIXED_VALUE then commonAttributes.ComponentType = nil end
	if commonAttributes.Lane == MIXED_VALUE then commonAttributes.Lane = nil end

	local layout = panel:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout", panel)
	layout.Padding = UDim.new(0, 5); layout.SortOrder = Enum.SortOrder.LayoutOrder

	local layoutOrderCounter = 1
	for _, category in ipairs(PROPERTY_CATEGORIES) do
		local hasAnyPropertyInCategory = false
		for _, name in ipairs(category.Properties) do if commonAttributes[name] ~= nil then hasAnyPropertyInCategory = true; break end end
		if hasAnyPropertyInCategory then
			local header = Instance.new("TextLabel"); header.LayoutOrder = layoutOrderCounter; layoutOrderCounter += 1; header.Size = UDim2.new(1, -10, 0, 20); header.Text = " " .. category.Name .. " "; header.BackgroundColor3 = Color3.fromRGB(40,40,40); header.TextColor3 = Color3.fromRGB(200,200,200); header.Font = Enum.Font.SourceSansBold; header.TextXAlignment = Enum.TextXAlignment.Left; header.Parent = panel
			for _, name in ipairs(category.Properties) do
				if commonAttributes[name] == nil then continue end
				local value = commonAttributes[name]
				local firstTrack = tracks[1]
				local firstValue = firstTrack:GetAttribute(name)
				local isNumSequence = (PROPERTY_TYPES[name] == "NumberSequence")
				local isColorSequence = (name == "Color" and (firstTrack:GetAttribute("ComponentType") == "Particle" or firstTrack:GetAttribute("ComponentType") == "Beam" or firstTrack:GetAttribute("ComponentType") == "Trail"))
				local propFrame = createPropertyUI(panel, name, layoutOrderCounter, isNumSequence or isColorSequence); layoutOrderCounter += 1
				local dataType = PROPERTY_TYPES[name] or typeof(firstValue)

				if isColorSequence then createSequenceInput(propFrame, name, value, tracks, timelineManager.historyManager, "Color")
				elseif dataType == "NumberSequence" then createSequenceInput(propFrame, name, value, tracks, timelineManager.historyManager, "Number")
				elseif dataType == "Color3" then createColor3Input(propFrame, name, value, tracks, timelineManager.historyManager)
				elseif dataType == "Vector3" then createVector3Input(propFrame, name, value, tracks, timelineManager.historyManager)
				elseif dataType == "Enum" then createEnumDropdown(propFrame, name, value, tracks, timelineManager.historyManager)
				elseif dataType == "NumberRange" then createNumberRangeInput(propFrame, name, value, tracks, timelineManager.historyManager)
				else createGenericInput(propFrame, name, value, tracks, timelineManager.historyManager) end
			end
		end
	end
	local deleteButton = Instance.new("TextButton"); deleteButton.Name = "DeleteTrackButton"; deleteButton.LayoutOrder = layoutOrderCounter; deleteButton.Size = UDim2.new(1, -10, 0, 30); deleteButton.Text = "Delete " .. #tracks .. " Tracks"; deleteButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40); deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255); deleteButton.Parent = panel
	deleteButton.MouseButton1Click:Connect(function() timelineManager:deleteSelectedTracks() end)
	task.wait(); panel.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
end

return PropertiesManager
