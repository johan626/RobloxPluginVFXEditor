-- TimelineManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/TimelineManager.lua

local Config = require(script.Parent.Config)

local TimelineManager = {}
TimelineManager.__index = TimelineManager

function TimelineManager.new(ui)
	local self = setmetatable({}, TimelineManager)

	self.ui = ui
	self.timeline = ui.Timeline

	-- Configuration (from shared module)
	self.PIXELS_PER_SECOND = Config.PIXELS_PER_SECOND
	self.SNAP_INTERVAL = Config.SNAP_INTERVAL
	self.TOTAL_TIME = Config.TOTAL_TIME
	self.TRACK_HEIGHT = Config.TRACK_HEIGHT
	self.LANE_PADDING = Config.LANE_PADDING

	-- State
	self.drawingMode = nil
	self.isDrawing = false
	self.startMouseX = 0
	self.ghostTrack = nil
	self.selectedTrack = nil

	self.TrackSelected = {} -- Simple signal implementation
	function self.TrackSelected:Connect(callback)
		self.callback = callback
	end
	function self.TrackSelected:Fire(...)
		if self.callback then
			self.callback(...)
		end
	end

	self:drawTimelineGrid()
	self:connectEvents()

	return self
end

function TimelineManager:drawTimelineGrid()
	for i = 0, self.TOTAL_TIME do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, 1, 1, 0)
		line.Position = UDim2.new(0, i * self.PIXELS_PER_SECOND, 0, 0)
		line.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		line.Parent = self.timeline

		local timeLabel = Instance.new("TextLabel")
		timeLabel.Size = UDim2.new(0, 50, 0, 20)
		timeLabel.Position = UDim2.new(0, i * self.PIXELS_PER_SECOND - 25, 0, -2)
		timeLabel.BackgroundTransparency = 1
		timeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		timeLabel.Text = tostring(i) .. "s"
		timeLabel.Parent = self.timeline
	end
	self.timeline.CanvasSize = UDim2.new(0, self.TOTAL_TIME * self.PIXELS_PER_SECOND, 1, 0)
end

function TimelineManager:findNextAvailableLane(newTrackStartTime, newTrackEndTime)
	local lanes = {}
	for _, child in ipairs(self.timeline:GetChildren()) do
		if child:IsA("TextButton") and child.Name == "TimelineTrack" then
			local lane = child:GetAttribute("Lane")
			if lane then
				local startTime = child.Position.X.Offset / self.PIXELS_PER_SECOND
				local endTime = startTime + (child.Size.X.Offset / self.PIXELS_PER_SECOND)
				if not (newTrackEndTime <= startTime or newTrackStartTime >= endTime) then
					lanes[lane] = true
				end
			end
		end
	end
	local nextLane = 1
	while lanes[nextLane] do nextLane = nextLane + 1 end
	return nextLane
end

