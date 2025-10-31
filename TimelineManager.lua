-- TimelineManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/TimelineManager.lua

local Config = require(script.Parent.Config)
local UserInputService = game:GetService("UserInputService")
local UIManager = require(script.Parent.UIManager)
local TrackInteractor = require(script.Parent.TrackInteractor)

local LOCK_ICON_UNLOCKED = "rbxasset://textures/StudioShared/unlocked-light.png"
local LOCK_ICON_LOCKED = "rbxasset://textures/StudioShared/locked-light.png"


local ParticlePresets = {
	Fire = {
		TrackLabel = "Fire",
		Texture = "rbxasset://textures/particles/fire_sparks_main.dds",
		Color = "0,1,1,1;0.5,1,0.5,0;1,0.5,0,0",
		Size = "0,0;0.25,1;1,0",
		Lifetime = "0.5 1",
		Rotation = "0 360",
		RotSpeed = "-180 180",
		Speed = "2 4",
		Acceleration = "0,5,0",
		LightEmission = 1
	},
	Smoke = {
		TrackLabel = "Smoke",
		Texture = "rbxassetid://160492415", -- A common smoke texture
		Color = "0,0.8,0.8,0.8;1,0.1,0.1,0.1",
		Transparency = "0,0.8;0.5,0.2;1,0.9",
		Size = "0,0;0.5,2;1,5",
		Lifetime = "3 5",
		Rotation = "0 360",
		RotSpeed = "-20 20",
		Speed = "1 2",
		Acceleration = "0,2,0",
		Drag = 0.1
	},
	Explosion = {
		TrackLabel = "Explosion",
		Texture = "rbxassetid://287992173", -- Spark/burst texture
		Color = "0,1,1,1;0.1,1,0.8,0;0.8,1,0.2,0;1,0.5,0.5,0.5",
		Transparency = "0,0;0.5,0.5;1,1",
		Size = "0,0;0.1,5;1,10",
		Lifetime = "0.3 0.6",
		Speed = "25 40",
		SpreadAngle = "360 360",
		Drag = 5,
		LightEmission = 1,
		Rate = 500 -- Emit a large burst
	}
}

local TimelineManager = {}
TimelineManager.__index = TimelineManager

function TimelineManager.new(ui, playhead, historyManager)
	local self = setmetatable({}, TimelineManager)

	self.ui = ui
	self.timeline = ui.Timeline
	self.playhead = playhead
	self.historyManager = historyManager
	self.trackInteractor = TrackInteractor.new(self, ui, playhead, historyManager)

	self.PIXELS_PER_SECOND = Config.PIXELS_PER_SECOND
	self.SNAP_INTERVAL = Config.SNAP_INTERVAL
	self.TOTAL_TIME = Config.TOTAL_TIME
	self.TRACK_HEIGHT = Config.TRACK_HEIGHT
	self.LANE_PADDING = Config.LANE_PADDING

	self.drawingMode = nil
	self.isDrawing = false
	self.startMouseX = 0
	self.ghostTrack = nil
	self.selectedTracks = {}
	self.copiedTracksData = nil
	self.pasteTime = 0
	self.zoom = 1

	-- State for middle-mouse panning
	self.isPanning = false
	self.panStartPosition = Vector2.new(0, 0)
	self.panStartCanvasPosition = Vector2.new(0, 0)

	self.TrackSelected = {}
	function self.TrackSelected:Connect(callback) table.insert(self, callback) end
	function self.TrackSelected:Fire(...) for _, cb in ipairs(self) do cb(...) end end

	self.TrackDeleted = {}
	function self.TrackDeleted:Connect(callback) table.insert(self, callback) end
	function self.TrackDeleted:Fire(...) for _, cb in ipairs(self) do cb(...) end end

	self.MuteSoloChanged = {}
	function self.MuteSoloChanged:Connect(callback) table.insert(self, callback) end
	function self.MuteSoloChanged:Fire(...) for _, cb in ipairs(self) do cb(...) end end

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, self.LANE_PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = self.timeline

	self:drawTimelineGrid()
	self:connectEvents()

	return self
end

