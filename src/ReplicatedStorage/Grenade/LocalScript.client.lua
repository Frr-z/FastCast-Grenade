local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BridgeNet = require(ReplicatedStorage.BridgeNet)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local Tool = script.Parent
local Bind = Tool.Bind

local ThrowBridge = BridgeNet.CreateBridge("ThrowBridge")

local Debounce = false


Mouse.Button1Down:Connect(function()
	if Tool.Parent:IsA("Model")  and Debounce == false then
		Debounce = true
		ThrowBridge:Fire(Mouse.Hit.Position)		
	end
end)
