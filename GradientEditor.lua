-- GradientEditor.lua (ModuleScript)
-- Creates an interactive gradient editor UI for ColorSequence and NumberSequence.

local Config = require(script.Parent.Config)
local UserInputService = game:GetService("UserInputService")

local GradientEditor = {}
GradientEditor.__index = GradientEditor

local Z_INDEX_BASE = 5
local HANDLE_SIZE = 10

-- Entry point: Creates the full editor instance and returns a controller object.
function GradientEditor.create(parent, sequenceString, sequenceType)
	local self = setmetatable({}, GradientEditor)

	self.keypoints = {} -- Table of {Time, Value}
	self.handles = {}   -- Map of keypoint -> UI handle
	self.sequenceType = sequenceType or "Color"
	self.activeHandle = nil
	self.parent = parent
	self.valueEditor = nil -- UI for editing the value (color picker/number input)

	-- Event to fire when the sequence is updated
	self.SequenceChanged = {}
	function self.SequenceChanged:Connect(callback) table.insert(self, callback) end
	function self.SequenceChanged:Fire(...) for _, cb in ipairs(self) do cb(...) end end

	self:_createUI(parent)
	self:_parseSequenceString(sequenceString)
	self:_updateAndFire(false) -- Initial update without firing event
	self:_populateHandles()
	self:_connectEvents()

	return self
end

--#region UI Creation
function GradientEditor:_createUI(parent)
	local theme = Config.Theme

	self.mainFrame = Instance.new("Frame")
	self.mainFrame.Name = "GradientEditor"
	self.mainFrame.Size = UDim2.new(1, 0, 1, 0)
	self.mainFrame.BackgroundColor3 = theme.Button
	self.mainFrame.BorderSizePixel = 0
	self.mainFrame.Parent = parent

	self.gradientBar = Instance.new("TextButton")
	self.gradientBar.Name = "GradientBar"
	self.gradientBar.Text = ""
	self.gradientBar.Size = UDim2.new(1, -10, 0, 20)
	self.gradientBar.Position = UDim2.new(0, 5, 0, 5)
	self.gradientBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	self.gradientBar.Parent = self.mainFrame
	self.gradientBar.ZIndex = Z_INDEX_BASE

	self.uiGradient = Instance.new("UIGradient")
	self.uiGradient.Parent = self.gradientBar

	self.handleContainer = Instance.new("Frame")
	self.handleContainer.Name = "HandleContainer"
	self.handleContainer.Size = UDim2.new(1, 0, 0, HANDLE_SIZE)
	self.handleContainer.Position = UDim2.new(0, 0, 0, 25)
	self.handleContainer.BackgroundTransparency = 1
	self.handleContainer.Parent = self.mainFrame
	self.handleContainer.ZIndex = Z_INDEX_BASE + 1
end

function GradientEditor:_createHandle(keypoint)
	local handle = Instance.new("TextButton")
	handle.Name = "KeypointHandle"
	handle.Text = ""
	handle.Size = UDim2.new(0, HANDLE_SIZE, 1, 0)
	handle.Position = UDim2.new(keypoint.Time, -HANDLE_SIZE/2, 0, 0)
	handle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	handle.BorderColor3 = Color3.fromRGB(0, 0, 0)
	handle.BorderSizePixel = 1
	handle.ZIndex = Z_INDEX_BASE + 2
	handle.Parent = self.handleContainer

	self.handles[keypoint] = handle
	return handle
end

