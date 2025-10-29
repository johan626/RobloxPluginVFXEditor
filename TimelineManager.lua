-- TimelineManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/TimelineManager.lua

local Config = require(script.Parent.Config)

local TimelineManager = {}
TimelineManager.__index = TimelineManager

function TimelineManager.new(ui, playhead) -- Pass playhead
	local self = setmetatable({}, TimelineManager)

	self.ui = ui
	self.timeline = ui.Timeline
	self.playhead = playhead -- Store playhead

	-- Configuration
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
	self.copiedTrackData = nil

	-- Zoom & Pan State
	self.zoom = 1 -- 1 = 100% zoom
	self.isPanning = false

	self.TrackSelected = {} -- Simple signal implementation
	function self.TrackSelected:Connect(callback)
		table.insert(self, callback)
	end
	function self.TrackSelected:Fire(...)
		for _, callback in ipairs(self) do
			callback(...)
		end
	end

	self:drawTimelineGrid()
	self:connectEvents()

	return self
end

function TimelineManager:clearTimeline()
	for _, child in ipairs(self.timeline:GetChildren()) do
		if child.Name == "TimelineTrack" then
			child:Destroy()
		end
	end
end

function TimelineManager:redrawTimeline()
	-- Clear existing grid and tracks
	for _, child in ipairs(self.timeline:GetChildren()) do
		if child.Name == "TimelineGridLine" or child.Name == "TimelineTimeLabel" then
			child:Destroy()
		end
	end

	-- Redraw grid with new zoom
	self:drawTimelineGrid()

	-- Update all tracks with new zoom
	for _, child in ipairs(self.timeline:GetChildren()) do
		if child:IsA("TextButton") and child.Name == "TimelineTrack" then
			local startTime = child:GetAttribute("StartTime")
			local duration = child:GetAttribute("Duration")

			if startTime and duration then
				child.Position = UDim2.new(0, startTime * self.PIXELS_PER_SECOND * self.zoom, 0, child.Position.Y.Offset)
				child.Size = UDim2.new(0, duration * self.PIXELS_PER_SECOND * self.zoom, 0, child.Size.Y.Offset)
			end
		end
	end
end


function TimelineManager:drawTimelineGrid()
	local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom
	self.timeline.CanvasSize = UDim2.new(0, self.TOTAL_TIME * zoomedPixelsPerSecond, 1, 0)

	for i = 0, self.TOTAL_TIME do
		local line = Instance.new("Frame")
		line.Name = "TimelineGridLine"
		line.Size = UDim2.new(0, 1, 1, 0)
		line.Position = UDim2.new(0, i * zoomedPixelsPerSecond, 0, 0)
		line.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		line.Parent = self.timeline

		local timeLabel = Instance.new("TextLabel")
		timeLabel.Name = "TimelineTimeLabel"
		timeLabel.Size = UDim2.new(0, 50, 0, 20)
		timeLabel.Position = UDim2.new(0, i * zoomedPixelsPerSecond - 25, 0, -2)
		timeLabel.BackgroundTransparency = 1
		timeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		timeLabel.Text = tostring(i) .. "s"
		timeLabel.Parent = self.timeline
	end
end

function TimelineManager:findNextAvailableLane(newTrackStartTime, newTrackEndTime)
	local lanes = {}
	for _, child in ipairs(self.timeline:GetChildren()) do
		if child:IsA("TextButton") and child.Name == "TimelineTrack" then
			local lane = child:GetAttribute("Lane")
			if lane then
				local startTime = child:GetAttribute("StartTime")
				local duration = child:GetAttribute("Duration")
				local endTime = startTime + duration
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

