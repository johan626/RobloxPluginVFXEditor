-- PreviewManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/PreviewManager.lua

local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local TweenService = game:GetService("TweenService")
local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)

local PreviewManager = {}
PreviewManager.__index = PreviewManager

function PreviewManager.new(ui)
	local self = setmetatable({}, PreviewManager)

	self.Config = Config
	self.ui = ui
	self.timelineManager = nil -- Will be set later
	self.propertiesManager = nil -- Will be set later
	self.timeline = ui.Timeline -- Direct reference to UI component
	self.previewFolder = nil

	-- State
	self.isPlaying = false
	self.currentTime = 0
	self.playbackConnection = nil
	self.previewInstances = {}

	self.playhead = Instance.new("Frame")
	self.playhead.Size = UDim2.new(0, 2, 1, 0)
	self.playhead.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	self.playhead.ZIndex = 10
	self.playhead.Parent = self.timeline

	self:connectEvents()

	return self
end

-- Method to inject the TimelineManager after both are created
function PreviewManager:setTimelineManager(timelineManager)
	self.timelineManager = timelineManager
	self.timelineManager.MuteSoloChanged:Connect(function()
		-- When mute/solo state changes, refresh the preview immediately
		self:updatePreviewAtTime(self.currentTime)
	end)
end

function PreviewManager:setPropertiesManager(propertiesManager)
	self.propertiesManager = propertiesManager
end

-- The core function for real-time scrubbing and playback
function PreviewManager:updatePreviewAtTime(time)
	if not self.timelineManager then return end -- Guard until timelineManager is set

	self.currentTime = time
	if self.propertiesManager then
		self.propertiesManager.updateValues(time)
	end
	local playheadX = time * self.Config.PIXELS_PER_SECOND * self.timelineManager.zoom
	self.playhead.Position = UDim2.new(0, playheadX, 0, 0)

	if not self.previewFolder or not self.previewFolder.Parent then
		self:createPreviewFolder()
	end

	local selected = Selection:Get()[1]
	local previewPosition
	if selected and selected:IsA("BasePart") then
		previewPosition = selected.Position
	else
		previewPosition = Vector3.new(0, 5, 0)
	end

	local trackStates = self.timelineManager:getTrackStates()
	local activeTracks = {}
	for _, track in ipairs(self.timeline:GetChildren()) do
		if track:IsA("Frame") and track.Name == "TimelineTrack" then
			local trackState = trackStates[track]
			if not trackState or not trackState.IsVisible then
				continue -- Skip muted/unsoloed tracks
			end

			local attributes = track:GetAttributes()

			-- Sounds are handled entirely by _handleSounds during playback, not scrubbing.
			if attributes.ComponentType == "Sound" then
				continue
			end

			local startTime = track:GetAttribute("StartTime")
			local duration = track:GetAttribute("Duration")
			local endTime = startTime + duration

			if time >= startTime and time < endTime then
				activeTracks[track] = true

				local instance = self.previewInstances[track]
				local timeIntoTrack = time - startTime

				if not instance then
					instance = self:_createPreviewInstance(track, previewPosition)
					self.previewInstances[track] = instance
				end

				self:_updateInstanceProperties(instance, attributes, timeIntoTrack, duration, previewPosition)
			end
		end
	end

	for track, instance in pairs(self.previewInstances) do
		if not activeTracks[track] then
			if typeof(instance) == "Instance" and instance.Parent then
				instance:Destroy()
			end
			self.previewInstances[track] = nil
		end
	end
end

