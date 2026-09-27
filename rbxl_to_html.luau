--[[ Place file -> one self-contained HTML explorer (open it in any browser, works offline).

     lune run lune/rbxl_to_html.luau [Heavensunder.rbxl] [Heavensunder_explorer.html]

     Explorer tree like Studio, search by name/class, properties of the selected instance, full
     script source. Good for looking around without Studio, and for sharing with people/AIs that
     can open HTML.
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")

local placePath = process.args[1] or "Heavensunder.rbxl"
local outPath = process.args[2] or "Heavensunder_explorer.html"
local game = roblox.deserializePlace(fs.readFile(placePath))

local PROPS = { "Size", "CFrame", "Color", "Material", "Transparency", "Reflectance", "Anchored", "CanCollide", "CanQuery",
	"CanTouch", "Massless", "CastShadow", "Shape", "Part0", "Part1", "C0", "C1", "Value", "Text", "TextColor3", "TextSize",
	"BackgroundColor3", "BackgroundTransparency", "Enabled", "Brightness", "Range", "PrimaryPart", "HipHeight", "WalkSpeed",
	"MaxHealth", "RigType", "DisplayName", "ActionText", "ObjectText", "HoldDuration", "MaxActivationDistance",
	"KeyboardKeyCode", "Attachment0", "Attachment1", "Texture", "Rate", "Lifetime", "Speed", "Width0", "Width1",
	"StudsOffset", "AlwaysOnTop", "MaxDistance", "ClockTime", "TimeOfDay", "Ambient", "OutdoorAmbient",
	"FogEnd", "FogColor", "Density", "Haze", "Glare", "Cover", "Intensity", "Saturation", "Contrast", "TintColor",
	"Disabled", "RunContext", "Gravity", "Adornee", "Face", "Visible", "ZIndex", "Position", "AnchorPoint", "Image" }

local function fmt(v)
	local t = typeof(v)
	if t == "CFrame" then
		local x, y, z = v.Position.X, v.Position.Y, v.Position.Z
		local rx, ry, rz = v:ToOrientation()
		return string.format("pos (%.3f, %.3f, %.3f)  rot° (%.1f, %.1f, %.1f)", x, y, z, math.deg(rx), math.deg(ry), math.deg(rz))
	elseif t == "Vector3" then
		return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
	elseif t == "Color3" then
		return string.format("#%02x%02x%02x", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	elseif t == "Instance" then
		return v:GetFullName()
	elseif t == "number" then
		return string.format("%.4g", v)
	end
	return tostring(v)
end

local _db = roblox.getReflectionDatabase()
local _known = {}
-- Lune crashes (not just errors) when reading properties of classes missing from its API database (e.g. Packages)
local function knownClass(inst)
	local c = inst.ClassName
	if _known[c] == nil then _known[c] = _db:GetClass(c) ~= nil end
	return _known[c]
end
local nodes = {}
local ids = 0
local function add(inst, parentId)
	ids += 1
	local id = ids
	local props = {}
	for _, n in (knownClass(inst) and PROPS or {}) do
		local ok, v = pcall(function() return inst[n] end)
		if ok and v ~= nil and (n ~= "Position" or not inst:IsA("BasePart")) then
			props[#props + 1] = { n, fmt(v) }
		end
	end
	local ok, attrs = pcall(function() return knownClass(inst) and inst:GetAttributes() or {} end)
	if ok then for k, v in attrs do props[#props + 1] = { "@" .. k, fmt(v) } end end
	local node = { id, parentId, inst.Name, inst.ClassName, props }
	if knownClass(inst) and inst:IsA("LuaSourceContainer") then node[6] = inst.Source end
	nodes[#nodes + 1] = node
	for _, c in inst:GetChildren() do add(c, id) end
end
for _, service in game:GetChildren() do add(service, 0) end

local json = serde.encode("json", nodes)
json = string.gsub(json, "</", "<\\/")

local HTML = [==[<!doctype html><html><head><meta charset="utf-8"><title>@@TITLE@@</title>
<style>
body{margin:0;font:13px system-ui,Segoe UI,Arial;background:#1e2227;color:#d8dee4;display:flex;height:100vh}
#left{width:42%;min-width:300px;border-right:1px solid #333;display:flex;flex-direction:column}
#right{flex:1;overflow:auto;padding:10px 16px}
#bar{padding:8px;border-bottom:1px solid #333;display:flex;gap:6px}
#q{flex:1;padding:6px;background:#111;border:1px solid #444;color:#ddd;border-radius:4px}
#tree{overflow:auto;flex:1;padding:4px 0}
.row{white-space:nowrap;cursor:pointer;padding:1px 4px}
.row:hover{background:#2a3038}.sel{background:#264f78!important}
.tw{display:inline-block;width:14px;color:#888}.cls{color:#7aa2c8;margin-left:6px;font-size:11px}
.cnt{color:#777;font-size:11px;margin-left:4px}
table{border-collapse:collapse;margin:8px 0}td{padding:2px 10px 2px 0;vertical-align:top}td:first-child{color:#9aa5b1}
pre{background:#111;padding:10px;border-radius:4px;overflow:auto;font:12px Consolas,monospace;color:#cfe}
h2{margin:4px 0;font-size:16px}.path{color:#888;font-size:12px;word-break:break-all}
.sw{display:inline-block;width:12px;height:12px;border:1px solid #555;vertical-align:middle;margin-right:4px}
#info{color:#888;font-size:12px;padding:0 8px 6px}
</style></head><body>
<div id="left"><div id="bar"><input id="q" placeholder="Search name or class (e.g. Lantern, Motor6D, Script)…"></div>
<div id="info"></div><div id="tree"></div></div>
<div id="right"><h2>@@TITLE@@</h2><p>Click an instance on the left. Search matches names and class names.</p></div>
<script id="data" type="application/json">@@DATA@@</script>
<script>
const N=JSON.parse(document.getElementById('data').textContent);const by={},kids={};
for(const n of N){by[n[0]]=n;(kids[n[1]]=kids[n[1]]||[]).push(n[0]);}
const desc={};function dc(id){let c=0;for(const k of (kids[id]||[]))c+=1+dc(k);return desc[id]=c}for(const r of kids[0])dc(r);
const tree=document.getElementById('tree'),right=document.getElementById('right'),open=new Set();let sel=null;
document.getElementById('info').textContent=N.length.toLocaleString()+' instances';
function esc(s){return String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]))}
function path(id){const p=[];while(id){p.unshift(by[id][2]);id=by[id][1]}return p.join('.')}
function render(){const out=[];const walk=(id,d)=>{const n=by[id],k=kids[id]||[];
 out.push(`<div class="row${sel===id?' sel':''}" data-id="${id}" style="padding-left:${d*14+4}px"><span class="tw">${k.length?(open.has(id)?'▾':'▸'):''}</span>${esc(n[2])}<span class="cls">${n[3]}</span>${k.length?`<span class="cnt">${desc[id]}</span>`:''}</div>`);
 if(open.has(id)){if(k.length>400&&!n.all){for(const c of k.slice(0,400))walk(c,d+1);out.push(`<div class="row" data-more="${id}" style="padding-left:${(d+1)*14+4}px">… ${k.length-400} more (click)</div>`)}else for(const c of k)walk(c,d+1)}};
 for(const r of kids[0])walk(r,0);tree.innerHTML=out.join('')}
function show(id){sel=id;const n=by[id];let h=`<h2>${esc(n[2])} <span class="cls">${n[3]}</span></h2><div class="path">${esc(path(id))}</div><table>`;
 for(const [k,v] of (Array.isArray(n[4])?n[4]:[])){const sw=/^#[0-9a-f]{6}$/.test(v)?`<span class="sw" style="background:${v}"></span>`:'';h+=`<tr><td>${esc(k)}</td><td>${sw}${esc(v)}</td></tr>`}
 h+='</table>';const k=kids[id]||[];if(k.length){const c={};for(const x of k)c[by[x][3]]=(c[by[x][3]]||0)+1;h+='<div class="path">Children: '+Object.entries(c).map(([a,b])=>b+'× '+a).join(', ')+'</div>'}
 if(n[5]!==undefined)h+=`<pre>${esc(n[5])}</pre>`;right.innerHTML=h;render()}
tree.onclick=e=>{const r=e.target.closest('.row');if(!r)return;if(r.dataset.more){by[r.dataset.more].all=true;render();return}
 const id=+r.dataset.id;if(e.target.classList.contains('tw')||(kids[id]||[]).length&&sel===id){open.has(id)?open.delete(id):open.add(id)}show(id)};
document.getElementById('q').oninput=e=>{const q=e.target.value.trim().toLowerCase();if(!q){render();return}
 const m=N.filter(n=>n[2].toLowerCase().includes(q)||n[3].toLowerCase()===q).slice(0,500);
 tree.innerHTML=m.map(n=>`<div class="row" data-hit="${n[0]}">${esc(n[2])}<span class="cls">${n[3]}</span><div class="path">${esc(path(n[0]))}</div></div>`).join('')||'<div class="row">no match</div>';
 tree.querySelectorAll('[data-hit]').forEach(r=>r.onclick=()=>{const id=+r.dataset.hit;let p=by[id][1];while(p){open.add(p);p=by[p][1]}document.getElementById('q').value='';show(id);
  const el=tree.querySelector(`[data-id="${id}"]`);if(el)el.scrollIntoView({block:'center'})})};
render();
</script></body></html>]==]

local title = "Heavensunder - " .. string.match(placePath, "[^/\\]+$")
local html = string.gsub(HTML, "@@TITLE@@", function() return title end)
html = string.gsub(html, "@@DATA@@", function() return json end)
fs.writeFile(outPath, html)
print(string.format("wrote %s (%d instances, %.1f MB)", outPath, #nodes, #html / 1e6))
