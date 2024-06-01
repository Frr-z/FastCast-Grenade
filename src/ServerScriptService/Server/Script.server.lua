for i, v in pairs(script.Parent:GetChildren()) do
    if v:IsA("ModuleScript") then
        require(v)
    end
end