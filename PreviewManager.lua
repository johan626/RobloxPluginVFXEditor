-- PreviewManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/PreviewManager.lua

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Selection = game:GetService("Selection")
local TweenService = game:GetService("TweenService")
local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)

local PreviewManager = {}
PreviewManager.__index = PreviewManager

function PreviewManager.new(ui, timeline)
	local self = setmetatable({}, PreviewManager)

	self.Config = Config
	self.ui = ui
	self.timeline = timeline
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

function PreviewManager:update(deltaTime)
	self.currentTime = self.currentTime + deltaTime
	local playheadX = self.currentTime * self.Config.PIXELS_PER_SECOND
	self.playhead.Position = UDim2.new(0, playheadX, 0, 0)

	if not self.previewFolder or not self.previewFolder.Parent then
		self:stop()
		return
	end

	local selected = Selection:Get()[1]
	local previewPosition
	if selected and selected:IsA("BasePart") then
		previewPosition = selected.Position
	else
		previewPosition = Vector3.new(0, 5, 0) -- Default position if nothing is selected
	end

	for _, track in ipairs(self.timeline:GetChildren()) do
		if track:IsA("TextButton") and track.Name == "TimelineTrack" then
			local startTime = track:GetAttribute("StartTime")
			local endTime = startTime + track:GetAttribute("Duration")
			local isActive = self.currentTime >= startTime and self.currentTime < endTime
			local instanceExists = self.previewInstances[track] ~= nil

			if isActive and not instanceExists then
				local attributes = track:GetAttributes()
				local componentType = attributes.ComponentType

				if componentType == "Light" then
					local attachment = Instance.new("Attachment")
					attachment.WorldPosition = previewPosition
					local light = Instance.new("PointLight")
					light.Enabled = attributes.Enabled
					light.Brightness = attributes.Brightness
					light.Color = attributes.Color
					light.Range = attributes.Range
					light.Shadows = attributes.Shadows
					light.Parent = attachment
					attachment.Parent = self.previewFolder
					self.previewInstances[track] = attachment

				elseif componentType == "SpotLight" or componentType == "SurfaceLight" then
					local attachment = Instance.new("Attachment")
					attachment.WorldPosition = previewPosition
					local light
					if componentType == "SpotLight" then
						light = Instance.new("SpotLight")
					else
						light = Instance.new("SurfaceLight")
					end
					light.Enabled = attributes.Enabled
					light.Brightness = attributes.Brightness
					light.Color = attributes.Color
					light.Range = attributes.Range
					light.Angle = attributes.Angle
					light.Face = Utils.parseEnum(Enum.NormalId, attributes.Face) or Enum.NormalId.Front
					light.Shadows = attributes.Shadows
					light.Parent = attachment
					attachment.Parent = self.previewFolder
					self.previewInstances[track] = attachment

				elseif componentType == "Beam" then
					local beam = Instance.new("Beam")
					beam.Enabled = attributes.Enabled
					beam.Color = Utils.parseColorSequence(attributes.Color)
					beam.Width0 = attributes.Width0
					beam.Width1 = attributes.Width1
					beam.Texture = attributes.Texture
					beam.CurveSize0 = attributes.CurveSize0
					beam.CurveSize1 = attributes.CurveSize1
					beam.FaceCamera = attributes.FaceCamera
					beam.LightEmission = attributes.LightEmission
					beam.LightInfluence = attributes.LightInfluence
					beam.Segments = attributes.Segments
					beam.TextureLength = attributes.TextureLength
					beam.TextureMode = Utils.parseEnum(Enum.TextureMode, attributes.TextureMode) or Enum.TextureMode.Stretch
					beam.TextureSpeed = attributes.TextureSpeed
					beam.Transparency = Utils.parseNumberSequence(attributes.Transparency)
					beam.ZOffset = attributes.ZOffset

					local attachment0 = Instance.new("Attachment")
					attachment0.WorldPosition = previewPosition + Utils.parseVector3(attributes.Attachment0Offset)
					attachment0.Parent = self.previewFolder

					local attachment1 = Instance.new("Attachment")
					attachment1.WorldPosition = previewPosition + Utils.parseVector3(attributes.Attachment1Offset)
					attachment1.Parent = self.previewFolder

					beam.Attachment0 = attachment0
					beam.Attachment1 = attachment1
					beam.Parent = self.previewFolder
					self.previewInstances[track] = beam

				elseif componentType == "Sound" then
					local sound = Instance.new("Sound")
					sound.SoundId = attributes.SoundId
					sound.Volume = attributes.Volume
					sound.PlaybackSpeed = attributes.PlaybackSpeed
					sound.TimePosition = attributes.TimePosition
					sound.Looped = attributes.Looped
					sound.RollOffMode = Utils.parseEnum(Enum.RollOffMode, attributes.RollOffMode) or Enum.RollOffMode.Inverse
					sound.RollOffMinDistance = attributes.RollOffMinDistance
					sound.RollOffMaxDistance = attributes.RollOffMaxDistance
					sound.Parent = self.previewFolder
					sound:Play()
					self.previewInstances[track] = sound -- Sounds will self-destroy or stop

				elseif componentType == "Particle" then
					local attachment = Instance.new("Attachment")
					attachment.WorldPosition = previewPosition
					local emitter = Instance.new("ParticleEmitter")
					emitter.Enabled = attributes.Enabled
					emitter.Rate = attributes.Rate
					emitter.Lifetime = Utils.parseNumberRange(attributes.Lifetime)
					emitter.Size = Utils.parseNumberSequence(attributes.Size)
					emitter.Color = Utils.parseColorSequence(attributes.Color)
					emitter.Texture = attributes.Texture
					local spreadAngle = tostring(attributes.SpreadAngle)
					local spreadAngleParts = spreadAngle:split(" ")
					emitter.SpreadAngle = Vector2.new(tonumber(spreadAngleParts[1]) or 0, tonumber(spreadAngleParts[2]) or tonumber(spreadAngleParts[1]) or 0)
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
					emitter.Parent = attachment
					attachment.Parent = self.previewFolder
					self.previewInstances[track] = attachment

				elseif componentType == "Trail" then
					local trailPart = Instance.new("Part")
					trailPart.Size = Vector3.new(0.1, 0.1, 0.1)
					trailPart.Transparency = 1
					trailPart.Anchored = true
					trailPart.CFrame = CFrame.new(previewPosition + Utils.parseVector3(attributes.StartPosition))

					local attachment0 = Instance.new("Attachment")
					attachment0.Parent = trailPart
					local attachment1 = Instance.new("Attachment")
					attachment1.Position = Vector3.new(0, 0, -1) -- Small offset to create initial trail
					attachment1.Parent = trailPart

					local trail = Instance.new("Trail")
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
					trail.Attachment0 = attachment0
					trail.Attachment1 = attachment1
					trail.Parent = trailPart

					trailPart.Parent = self.previewFolder

					local tweenInfo = TweenInfo.new(attributes.Duration, Enum.EasingStyle.Linear)
					local goal = {CFrame = CFrame.new(previewPosition + Utils.parseVector3(attributes.EndPosition))}
					local tween = TweenService:Create(trailPart, tweenInfo, goal)
					tween:Play()

					self.previewInstances[track] = trailPart
				end
			elseif not isActive and instanceExists then
				if typeof(self.previewInstances[track]) == "Instance" then
					self.previewInstances[track]:Destroy()
				end
				self.previewInstances[track] = nil
			end
		end
	end

	if playheadX > self.timeline.CanvasSize.X.Offset then
		self:stop()
	end
end

function PreviewManager:play()
	if self.isPlaying then return end
	self.isPlaying = true

	self.previewFolder = Instance.new("Folder")
	self.previewFolder.Name = "VFX_Preview"
	self.previewFolder.Parent = workspace

	self.playbackConnection = RunService.Heartbeat:Connect(function(dt) self:update(dt) end)
end

function PreviewManager:stop()
	self.isPlaying = false
	if self.playbackConnection then
		self.playbackConnection:Disconnect()
		self.playbackConnection = nil
	end

	if self.previewFolder then
		self.previewFolder:Destroy()
		self.previewFolder = nil
	end

	self.currentTime = 0
	self.playhead.Position = UDim2.new(0, 0, 0, 0)
	self.previewInstances = {}
end

function PreviewManager:connectEvents()
	self.ui.PlayButton.MouseButton1Click:Connect(function()
		if self.isPlaying then self:pause() else self:play() end
	end)
	self.ui.StopButton.MouseButton1Click:Connect(function() self:stop() end)
end

function PreviewManager:pause()
	self.isPlaying = false
	if self.playbackConnection then
		self.playbackConnection:Disconnect()
		self.playbackConnection = nil
	end
end

return PreviewManager
