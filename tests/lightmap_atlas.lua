-- Run from the NikNaks root: lua tests/lightmap_atlas.lua
-- Exercise atlas pixels through the public API without a graphics device.
function isfunction(v) return type(v) == 'function' end
function istable(v) return type(v) == 'table' end
function math.Clamp(v, lo, hi) return math.min(math.max(v, lo), hi) end
NikNaks = { __metatables = { BSP = {} } }
local current, color, material
local targets = {}
local function target(name)
	local rt = { pixels = {}, name = name }
	function rt:GetName() return self.name end
	targets[name] = rt
	return rt
end
render = {
	PushRenderTarget = function(rt) assert(not current) current = rt end,
	PopRenderTarget = function() current = nil end,
	Clear = function() current.pixels = {} end,
}
cam = { Start2D = function() end, End2D = function() end }
surface = {}
function surface.SetDrawColor(r, g, b) color = { r, g, b } end
function surface.DrawRect(x, y, w, h)
	for py = y, y + h - 1 do
		for px = x, x + w - 1 do current.pixels[py .. ':' .. px] = { unpack(color) } end
	end
end
function surface.SetMaterial(value) material = value end
function CreateMaterial(_, _, values) return values end
function surface.DrawTexturedRectUV(x, y, w, h, u0, v0)
	local rt = assert(targets[material['$basetexture']])
	for py = 0, h - 1 do
		for px = 0, w - 1 do
			local src = assert(rt.pixels[(v0 * rt.height + py) .. ':' .. (u0 * rt.width + px)])
			local key = (y + py) .. ':' .. (x + px)
			local dst = material['$additive'] and current.pixels[key] or { 0, 0, 0 }
			local result = {}
			for c = 1, 3 do result[c] = dst[c] + src[c] * color[c] / 255 end
			current.pixels[key] = result
		end
	end
end
dofile('lua/niknaks/modules/cl_lightmap_atlas.lua')

