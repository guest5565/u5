-- Pure viewport policy. Root HUD stays in native pixels; only modals scale.
local Layout={}
function Layout.ModalScale(width,height,panelWidth,panelHeight)
 return math.min(1,math.max(.1,(width-28)/panelWidth),math.max(.1,(height-36)/panelHeight))
end
function Layout.StatsY(width) return width<950 and -164 or -114 end
function Layout.HotbarScale(width) return math.min(1,math.max(.5,(width-20)/436)) end
function Layout.ShowLocation(width) return width>=680 end
function Layout.ShowHelp(width) return width>=430 end
function Layout.PromptY(width) return width<950 and -220 or -115 end
function Layout.ToastY(width) return width<950 and -286 or -146 end
return table.freeze(Layout)
