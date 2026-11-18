-- Run from the NikNaks root: lua tests/mesh_lighting.lua
local v={}v.__index=v
function Vector(x,y,z)return setmetatable({x=x,y=y,z=z},v)end
function v.__sub(a,b)return Vector(a.x-b.x,a.y-b.y,a.z-b.z)end
function v.__mul(a,b)return Vector(a.x*b,a.y*b,a.z*b)end
function v.__div(a,b)return a*(1/b)end
function v:GetNormalized()local n=math.sqrt(self.x^2+self.y^2+self.z^2)return self/n end
function Color(r,g,b,a)return {r=r,g=g,b=b,a=a}end
color_white=Color(255,255,255,255)
bit={band=function(a,b)
	local result, place = 0, 1
	while a>0 and b>0 do
		if a%2==1 and b%2==1 then result=result+place end
		a,b,place=math.floor(a/2),math.floor(b/2),place*2
	end
	return result
end}
NikNaks={}
local mat={GetName=function()return 'lit/floor'end,GetShader=function()return 'LightmappedGeneric'end,GetInt=function()return 0 end}
function Material()return mat end
local built={}
function Mesh()local m={}built[#built+1]=m return m end
local current,vertex
mesh={Begin=function(m)current=m m.vertices={}vertex={}end,End=function()end}
for _,field in ipairs({'Normal','Position','TangentS','TangentT'})do mesh[field]=function(value)vertex[field]=value end end
function mesh.Color()end
function mesh.TexCoord(set,u,w)vertex[set]={u,w}end
function mesh.AdvanceVertex()current.vertices[#current.vertices+1]=vertex vertex={}end
dofile('lua/niknaks/modules/cl_mesh_builder.lua')
local verts={
	{pos=Vector(0,0,0),normal=Vector(0,0,1),u=0,v=0},
	{pos=Vector(10,0,0),normal=Vector(0,0,1),u=1,v=0},
	{pos=Vector(0,-10,0),normal=Vector(0,0,1),u=0,v=1},
}
local face={GenerateVertexTriangleData=function()return verts end,GetMaterial=function()return mat end,IsDisplacement=function()return false end}
local builder=NikNaks.MeshBuilder()
assert(builder:AddFace(face,{lightUV=function()return {.1,.2,.1},{.3,.3,.4},{.25,.25,.25},{0,0,0}end}))
builder:Build()
for _,vertex in ipairs(built[1].vertices)do
	assert(vertex.TangentS.x==1 and vertex.TangentT.y==-1,'texture-aligned tangent frame was lost')
	assert(vertex[2][1]==.25 and vertex[2][2]==0,'directional lightmap offset was not uploaded')
end
assert(built[1].vertices[2][1][1]==.2,'base lightmap UV was replaced by bump offset')
print('mesh lighting: texture tangents and directional lightmap channels passed')

local function alphaMaterial(shader, flags, secondTexture)
	return {GetShader=function()return shader end,
		GetInt=function(_,key)return key=='$flags' and flags or 0 end,
		GetTexture=function()return secondTexture end}
end
local blends = NikNaks.MeshBuilder.BlendsWithBackground
assert(blends(alphaMaterial('LightmappedGeneric',0x20)), 'fading world faces must blend')
assert(blends(alphaMaterial('WorldVertexTransition_DX9',0x20)), 'single-texture displacement alpha must blend')
local function texture(name)
	return {GetName=function()return name end,IsError=function()return false end}
end
assert(blends(alphaMaterial('WorldVertexTransition',0x20,texture('error'))), 'the engine placeholder is not a second layer')
assert(not blends(alphaMaterial('WorldVertexTransition',0x20,texture('terrain/rock'))),
	'two-texture terrain weights must keep opaque depth')
assert(not blends(alphaMaterial('UnlitGeneric',0x120)), 'alpha-tested surfaces must keep opaque depth')
print('mesh lighting: vertex fades, terrain weights, and alpha tests use the correct draw passes')
