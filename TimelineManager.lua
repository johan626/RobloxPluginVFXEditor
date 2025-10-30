-- TimelineManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/TimelineManager.lua

local Config = require(script.Parent.Config)
local UserInputService = game:GetService("UserInputService")

local TimelineManager = {}
TimelineManager.__index = TimelineManager

function TimelineManager.new(ui, playhead, historyManager)
	local self = setmetatable({}, TimelineManager)

	self.ui = ui
	self.timeline = ui.Timeline
	self.playhead = playhead
	self.historyManager = historyManager

	self.PIXELS_PER_SECOND = Config.PIXELS_PER_SECOND
	self.SNAP_INTERVAL = Config.SNAP_INTERVAL
	self.TOTAL_TIME = Config.TOTAL_TIME
	self.TRACK_HEIGHT = Config.TRACK_HEIGHT
	self.LANE_PADDING = Config.LANE_PADDING
	self.PLAYHEAD_SNAP_DISTANCE = Config.PLAYHEAD_SNAP_DISTANCE

	self.drawingMode = nil
	self.isDrawing = false
	self.startMouseX = 0
	self.ghostTrack = nil
	self.selectedTracks = {}
	self.copiedTracksData = nil
	self.pasteTime = 0
	self.zoom = 1

	self.TrackSelected = {}
	function self.TrackSelected:Connect(callback) table.insert(self, callback) end
	function self.TrackSelected:Fire(...) for _, cb in ipairs(self) do cb(...) end end

	self.TrackDeleted = {}
	function self.TrackDeleted:Connect(callback) table.insert(self, callback) end
	function self.TrackDeleted:Fire(...) for _, cb in ipairs(self) do cb(...) end end

	self:drawTimelineGrid()
	self:connectEvents()

	return self
end

-- INTERNAL, NON-HISTORY ACTION: Create track UI directly
function TimelineManager:_createTrackUI(trackData)
	local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom
	local startTime = trackData.StartTime or 0
	local duration = trackData.Duration or 1
	local nextLane = self:findNextAvailableLane(startTime, startTime + duration)
	local yPos = (nextLane - 1) * (self.TRACK_HEIGHT + self.LANE_PADDING) + self.LANE_PADDING

	local newTrack = Instance.new("TextButton")
	newTrack.Name = "TimelineTrack"
	newTrack.Text = trackData.ComponentType or ""
	newTrack.Size = UDim2.new(0, duration * zoomedPixelsPerSecond, 0, self.TRACK_HEIGHT)
	newTrack.Position = UDim2.new(0, startTime * zoomedPixelsPerSecond, 0, yPos)
	newTrack.Active = true

	local componentType = trackData.ComponentType
	if Config.TrackColors[componentType] then
		newTrack.BackgroundColor3 = Config.TrackColors[componentType]
	end

	for key, value in pairs(trackData) do
		newTrack:SetAttribute(key, value)
	end
	newTrack:SetAttribute("Lane", nextLane)

	newTrack.Parent = self.timeline
	self:makeTrackInteractive(newTrack)
	return newTrack
end

-- PUBLIC, HISTORY-LOGGED ACTION: Create tracks
function TimelineManager:createTracks(tracksData)
	local createdTracks = {}
	local action = {
		execute = function()
			createdTracks = {} -- Clear previous references on redo
			for _, data in ipairs(tracksData) do
				local track = self:_createTrackUI(data)
				table.insert(createdTracks, track)
			end
		end,
		undo = function()
			for _, track in ipairs(createdTracks) do
				track:Destroy()
			end
		end
	}
	self.historyManager:registerAction(action)
end

-- PUBLIC, HISTORY-LOGGED ACTION: Delete selected tracks
function TimelineManager:deleteSelectedTracks()
	if next(self.selectedTracks) == nil then return end

	local deletedTracksData = {}
	for track, _ in pairs(self.selectedTracks) do
		local data = {}
		for name, value in pairs(track:GetAttributes()) do data[name] = value end
		table.insert(deletedTracksData, data)
	end

	local action = {
		execute = function()
			for track in pairs(self.selectedTracks) do
				track:Destroy()
			end
			self:deselectAllTracks()
			self.TrackDeleted:Fire()
		end,
		undo = function()
			for _, data in ipairs(deletedTracksData) do
				self:_createTrackUI(data)
			end
		end
	}
	self.historyManager:registerAction(action)
end


-- NON-HISTORY ACTIONS
function TimelineManager:deselectAllTracks()
	for track in pairs(self.selectedTracks) do
		if track and track.Parent then
			track:FindFirstChild("SelectionOutline").Enabled = false
		end
	end
	self.selectedTracks = {}