function PreviewManager:_createPreviewInstance(track, previewPosition)
	local attributes = track:GetAttributes()
	local componentType = attributes.ComponentType
	local instance

	if componentType == "Light" or componentType == "SpotLight" or componentType == "SurfaceLight" then
		local attachment = Instance.new("Attachment")
		local light
		if componentType == "Light" then light = Instance.new("PointLight")
		elseif componentType == "SpotLight" then light = Instance.new("SpotLight")
		else light = Instance.new("SurfaceLight") end
		light.Parent = attachment
		attachment.Parent = self.previewFolder
		instance = attachment
	elseif componentType == "Beam" then
		local beam = Instance.new("Beam")
		local attachment0 = Instance.new("Attachment"); attachment0.Parent = self.previewFolder
		local attachment1 = Instance.new("Attachment"); attachment1.Parent = self.previewFolder
		beam.Attachment0 = attachment0
		beam.Attachment1 = attachment1
		beam.Parent = self.previewFolder
		instance = beam
	elseif componentType == "Particle" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = previewPosition

		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = attributes.Enabled
		emitter.Lifetime = Utils.parseNumberRange(attributes.Lifetime)
		emitter.Size = Utils.parseNumberSequence(attributes.Size)
		emitter.Color = Utils.parseColorSequence(attributes.Color)
		emitter.Texture = attributes.Texture
		local spreadAngle = tostring(attributes.SpreadAngle):split(" ")
		emitter.SpreadAngle = Vector2.new(tonumber(spreadAngle[1]) or 0, tonumber(spreadAngle[2]) or tonumber(spreadAngle[1]) or 0)
		emitter.EmissionDirection = Utils.parseEnum(Enum.NormalId, attributes.EmissionDirection) or Enum.NormalId.Top
		emitter.LightInfluence = attributes.LightInfluence
		emitter.Orientation = Utils.parseEnum(Enum.ParticleOrientation, attributes.Orientation) or Enum.ParticleOrientation.FacingCamera
		emitter.RotSpeed = Utils.parseNumberRange(attributes.RotSpeed)
		emitter.Rotation = Utils.parseNumberRange(attributes.Rotation)
		emitter.Speed = Utils.parseNumberRange(attributes.Speed)
		emitter.Squash = Utils.parseNumberSequence(attributes.Squash)
		emitter.Transparency = Utils.parseNumberSequence(attributes.Transparency)
		emitter.Parent = attachment

		attachment.Parent = self.previewFolder
		instance = attachment
	elseif componentType == "Trail" then
		local trailPart = Instance.new("Part"); trailPart.Size = Vector3.new(0.1, 0.1, 0.1); trailPart.Transparency = 1; trailPart.Anchored = true
		local attachment0 = Instance.new("Attachment"); attachment0.Parent = trailPart
		local attachment1 = Instance.new("Attachment"); attachment1.Position = Vector3.new(0, 0, -1); attachment1.Parent = trailPart
		local trail = Instance.new("Trail"); trail.Attachment0 = attachment0; trail.Attachment1 = attachment1; trail.Parent = trailPart
		trailPart.Parent = self.previewFolder
		instance = trailPart
	end

	return instance
end