local function run(raw, options, styles, bumped, srgbToLinear)
	local face = { __id = 0, lightofs = 0, styles = styles or { 0, 255, 255, 255 }, LightmapTextureSizeInLuxels = { 1, 0 } }
	function face:HasTexInfoFlag() return bumped == true end
	local bsp = { _lumpheader = { [8] = { filelen = #raw }, [53] = { filelen = #raw } } }
	function bsp:GetLumpString() return raw end
	function bsp:GetFacesHDRLighting() return { [0] = { lightofs = 0, styles = face.styles } } end
	options = options or {}
	options.width, options.maxHeight, options.smoothing, options.desaturate = 16, 16, 1, 0
	local atlas = assert(NikNaks.LightmapAtlas(bsp, { [0] = face }, options))
	local rt, layer = target('atlas'), target('layers')
	rt.width, rt.height = atlas:GetSize()
	layer.width, layer.height = atlas:GetLayerSize()
	atlas:Write(rt, layer.width and layer or false, srgbToLinear)
	local us, vs = atlas:GetLightUV()(face, { { u1 = 0, v1 = 0 }, { u1 = 0.5, v1 = 0 } })
	local function pixel(i) return rt.pixels[math.floor(vs[i] * rt.height) .. ':' .. math.floor(us[i] * rt.width)] end
	return pixel(1), pixel(2), atlas, rt
end
local black, lit, redError = string.char(0, 0, 0, 0), string.char(128, 128, 128, 0), string.char(255, 0, 0, 8)
for _, hdr in ipairs({ false, true }) do
	local a, b = run(black .. black, { hdr = hdr })
	assert(a[1] == 0 and b[1] == 0, 'a fully dark face became fullbright')
	a, b = run(black .. lit, { hdr = hdr })
	assert(a[1] == 0 and b[1] > 0, 'a shadow boundary was filled with neighboring light')
	a, b = run(redError .. lit, { hdr = hdr })
	assert(a[1] == b[1] and b[1] > 0, 'explicit VRAD error repair regressed')
end
local a, b = run(lit .. lit, { lightToggle = { [32] = 0 } }, { 32, 255, 255, 255 })
assert(a[1] == 0 and b[1] == 0, 'a switched-off light became fullbright')
a, b = run(lit)
assert(a[1] == b[1] and a[1] > 0, 'a missing sample was not repaired from its neighbor')
a, b = run(string.char(0))
assert(a[1] == 128 and b[1] == 128, 'a wholly missing lightmap lost its unlit fallback')
local atlas, rt
a, b, atlas, rt = run(black .. black .. lit .. lit,
	{ animatedStyles = { [32] = true }, lightToggle = { [32] = 0 }, layerWidth = 16 }, { 0, 32, 255, 255 })
assert(a[1] == 0 and b[1] == 0, 'an animated face lost its dark base')
atlas:Update({ [32] = 1 })
assert(rt.pixels['0:2'][1] > 0, 'the animated light did not turn on')
atlas:Update({ [32] = 0 })
assert(rt.pixels['0:2'][1] == 0, 'the animated light did not return to black')
print('lightmap atlas shadow tests passed')

-- A bumped face contains a flat map followed by three independent directional
-- maps. A second style starts after all four, not after the flat map alone.
local red, green, blue = string.char(128,0,0,0), string.char(0,128,0,0), string.char(0,0,128,0)
local dim = string.char(32,32,32,0)
a,b,atlas,rt=run(dim..dim..red..red..green..green..blue..blue,nil,nil,true)
local rect=atlas._rects[0]
local function setPixel(k)return rt.pixels[rect.y..':'..(rect.x+k*rect.w)]end
assert(rect.sets==4 and rect.pw==rect.w*4,'directional maps were not allocated')
assert(setPixel(1)[1]>0 and setPixel(1)[2]==0,'first bump direction lost red light')
assert(setPixel(2)[2]>0 and setPixel(2)[1]==0,'second bump direction lost green light')
assert(setPixel(3)[3]>0 and setPixel(3)[1]==0,'third bump direction lost blue light')
local face={__id=0}
local us,vs,du,dv=atlas:GetLightUV()(face,{{u1=0,v1=0}})
assert(du[1]==rect.w/rt.width and dv[1]==0,'bump UV offset does not match packed sets')

local dark=black..black..black..black..black..black..black..black
a,b,atlas,rt=run(dark..dim..dim..red..red..green..green..blue..blue,
	{animatedStyles={[32]=true},lightToggle={[32]=0},layerWidth=16},{0,32,255,255},true)
rect=atlas._rects[0]
atlas:Update({[32]=1})
assert(setPixel(1)[1]>0 and setPixel(2)[2]>0 and setPixel(3)[3]>0,'animated style skipped directional sets')
atlas:Update({[32]=0})
assert(setPixel(1)[1]==0 and setPixel(2)[2]==0 and setPixel(3)[3]==0,'animated directions failed to return to black')

-- Float render targets receive gamma-decoded surface colors. Reproduce that
-- write and compare the result with Source's native LDR sRGB sampler, including
-- its linear toe where the old conversion crushed dark green and blue.
local color=string.char(35,8,1,0)
local encoded=run(color..color,nil,nil,false,false)
local converted=run(color..color,nil,nil,false,true)
for channel=1,3 do
	local c=encoded[channel]/255
	local expected=c<=.04045 and c/12.92 or ((c+.055)/1.055)^2.4
	local actual=(converted[channel]/255)^2.2
	assert(math.abs(actual-expected)<.001,'LDR float output differs from native sRGB lightmap')
end
assert(converted[3]>encoded[3],'dark blue was still crushed by gamma 2.2')
print('lightmap directional sets, style stride, bump UVs and native LDR transfer tests passed')

-- Native LDR RNM upload: gamma-correct the flat sample, then preserve the
-- LINEAR ratios of its directional lobes in encoded space. A normal-map
-- highlight must retain that ratio instead of being flattened by gamma.
local flat=string.char(32,16,8,0)
local low=string.char(16,8,4,0)
local mid=string.char(32,16,8,0)
local high=string.char(48,24,12,0)
a,b,atlas,rt=run(flat..flat..low..low..mid..mid..high..high,nil,nil,true)
rect=atlas._rects[0]
for channel,raw in ipairs({32,16,8})do
	local q=math.floor(raw/255*1024+.5)/1024
	local encoded=255*q^(1/2.2)
	for direction=1,3 do
		local expected=math.floor(encoded*(direction*.5)*.5+.5)
		assert(setPixel(direction)[channel]==expected,'directional light ratio was gamma-corrected twice')
	end
end
-- An overflowing red lobe shares excess with the other directions, preserving
-- brightness rather than silently clipping it out of the lightmap.
a,b,atlas,rt=run(lit..lit..red..red..green..green..blue..blue,nil,nil,true)
rect=atlas._rects[0]
assert(setPixel(1)[2]>0 and setPixel(2)[1]>0,'over-range lobe energy was discarded')
print('native LDR RNM balance and bright-lobe redistribution passed')
