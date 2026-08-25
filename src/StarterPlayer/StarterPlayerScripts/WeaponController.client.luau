--!strict
-- Keyboard/mouse is one adapter over abstract actions; controller/mobile can dispatch the same packets.
local Players=game:GetService("Players"); local CAS=game:GetService("ContextActionService")
local remote=game.ReplicatedStorage.MechFramework.Remotes.Events.RequestControlAction
local player=Players.LocalPlayer; local sequence=0
local bindings={Primary={Enum.UserInputType.MouseButton1},Secondary={Enum.UserInputType.MouseButton2},UtilityQ={Enum.KeyCode.Q},UtilityE={Enum.KeyCode.E},Reload={Enum.KeyCode.R},Mechanism1={Enum.KeyCode.One},Mechanism2={Enum.KeyCode.Two}}
local function dispatch(action,state)
	local mechId=player:GetAttribute("ActiveMechId"); if type(mechId)~="string" then return end
	sequence+=1; local mouse=player:GetMouse(); local camera=workspace.CurrentCamera
	remote:FireServer({MechId=mechId,Action=action,Active=state~=Enum.UserInputState.End,Sequence=sequence,Aim={Origin=camera and camera.CFrame.Position,Direction=(mouse.Hit.Position-(camera and camera.CFrame.Position or Vector3.zero)).Unit}})
end
for action,inputs in bindings do CAS:BindAction("Mech_"..action,function(_,state) dispatch(action,state); return Enum.ContextActionResult.Sink end,true,table.unpack(inputs)) end