end

function TimelineManager:addTrackToSelection(track)
	if self.selectedTracks[track] then return end
	self.selectedTracks[track] = true
	track:FindFirstChild("SelectionOutline").Enabled = true
end

function TimelineManager:removeTrackFromSelection(track)
	if not self.selectedTracks[track] then return end
	self.selectedTracks[track] = nil
	track:FindFirstChild("SelectionOutline").Enabled = false
end

function TimelineManager:clearTimeline()
	for _, child in ipairs(self.timeline:GetChildren()) do
		if child.Name == "TimelineTrack" then
			child:Destroy()
		end
	end
	self:deselectAllTracks()
	self.TrackSelected:Fire({})
	self.ui.ContextMenu.Visible = false
end

function TimelineManager:copySelectedTracks()
	if next(self.selectedTracks) == nil then return end
	self.copiedTracksData = {}
	for track in pairs(self.selectedTracks) do
		local data = {}
		for name, value in pairs(track:GetAttributes()) do
			data[name] = value
		end
		table.insert(self.copiedTracksData, data)
	end
end

function TimelineManager:pasteTracksAtTime(time)
	if not self.copiedTracksData or #self.copiedTracksData == 0 then return end

	local firstStartTime = math.huge
	for _, data in ipairs(self.copiedTracksData) do
		if data.StartTime < firstStartTime then
			firstStartTime = data.StartTime
		end
	end

	local tracksToCreate = {}
	for _, data in ipairs(self.copiedTracksData) do
		local newData = {}
		for k, v in pairs(data) do newData[k] = v end
		newData.StartTime = time + (data.StartTime - firstStartTime)
		table.insert(tracksToCreate, newData)
	end

	self:createTracks(tracksToCreate)
end

function TimelineManager:showContextMenu(mouseX, mouseY, options)
	local menu = self.ui.ContextMenu
	menu.Position = UDim2.new(0, mouseX, 0, mouseY)
	menu.CopyButton.Visible = options.showCopy or false
	menu.PasteButton.Visible = options.showPaste or false
	menu.Visible = true
end

function TimelineManager:redrawTimeline()
	for _, child in ipairs(self.timeline:GetChildren()) do
		if child.Name == "TimelineGridLine" or child.Name == "TimelineTimeLabel" then
			child:Destroy()
		end
	end
	self:drawTimelineGrid()
	for _, child in ipairs(self.timeline:GetChildren()) do
		if child:IsA("TextButton") and child.Name == "TimelineTrack" then
			local startTime, duration = child:GetAttribute("StartTime"), child:GetAttribute("Duration")
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

function TimelineManager:findNextAvailableLane(startTime, endTime)
	local lanes = {}
	for _, child in ipairs(self.timeline:GetChildren()) do
		if child:IsA("TextButton") and child.Name == "TimelineTrack" then
			local lane, s, d = child:GetAttribute("Lane"), child:GetAttribute("StartTime"), child:GetAttribute("Duration")
			if lane and s and d then
				if not (endTime <= s or startTime >= s + d) then
					lanes[lane] = true
				end
			end
		end
	end
	local nextLane = 1
	while lanes[nextLane] do nextLane = nextLane + 1 end
	return nextLane
end