function TimelineManager:createTrack(trackData)
	local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom

	local nextLane = self:findNextAvailableLane(trackData.StartTime, trackData.StartTime + trackData.Duration)
	local yPos = (nextLane - 1) * (self.TRACK_HEIGHT + self.LANE_PADDING) + self.LANE_PADDING

	local newTrack = Instance.new("TextButton")
	newTrack.Name = "TimelineTrack"
	newTrack.Text = trackData.ComponentType or ""
	newTrack.Size = UDim2.new(0, trackData.Duration * zoomedPixelsPerSecond, 0, self.TRACK_HEIGHT)
	newTrack.Position = UDim2.new(0, trackData.StartTime * zoomedPixelsPerSecond, 0, yPos)
	newTrack.Active = true -- For sinking input

	if trackData.ComponentType == 'Light' then
		newTrack.BackgroundColor3 = Config.TrackColors.Light
	elseif trackData.ComponentType == 'Sound' then
		newTrack.BackgroundColor3 = Config.TrackColors.Sound
	elseif trackData.ComponentType == 'Particle' then
		newTrack.BackgroundColor3 = Config.TrackColors.Particle
	end

	-- Store all data as attributes
	for key, value in pairs(trackData) do
		newTrack:SetAttribute(key, value)
	end
	newTrack:SetAttribute("Lane", nextLane)

	newTrack.Parent = self.timeline
	self:makeTrackInteractive(newTrack)
	return newTrack
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
		self.TrackSelected:Fire(track)
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
			local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom
			local currentPos = track.Position.X.Offset
			local originalY = track.Position.Y.Offset

			local snappedStart = math.floor((currentPos / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
			track.Position = UDim2.new(0, snappedStart * zoomedPixelsPerSecond, 0, originalY)
			track:SetAttribute("StartTime", snappedStart)
		end
	end)

	-- Resizing logic
	local function createHandle(side)
		local handle = Instance.new("Frame")
		handle.Size = UDim2.new(0, 8, 1, 0)
		handle.Position = (side == "Left") and UDim2.new(0, -4, 0, 0) or UDim2.new(1, -4, 0, 0)
		handle.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
		handle.Parent = track
		handle.Active = true -- For sinking input

		local resizing = false
		local resizeStart, originalSize, originalPos = 0, 0, 0
		handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = true
				resizeStart = input.Position.X
				originalSize = track.Size.X.Offset
				originalPos = track.Position.X.Offset
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
				local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom
				local finalPos = track.Position.X.Offset
				local finalSize = track.Size.X.Offset

				local snappedStart = math.floor((finalPos / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
				local snappedEnd = math.floor(((finalPos + finalSize) / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL

				track.Position = UDim2.new(0, snappedStart * zoomedPixelsPerSecond, 0, track.Position.Y.Offset)
				track.Size = UDim2.new(0, (snappedEnd - snappedStart) * zoomedPixelsPerSecond, 0, track.Size.Y.Offset)
				track:SetAttribute("StartTime", snappedStart)
				track:SetAttribute("Duration", snappedEnd - snappedStart)
			end
		end)
	end
	createHandle("Left")
	createHandle("Right")
end


function TimelineManager:connectEvents()
	local UserInputService = game:GetService("UserInputService")

	local function startDrawing(componentType)
		self.drawingMode = componentType
	end

	self.ui.AddLightButton.MouseButton1Click:Connect(function() startDrawing('Light') end)
	self.ui.AddSoundButton.MouseButton1Click:Connect(function() startDrawing('Sound') end)
	self.ui.AddParticleButton.MouseButton1Click:Connect(function() startDrawing('Particle') end)

	-- Drawing logic
	local inputBeganConnection1
	inputBeganConnection1 = self.timeline.InputBegan:Connect(function(input)
		if self.drawingMode and input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.isDrawing = true
			local mouseX = input.Position.X - self.timeline.AbsolutePosition.X
			self.startMouseX = mouseX + self.timeline.CanvasPosition.X
			self.ghostTrack = Instance.new("Frame")
			self.ghostTrack.Size = UDim2.new(0, 0, 0, self.TRACK_HEIGHT)
			self.ghostTrack.Position = UDim2.new(0, self.startMouseX, 0, 50)
			self.ghostTrack.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
			self.ghostTrack.BackgroundTransparency = 0.5
			self.ghostTrack.Parent = self.timeline
		end
	end)

	local inputChangedConnection1
	inputChangedConnection1 = self.timeline.InputChanged:Connect(function(input)
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

	local inputEndedConnection1
	inputEndedConnection1 = self.timeline.InputEnded:Connect(function(input)
		if self.isDrawing and input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.isDrawing = false
			if self.ghostTrack then
				local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom
				local finalPos = self.ghostTrack.Position.X.Offset
				local finalSize = self.ghostTrack.Size.X.Offset

				local snappedStart = math.floor((finalPos / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
				local snappedDuration = math.floor((finalSize / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL

				if snappedDuration > 0 then
					local trackData = {
						ComponentType = self.drawingMode,
						StartTime = snappedStart,
						Duration = snappedDuration,
					}
					-- Add default attributes based on type
					if self.drawingMode == 'Light' then
						trackData.Enabled = true
						trackData.Brightness = 1
						trackData.Color = Color3.fromRGB(255, 255, 255)
						trackData.Range = 8
					elseif self.drawingMode == 'Sound' then
						trackData.SoundId = "rbxassetid://"
						trackData.Volume = 0.5
						trackData.PlaybackSpeed = 1
					elseif self.drawingMode == 'Particle' then
						trackData.Enabled = true
						trackData.Rate = 20
						trackData.Lifetime = "1 2" -- NumberRange
						trackData.Size = "0,1;1,0" -- NumberSequence
						trackData.Color = "0,1,1,1;1,1,1,1" -- ColorSequence
						trackData.SpreadAngle = 360
						trackData.Rotation = "0 360" -- NumberRange
						trackData.Speed = "5 10" -- NumberRange
					end
					self:createTrack(trackData)
				end
				self.ghostTrack:Destroy()
			end
			self.drawingMode = nil
		end
	end)

	-- Copy/Paste logic
	local inputBeganConnection2
	inputBeganConnection2 = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then return end
		local isCtrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

		if isCtrlDown and input.KeyCode == Enum.KeyCode.C then
			if self.selectedTrack then
				local data = {}
				for _, attr in ipairs(self.selectedTrack:GetAttributes()) do
					data[attr] = self.selectedTrack:GetAttribute(attr)
				end
				self.copiedTrackData = data
				print("Track copied!")
			end
		end

		if isCtrlDown and input.KeyCode == Enum.KeyCode.V then
			if self.copiedTrackData then
				local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom
				-- Paste at playhead position
				local playheadTime = self.playhead.Position.X.Offset / zoomedPixelsPerSecond
				local newData = {}
				for k, v in pairs(self.copiedTrackData) do newData[k] = v end
				newData.StartTime = playheadTime
				self:createTrack(newData)
				print("Track pasted!")
			end
		end
	end)

	-- Zoom & Pan logic
	local lastPanPosition
	local inputBeganConnection3
	inputBeganConnection3 = self.timeline.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then -- Right mouse for pan
			self.isPanning = true
			lastPanPosition = input.Position
		end
	end)

	local inputChangedConnection2
	inputChangedConnection2 = self.timeline.InputChanged:Connect(function(input)
		if self.isPanning and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - lastPanPosition
			lastPanPosition = input.Position
			local currentPos = self.timeline.CanvasPosition
			self.timeline.CanvasPosition = Vector2.new(currentPos.X - delta.X, currentPos.Y)
		end
	end)

	local inputEndedConnection2
	inputEndedConnection2 = self.timeline.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self.isPanning = false
		end
	end)

	local inputChangedConnection3
	inputChangedConnection3 = UserInputService.InputChanged:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local isCtrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			if isCtrlDown then
				-- Calculate mouse position relative to timeline content
				local mousePos = UserInputService:GetMouseLocation()
				local relativeMouseX = mousePos.X - self.timeline.AbsolutePosition.X + self.timeline.CanvasPosition.X
				local timeAtMouse = relativeMouseX / (self.PIXELS_PER_SECOND * self.zoom)

				-- Apply zoom
				self.zoom = math.clamp(self.zoom - input.Position.Z * 0.2, 0.2, 10)
				self:redrawTimeline()

				-- Adjust canvas position to keep the point under the mouse stationary
				local newMouseX = timeAtMouse * (self.PIXELS_PER_SECOND * self.zoom)
				self.timeline.CanvasPosition = Vector2.new(newMouseX - (mousePos.X - self.timeline.AbsolutePosition.X), self.timeline.CanvasPosition.Y)
			end
		end
	end)
end

return TimelineManager