function GradientEditor:_createValueEditor()
	if self.valueEditor then self.valueEditor:Destroy() end
	if not self.activeKeypoint then return end

	local theme = Config.Theme
	if self.sequenceType == "Color" then
		self.valueEditor = Instance.new("Frame")
		self.valueEditor.Size = UDim2.new(0, 150, 0, 180)
		self.valueEditor.Position = UDim2.new(self.activeKeypoint.Time, -75, 0, 40)
		self.valueEditor.BackgroundColor3 = theme.TopBar
		self.valueEditor.BorderSizePixel = 1
		self.valueEditor.BorderColor3 = theme.ButtonAccent
		self.valueEditor.ZIndex = Z_INDEX_BASE + 10
		self.valueEditor.Parent = self.mainFrame

		local h, s, v = self.activeKeypoint.Value:ToHSV()
		local svPicker = Instance.new("ImageButton"); svPicker.Size = UDim2.new(1, -25, 0, 120); svPicker.Position = UDim2.new(0, 10, 0, 10); svPicker.BackgroundColor3 = Color3.fromHSV(h, 1, 1); svPicker.Parent = self.valueEditor
		local svGradient = Instance.new("UIGradient"); svGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.new(0,0,0))}); svGradient.Rotation = 90; svGradient.Parent = svPicker
		local svGradient2 = Instance.new("UIGradient"); svGradient2.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,1,1,1)), ColorSequenceKeypoint.new(1, Color3.new(1,1,1))}); svGradient2.Parent = svPicker
		local svSelector = Instance.new("Frame"); svSelector.Size = UDim2.new(0, 5, 0, 5); svSelector.BackgroundColor3 = Color3.new(1,1,1); svSelector.BorderSizePixel = 1; svSelector.Position = UDim2.new(s, -2.5, 1-v, -2.5); svSelector.Parent = svPicker
		local hueSlider = Instance.new("ImageButton"); hueSlider.Size = UDim2.new(0, 15, 0, 120); hueSlider.Position = UDim2.new(1, -20, 0, 10); hueSlider.Parent = self.valueEditor
		local hueGradient = Instance.new("UIGradient"); hueGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1,0,0)), ColorSequenceKeypoint.new(0.16, Color3.new(1,1,0)), ColorSequenceKeypoint.new(0.33, Color3.new(0,1,0)), ColorSequenceKeypoint.new(0.5, Color3.new(0,1,1)), ColorSequenceKeypoint.new(0.66, Color3.new(0,0,1)), ColorSequenceKeypoint.new(0.83, Color3.new(1,0,1)), ColorSequenceKeypoint.new(1, Color3.new(1,0,0))}); hueGradient.Rotation = 90; hueGradient.Parent = hueSlider
		local hueSelector = Instance.new("Frame"); hueSelector.Size = UDim2.new(1, 4, 0, 3); hueSelector.Position = UDim2.new(0, -2, h, -1.5); hueSelector.BackgroundColor3 = Color3.new(1,1,1); hueSelector.BorderSizePixel = 1; hueSelector.Parent = hueSlider

		local function updateColor()
			local newColor = Color3.fromHSV(h, s, v)
			self.activeKeypoint.Value = newColor
			self:_updateAndFire(true)
			svPicker.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		end
		local function inputHandler(input, frame, selector)
			local pos = Vector2.new(input.Position.X, input.Position.Y) - frame.AbsolutePosition; local size = frame.AbsoluteSize
			if frame == svPicker then s = math.clamp(pos.x / size.x, 0, 1); v = 1 - math.clamp(pos.y / size.y, 0, 1); selector.Position = UDim2.new(s, -2.5, 1-v, -2.5)
			else h = math.clamp(pos.y / size.y, 0, 1); selector.Position = UDim2.new(0, -2, h, -1.5) end
			updateColor()
		end
		svPicker.InputBegan:Connect(function(input) inputHandler(input, svPicker, svSelector) end); svPicker.InputChanged:Connect(function(input) inputHandler(input, svPicker, svSelector) end); hueSlider.InputBegan:Connect(function(input) inputHandler(input, hueSlider, hueSelector) end); hueSlider.InputChanged:Connect(function(input) inputHandler(input, hueSlider, hueSelector) end)

	else -- Number
		self.valueEditor = Instance.new("TextBox")
		self.valueEditor.Size = UDim2.new(0, 50, 0, 25)
		self.valueEditor.Position = UDim2.new(self.activeKeypoint.Time, -25, 0, 40)
		self.valueEditor.Text = tostring(self.activeKeypoint.Value)
		self.valueEditor.BackgroundColor3 = theme.Button
		self.valueEditor.TextColor3 = theme.Text
		self.valueEditor.ZIndex = Z_INDEX_BASE + 10
		self.valueEditor.Parent = self.mainFrame

		self.valueEditor.FocusLost:Connect(function(enterPressed)
			local newValue = tonumber(self.valueEditor.Text)
			if newValue then
				self.activeKeypoint.Value = newValue
				self:_updateAndFire(true)
			else
				self.valueEditor.Text = tostring(self.activeKeypoint.Value) -- Revert
			end
		end)
	end
end
--#endregion

--#region Event Connection
function GradientEditor:_connectEvents()
	self.gradientBar.MouseButton1Click:Connect(function(x, y)
		local relativeX = x - self.gradientBar.AbsolutePosition.X
		local time = math.clamp(relativeX / self.gradientBar.AbsoluteSize.X, 0, 1)
		self:_addKeypoint(time)
	end)

	for keypoint, handle in pairs(self.handles) do
		self:_connectHandleEvents(handle, keypoint)
	end
end

function GradientEditor:_connectHandleEvents(handle, keypoint)
	local isDragging = false
	local dragStart = 0

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = true
			dragStart = input.Position.X
			self:_setActiveHandle(handle, keypoint)
			-- input:SetProcessed() -- No longer a valid method, but capturing focus here is too aggressive.
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_removeKeypoint(keypoint)
		end
	end)

	handle.InputChanged:Connect(function(input)
		if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position.X - dragStart
			local containerWidth = self.handleContainer.AbsoluteSize.X
			local newTime = (handle.AbsolutePosition.X - self.handleContainer.AbsolutePosition.X + delta) / containerWidth
			newTime = math.clamp(newTime, 0, 1)

			local index = table.find(self.keypoints, keypoint)
			if index > 1 then newTime = math.max(newTime, self.keypoints[index-1].Time + 0.001) end
			if index < #self.keypoints then newTime = math.min(newTime, self.keypoints[index+1].Time - 0.001) end

			keypoint.Time = newTime
			handle.Position = UDim2.new(keypoint.Time, -HANDLE_SIZE/2, 0, 0)

			self:_updateGradient()
			dragStart = input.Position.X
		end
	end)

	handle.InputEnded:Connect(function(input)
		if isDragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = false
			self:_updateAndFire(true)
		end
	end)
