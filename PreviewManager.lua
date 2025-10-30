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
end

-- The core function for real-time scrubbing and playback
function PreviewManager:updatePreviewAtTime(time)
	if not self.timelineManager then return end -- Guard until timelineManager is set

	self.currentTime = time
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

	local activeTracks = {}
	for _, track in ipairs(self.timeline:GetChildren()) do
		if track:IsA("TextButton") and track.Name == "TimelineTrack" then
			local startTime = track:GetAttribute("StartTime")
			local duration = track:GetAttribute("Duration")
			local endTime = startTime + duration

			if time >= startTime and time < endTime then
				activeTracks[track] = true

				local instance = self.previewInstances[track]
				local attributes = track:GetAttributes()
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

-- (The rest of the file remains the same)
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
		local emitter = Instance.new("ParticleEmitter"); emitter.Parent = attachment
		attachment.Parent = self.previewFolder
		instance = attachment
	elseif componentType == "Trail" then
		local trailPart = Instance.new("Part"); trailPart.Size = Vector3.new(0.1, 0.1, 0.1); trailPart.Transparency = 1; trailPart.Anchored = true
		local attachment0 = Instance.new("Attachment"); attachment0.Parent = trailPart
		local attachment1 = Instance.new("Attachment"); attachment1.Position = Vector3.new(0, 0, -1); attachment1.Parent = trailPart
		local trail = Instance.new("Trail"); trail.Attachment0 = attachment0; trail.Attachment1 = attachment1; trail.Parent = trailPart
		trailPart.Parent = self.previewFolder
		instance = trailPart
	elseif componentType == "Sound" then
		instance = "Sound" 
	end

	return instance
end

function PreviewManager:_updateInstanceProperties(instance, attributes, timeIntoTrack, duration, previewPosition)
	local componentType = attributes.ComponentType
	local progress = timeIntoTrack / duration

	if componentType == "Light" or componentType == "SpotLight" or componentType == "SurfaceLight" then
		instance.WorldPosition = previewPosition
		local light = instance:FindFirstChildOfClass("Light")
		light.Enabled = attributes.Enabled
		light.Brightness = attributes.Brightness
		light.Color = attributes.Color
		light.Range = attributes.Range
		light.Shadows = attributes.Shadows
		if componentType ~= "Light" then
			light.Angle = attributes.Angle
			light.Face = Utils.parseEnum(Enum.NormalId, attributes.Face) or Enum.NormalId.Front
		end
	elseif componentType == "Beam" then
		instance.Enabled = attributes.Enabled
		instance.Color = Utils.parseColorSequence(attributes.Color)
		instance.Width0 = attributes.Width0
		instance.Width1 = attributes.Width1
		instance.Texture = attributes.Texture
		instance.CurveSize0 = attributes.CurveSize0
		instance.CurveSize1 = attributes.CurveSize1
		instance.FaceCamera = attributes.FaceCamera
		instance.LightEmission = attributes.LightEmission
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
		instance.WorldPosition = previewPosition
		local emitter = instance:FindFirstChildOfClass("ParticleEmitter")
		emitter:Clear()
		emitter.Enabled = attributes.Enabled
		emitter.Lifetime = Utils.parseNumberRange("0.1 0.1")
		emitter.Size = Utils.parseNumberSequence(attributes.Size)
		emitter.Color = Utils.parseColorSequence(attributes.Color)
		emitter.Texture = attributes.Texture
		local spreadAngle = tostring(attributes.SpreadAngle):split(" ")
		emitter.SpreadAngle = Vector2.new(tonumber(spreadAngle[1]) or 0, tonumber(spreadAngle[2]) or tonumber(spreadAngle[1]) or 0)
		emitter.Acceleration = Utils.parseVector3(attributes.Acceleration)
		emitter.Drag = attributes.Drag
		emitter.EmissionDirection = Utils.parseEnum(Enum.NormalId, attributes.EmissionDirection) or Enum.NormalId.Top
		emitter.LightEmission = attributes.LightEmission
		emitter.LightInfluence = attributes.LightInfluence
		emitter.Orientation = Utils.parseEnum(Enum.ParticleOrientation, attributes.Orientation) or Enum.ParticleOrientation.FacingCamera
		emitter.RotSpeed = Utils.parseNumberRange(attributes.RotSpeed)
		emitter.Rotation = Utils.parseNumberRange(attributes.Rotation)
		emitter.Speed = Utils.parseNumberRange(attributes.Speed)
		emitter.Squash = Utils.parseNumberSequence(attributes.Squash)
		emitter.TimeScale = attributes.TimeScale
		emitter.Transparency = Utils.parseNumberSequence(attributes.Transparency)
		emitter.ZOffset = attributes.ZOffset
		emitter:Emit(math.ceil(attributes.Rate * 0.1))

	elseif componentType == "Trail" then
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
		trail.LightEmission = attributes.LightEmission
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
		self.previewFolder = nil
	end
	self:updatePreviewAtTime(0)
	self.previewInstances = {}
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
	for _, track in ipairs(self.timeline:GetChildren()) do
		if track:IsA("TextButton") and track.Name == "TimelineTrack" and track:GetAttribute("ComponentType") == "Sound" then
			local instance = self.previewInstances[track]
			if shouldPlay then
				local startTime = track:GetAttribute("StartTime")
				if self.currentTime >= startTime and not instance then
					local sound = Instance.new("Sound")
					sound.SoundId = track:GetAttribute("SoundId"); sound.Volume = track:GetAttribute("Volume"); sound.PlaybackSpeed = track:GetAttribute("PlaybackSpeed"); sound.TimePosition = self.currentTime - startTime; sound.Looped = track:GetAttribute("Looped"); sound.RollOffMode = Utils.parseEnum(Enum.RollOffMode, track:GetAttribute("RollOffMode")) or Enum.RollOffMode.Inverse; sound.RollOffMinDistance = track:GetAttribute("RollOffMinDistance"); sound.RollOffMaxDistance = track:GetAttribute("RollOffMaxDistance")
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
