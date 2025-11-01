-- PropertiesManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/PropertiesManager.lua

local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)
local GradientEditor = require(script.Parent.GradientEditor)
local CurveEditor = require(script.Parent.CurveEditor) -- Require the new module
local PropertiesManager = {}

-- Module-level state
local activeGradientEditors = {}
local curveEditorInstance = nil -- To hold the single instance
local currentPanel = nil
local currentTracks = {}

PropertiesManager.KeyframeChanged = {}
function PropertiesManager.KeyframeChanged:Connect(callback) table.insert(self, callback) end
function PropertiesManager.KeyframeChanged:Fire(...) for _, cb in ipairs(self) do cb(...) end end
local currentTimelineManager = nil
local currentPreviewManager = nil
local connections = {} -- To manage connections and prevent leaks

-- Constant to represent a mixed value state
local MIXED_VALUE = { isMixed = true }
local KEYFRAME_TIME_EPSILON = 0.01 -- Tolerance for being "on" a keyframe

local ENUM_OPTIONS = {
	Face = {"Right", "Top", "Back", "Left", "Bottom", "Front"},
	EmissionDirection = {"Right", "Top", "Back", "Left", "Bottom", "Front"},
	Orientation = {"FacingCamera", "FacingCameraWorldUp", "VelocityParallel"},
	TextureMode = {"Stretch", "Wrap", "Static"},
	RollOffMode = {"Inverse", "Linear", "LinearSquare", "InverseTapered"}
}
local PROPERTY_CATEGORIES = {
	{ Name = "General", Properties = {"ComponentType", "LayoutOrder", "Enabled", "TimeScale", "IsLocked"} },
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
local KEYFRAMEABLE_PROPERTIES = {
	Brightness = true, Color = true, Range = true, Angle = true,
	Width0 = true, Width1 = true, LightEmission = true, Volume = true, PlaybackSpeed = true,
	Rate = true, Acceleration = true, Drag = true, TimeScale = true, ZOffset = true
}

-- Made public to be accessible from TimelineManager and event connections
function PropertiesManager.createKeyframeAction(track, propName, time, value, isDelete)
	local historyManager = currentTimelineManager.historyManager
	local originalKeyframes = track:GetAttribute(propName)
	local newKeyframes

	local action = {
		execute = function()
			newKeyframes = {}
			for _, kf in ipairs(originalKeyframes) do
				if math.abs(kf.time - time) > KEYFRAME_TIME_EPSILON then
					table.insert(newKeyframes, kf)
				end
			end
			if not isDelete then
				-- p1x, p1y, p2x, p2y
				-- Corresponds to the out-tangent of the first key and the in-tangent of the second.
				-- For a new keyframe, we can use a default smooth curve.
				local defaultEasing = { p1x = 0.33, p1y = 0, p2x = 0.67, p2y = 1 }
				table.insert(newKeyframes, {time = time, value = value, easing = defaultEasing})
			end
			table.sort(newKeyframes, function(a, b) return a.time < b.time end)
			track:SetAttribute(propName, newKeyframes)
			PropertiesManager.KeyframeChanged:Fire(track)
		end,
		undo = function()
			track:SetAttribute(propName, originalKeyframes)
			PropertiesManager.KeyframeChanged:Fire(track)
		end
	}
	historyManager:registerAction(action)
end

-- Made public to avoid unknown global issues in event connections
function PropertiesManager.createMultiTrackUpdateAction(tracks, propertyName, newValue, historyManager)
	local originalValues = {}
	for _, track in ipairs(tracks) do
		originalValues[track] = track:GetAttribute(propertyName)
	end

	local action = {
		execute = function()
			for _, track in ipairs(tracks) do
				track:SetAttribute(propertyName, newValue)
			end
		end,
		undo = function()
			for track, originalValue in pairs(originalValues) do
				if track and track.Parent then
					track:SetAttribute(propertyName, originalValue)
				end
			end
		end
	}
	historyManager:registerAction(action)
end

function PropertiesManager.clear(panel)
	for _, conn in ipairs(connections) do conn:Disconnect() end; connections = {}
	for _, editor in ipairs(activeGradientEditors) do editor:destroy() end; activeGradientEditors = {}
	if curveEditorInstance then curveEditorInstance:hide() end -- Hide the editor
	if panel then
		for _, child in ipairs(panel:GetChildren()) do
			if not child:IsA("UILayout") and child.Name ~= "CurveEditor" then -- Don't destroy the editor
				child:Destroy()
			end
		end
		panel.CanvasSize = UDim2.new(0, 0, 0, 0)
	end
	currentPanel = nil; currentTracks = {}
end

local function createPropertyUI(panel, name, layoutOrder, isSequence, isKeyframeable)
	local height = isSequence and 80 or 25
	local propFrame = Instance.new("Frame")
	propFrame.LayoutOrder = layoutOrder
	propFrame.Size = UDim2.new(1, 0, 0, height)
	propFrame.BackgroundTransparency = 1
	propFrame.Parent = panel

	local labelSize = 0.4
	local inputStartPos = 0.4
	if isKeyframeable then
		labelSize = 0.35
		inputStartPos = 0.45
		local keyframeButton = Instance.new("TextButton")
		keyframeButton.Name = "KeyframeButton"
		keyframeButton.Size = UDim2.new(0.08, 0, 1, -10)
		keyframeButton.Position = UDim2.new(labelSize - 0.08, 0, 0.5, -((height - 10)/2))
		keyframeButton.Text = "K"
		keyframeButton.Parent = propFrame

		local curveEditButton = Instance.new("TextButton")
		curveEditButton.Name = "CurveEditButton"
		curveEditButton.Size = UDim2.new(0.08, 0, 1, -10)
		curveEditButton.Position = UDim2.new(labelSize, 0, 0.5, -((height - 10)/2))
		curveEditButton.Text = "E"
		curveEditButton.Visible = false -- Only visible when on a keyframe
		curveEditButton.Parent = propFrame

		local conn = keyframeButton.MouseButton1Click:Connect(function()
			if #currentTracks > 0 then
				local track = currentTracks[1]
				local timeIntoTrack = currentPreviewManager.currentTime - (track:GetAttribute("StartTime") or 0)
				timeIntoTrack = math.max(0, timeIntoTrack)

				local keyframes = track:GetAttribute(name)
				local currentValue = PropertiesManager._getInterpolatedValue(keyframes, timeIntoTrack)

				PropertiesManager.createKeyframeAction(track, name, timeIntoTrack, currentValue, false)
			end
		end)
		table.insert(connections, conn)

		local conn2 = curveEditButton.MouseButton1Click:Connect(function()
			if curveEditorInstance and #currentTracks > 0 then
				local track = currentTracks[1]
				local timeIntoTrack = currentPreviewManager.currentTime - (track:GetAttribute("StartTime") or 0)
				local keyframes = track:GetAttribute(name)
				for _, kf in ipairs(keyframes) do
					if math.abs(kf.time - timeIntoTrack) < KEYFRAME_TIME_EPSILON then
						curveEditorInstance:loadKeyframe(kf)
						break
					end
				end
			end
		end)
		table.insert(connections, conn2)
	end

	local propLabel = Instance.new("TextLabel")
	propLabel.Size = UDim2.new(labelSize, 0, 1, 0)
	propLabel.BackgroundTransparency = 1
	propLabel.TextColor3 = Config.Theme.Text
	propLabel.Text = name
	propLabel.TextXAlignment = Enum.TextXAlignment.Left
	propLabel.Parent = propFrame

	return propFrame, inputStartPos
end

local function styleGenericInput(textbox, isLocked)
	local theme = Config.Theme
	textbox.BackgroundColor3 = isLocked and theme.ButtonDisabled or theme.Button
	textbox.TextColor3 = isLocked and theme.TextDisabled or theme.Text
	textbox.Font = theme.Font
	textbox.TextSize = theme.FontSize
	textbox.BorderSizePixel = 1
	textbox.BorderColor3 = theme.ButtonAccent
	textbox.Active = not isLocked
end

function PropertiesManager._getInterpolatedValue(keyframes, timeIntoTrack)
	if not keyframes or #keyframes == 0 then return nil end

	-- Find the two keyframes to interpolate between
	local key1, key2

	if #keyframes == 1 or timeIntoTrack < keyframes[1].time then
		return keyframes[1].value
	end

	for i = 1, #keyframes - 1 do
		if keyframes[i].time <= timeIntoTrack and keyframes[i+1].time >= timeIntoTrack then
			key1, key2 = keyframes[i], keyframes[i+1]; break
		end
	end

	if not key1 then
		return keyframes[#keyframes].value
	end

	local value = Utils.interpolate(key1, key2, timeIntoTrack)

	-- The interpolate function returns Vector3, but the UI expects a string.
	if typeof(value) == "Vector3" then
		return string.format("%.2f,%.2f,%.2f", value.X, value.Y, value.Z)
	end
	return value
end

function PropertiesManager.updateValues(time)
	if not currentPanel or #currentTracks == 0 then return end
	local startTime = currentTracks[1]:GetAttribute("StartTime") or 0
	local timeIntoTrack = time - startTime

	for _, propFrame in ipairs(currentPanel:GetChildren()) do
		local propName = propFrame:GetAttribute("PropertyName")
		if propName and KEYFRAMEABLE_PROPERTIES[propName] then
			local keyframes = currentTracks[1]:GetAttribute(propName)
			if type(keyframes) ~= "table" then continue end

			local onKeyframe = false
			for _, kf in ipairs(keyframes) do
				if math.abs(kf.time - timeIntoTrack) < KEYFRAME_TIME_EPSILON then
					onKeyframe = true
					break
				end
			end

			local curveEditButton = propFrame:FindFirstChild("CurveEditButton")
			if curveEditButton then curveEditButton.Visible = onKeyframe end

			local interpolatedValue = PropertiesManager._getInterpolatedValue(keyframes, timeIntoTrack)
			local input = propFrame:FindFirstChild("PropertyInput")
			if input then
				input.Active = onKeyframe
				input.BorderColor3 = onKeyframe and Color3.fromRGB(255, 255, 0) or Config.Theme.ButtonAccent

				if interpolatedValue then
					if input:IsA("TextButton") then -- Color
						input.BackgroundColor3 = interpolatedValue
					elseif input:IsA("Frame") and input:FindFirstChild("X") then -- Vector3
						local v = Utils.parseVector3(interpolatedValue)
						input.X.Text = string.format("%.2f", v.X); input.Y.Text = string.format("%.2f", v.Y); input.Z.Text = string.format("%.2f", v.Z)
					elseif input:IsA("TextBox") then
						input.Text = (typeof(interpolatedValue) == "number") and string.format("%.2f", interpolatedValue) or tostring(interpolatedValue)
					end
				end
			end
		end
	end
end

local function createGenericInput(parent, name, value, tracks, historyManager, isLocked, startPos, isKeyframeable)
	local valueType = typeof(value)
	local propInput = Instance.new("TextBox")
	propInput.Name = "PropertyInput"
	propInput.Size = UDim2.new(1 - startPos, 0, 1, 0); propInput.Position = UDim2.new(startPos, 0, 0, 0)
	styleGenericInput(propInput, isLocked); propInput.Parent = parent
	if value == MIXED_VALUE then propInput.PlaceholderText = "<Mixed>" else propInput.Text = tostring(value) end

	if isKeyframeable then propInput.Active = false end -- Not editable by default

	if not isLocked then
		local conn = propInput.FocusLost:Connect(function(enterPressed)
			if not enterPressed or propInput.Text == "" then return end
			local textValue = propInput.Text
			local newValue
			if valueType == "number" then newValue = tonumber(textValue)
			elseif valueType == "boolean" then newValue = (textValue:lower() == "true")
			else newValue = textValue end
			if newValue == nil then return end

			if isKeyframeable then
				local track = tracks[1]
				local timeIntoTrack = currentPreviewManager.currentTime - (track:GetAttribute("StartTime") or 0)
				PropertiesManager.createKeyframeAction(track, name, timeIntoTrack, newValue, false)
			else
				PropertiesManager.createMultiTrackUpdateAction(tracks, name, newValue, historyManager)
			end
		end)
		table.insert(connections, conn)
	end
end

local function createVector3Input(parent, name, value, tracks, historyManager, isLocked, startPos, isKeyframeable)
	local vecFrame = Instance.new("Frame"); vecFrame.Name = "PropertyInput"; vecFrame.Size = UDim2.new(1 - startPos, 0, 1, 0); vecFrame.Position = UDim2.new(startPos, 0, 0, 0); vecFrame.BackgroundTransparency = 1; vecFrame.Parent = parent
	local layout = Instance.new("UIListLayout"); layout.FillDirection = Enum.FillDirection.Horizontal; layout.Parent = vecFrame
	local function createVecInput(axis) local input = Instance.new("TextBox"); input.Name = axis; input.Size = UDim2.new(0.33, -2, 1, 0); input.Parent = vecFrame; styleGenericInput(input, isLocked); return input end
	local xInput, yInput, zInput = createVecInput("X"), createVecInput("Y"), createVecInput("Z")

	if isKeyframeable then xInput.Active, yInput.Active, zInput.Active = false, false, false end

	if value == MIXED_VALUE then xInput.PlaceholderText, yInput.PlaceholderText, zInput.PlaceholderText = "<X>", "<Y>", "<Z>" else local parts = tostring(value):split(","); xInput.Text, yInput.Text, zInput.Text = parts[1] or "0", parts[2] or "0", parts[3] or "0" end
	if not isLocked then
		local function onFocusLost()
			if xInput.Text == "" or yInput.Text == "" or zInput.Text == "" then return end
			local xV,yV,zV = tonumber(xInput.Text), tonumber(yInput.Text), tonumber(zInput.Text)
			if not (xV and yV and zV) then return end
			local newValue = string.format("%s,%s,%s", xV,yV,zV)
			if isKeyframeable then
				local track = tracks[1]
				local timeIntoTrack = currentPreviewManager.currentTime - (track:GetAttribute("StartTime") or 0)
				PropertiesManager.createKeyframeAction(track, name, timeIntoTrack, newValue, false)
			else
				PropertiesManager.createMultiTrackUpdateAction(tracks, name, newValue, historyManager)
			end
		end
		local conn1 = xInput.FocusLost:Connect(onFocusLost); local conn2 = yInput.FocusLost:Connect(onFocusLost); local conn3 = zInput.FocusLost:Connect(onFocusLost)
		table.insert(connections, conn1); table.insert(connections, conn2); table.insert(connections, conn3)
	end
end

local function createEnumDropdown(parent, name, value, tracks, historyManager, isLocked, startPos)
	local theme = Config.Theme; local options = ENUM_OPTIONS[name]; if not options then return end
	local dropdownFrame = Instance.new("Frame"); dropdownFrame.Size = UDim2.new(1 - startPos, 0, 1, 0); dropdownFrame.Position = UDim2.new(startPos, 0, 0, 0); dropdownFrame.BackgroundTransparency = 1; dropdownFrame.Parent = parent; dropdownFrame.ZIndex = 2
	local mainButton = Instance.new("TextButton"); mainButton.Size = UDim2.new(1, 0, 1, 0); styleGenericInput(mainButton, isLocked); mainButton.Parent = dropdownFrame
	if value == MIXED_VALUE then mainButton.Text = "<Mixed>" else mainButton.Text = tostring(value) end
	local optionsList = Instance.new("ScrollingFrame"); optionsList.Size = UDim2.new(1, 0, 0, 100); optionsList.Position = UDim2.new(0, 0, 1, 0); optionsList.BackgroundColor3 = theme.Properties; optionsList.BorderSizePixel = 1; optionsList.BorderColor3 = theme.ButtonAccent; optionsList.Visible = false; optionsList.Parent = dropdownFrame; optionsList.ZIndex = 3
	local listLayout = Instance.new("UIListLayout"); listLayout.Parent = optionsList
	for _, option in ipairs(options) do
		local optionButton = Instance.new("TextButton"); optionButton.Size = UDim2.new(1, 0, 0, 25); optionButton.Text = option; styleGenericInput(optionButton, false); optionButton.Parent = optionsList
		local conn1 = optionButton.MouseButton1Click:Connect(function() mainButton.Text = option; optionsList.Visible = false; PropertiesManager.createMultiTrackUpdateAction(tracks, name, option, historyManager) end)
		table.insert(connections, conn1)
	end
	local conn2 = mainButton.MouseButton1Click:Connect(function() if not isLocked then optionsList.Visible = not optionsList.Visible end end)
	table.insert(connections, conn2)
end

local function createNumberRangeInput(parent, name, value, tracks, historyManager, isLocked, startPos)
	local rangeFrame = Instance.new("Frame"); rangeFrame.Size = UDim2.new(1 - startPos, 0, 1, 0); rangeFrame.Position = UDim2.new(startPos, 0, 0, 0); rangeFrame.BackgroundTransparency = 1; rangeFrame.Parent = parent
	local layout = Instance.new("UIListLayout"); layout.FillDirection = Enum.FillDirection.Horizontal; layout.Parent = rangeFrame
	local function createRangeInput() local input = Instance.new("TextBox"); input.Size = UDim2.new(0.5, -2, 1, 0); input.Parent = rangeFrame; styleGenericInput(input, isLocked); return input end
	local minInput, maxInput = createRangeInput(), createRangeInput()
	if value == MIXED_VALUE then minInput.PlaceholderText = "<Mixed>"; maxInput.PlaceholderText = "<Mixed>" else local parts = tostring(value):split(" "); minInput.Text = parts[1] or "0"; maxInput.Text = parts[2] or parts[1] or "0" end
	if not isLocked then
		local function onFocusLost() if minInput.Text == "" or maxInput.Text == "" then return end; local minV, maxV = tonumber(minInput.Text), tonumber(maxInput.Text); if not (minV and maxV) then return end; PropertiesManager.createMultiTrackUpdateAction(tracks, name, string.format("%s %s", minV, maxV), historyManager) end
		local conn1 = minInput.FocusLost:Connect(onFocusLost); local conn2 = maxInput.FocusLost:Connect(onFocusLost)
		table.insert(connections, conn1); table.insert(connections, conn2)
	end
end

local function createColor3Input(parent, name, value, tracks, historyManager, isLocked, startPos, isKeyframeable)
	local container = Instance.new("Frame"); container.Size = UDim2.new(1 - startPos, 0, 1, 0); container.Position = UDim2.new(startPos, 0, 0, 0); container.BackgroundTransparency = 1; container.Parent = parent
	local colorButton = Instance.new("TextButton"); colorButton.Name = "PropertyInput"
	colorButton.Size = UDim2.new(1, 0, 1, 0); colorButton.Parent = container;
	styleGenericInput(colorButton, isLocked)
	if isKeyframeable then colorButton.Active = false end
	if value == MIXED_VALUE then colorButton.Text = "<Mixed>" else colorButton.Text = ""; colorButton.BackgroundColor3 = value end
end

local function createSequenceInput(parent, name, value, tracks, historyManager, sequenceType, isLocked, startPos)
	local container = Instance.new("Frame"); container.Name = "GradientEditorContainer"; container.Size = UDim2.new(1 - startPos, 0, 1, 0); container.Position = UDim2.new(startPos, 0, 0, 0); container.BackgroundTransparency = 1; container.Parent = parent
	local sequenceString = (value ~= MIXED_VALUE) and tostring(value) or (sequenceType == "Color" and "0,1,1,1;1,0,0,0" or "0,1;1,0")
	if value == MIXED_VALUE then
		local mixedLabel = Instance.new("TextLabel"); mixedLabel.Size = UDim2.new(1, 0, 0, 15); mixedLabel.Position = UDim2.new(0, 0, 0, -15); mixedLabel.BackgroundTransparency = 1; mixedLabel.TextColor3 = Color3.fromRGB(200, 200, 100); mixedLabel.Text = "Mixed Values - editing will override all."; mixedLabel.Font = Enum.Font.SourceSansItalic; mixedLabel.TextSize = 12; mixedLabel.Parent = container
	end
	if isLocked then container.BackgroundTransparency = 0.5; container.BackgroundColor3 = Config.Theme.ButtonDisabled end
	local editor = GradientEditor.create(container, sequenceString, sequenceType)
	table.insert(activeGradientEditors, editor)
	if not isLocked then
		local conn = editor.SequenceChanged:Connect(function(newSequenceString) PropertiesManager.createMultiTrackUpdateAction(tracks, name, newSequenceString, historyManager) end)
		table.insert(connections, conn)
	end
end

function PropertiesManager.populate(panel, selectedTracks, timelineManager, previewManager)
	PropertiesManager.clear(panel)

	if not curveEditorInstance then
		-- Create the editor instance, parented to a suitable frame that doesn't get cleared
		curveEditorInstance = CurveEditor.new(panel.Parent)
		curveEditorInstance.CurveChanged:Connect(function()
			if #currentTracks > 0 then
				PropertiesManager.KeyframeChanged:Fire(currentTracks[1])
			end
		end)
	end

	currentPanel = panel
	currentTracks = {}
	for track in pairs(selectedTracks) do table.insert(currentTracks, track) end
	if #currentTracks == 0 then return end

	currentTimelineManager = timelineManager
	currentPreviewManager = previewManager

	local allLocked = true
	for _, track in ipairs(currentTracks) do
		if not track:GetAttribute("IsLocked") then allLocked = false; break end
	end

	local commonAttributes = {}
	local firstTrackAttributes = currentTracks[1]:GetAttributes()
	for name, value in pairs(firstTrackAttributes) do
		local isCommon = true
		for i = 2, #currentTracks do if currentTracks[i]:GetAttribute(name) == nil then isCommon = false; break end end
		if isCommon then commonAttributes[name] = value end
	end

	for name, _ in pairs(commonAttributes) do
		local firstValue = currentTracks[1]:GetAttribute(name)
		for i = 2, #currentTracks do
			if currentTracks[i]:GetAttribute(name) ~= firstValue then commonAttributes[name] = MIXED_VALUE; break end
		end
	end

	local layout = panel:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout", panel)
	layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder
	local layoutOrderCounter = 1

	for _, category in ipairs(PROPERTY_CATEGORIES) do
		local hasAnyPropertyInCategory = false
		for _, name in ipairs(category.Properties) do if commonAttributes[name] ~= nil then hasAnyPropertyInCategory = true; break end end
		if hasAnyPropertyInCategory then
			local header = Instance.new("TextLabel"); header.LayoutOrder = layoutOrderCounter; layoutOrderCounter += 1; header.Size = UDim2.new(1, 0, 0, 22); header.Text = "  " .. category.Name; header.BackgroundColor3 = Config.Theme.TopBar:Lerp(Color3.new(0,0,0), 0.2); header.TextColor3 = Config.Theme.Text; header.Font = Enum.Font.SourceSansBold; header.TextXAlignment = Enum.TextXAlignment.Left; header.Parent = panel
			for _, name in ipairs(category.Properties) do
				if commonAttributes[name] == nil then continue end

				local isKeyframeable = KEYFRAMEABLE_PROPERTIES[name] or false
				local value = commonAttributes[name]

				if isKeyframeable and value ~= MIXED_VALUE and type(value) == "table" then
					local timeIntoTrack = previewManager.currentTime - (currentTracks[1]:GetAttribute("StartTime") or 0)
					value = PropertiesManager._getInterpolatedValue(value, timeIntoTrack)
				end

				local firstTrack = currentTracks[1]
				local firstValue = firstTrack:GetAttribute(name)
				local isNumSequence = (PROPERTY_TYPES[name] == "NumberSequence")
				local isColorSequence = (name == "Color" and (firstTrack:GetAttribute("ComponentType") == "Particle" or firstTrack:GetAttribute("ComponentType") == "Beam" or firstTrack:GetAttribute("ComponentType") == "Trail"))

				local propFrame, startPos = createPropertyUI(panel, name, layoutOrderCounter, isNumSequence or isColorSequence, isKeyframeable)
				propFrame:SetAttribute("PropertyName", name)
				layoutOrderCounter += 1

				local dataType = PROPERTY_TYPES[name] or typeof(value)
				if type(firstValue) == "table" and firstValue[1] then dataType = typeof(firstValue[1].value) end

				local isPropertyLocked = allLocked and (name ~= "IsLocked")

				if isColorSequence then createSequenceInput(propFrame, name, value, currentTracks, timelineManager.historyManager, "Color", isPropertyLocked, startPos)
				elseif dataType == "NumberSequence" then createSequenceInput(propFrame, name, value, currentTracks, timelineManager.historyManager, "Number", isPropertyLocked, startPos)
				elseif dataType == "Color3" then createColor3Input(propFrame, name, value, currentTracks, timelineManager.historyManager, isPropertyLocked, startPos, isKeyframeable)
				elseif dataType == "Vector3" then createVector3Input(propFrame, name, value, currentTracks, timelineManager.historyManager, isPropertyLocked, startPos, isKeyframeable)
				elseif dataType == "Enum" then createEnumDropdown(propFrame, name, value, currentTracks, timelineManager.historyManager, isPropertyLocked, startPos)
				elseif dataType == "NumberRange" then createNumberRangeInput(propFrame, name, value, currentTracks, timelineManager.historyManager, isPropertyLocked, startPos)
				else createGenericInput(propFrame, name, value, currentTracks, timelineManager.historyManager, isPropertyLocked, startPos, isKeyframeable) end
			end
		end
	end
	task.wait(); panel.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
end

return PropertiesManager