function TimelineManager:addDefaultAttributes(trackData)
	local c = trackData.ComponentType
	if c == 'Light' then trackData.Enabled=true; trackData.Brightness=1; trackData.Color=Color3.fromRGB(255,255,255); trackData.Range=8; trackData.Shadows=false
	elseif c == 'SpotLight' or c == 'SurfaceLight' then trackData.Enabled=true; trackData.Brightness=1; trackData.Color=Color3.fromRGB(255,255,255); trackData.Range=8; trackData.Angle=60; trackData.Face="Front"; trackData.Shadows=false
	elseif c == 'Beam' then trackData.Enabled=true; trackData.Color="0,1,1,1;1,1,1,1"; trackData.Width0=1; trackData.Width1=1; trackData.Attachment0Offset="0,2,0"; trackData.Attachment1Offset="0,10,0"; trackData.Texture=""; trackData.CurveSize0=0; trackData.CurveSize1=0; trackData.FaceCamera=false; trackData.LightEmission=0; trackData.LightInfluence=1; trackData.Segments=10; trackData.TextureLength=1; trackData.TextureMode="Stretch"; trackData.TextureSpeed=1; trackData.Transparency="0,0;1,0"; trackData.ZOffset=0
	elseif c == 'Trail' then trackData.Enabled=true; trackData.Color="0,1,1,1;1,1,1,1"; trackData.Texture=""; trackData.Lifetime=1; trackData.WidthScale="0,1;1,1"; trackData.FaceCamera=false; trackData.LightEmission=0; trackData.LightInfluence=1; trackData.MinLength=0; trackData.MaxLength=0; trackData.TextureLength=1; trackData.TextureMode="Stretch"; trackData.Transparency="0,0;1,0"; trackData.StartPosition="0,0,0"; trackData.EndPosition="10,0,0"
	elseif c == 'Sound' then trackData.SoundId="rbxassetid://"; trackData.Volume=0.5; trackData.PlaybackSpeed=1; trackData.TimePosition=0; trackData.Looped=false; trackData.RollOffMode="Inverse"; trackData.RollOffMinDistance=10; trackData.RollOffMaxDistance=100
	elseif c == 'Particle' then trackData.Enabled=true; trackData.Rate=20; trackData.Lifetime="1 2"; trackData.Size="0,1;1,0"; trackData.Color="0,1,1,1;1,1,1,1"; trackData.SpreadAngle="360 360"; trackData.Texture="rbxasset://textures/particles/sparkles_main.dds"; trackData.Rotation="0 360"; trackData.Speed="5 10"; trackData.Acceleration="0,0,0"; trackData.Drag=0; trackData.EmissionDirection="Top"; trackData.LightEmission=0; trackData.LightInfluence=1; trackData.Orientation="FacingCamera"; trackData.RotSpeed="0 0"; trackData.Squash="0,0;1,0"; trackData.TimeScale=1; trackData.Transparency="0,0;1,0"; trackData.ZOffset=0 end
end