function TimelineManager:_updateLockVisuals(track, isLocked)
	local lockButton = track:FindFirstChild("LockButton")
	if lockButton then
		lockButton.Image = isLocked and LOCK_ICON_LOCKED or LOCK_ICON_UNLOCKED
	end
	-- Apply a visual effect to the track itself
	track.BackgroundTransparency = isLocked and 0.5 or 0
end

function TimelineManager:_updateMuteSoloVisuals(track)
	local isMuted = track:GetAttribute("IsMuted")
	local isSoloed = track:GetAttribute("IsSoloed")

	local muteButton = track:FindFirstChild("MuteButton")
	if muteButton then
		muteButton.BackgroundColor3 = isMuted and Color3.fromRGB(255, 180, 0) or Color3.fromRGB(80, 80, 80)
	end

	local soloButton = track:FindFirstChild("SoloButton")
	if soloButton then
		soloButton.BackgroundColor3 = isSoloed and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(80, 80, 80)
	end
end


-- INTERNAL, NON-HISTORY ACTION: Create track UI directly
function TimelineManager:_createTrackUI(trackData)
	local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * self.zoom
	local startTime = trackData.StartTime or 0
	local duration = trackData.Duration or 1

	local newTrack = Instance.new("TextButton")
	newTrack.Name = "TimelineTrack"
	newTrack.Text = "" -- Text will be handled by a child TextLabel
	newTrack.Size = UDim2.new(0, duration * zoomedPixelsPerSecond, 0, self.TRACK_HEIGHT)
	newTrack.Position = UDim2.new(0, startTime * zoomedPixelsPerSecond, 0, 0) -- Y position is now handled by UIListLayout
	newTrack.Active = true

	-- Determine the next available layout order
	local maxLayoutOrder = 0
	for _, child in ipairs(self.timeline:GetChildren()) do
		if child:IsA("GuiObject") and child.Name == "TimelineTrack" then
			maxLayoutOrder = math.max(maxLayoutOrder, child.LayoutOrder)
		end
	end
	newTrack.LayoutOrder = trackData.LayoutOrder or (maxLayoutOrder + 1)


	local componentType = trackData.ComponentType
	local baseColor = Color3.fromRGB(80, 80, 80)
	if Config.TrackColors[componentType] then
		baseColor = Config.TrackColors[componentType]
	end
	newTrack.BackgroundColor3 = baseColor
	newTrack:SetAttribute("BaseColor", baseColor)

	-- Set default attributes if they don't exist
	if trackData.IsLocked == nil then trackData.IsLocked = false end
	if trackData.IsMuted == nil then trackData.IsMuted = false end
	if trackData.IsSoloed == nil then trackData.IsSoloed = false end

	for key, value in pairs(trackData) do
		newTrack:SetAttribute(key, value)
	end
	newTrack:SetAttribute("LayoutOrder", newTrack.LayoutOrder)

	-- Add a frame for the group color indicator
	local groupColorIndicator = Instance.new("Frame")
	groupColorIndicator.Name = "GroupColorIndicator"
	groupColorIndicator.Size = UDim2.new(0, 5, 1, 0)
	groupColorIndicator.Position = UDim2.new(0, 0, 0, 0)
	groupColorIndicator.BackgroundColor3 = trackData.GroupColor or Color3.fromRGB(50, 50, 50)
	groupColorIndicator.BorderSizePixel = 0
	groupColorIndicator.Parent = newTrack

	-- Add Lock Button
	local lockButton = Instance.new("ImageButton")
	lockButton.Name = "LockButton"
	lockButton.Size = UDim2.new(0, 16, 0, 16)
	lockButton.Position = UDim2.new(0, 8, 0.5, -8)
	lockButton.BackgroundTransparency = 1
	lockButton.Parent = newTrack

	-- Add Mute Button
	local muteButton = Instance.new("TextButton")
	muteButton.Name = "MuteButton"
	muteButton.Size = UDim2.new(0, 18, 0, 18)
	muteButton.Position = UDim2.new(0, 28, 0.5, -9)
	muteButton.Text = "M"
	muteButton.Font = Enum.Font.SourceSansBold
	muteButton.TextSize = 12
	muteButton.Parent = newTrack

	-- Add Solo Button
	local soloButton = Instance.new("TextButton")
	soloButton.Name = "SoloButton"
	soloButton.Size = UDim2.new(0, 18, 0, 18)
	soloButton.Position = UDim2.new(0, 50, 0.5, -9)
	soloButton.Text = "S"
	soloButton.Font = Enum.Font.SourceSansBold
	soloButton.TextSize = 12
	soloButton.Parent = newTrack

	-- Add TextLabel for track name
	local trackLabel = Instance.new("TextLabel")
	trackLabel.Name = "TrackLabel"
	trackLabel.Size = UDim2.new(1, -75, 1, 0)
	trackLabel.Position = UDim2.new(0, 72, 0, 0)
	trackLabel.BackgroundTransparency = 1
	trackLabel.Font = Config.Theme.Font
	trackLabel.Text = trackData.TrackLabel or trackData.ComponentType or ""
	trackLabel.TextColor3 = Color3.new(1, 1, 1)
	trackLabel.TextXAlignment = Enum.TextXAlignment.Left
	trackLabel.Parent = newTrack

	self:_updateLockVisuals(newTrack, trackData.IsLocked)
	self:_updateMuteSoloVisuals(newTrack)

	newTrack.Parent = self.timeline

	self.trackInteractor:makeTrackInteractive(newTrack)

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
	-- Filter out locked tracks before proceeding
	local tracksToDelete = {}
	for track in pairs(self.selectedTracks) do
		if not track:GetAttribute("IsLocked") then
			table.insert(tracksToDelete, track)
		end
	end
	if #tracksToDelete == 0 then return end

	local deletedTracksData = {}
	for _, track in ipairs(tracksToDelete) do
		local data = {}
		for name, value in pairs(track:GetAttributes()) do data[name] = value end
		table.insert(deletedTracksData, data)
	end

	local action = {
		execute = function()
			for _, track in ipairs(tracksToDelete) do
				if self.selectedTracks[track] then
					self.selectedTracks[track] = nil
					track:Destroy()
				end
			end
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

-- PUBLIC, HISTORY-LOGGED ACTION: Set track label
function TimelineManager:setTrackLabel(track, newLabel)
	if track:GetAttribute("IsLocked") then return end
	local oldLabel = track:GetAttribute("TrackLabel") or nil
	local trackLabel = track:FindFirstChild("TrackLabel")
	if not trackLabel then return end

	local oldText = trackLabel.Text

	local action = {
		execute = function()
			track:SetAttribute("TrackLabel", newLabel)
			trackLabel.Text = newLabel
		end,
		undo = function()
			track:SetAttribute("TrackLabel", oldLabel)
			trackLabel.Text = oldText
		end
	}
	self.historyManager:registerAction(action)
end

-- NON-HISTORY ACTIONS
function TimelineManager:deselectAllTracks()
	for track in pairs(self.selectedTracks) do
		if track and track.Parent then
			track:FindFirstChild("SelectionOutline").Enabled = false
			local baseColor = track:GetAttribute("BaseColor")
			if baseColor then
				track.BackgroundColor3 = baseColor
			end
		end
	end
	self.selectedTracks = {}
end

function TimelineManager:addTrackToSelection(track)
	-- No guard here, allow selecting locked tracks
	if self.selectedTracks[track] then return end
	self.selectedTracks[track] = true
	track:FindFirstChild("SelectionOutline").Enabled = true
	track.BackgroundColor3 = track.BackgroundColor3:Lerp(Color3.new(1,1,1), 0.3)
end

function TimelineManager:removeTrackFromSelection(track)
	if not self.selectedTracks[track] then return end
	self.selectedTracks[track] = nil
	track:FindFirstChild("SelectionOutline").Enabled = false
	local baseColor = track:GetAttribute("BaseColor")
	if baseColor then
		track.BackgroundColor3 = baseColor
	end
end

function TimelineManager:getSelectedTracksTable()
	local tracks = {}
	for track in pairs(self.selectedTracks) do
		table.insert(tracks, track)
	end
	return tracks
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
	self.copiedTracksData = {}
	for track in pairs(self.selectedTracks) do
		-- Do not copy locked tracks
		if not track:GetAttribute("IsLocked") then
			local data = {}
			for name, value in pairs(track:GetAttributes()) do
				data[name] = value
			end
			table.insert(self.copiedTracksData, data)
		end
	end
	if #self.copiedTracksData == 0 then
		self.copiedTracksData = nil
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

function TimelineManager:setTrackLockState(tracks, isLocked)
	local originalStates = {}
	for _, track in ipairs(tracks) do
		originalStates[track] = track:GetAttribute("IsLocked") or false
	end

	local action = {
		execute = function()
			for _, track in ipairs(tracks) do
				track:SetAttribute("IsLocked", isLocked)
				self:_updateLockVisuals(track, isLocked)
				if isLocked and self.selectedTracks[track] then
					self:removeTrackFromSelection(track)
				end
			end
			self.TrackSelected:Fire(self.selectedTracks)
		end,
		undo = function()
			for track, originalState in pairs(originalStates) do
				track:SetAttribute("IsLocked", originalState)
				self:_updateLockVisuals(track, originalState)
			end
		end
	}
	self.historyManager:registerAction(action)
end

-- NON-HISTORY-LOGGED ACTION: Toggle Mute state
function TimelineManager:_toggleMute(track)
	local isMuted = not track:GetAttribute("IsMuted")
	track:SetAttribute("IsMuted", isMuted)
	self:_updateMuteSoloVisuals(track)
	self.MuteSoloChanged:Fire()
end

-- NON-HISTORY-LOGGED ACTION: Toggle Solo state
function TimelineManager:_toggleSolo(track)
	local isSoloed = not track:GetAttribute("IsSoloed")
	-- Unsolo all other tracks if this one is being soloed
	if isSoloed then
		for _, otherTrack in ipairs(self.timeline:GetChildren()) do
			if otherTrack.Name == "TimelineTrack" and otherTrack ~= track and otherTrack:GetAttribute("IsSoloed") then
				otherTrack:SetAttribute("IsSoloed", false)
				self:_updateMuteSoloVisuals(otherTrack)
			end
		end
	end
	track:SetAttribute("IsSoloed", isSoloed)
	self:_updateMuteSoloVisuals(track)
	self.MuteSoloChanged:Fire()
end

function TimelineManager:getTrackStates()
	local states = {}
	local isAnyTrackSoloed = false
	for _, track in ipairs(self.timeline:GetChildren()) do
		if track.Name == "TimelineTrack" and track:GetAttribute("IsSoloed") then
			isAnyTrackSoloed = true
			break
		end
	end

	for _, track in ipairs(self.timeline:GetChildren()) do
		if track.Name == "TimelineTrack" then
			local isMuted = track:GetAttribute("IsMuted")
			local isSoloed = track:GetAttribute("IsSoloed")
			local isVisible = true
			if isAnyTrackSoloed then
				isVisible = isSoloed
			elseif isMuted then
				isVisible = false
			end
			states[track] = {
				IsVisible = isVisible
			}
		end
	end
	return states
end

function TimelineManager:setGroupColorForSelectedTracks(color)
	if next(self.selectedTracks) == nil then return end

	local originalColors = {}
	for track in pairs(self.selectedTracks) do
		originalColors[track] = track:GetAttribute("GroupColor") or nil
	end

	local action = {
		execute = function()
			for track in pairs(self.selectedTracks) do
				track:SetAttribute("GroupColor", color)
				local indicator = track:FindFirstChild("GroupColorIndicator")
				if indicator then
					indicator.BackgroundColor3 = color
				end
			end
		end,
		undo = function()
			for track, originalColor in pairs(originalColors) do
				track:SetAttribute("GroupColor", originalColor)
				local indicator = track:FindFirstChild("GroupColorIndicator")
				if indicator then
					indicator.BackgroundColor3 = originalColor or Color3.fromRGB(50, 50, 50)
				end
			end
		end
	}
	self.historyManager:registerAction(action)
end

function TimelineManager:showContextMenu(mouseX, mouseY, options)
	local menu = self.ui.ContextMenu
	-- Adjust position to prevent the menu from going off-screen
	local viewportSize = self.ui.MainFrame.AbsoluteSize
	local menuSize = menu.AbsoluteSize
	local x = math.min(mouseX, viewportSize.X - menuSize.X - 150) -- Account for submenu
	local y = math.min(mouseY, viewportSize.Y - menuSize.Y)
	menu.Position = UDim2.new(0, x, 0, y)

	menu.CreateTrackButton.Visible = options.showCreate or false
	menu.CopyButton.Visible = options.showCopy or false
	menu.PasteButton.Visible = options.showPaste or false

	-- Auto-adjust height based on visible buttons
	local visibleButtons = 0
	if menu.CreateTrackButton.Visible then visibleButtons = visibleButtons + 1 end
	if menu.CopyButton.Visible then visibleButtons = visibleButtons + 1 end
	if menu.PasteButton.Visible then visibleButtons = visibleButtons + 1 end
	menu.Size = UDim2.new(0, 150, 0, visibleButtons * 30 + 4)

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
				child.Position = UDim2.new(0, startTime * self.PIXELS_PER_SECOND * self.zoom, 0, 0) -- Y is handled by layout
				child.Size = UDim2.new(0, duration * self.PIXELS_PER_SECOND * self.zoom, 0, self.TRACK_HEIGHT)
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

function TimelineManager:addDefaultAttributes(trackData)
	trackData.IsLocked = false
	local c = trackData.ComponentType
	if c == 'Light' then trackData.Enabled=true; trackData.Brightness=1; trackData.Color=Color3.fromRGB(255,255,255); trackData.Range=8; trackData.Shadows=false
	elseif c == 'SpotLight' or c == 'SurfaceLight' then trackData.Enabled=true; trackData.Brightness=1; trackData.Color=Color3.fromRGB(255,255,255); trackData.Range=8; trackData.Angle=60; trackData.Face="Front"; trackData.Shadows=false
	elseif c == 'Beam' then trackData.Enabled=true; trackData.Color="0,1,1,1;1,1,1,1"; trackData.Width0=1; trackData.Width1=1; trackData.Attachment0Offset="0,2,0"; trackData.Attachment1Offset="0,10,0"; trackData.Texture=""; trackData.CurveSize0=0; trackData.CurveSize1=0; trackData.FaceCamera=false; trackData.LightEmission=0; trackData.LightInfluence=1; trackData.Segments=10; trackData.TextureLength=1; trackData.TextureMode="Stretch"; trackData.TextureSpeed=1; trackData.Transparency="0,0;1,0"; trackData.ZOffset=0
	elseif c == 'Trail' then trackData.Enabled=true; trackData.Color="0,1,1,1;1,1,1,1"; trackData.Texture=""; trackData.Lifetime=1; trackData.WidthScale="0,1;1,1"; trackData.FaceCamera=false; trackData.LightEmission=0; trackData.LightInfluence=1; trackData.MinLength=0; trackData.MaxLength=0; trackData.TextureLength=1; trackData.TextureMode="Stretch"; trackData.Transparency="0,0;1,0"; trackData.StartPosition="0,0,0"; trackData.EndPosition="10,0,0"
	elseif c == 'Sound' then trackData.SoundId="rbxassetid://"; trackData.Volume=0.5; trackData.PlaybackSpeed=1; trackData.TimePosition=0; trackData.Looped=false; trackData.RollOffMode="Inverse"; trackData.RollOffMinDistance=10; trackData.RollOffMaxDistance=100
	elseif c == 'Particle' then trackData.Enabled=true; trackData.Rate=20; trackData.Lifetime="1 2"; trackData.Size="0,1;1,0"; trackData.Color="0,1,1,1;1,1,1,1"; trackData.SpreadAngle="360 360"; trackData.Texture="rbxasset://textures/particles/sparkles_main.dds"; trackData.Rotation="0 360"; trackData.Speed="5 10"; trackData.Acceleration="0,0,0"; trackData.Drag=0; trackData.EmissionDirection="Top"; trackData.LightEmission=0; trackData.LightInfluence=1; trackData.Orientation="FacingCamera"; trackData.RotSpeed="0 0"; trackData.Squash="0,0;1,0"; trackData.TimeScale=1; trackData.Transparency="0,0;1,0"; trackData.ZOffset=0 end
end

function TimelineManager:addPresetAttributes(trackData, presetName)
	local preset = ParticlePresets[presetName]
	if not preset then return end

	-- Override default particle attributes with preset values
	for key, value in pairs(preset) do
		trackData[key] = value
	end
end

-- PUBLIC, HISTORY-LOGGED ACTION: Create a track from a preset
function TimelineManager:createTrackFromPreset(presetName, time)
	local preset = ParticlePresets[presetName]
	if not preset then
		warn("Unknown preset:", presetName)
		return
	end

	-- 1. Start with default particle attributes
	local trackData = {
		ComponentType = "Particle",
		StartTime = time,
		Duration = 2 -- Default duration for presets
	}
	self:addDefaultAttributes(trackData)

	-- 2. Override with preset attributes
	self:addPresetAttributes(trackData, presetName)

	-- 3. Create the track using the standard, history-logged method
	self:createTracks({trackData})
end

function TimelineManager:connectEvents()
	self.ui.CopyButton.MouseButton1Click:Connect(function() self:copySelectedTracks() end)
	self.ui.PasteButton.MouseButton1Click:Connect(function() self:pasteTracksAtTime(self.pasteTime) end)

	self.ui.ClearAllButton.MouseButton1Click:Connect(function()
		UIManager.showConfirmationDialog(
			self.ui,
			"Clear Timeline",
			"Are you sure you want to delete all tracks? This action cannot be undone.",
			function()
				self:clearTimeline()
			end
		)
	end)

	self.timeline.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:deselectAllTracks()
			self.TrackSelected:Fire({})
		end

		if input.UserInputType == Enum.UserInputType.MouseButton3 then -- Middle mouse for panning
			self.isPanning = true
			self.panStartPosition = Vector2.new(input.Position.X, input.Position.Y)
			self.panStartCanvasPosition = self.timeline.CanvasPosition
		end

		self.ui.ContextMenu.Visible = false
		if input.Position then -- Guard against non-mouse inputs
			if self.drawingMode and input.UserInputType == Enum.UserInputType.MouseButton1 then
				self.isDrawing = true
				local mouseX = input.Position.X - self.timeline.AbsolutePosition.X
				self.startMouseX = mouseX + self.timeline.CanvasPosition.X
				self.ghostTrack = Instance.new("Frame"); self.ghostTrack.Size = UDim2.new(0, 0, 0, self.TRACK_HEIGHT); self.ghostTrack.Position = UDim2.new(0, self.startMouseX, 0, 50); self.ghostTrack.BackgroundColor3 = Color3.fromRGB(100, 150, 255); self.ghostTrack.BackgroundTransparency = 0.5; self.ghostTrack.Parent = self.timeline
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then -- Right-click for context menu
				local mouseX, mouseY = input.Position.X, input.Position.Y
				self:showContextMenu(mouseX, mouseY, {showCreate = true, showPaste = self.copiedTracksData ~= nil})
				local relativeMouseX = input.Position.X - self.timeline.AbsolutePosition.X + self.timeline.CanvasPosition.X
				self.pasteTime = relativeMouseX / (self.PIXELS_PER_SECOND * self.zoom)
			end
		end
	end)

	self.timeline.InputChanged:Connect(function(input)
		if self.isPanning and input.UserInputType == Enum.UserInputType.MouseMovement then
			if not input.Position then return end
			local delta = input.Position.X - self.panStartPosition.X
			self.timeline.CanvasPosition = Vector2.new(self.panStartCanvasPosition.X - delta, self.panStartCanvasPosition.Y)
		end

		if self.isDrawing and input.UserInputType == Enum.UserInputType.MouseMovement and input.Position then
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
		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			self.isPanning = false
		end

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
				if UserInputService:GetMouseLocation() then
					local mousePos = UserInputService:GetMouseLocation()
					local relativeMouseX = mousePos.X - self.timeline.AbsolutePosition.X + self.timeline.CanvasPosition.X
					local timeAtMouse = relativeMouseX / (self.PIXELS_PER_SECOND * self.zoom)
					self.zoom = math.clamp(self.zoom - input.Position.Z * 0.2, 0.2, 10)
					self:redrawTimeline()
					local newMouseX = timeAtMouse * (self.PIXELS_PER_SECOND * self.zoom)
					self.timeline.CanvasPosition = Vector2.new(newMouseX - (mousePos.X - self.timeline.AbsolutePosition.X), self.timeline.CanvasPosition.Y)
				end
			end
		end
	end)
end

return TimelineManager
