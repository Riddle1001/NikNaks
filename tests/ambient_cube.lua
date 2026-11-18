-- GLuaTest: exercises the public API with synthetic RGBExp32 samples.
local function sample(r, g, b, exponent, x)
	local cube = {}
	for side = 1, 6 do cube[side] = {r = r, g = g, b = b, exponent = exponent} end
	return {cube = cube, x = x or 0, y = 0, z = 0}
end
local function cube(samples, at, hdr)
	local leaf = setmetatable({mins = Vector(), maxs = Vector(255, 255, 255),
		GetAmbientLighting = function(_, requested) assert(requested == hdr) return samples end},
		{__index = NikNaks.__metatables["BSP Leaf"]})
	return leaf:CalculateAmbientCube(at or Vector(), hdr)
end
return {groupName = "Ambient cube linear irradiance", cases = {
	{name = "RGBExp32 mantissas retain their magnitude", func = function()
		local result = cube({sample(128, 64, 32, -7)})
		for side = 1, 6 do
			assert(result[side].r == 1 and result[side].g == 0.5 and result[side].b == 0.25)
		end
	end},
	{name = "HDR and interpolation preserve black and overbright light", func = function()
		local result = cube({sample(0, 0, 0, 0, 0), sample(128, 64, 32, -5, 100)}, Vector(50, 0, 0), true)
		assert(result[1].r == 2 and result[1].g == 1 and result[1].b == 0.5)
		assert(cube({}) == nil)
	end},
}}