end
--#endregion

--#region Data & State Management
function GradientEditor:_parseSequenceString(sequenceString)
	self.keypoints = {}
	local parts = sequenceString:split(";")
	for _, part in ipairs(parts) do
		local values = part:split(",")
		if self.sequenceType == "Color" and #values == 4 then
			local t,r,g,b = tonumber(values[1]),tonumber(values[2]),tonumber(values[3]),tonumber(values[4])
			if t and r and g and b then table.insert(self.keypoints, {Time=t, Value=Color3.new(r,g,b)}) end
		elseif self.sequenceType == "Number" and #values == 2 then
			local t,v = tonumber(values[1]), tonumber(values[2])
			if t and v then table.insert(self.keypoints, {Time=t, Value=v}) end
		end
	end
	if #self.keypoints < 2 then
		if self.sequenceType == "Color" then self.keypoints = { {Time=0,Value=Color3.new(1,1,1)},{Time=1,Value=Color3.new(0,0,0)} }
		else self.keypoints = { {Time=0,Value=1},{Time=1,Value=0} } end
	end
end

function GradientEditor:_populateHandles()
	for _, handle in pairs(self.handles) do handle:Destroy() end
	self.handles = {}
	for _, keypoint in ipairs(self.keypoints) do self:_createHandle(keypoint) end
end

function GradientEditor:_updateAndFire(shouldFireEvent)
	table.sort(self.keypoints, function(a, b) return a.Time < b.Time end)
	self:_updateGradient()
	if shouldFireEvent then
		self.SequenceChanged:Fire(self:_getSequenceString())
	end
end

function GradientEditor:_setActiveHandle(handle, keypoint)
	if self.activeHandle then
		self.activeHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		self.activeHandle.ZIndex = Z_INDEX_BASE + 2
	end
	self.activeHandle = handle
	self.activeKeypoint = keypoint
	handle.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
	handle.ZIndex = Z_INDEX_BASE + 3
	self:_createValueEditor()
end

function GradientEditor:_addKeypoint(time)
	if #self.keypoints >= 8 then return end
	local left, right
	for _, kp in ipairs(self.keypoints) do
		if kp.Time <= time then left = kp else right = kp; break end
	end
	if not left or not right then return end -- Should not happen with >= 2 keypoints

	local newValue
	local t = (time - left.Time) / (right.Time - left.Time)
	if self.sequenceType == "Color" then newValue = left.Value:Lerp(right.Value, t)
	else newValue = left.Value + (right.Value - left.Value) * t end

	local newKeypoint = { Time = time, Value = newValue }
	table.insert(self.keypoints, newKeypoint)

	local newHandle = self:_createHandle(newKeypoint)
	self:_connectHandleEvents(newHandle, newKeypoint)
	self:_setActiveHandle(newHandle, newKeypoint)
	self:_updateAndFire(true)
end

function GradientEditor:_removeKeypoint(keypoint)
	if #self.keypoints <= 2 then return end
	local handle = self.handles[keypoint]
	if handle then handle:Destroy(); self.handles[keypoint] = nil end
	local index = table.find(self.keypoints, keypoint)
	if index then table.remove(self.keypoints, index) end

	if self.activeKeypoint == keypoint then
		self.activeKeypoint = nil; self.activeHandle = nil
		if self.valueEditor then self.valueEditor:Destroy() end
	end
	self:_updateAndFire(true)
end

function GradientEditor:_getSequenceString()
	local parts = {}
	table.sort(self.keypoints, function(a,b) return a.Time < b.Time end)
	for _, kp in ipairs(self.keypoints) do
		local str
		if self.sequenceType == "Color" then str = string.format("%.3f,%.3f,%.3f,%.3f", kp.Time, kp.Value.r, kp.Value.g, kp.Value.b)
		else str = string.format("%.3f,%.3f", kp.Time, kp.Value) end
		table.insert(parts, str)
	end
	return table.concat(parts, ";")
end

function GradientEditor:_updateGradient()
	local sequenceKeypoints = {}
	if self.sequenceType == "Color" then
		for _, kp in ipairs(self.keypoints) do table.insert(sequenceKeypoints, ColorSequenceKeypoint.new(kp.Time, kp.Value)) end
		self.uiGradient.Color = ColorSequence.new(sequenceKeypoints)
	else
		local maxValue = 0
		for _, kp in ipairs(self.keypoints) do if math.abs(kp.Value) > maxValue then maxValue = math.abs(kp.Value) end end
		maxValue = math.max(maxValue, 1)
		for _, kp in ipairs(self.keypoints) do
			local gray = (kp.Value / maxValue) * 0.5 + 0.5
			table.insert(sequenceKeypoints, ColorSequenceKeypoint.new(kp.Time, Color3.new(gray, gray, gray)))
		end
		self.uiGradient.Color = ColorSequence.new(sequenceKeypoints)
	end
end
--#endregion

function GradientEditor:destroy()
	if self.mainFrame then self.mainFrame:Destroy() end
	for k in pairs(self) do self[k] = nil end
end

return GradientEditor
