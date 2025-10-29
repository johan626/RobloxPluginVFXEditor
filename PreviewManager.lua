-- PreviewManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/PreviewManager.lua

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)

local PreviewManager = {}
PreviewManager.__index = PreviewManager

function PreviewManager.new(ui, timeline)
	local self = setmetatable({}, PreviewManager)

	self.Config = Config
	self.ui = ui
	self.timeline = timeline -- The timeline ScrollingFrame
	self.worldModel = Instance.new("WorldModel")
	self.worldModel.Parent = ui.PreviewWindow

	-- Setup camera and floor
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(0, 5, 15) * CFrame.Angles(-math.rad(15), 0, 0)
	camera.Parent = self.worldModel -- This line was missing
	ui.PreviewWindow.CurrentCamera = camera

	local floor = Instance.new("Part")
	floor.Size = Vector3.new(40, 1, 40)
	floor.Anchored = true
	floor.Parent = self.worldModel

	-- Add a spotlight to illuminate the scene
	local lightAttachment = Instance.new("Attachment")
	lightAttachment.Position = Vector3.new(0, 15, 0)
	local spotLight = Instance.new("SpotLight")
	spotLight.Face = Enum.NormalId.Bottom
	spotLight.Angle = 60
	spotLight.Range = 40
	spotLight.Brightness = 2
	spotLight.Parent = lightAttachment
	lightAttachment.Parent = self.worldModel

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

	for _, track in ipairs(self.timeline:GetChildren()) do
		if track:IsA("TextButton") and track.Name == "TimelineTrack" then
			local startTime = track.Position.X.Offset / self.Config.PIXELS_PER_SECOND
			local endTime = startTime + (track.Size.X.Offset / self.Config.PIXELS_PER_SECOND)
			local isActive = self.currentTime >= startTime and self.currentTime < endTime
			local instanceExists = self.previewInstances[track] ~= nil

			if isActive and not instanceExists then
				local componentType = track:GetAttribute("ComponentType")
				if componentType == "Light" then
					local attachment = Instance.new("Attachment")
					local light = Instance.new("PointLight")
					light.Brightness = track:GetAttribute("Brightness")
					light.Color = track:GetAttribute("Color")
					light.Range = track:GetAttribute("Range")
					light.Enabled = track:GetAttribute("Enabled")
					light.Parent = attachment
					attachment.Parent = self.worldModel
					self.previewInstances[track] = attachment
				elseif componentType == "Sound" then
					local sound = Instance.new("Sound")
					sound.SoundId = track:GetAttribute("SoundId")
					sound.Volume = track:GetAttribute("Volume")
					sound.PlaybackSpeed = track:GetAttribute("PlaybackSpeed")
					sound.Parent = workspace -- Play in the main workspace
					sound:Play()
					local duration = track.Size.X.Offset / self.Config.PIXELS_PER_SECOND
					Debris:AddItem(sound, duration + 5) -- Add to debris
					self.previewInstances[track] = true -- Just mark as played
				elseif componentType == "Particle" then
					local attachment = Instance.new("Attachment")
					local emitter = Instance.new("ParticleEmitter")
					emitter.Enabled = track:GetAttribute("Enabled")
					emitter.Rate = track:GetAttribute("Rate")
					emitter.Lifetime = Utils.parseNumberRange(track:GetAttribute("Lifetime"))
					emitter.Size = Utils.parseNumberSequence(track:GetAttribute("Size"))
					emitter.Color = Utils.parseColorSequence(track:GetAttribute("Color"))
					local spreadAngle = track:GetAttribute("SpreadAngle")
					local spreadAngleParts = spreadAngle:split(" ")
					emitter.SpreadAngle = Vector2.new(tonumber(spreadAngleParts[1]), tonumber(spreadAngleParts[2]))

					emitter.Parent = attachment
					attachment.Parent = self.worldModel
					self.previewInstances[track] = attachment
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
	self.isPlaying = true
	self.playbackConnection = RunService.Heartbeat:Connect(function(dt) self:update(dt) end)
end

function PreviewManager:stop()
	self.isPlaying = false
	if self.playbackConnection then
		self.playbackConnection:Disconnect()
		self.playbackConnection = nil
	end
	self.currentTime = 0
	self.playhead.Position = UDim2.new(0, 0, 0, 0)
	for track, instance in pairs(self.previewInstances) do
		if typeof(instance) == "Instance" then
			instance:Destroy()
		end
	end
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
