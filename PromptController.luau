-- Custom presentation for authoritative Roblox ProximityPrompts. No fake remote trigger.
local Service = game:GetService('ProximityPromptService')
local Input = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local Controller = {}
local current, began, holding = nil, 0, false
function Controller.GamepadActive()
 return current ~= nil and string.find(Input:GetLastInputType().Name, 'Gamepad') ~= nil
end
function Controller.Start(panel, blocked)
 local function release()
  if current and holding then current:InputHoldEnd() end
  holding=false;began=0
 end
 Service.PromptShown:Connect(function(prompt, inputType)
  release(); current=prompt
  panel.Action.Text='HOLD · '..prompt.ActionText
  panel.Object.Text=prompt.ObjectText
  panel.Key.Text=inputType==Enum.ProximityPromptInputType.Gamepad and 'X' or inputType==Enum.ProximityPromptInputType.Touch and 'HOLD' or 'E'
 end)
 Service.PromptHidden:Connect(function(prompt) if current==prompt then release();current=nil;panel.Visible=false end end)
 Service.PromptButtonHoldBegan:Connect(function(prompt) if current==prompt then began=os.clock();holding=true end end)
 Service.PromptButtonHoldEnded:Connect(function(prompt) if current==prompt then holding=false;began=0 end end)
 Service.PromptTriggered:Connect(function(prompt) if current==prompt then holding=false;began=0 end end)
 panel.Key.InputBegan:Connect(function(input)
  if current and not blocked() and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then current:InputHoldBegin() end
 end)
 Input.InputEnded:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then release() end
 end)
 Input.WindowFocusReleased:Connect(release)
 RunService.RenderStepped:Connect(function()
  local hidden=blocked();Service.Enabled=not hidden
  panel.Visible=not hidden and current~=nil and current.Parent~=nil
  if hidden then release() end
  local fraction=holding and current and math.clamp((os.clock()-began)/math.max(.05,current.HoldDuration),0,1) or 0
  panel.Progress.Fill.Size=UDim2.fromScale(fraction,1)
 end)
end
return Controller