-- Gets the interpolated value of a property at a specific time
function PreviewManager:_getInterpolatedValue(keyframes, timeIntoTrack)
	if not keyframes or #keyframes == 0 then return nil end

	-- Find the two keyframes to interpolate between
	local key1, key2

	-- If there's only one keyframe, or time is before the first, use the first.
	if #keyframes == 1 or timeIntoTrack < keyframes[1].time then
		return keyframes[1].value
	end

	-- Find the correct segment
	for i = 1, #keyframes - 1 do
		if keyframes[i].time <= timeIntoTrack and keyframes[i+1].time >= timeIntoTrack then
			key1 = keyframes[i]
			key2 = keyframes[i+1]
			break
		end
	end

	-- If time is after the last keyframe, clamp to the last value
	if not key1 then
		return keyframes[#keyframes].value
	end

	-- Interpolate using the unified function
	return Utils.interpolate(key1, key2, timeIntoTrack)
end

function PreviewManager:_updateInstanceProperties(instance, attributes, timeIntoTrack, duration, previewPosition)
	if not instance or typeof(instance) ~= "Instance" then return end

	local componentType = attributes.ComponentType
	local progress = timeIntoTrack / duration

	if componentType == "Light" or componentType == "SpotLight" or componentType == "SurfaceLight" then
		if not (instance:IsA("Attachment") and instance:FindFirstChildOfClass("Light")) then return end

		instance.WorldPosition = previewPosition
		local light = instance:FindFirstChildOfClass("Light")
		light.Enabled = attributes.Enabled
		light.Brightness = self:_getInterpolatedValue(attributes.Brightness, timeIntoTrack)
		light.Color = self:_getInterpolatedValue(attributes.Color, timeIntoTrack)
		light.Range = self:_getInterpolatedValue(attributes.Range, timeIntoTrack)
		light.Shadows = attributes.Shadows
		if componentType ~= "Light" then
			light.Angle = self:_getInterpolatedValue(attributes.Angle, timeIntoTrack)
			light.Face = Utils.parseEnum(Enum.NormalId, attributes.Face) or Enum.NormalId.Front
		end
	elseif componentType == "Beam" then
		if not instance:IsA("Beam") then return end

		instance.Enabled = attributes.Enabled
		instance.Color = Utils.parseColorSequence(attributes.Color)
		instance.Width0 = self:_getInterpolatedValue(attributes.Width0, timeIntoTrack)
		instance.Width1 = self:_getInterpolatedValue(attributes.Width1, timeIntoTrack)
		instance.Texture = attributes.Texture
		instance.CurveSize0 = attributes.CurveSize0
		instance.CurveSize1 = attributes.CurveSize1
		instance.FaceCamera = attributes.FaceCamera
		instance.LightEmission = self:_getInterpolatedValue(attributes.LightEmission, timeIntoTrack)
		instance.LightInfluence = attributes.LightInfluence
		instance.Segments = attributes.Segments
		instance.TextureLength = attributes.TextureLength
		instance.TextureMode = Utils.parseEnum(Enum.TextureMode, attributes.TextureMode) or Enum.TextureMode.Stretch
		instance.TextureSpeed = attributes.TextureSpeed
		instance.Transparency = Utils.parseNumberSequence(attributes.Transparency)
		instance.ZOffset = attributes.ZOffset
		instance.Attachment0.WorldPosition = previewPosition + Utils.parseVector3(attributes.Attachment0Offset)
		instance.Attachment1.WorldPosition = previewPosition + Utils.parseVector3(attributes.Attachment1Offset)
	elseif componentType == "Particle" then
		if not (instance:IsA("Attachment") and instance:FindFirstChildOfClass("ParticleEmitter")) then return end
		local emitter = instance:FindFirstChildOfClass("ParticleEmitter")
		emitter.Rate = self:_getInterpolatedValue(attributes.Rate, timeIntoTrack) or emitter.Rate
		emitter.Acceleration = Utils.parseVector3(self:_getInterpolatedValue(attributes.Acceleration, timeIntoTrack) or "0,0,0")
		emitter.Drag = self:_getInterpolatedValue(attributes.Drag, timeIntoTrack) or emitter.Drag
		emitter.LightEmission = self:_getInterpolatedValue(attributes.LightEmission, timeIntoTrack) or emitter.LightEmission
		emitter.TimeScale = self:_getInterpolatedValue(attributes.TimeScale, timeIntoTrack) or emitter.TimeScale
		emitter.ZOffset = self:_getInterpolatedValue(attributes.ZOffset, timeIntoTrack) or emitter.ZOffset
		instance.WorldPosition = previewPosition

	elseif componentType == "Trail" then
		if not (instance:IsA("Part") and instance:FindFirstChildOfClass("Trail")) then return end

		local startPos = previewPosition + Utils.parseVector3(attributes.StartPosition)
		local endPos = previewPosition + Utils.parseVector3(attributes.EndPosition)
		instance.CFrame = CFrame.new(startPos:Lerp(endPos, progress))
		local trail = instance:FindFirstChildOfClass("Trail")
		trail.Enabled = attributes.Enabled
		trail.Color = Utils.parseColorSequence(attributes.Color)
		trail.Lifetime = attributes.Lifetime
		trail.WidthScale = Utils.parseNumberSequence(attributes.WidthScale)
		trail.Texture = attributes.Texture
		trail.FaceCamera = attributes.FaceCamera
		trail.LightEmission = self:_getInterpolatedValue(attributes.LightEmission, timeIntoTrack) or trail.LightEmission
		trail.LightInfluence = attributes.LightInfluence
		trail.MinLength = attributes.MinLength
		trail.MaxLength = attributes.MaxLength
		trail.TextureLength = attributes.TextureLength
		trail.TextureMode = Utils.parseEnum(Enum.TextureMode, attributes.TextureMode) or Enum.TextureMode.Stretch
		trail.Transparency = Utils.parseNumberSequence(attributes.Transparency)
	end
end


function PreviewManager:play()
	if self.isPlaying then return end
	self.isPlaying = true
	self:createPreviewFolder()
	self:_handleSounds(true)
	self.playbackConnection = RunService.Heartbeat:Connect(function(dt)
		local newTime = self.currentTime + dt
		if newTime > self.Config.TOTAL_TIME then
			self:stop()
		else
			self:updatePreviewAtTime(newTime)
		end
	end)
end

function PreviewManager:stop()
	if not self.isPlaying and self.currentTime == 0 then return end
	self.isPlaying = false
	if self.playbackConnection then
		self.playbackConnection:Disconnect()
		self.playbackConnection = nil
	end
	self:_handleSounds(false)
	if self.previewFolder then
		self.previewFolder:Destroy()
	end
	-- Clear all visual (non-sound) instances
	for track, instance in pairs(self.previewInstances) do
		if typeof(instance) == "Instance" then
			instance:Destroy()
		end
		self.previewInstances[track] = nil
	end

	self:updatePreviewAtTime(0)
end

function PreviewManager:pause()
	self.isPlaying = false
	if self.playbackConnection then
		self.playbackConnection:Disconnect()
		self.playbackConnection = nil
	end
	self:_handleSounds(false)
end

function PreviewManager:_handleSounds(shouldPlay)
	if not self.timelineManager then return end

	local trackStates = self.timelineManager:getTrackStates()

	for _, track in ipairs(self.timeline:GetChildren()) do
		if track:IsA("Frame") and track.Name == "TimelineTrack" and track:GetAttribute("ComponentType") == "Sound" then
			local instance = self.previewInstances[track]
			local trackState = trackStates[track]

			if shouldPlay and trackState and trackState.IsVisible then
				local startTime = track:GetAttribute("StartTime")
				if self.currentTime >= startTime and not instance then
					local sound = Instance.new("Sound")
					local attributes = track:GetAttributes()
					sound.SoundId = attributes.SoundId
					sound.Volume = self:_getInterpolatedValue(attributes.Volume, self.currentTime - startTime)
					sound.PlaybackSpeed = self:_getInterpolatedValue(attributes.PlaybackSpeed, self.currentTime - startTime)
					sound.TimePosition = self.currentTime - startTime
					sound.Looped = attributes.Looped
					sound.RollOffMode = Utils.parseEnum(Enum.RollOffMode, attributes.RollOffMode) or Enum.RollOffMode.Inverse
					sound.RollOffMinDistance = attributes.RollOffMinDistance
					sound.RollOffMaxDistance = attributes.RollOffMaxDistance
					sound.Parent = self.previewFolder
					sound:Play()
					self.previewInstances[track] = sound
				end
			else
				if instance and typeof(instance) == "Instance" then
					instance:Stop(); instance:Destroy(); self.previewInstances[track] = nil
				end
			end
		end
	end
end

function PreviewManager:createPreviewFolder()
	if self.previewFolder and self.previewFolder.Parent then return end
	self.previewFolder = Instance.new("Folder")
	self.previewFolder.Name = "VFX_Preview"
	self.previewFolder.Parent = workspace
end

function PreviewManager:connectEvents()
	self.ui.PlayButton.MouseButton1Click:Connect(function()
		if self.isPlaying then self:pause() else self:play() end
	end)
	self.ui.StopButton.MouseButton1Click:Connect(function() self:stop() end)

	local isScrubbing = false
	self.playhead.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isScrubbing = true
			if self.isPlaying then self:pause() end
			self:createPreviewFolder()
		end
	end)

	self.timeline.InputChanged:Connect(function(input)
		if isScrubbing and input.UserInputType == Enum.UserInputType.MouseMovement then
			if not input.Position then return end
			local mouseX = input.Position.X - self.timeline.AbsolutePosition.X + self.timeline.CanvasPosition.X
			if self.timelineManager then
				local newTime = math.clamp(mouseX / (self.Config.PIXELS_PER_SECOND * self.timelineManager.zoom), 0, self.Config.TOTAL_TIME)
				self:updatePreviewAtTime(newTime)
			end
		end
	end)

	self.timeline.InputEnded:Connect(function(input)
		if isScrubbing and input.UserInputType == Enum.UserInputType.MouseButton1 then
			isScrubbing = false
		end
	end)
end

return PreviewManager
