return {
	["SimulationSettings"] = {
		Speed = 80, 
		TimeUntilExplosion = 4.5, 
		MaxBounces = 4, 
		Elasticity = 0.5, -- Momentum reduction factor; set to 1 to maintain momentum
	},
	["CastBehaviorSettings"] = {
		MaxDistance = 200, -- Maximum ray distance
		Projectile = game.ReplicatedStorage.Grenade.Handle, -- Object to be thrown
		ProjectileContainer = workspace, -- Parent container for projectiles
		Acceleration = Vector3.new(0, -workspace.Gravity, 0), -- Acceleration vector
		CanPierceFunction = function() -- Determines behavior on collision (bounce again, explode, etc.)
			return true
		end,
	},
	["OtherSettings"] = {
		ToolInstance = game.ReplicatedStorage.Grenade, -- Instance of the tool
		ToolName = nil, -- If nil, defaults to ToolInstance.Name 
		SpawnWhenCreatedOn = workspace, -- Parent for cloned ToolInstance
		FilterCharacter = true -- Disable collision with the player who threw the projectile
	}
}