function TimelineManager:makeTrackInteractive(track)
	local outline = Instance.new("UIStroke"); outline.Name = "SelectionOutline"; outline.Color = Color3.fromRGB(255, 255, 0); outline.Thickness = 2; outline.Enabled = false; outline.Parent = track

	track.MouseButton1Down:Connect(function()
		self.ui.ContextMenu.Visible = false
		local isCtrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if isCtrlDown then
			if self.selectedTracks[track] then self:removeTrackFromSelection(track) else self:addTrackToSelection(track) end
		else
			if not self.selectedTracks[track] then self:deselectAllTracks(); self:addTrackToSelection(track) end
		end
		self.TrackSelected:Fire(self.selectedTracks)
	end)

	track.MouseButton2Down:Connect(function(x, y)
		if not self.selectedTracks[track] then self:deselectAllTracks(); self:addTrackToSelection(track); self.TrackSelected:Fire(self.selectedTracks) end
		self:showContextMenu(x, y, {showCopy = true})
	end)

	local dragging, dragStart, originalStates = false, 0, {}
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position.X
			originalStates = {}
			for t in pairs(self.selectedTracks) do
				originalStates[t] = {Position = t.Position, StartTime = t:GetAttribute("StartTime")}
			end
		end
	end)

	track.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position.X - dragStart
			for t, state in pairs(originalStates) do
				t.Position = UDim2.new(0, state.Position.X.Offset + delta, 0, t.Position.Y.Offset)
			end
			if math.abs(track.Position.X.Offset - self.playhead.Position.X.Offset) < self.PLAYHEAD_SNAP_DISTANCE then
				self.playhead.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
			else
				self.playhead.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			end
		end
	end)

	track.InputEnded:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			self.playhead.BackgroundColor3 = Color3.fromRGB(255, 50, 50)

			local finalStates = {}
			local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom
			local primaryTrackPos = track.Position.X.Offset
			local finalPrimaryPos

			if math.abs(primaryTrackPos - self.playhead.Position.X.Offset) < self.PLAYHEAD_SNAP_DISTANCE then
				finalPrimaryPos = self.playhead.Position.X.Offset
			else
				local snappedStart = math.floor((primaryTrackPos / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
				finalPrimaryPos = snappedStart * zoomedPixelsPerSecond
			end

			local finalDelta = finalPrimaryPos - originalStates[track].Position.X.Offset
			for t, state in pairs(originalStates) do
				local newPos = state.Position.X.Offset + finalDelta
				finalStates[t] = {Position = UDim2.new(0, newPos, 0, t.Position.Y.Offset), StartTime = newPos / zoomedPixelsPerSecond}
			end

			local action = {
				execute = function() for t, s in pairs(finalStates) do t.Position = s.Position; t:SetAttribute("StartTime", s.StartTime) end end,
				undo = function() for t, s in pairs(originalStates) do t.Position = s.Position; t:SetAttribute("StartTime", s.StartTime) end end
			}
			self.historyManager:registerAction(action)
		end
	end)

	local function createHandle(side)
		local handle = Instance.new("Frame"); handle.Size = UDim2.new(0, 8, 1, 0); handle.Position = (side == "Left") and UDim2.new(0, -4, 0, 0) or UDim2.new(1, -4, 0, 0); handle.BackgroundColor3 = Color3.fromRGB(255, 255, 0); handle.Parent = track; handle.Active = true
		local resizing, resizeStart, originalSize, originalPos = false, 0, 0, 0

		handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = true; resizeStart = input.Position.X; originalSize = track.Size.X.Offset; originalPos = track.Position.X.Offset
			end
		end)

		handle.InputChanged:Connect(function(input)
			if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position.X - resizeStart
				local edgePos
				if side == "Left" then
					edgePos = originalPos + delta
					track.Position = UDim2.new(0, edgePos, 0, track.Position.Y.Offset)
					track.Size = UDim2.new(0, originalSize - delta, 0, track.Size.Y.Offset)
				else
					edgePos = originalPos + originalSize + delta
					track.Size = UDim2.new(0, originalSize + delta, 0, track.Size.Y.Offset)
				end
				if math.abs(edgePos - self.playhead.Position.X.Offset) < self.PLAYHEAD_SNAP_DISTANCE then self.playhead.BackgroundColor3 = Color3.fromRGB(255, 255, 0) else self.playhead.BackgroundColor3 = Color3.fromRGB(255, 50, 50) end
			end
		end)

		handle.InputEnded:Connect(function(input)
			if resizing and input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = false
				self.playhead.BackgroundColor3 = Color3.fromRGB(255, 50, 50)

				local originalState = {Position = UDim2.new(0, originalPos, 0, track.Position.Y.Offset), Size = UDim2.new(0, originalSize, 0, track.Size.Y.Offset), StartTime = track:GetAttribute("StartTime"), Duration = track:GetAttribute("Duration")}
				local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom
				local finalPos, finalSize = track.Position.X.Offset, track.Size.X.Offset

				if side == "Left" and math.abs(finalPos - self.playhead.Position.X.Offset) < self.PLAYHEAD_SNAP_DISTANCE then
					local oldEndTime = (originalPos + originalSize) / zoomedPixelsPerSecond
					finalPos = self.playhead.Position.X.Offset
					track:SetAttribute("Duration", oldEndTime - (finalPos / zoomedPixelsPerSecond))
				elseif side == "Right" and math.abs(finalPos + finalSize - self.playhead.Position.X.Offset) < self.PLAYHEAD_SNAP_DISTANCE then
					finalSize = self.playhead.Position.X.Offset - finalPos
					track:SetAttribute("Duration", finalSize / zoomedPixelsPerSecond)
				else
					local snappedStart = math.floor((finalPos / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
					local snappedEnd = math.floor(((finalPos + finalSize) / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
					track:SetAttribute("StartTime", snappedStart)
					track:SetAttribute("Duration", snappedEnd - snappedStart)
				end

				self:redrawTimeline()

				local finalState = {Position = track.Position, Size = track.Size, StartTime = track:GetAttribute("StartTime"), Duration = track:GetAttribute("Duration")}
				local action = {
					execute = function() track.Position = finalState.Position; track.Size = finalState.Size; track:SetAttribute("StartTime", finalState.StartTime); track:SetAttribute("Duration", finalState.Duration) end,
					undo = function() track.Position = originalState.Position; track.Size = originalState.Size; track:SetAttribute("StartTime", originalState.StartTime); track:SetAttribute("Duration", originalState.Duration) end
				}
				self.historyManager:registerAction(action)
			end
		end)
	end
	createHandle("Left"); createHandle("Right")
end

function TimelineManager:connectEvents()
	local function startDrawing(componentType) self.drawingMode = componentType end
	self.ui.LightButtons.DrawButton.MouseButton1Click:Connect(function() startDrawing('Light') end)
	self.ui.SoundButtons.DrawButton.MouseButton1Click:Connect(function() startDrawing('Sound') end)
	self.ui.ParticleButtons.DrawButton.MouseButton1Click:Connect(function() startDrawing('Particle') end)
	self.ui.SpotLightButtons.DrawButton.MouseButton1Click:Connect(function() startDrawing('SpotLight') end)
	self.ui.SurfaceLightButtons.DrawButton.MouseButton1Click:Connect(function() startDrawing('SurfaceLight') end)
	self.ui.BeamButtons.DrawButton.MouseButton1Click:Connect(function() startDrawing('Beam') end)
	self.ui.TrailButtons.DrawButton.MouseButton1Click:Connect(function() startDrawing('Trail') end)

	local function addAtPlayhead(componentType)
		local playheadTime = self.playhead.Position.X.Offset / (self.PIXELS_PER_SECOND * self.zoom)
		local trackData = {ComponentType = componentType, StartTime = playheadTime, Duration = 1}
		self:addDefaultAttributes(trackData)
		self:createTracks({trackData})
	end
	self.ui.LightButtons.AddAtPlayheadButton.MouseButton1Click:Connect(function() addAtPlayhead('Light') end)
	self.ui.SoundButtons.AddAtPlayheadButton.MouseButton1Click:Connect(function() addAtPlayhead('Sound') end)
	self.ui.ParticleButtons.AddAtPlayheadButton.MouseButton1Click:Connect(function() addAtPlayhead('Particle') end)
	self.ui.SpotLightButtons.AddAtPlayheadButton.MouseButton1Click:Connect(function() addAtPlayhead('SpotLight') end)
	self.ui.SurfaceLightButtons.AddAtPlayheadButton.MouseButton1Click:Connect(function() addAtPlayhead('SurfaceLight') end)
	self.ui.BeamButtons.AddAtPlayheadButton.MouseButton1Click:Connect(function() addAtPlayhead('Beam') end)
	self.ui.TrailButtons.AddAtPlayheadButton.MouseButton1Click:Connect(function() addAtPlayhead('Trail') end)

	self.ui.CopyButton.MouseButton1Click:Connect(function() self:copySelectedTracks() end)
	self.ui.PasteButton.MouseButton1Click:Connect(function() self:pasteTracksAtTime(self.pasteTime) end)

	self.timeline.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:deselectAllTracks()
			self.TrackSelected:Fire({})
		end
		self.ui.ContextMenu.Visible = false
		if input.Position then -- Guard against non-mouse inputs
			if self.drawingMode and input.UserInputType == Enum.UserInputType.MouseButton1 then
				self.isDrawing = true
				local mouseX = input.Position.X - self.timeline.AbsolutePosition.X
				self.startMouseX = mouseX + self.timeline.CanvasPosition.X
				self.ghostTrack = Instance.new("Frame"); self.ghostTrack.Size = UDim2.new(0, 0, 0, self.TRACK_HEIGHT); self.ghostTrack.Position = UDim2.new(0, self.startMouseX, 0, 50); self.ghostTrack.BackgroundColor3 = Color3.fromRGB(100, 150, 255); self.ghostTrack.BackgroundTransparency = 0.5; self.ghostTrack.Parent = self.timeline
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				local mouseX, mouseY = input.Position.X, input.Position.Y
				self:showContextMenu(mouseX, mouseY, {showPaste = self.copiedTracksData ~= nil})
				local relativeMouseX = input.Position.X - self.timeline.AbsolutePosition.X + self.timeline.CanvasPosition.X
				self.pasteTime = relativeMouseX / (self.PIXELS_PER_SECOND * self.zoom)
			end
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
				local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom
				local finalPos, finalSize = self.ghostTrack.Position.X.Offset, self.ghostTrack.Size.X.Offset
				local snappedStart = math.floor((finalPos / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
				local snappedDuration = math.floor((finalSize / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
				if snappedDuration > 0 then
					local trackData = {ComponentType = self.drawingMode, StartTime = snappedStart, Duration = snappedDuration}
					self:addDefaultAttributes(trackData)
					self:createTracks({trackData})
				end
				self.ghostTrack:Destroy()
			end
			self.drawingMode = nil
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.Delete then
			self:deleteSelectedTracks()
		end
	end)

	UserInputService.InputChanged:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local isCtrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			if isCtrlDown then
				local mousePos = UserInputService:GetMouseLocation()
				local relativeMouseX = mousePos.X - self.timeline.AbsolutePosition.X + self.timeline.CanvasPosition.X
				local timeAtMouse = relativeMouseX / (self.PIXELS_PER_SECOND * self.zoom)
				self.zoom = math.clamp(self.zoom - input.Position.Z * 0.2, 0.2, 10)
				self:redrawTimeline()
				local newMouseX = timeAtMouse * (self.PIXELS_PER_SECOND * self.zoom)
				self.timeline.CanvasPosition = Vector2.new(newMouseX - (mousePos.X - self.timeline.AbsolutePosition.X), self.timeline.CanvasPosition.Y)
			end
		end
	end)
end

return TimelineManager