function TimelineManager:makeTrackInteractive(track)
	-- Add selection outline
	local outline = Instance.new("UIStroke")
	outline.Name = "SelectionOutline"
	outline.Color = Color3.fromRGB(255, 255, 0)
	outline.Thickness = 2
	outline.Enabled = false
	outline.Parent = track

	track.MouseButton1Down:Connect(function()
		if self.selectedTrack and self.selectedTrack ~= track then
			self.selectedTrack.SelectionOutline.Enabled = false
		end
		self.selectedTrack = track
		outline.Enabled = true
		self.TrackSelected:Fire(track) -- Fire event
	end)

	-- Drag to move logic
	local dragging = false
	local dragStart = 0
	local originalPosition = 0

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position.X
			originalPosition = track.Position.X.Offset
			input:PreventSinking()
		end
	end)

	track.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position.X - dragStart
			local originalY = track.Position.Y.Offset
			track.Position = UDim2.new(0, originalPosition + delta, 0, originalY)
		end
	end)

	track.InputEnded:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			local currentPos = track.Position.X.Offset
			local originalY = track.Position.Y.Offset
			local snappedStart = math.floor((currentPos / self.PIXELS_PER_SECOND) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
			track.Position = UDim2.new(0, snappedStart * self.PIXELS_PER_SECOND, 0, originalY)
		end
	end)

	-- Resizing logic
	local function createHandle(side)
		local handle = Instance.new("Frame")
		handle.Size = UDim2.new(0, 8, 1, 0)
		handle.Position = (side == "Left") and UDim2.new(0, -4, 0, 0) or UDim2.new(1, -4, 0, 0)
		handle.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
		handle.Parent = track

		local resizing = false
		local resizeStart, originalSize, originalPos = 0, 0, 0
		handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = true
				resizeStart = input.Position.X
				originalSize = track.Size.X.Offset
				originalPos = track.Position.X.Offset
				input:PreventSinking()
			end
		end)
		handle.InputChanged:Connect(function(input)
			if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position.X - resizeStart
				if side == "Left" then
					track.Position = UDim2.new(0, originalPos + delta, 0, track.Position.Y.Offset)
					track.Size = UDim2.new(0, originalSize - delta, 0, track.Size.Y.Offset)
				else
					track.Size = UDim2.new(0, originalSize + delta, 0, track.Size.Y.Offset)
				end
			end
		end)
		handle.InputEnded:Connect(function(input)
			if resizing and input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = false
				local finalPos = track.Position.X.Offset
				local finalSize = track.Size.X.Offset
				local snappedStart = math.floor((finalPos / self.PIXELS_PER_SECOND) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
				local snappedEnd = math.floor(((finalPos + finalSize) / self.PIXELS_PER_SECOND) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
				track.Position = UDim2.new(0, snappedStart * self.PIXELS_PER_SECOND, 0, track.Position.Y.Offset)
				track.Size = UDim2.new(0, (snappedEnd - snappedStart) * self.PIXELS_PER_SECOND, 0, track.Size.Y.Offset)
			end
		end)
	end
	createHandle("Left")
	createHandle("Right")
end

function TimelineManager:connectEvents()
	local function startDrawing(componentType)
		self.drawingMode = componentType
	end

	self.ui.AddLightButton.MouseButton1Click:Connect(function() startDrawing('Light') end)
	self.ui.AddSoundButton.MouseButton1Click:Connect(function() startDrawing('Sound') end)

	self.timeline.InputBegan:Connect(function(input)
		if self.drawingMode and input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.isDrawing = true
			self.startMouseX = input.Position.X - self.timeline.AbsolutePosition.X + self.timeline.CanvasPosition.X
			self.ghostTrack = Instance.new("Frame")
			self.ghostTrack.Size = UDim2.new(0, 0, 0, self.TRACK_HEIGHT)
			self.ghostTrack.Position = UDim2.new(0, self.startMouseX, 0, 50)
			self.ghostTrack.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
			self.ghostTrack.BackgroundTransparency = 0.5
			self.ghostTrack.Parent = self.timeline
		end
	end)

	self.timeline.InputChanged:Connect(function(input)
		if self.isDrawing and input.UserInputType == Enum.UserInputType.MouseMovement then
			local currentMouseX = input.Position.X - self.timeline.AbsolutePosition.X + self.timeline.CanvasPosition.X
			local width = currentMouseX - self.startMouseX
			if width < 0 then
				self.ghostTrack.Position = UDim2.new(0, currentMouseX, 0, self.ghostTrack.Position.Y.Offset)
				self.ghostTrack.Size = UDim2.new(0, -width, 0, self.ghostTrack.Size.Y.Offset)
			else
				self.ghostTrack.Position = UDim2.new(0, self.startMouseX, 0, self.ghostTrack.Position.Y.Offset)
				self.ghostTrack.Size = UDim2.new(0, width, 0, self.ghostTrack.Size.Y.Offset)
			end
		end
	end)

	self.timeline.InputEnded:Connect(function(input)
		if self.isDrawing and input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.isDrawing = false
			if self.ghostTrack then
				local finalPos = self.ghostTrack.Position.X.Offset
				local finalSize = self.ghostTrack.Size.X.Offset

				local snappedStart = math.floor((finalPos / self.PIXELS_PER_SECOND) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
				local snappedEnd = math.floor(((finalPos + finalSize) / self.PIXELS_PER_SECOND) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL

				local pixelStart = snappedStart * self.PIXELS_PER_SECOND
				local pixelWidth = (snappedEnd - snappedStart) * self.PIXELS_PER_SECOND

				if pixelWidth > 0 then
					local nextLane = self:findNextAvailableLane(snappedStart, snappedEnd)
					local yPos = (nextLane - 1) * (self.TRACK_HEIGHT + self.LANE_PADDING) + self.LANE_PADDING

					local newTrack = Instance.new("TextButton")
					newTrack.Name = "TimelineTrack"
					newTrack.Text = self.drawingMode or ""
					newTrack.Size = UDim2.new(0, pixelWidth, 0, self.TRACK_HEIGHT)
					newTrack.Position = UDim2.new(0, pixelStart, 0, yPos)

					if self.drawingMode == 'Light' then
						newTrack.BackgroundColor3 = Color3.fromRGB(200, 180, 80)
						newTrack:SetAttribute("ComponentType", "Light")
						newTrack:SetAttribute("Enabled", true)
						newTrack:SetAttribute("Brightness", 1)
						newTrack:SetAttribute("Color", Color3.fromRGB(255, 255, 255))
						newTrack:SetAttribute("Range", 8)
						newTrack:SetAttribute("Lane", nextLane)
					elseif self.drawingMode == 'Sound' then
						newTrack.BackgroundColor3 = Color3.fromRGB(80, 180, 200)
						newTrack:SetAttribute("ComponentType", "Sound")
						newTrack:SetAttribute("SoundId", "rbxassetid://")
						newTrack:SetAttribute("Volume", 0.5)
						newTrack:SetAttribute("PlaybackSpeed", 1)
						newTrack:SetAttribute("Lane", nextLane)
					end

					newTrack.Parent = self.timeline
					self:makeTrackInteractive(newTrack)
				end

				self.ghostTrack:Destroy()
			end
			self.drawingMode = nil
		end
	end)
end

return TimelineManager
