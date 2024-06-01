--[[
    @class GrenadeModule
    @server
    Module for handling grenade throwing, simulation, and explosion.
]]

-- Import necessary services and modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local FastCast = require(ServerScriptService.FastCastRedux)
local BridgeNet = require(ReplicatedStorage.BridgeNet)

-- Create a communication bridge for throwing actions
local ThrowBridge = BridgeNet.CreateBridge("ThrowBridge")

-- Configuration flags
local SimulateBeforePhysics = true
local Debug = true

-- Module table definition
local GrenadeModule = {}
GrenadeModule.__index = GrenadeModule

-- Enable debugging and visualization for FastCast
FastCast.DebugLogging = Debug
FastCast.VisualizeCasts = Debug

-- Define raycast parameters
local CastParams = RaycastParams.new()
CastParams.IgnoreWater = true
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.FilterDescendantsInstances = {}

--[[
    @function new
    @within GrenadeModule
    @param Setting table -- Table containing the settings for the grenade.
    @return GrenadeModule -- Returns a new instance of the GrenadeModule.
    Creates a new grenade instance with the provided settings.
]]
function GrenadeModule.new(Setting)
	local self = setmetatable({}, GrenadeModule)

	-- Extract settings
	local CastBehaviorSettings = Setting.CastBehaviorSettings
	local SimulationSettings = Setting.SimulationSettings
	local OtherSettings = Setting.OtherSettings

	-- Initialize tool and its properties
	self.Tool = OtherSettings.ToolInstance:Clone()
	self.Tool.Parent = OtherSettings.SpawnWhenCreatedOn
	self.Tool.Name = OtherSettings.ToolName or self.Tool.Name

	self.HoldingPlayerCharacter = nil
	self.Bind = self.Tool.Bind
	self.Caster = FastCast.new(Workspace, SimulateBeforePhysics)

	-- Setup cast behavior properties
	self.CastBehavior = FastCast.newBehavior()
	self.CastBehavior.RaycastParams = CastParams
	self.CastBehavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default
	self.CastBehavior.AutoIgnoreContainer = false
	self.CastBehavior.MaxDistance = CastBehaviorSettings.MaxDistance
	self.CastBehavior.CosmeticBulletTemplate = CastBehaviorSettings.Projectile
	self.CastBehavior.CosmeticBulletContainer = CastBehaviorSettings.ProjectileContainer
	self.CastBehavior.Acceleration = CastBehaviorSettings.Acceleration
	self.CastBehavior.CanPierceFunction = CastBehaviorSettings.CanPierceFunction

	-- Define actions for when the ray pierces an object
	self.Caster.RayPierced:Connect(function(Cast, RaycastResult, SegmentVelocity)
		local Position = RaycastResult.Position
		local Normal = RaycastResult.Normal
		local Reflect = GrenadeModule.Reflect(Normal, SegmentVelocity.Unit)
		Cast.UserData.Bounces += 1
		-- Set the new velocity and position of the cast after it bounces
		Cast:SetVelocity(Reflect * SegmentVelocity.Magnitude * SimulationSettings.Elasticity)
		Cast:SetPosition(Position + (Normal * 0.1))
	end)

	-- Define actions for when the ray length changes
	self.Caster.LengthChanged:Connect(function(Cast, LastPoint, Direction, Length, Velocity, Bullet)
		local TimeElapsed = tick() - self.Tick
		Bullet.CFrame = CFrame.new(LastPoint)
		if Cast.UserData.Bounces >= SimulationSettings.MaxBounces then
			-- Terminate the cast and trigger the explosion if max bounces are reached
			Cast:Terminate()
			self:Explode(Bullet)
		end
	end)

	-- Handle tool being equipped
	self.Tool.Equipped:Connect(function()
		self.HoldingPlayerCharacter = self.Tool.Parent
		CastParams.FilterDescendantsInstances = {self.Tool.Parent}
		-- Wait for the specified time until explosion
		task.wait(SimulationSettings.TimeUntilExplosion)
		if not self.HoldingPlayerCharacter then return end
		if self.Tool:FindFirstChild("Handle") then
			self:Explode(self.Tool.Handle)
		end
		if self.Cast then self.Cast:Terminate() end
	end)

	-- Handle tool being unequipped
	self.Tool.Unequipped:Connect(function()
		self.HoldingPlayerCharacter = nil
		if self.Tool and self.Tool:FindFirstChild("Handle") then
			-- Disable collision for the tool handle when unequipped
			self.Tool.Handle.CanCollide = false
		end
	end)

	-- Handle throw action via bridge
	ThrowBridge:Connect(function(Player, MousePosition)
		if not Player then return end
		if Player and Player.Name == self.HoldingPlayerCharacter.Name then
			-- Trigger the throw action if the player is holding the tool
			self:Throw(MousePosition, SimulationSettings.Speed)
			self.Tool:Destroy()
		end
	end)

	return self
end

--[[
    @function Destroy
    @within GrenadeModule
    Cleans up and destroys the module instance.
]]
function GrenadeModule:Destroy()
	self.Tool:Destroy()
	self.Tool = nil
	self.HoldingPlayerCharacter = nil
	self.Bind = nil
	self.Caster = nil
	self.Cast = nil
	self.Tick = nil
	self = nil
end

--[[
    @function PlaySound
    @within GrenadeModule
    Placeholder function for playing sound.
]]
function GrenadeModule:PlaySound()
	-- Implementation for playing sound
end

--[[
    @function MakeVfx
    @within GrenadeModule
    Placeholder function for creating visual effects.
]]
function GrenadeModule:MakeVfx()
	-- Implementation for making visual effects
end

--[[
    @function Reflect
    @within GrenadeModule
    @param SurfaceNormal Vector3 -- The normal vector of the surface the object hits.
    @param PartVector Vector3 -- The incoming vector of the object.
    @return Vector3 -- The reflected vector.
    Reflects the incoming vector based on the surface normal.
]]
function GrenadeModule.Reflect(SurfaceNormal, PartVector)
	-- Reflect the incoming vector off the surface normal
	return PartVector - (2 * PartVector:Dot(SurfaceNormal) * SurfaceNormal)
end

--[[
    @function Explode
    @within GrenadeModule
    @param Bullet Instance -- The bullet instance that triggers the explosion.
    Handles the explosion logic.
]]
function GrenadeModule:Explode(Bullet)
	-- Create and configure an explosion instance
	local Explosion = Instance.new("Explosion", Workspace)
	Explosion.BlastRadius = 20
	Explosion.TimeScale = 0.5
	Explosion.BlastPressure = 0
	Explosion.Position = Bullet.Position
	Bullet:Destroy()
	self:Destroy()
end

--[[
    @function Throw
    @within GrenadeModule
    @param MousePosition Vector3 -- The position of the mouse when the throw action is triggered.
    @param Speed number -- The speed at which the grenade is thrown.
    Handles the throw action logic.
]]
function GrenadeModule:Throw(MousePosition, Speed)
	local Position = self.Tool.Handle.Position
	local Direction = (MousePosition - Position).Unit
	local HumanoidRootPart = self.HoldingPlayerCharacter.HumanoidRootPart
	local NewSpeed = Direction * Speed
	-- Fire the cast with the initial position, direction, and speed
	self.Cast = self.Caster:Fire(Position, Direction, NewSpeed, self.CastBehavior)
	self.Cast.UserData.Bounces = 0
	self.Tick = tick() -- Record the current time
end

-- Create a new grenade instance with settings
local Grenade = GrenadeModule.new(require(ReplicatedStorage.Grenade.Setting))

-- Return the module
return GrenadeModule
