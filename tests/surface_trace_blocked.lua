-- Standalone regression checks: lua tests/surface_trace_blocked.lua
local vector={} vector.__index=vector
function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},vector) end
function vector.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
function vector.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
function vector.__mul(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
function vector.__div(a,b) return a*(1/b) end
function vector:Length() return math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z) end
function vector:GetNormalized() local n=self:Length();return n>0 and self/n or Vector() end
function vector:Normalize() local n=self:Length();if n>0 then self.x,self.y,self.z=self.x/n,self.y/n,self.z/n end end
function vector:Distance(b) return (self-b):Length() end
bit={band=function(a,b)
    local result,power=0,1
    while a>0 and b>0 do
        if a%2==1 and b%2==1 then result=result+power end
        a,b,power=math.floor(a/2),math.floor(b/2),power*2
    end
    return result
end}
local bspMeta,faceMeta={},{ }
NikNaks={__metatables={BSP=bspMeta,['BSP Faces']=faceMeta,['BSP Leaf']={},['BSP Brush']={}}}
dofile('lua/niknaks/modules/sh_bsp_trace.lua')
local function face(x,normal,flags)
    local f={plane={nx=normal,ny=0,nz=0,dist=x*normal,normal=Vector(normal,0,0)},flags=flags or 1}
    function f:GetVertexs() return {Vector(x,-4,-4),Vector(x,4,-4),Vector(x,4,4),Vector(x,-4,4)} end
    function f:GetTexInfo() return {flags=self.flags} end
    function f:IsSkyBox3D() return false end
    function f:IsSkyBox() return false end
    return f
end
local function map(faces,records)
    local leaf={GetFaces=function() return faces end}
    return setmetatable({_dispTraceLeafs=records or {},
        GetNodes=function() return {[0]={plane={nx=1,ny=0,nz=0,dist=0,type=0},children={-1,-2}}} end,
        GetLeafs=function() return {[0]=leaf,[1]=leaf} end}, {__index=bspMeta})
end
local function equal(m,a,b,mask,ignore)
    local expected=not not m:SurfaceTraceLine(a,b,mask,ignore).Hit
    local actual=m:SurfaceTraceBlocked(a,b,mask,ignore)
    assert(type(actual)=='boolean' and actual==expected,'occlusion differs from full surface trace')
    return actual
end
local start,finish=Vector(-10,0,0),Vector(10,0,0)
assert(not equal(map({}),start,finish),'empty space is blocked')
assert(equal(map({face(2,-1)}),start,finish),'front-facing wall was missed')
assert(not equal(map({face(2,1)}),start,finish),'back-facing wall blocked the ray')
assert(equal(map({face(2,1)}),finish,start),'reversed front-facing wall was missed')
assert(not equal(map({face(2,-1)}),Vector(-10,8,0),Vector(10,8,0)),'polygon bounds ignored')
assert(not equal(map({face(2,-1)}),start,start),'zero-length segment hit a face')
assert(not equal(map({face(10,-1)}),start,finish),'segment endpoint counted as an obstruction')
assert(not equal(map({face(-10,-1)}),start,finish),'segment start counted as an obstruction')
local masked=map({face(2,-1,2)})
assert(not equal(masked,start,finish,1),'nonmatching surface mask blocked the ray')
assert(equal(masked,start,finish,2),'matching surface mask missed the wall')
assert(not equal(masked,start,finish,0),'empty surface mask hit the wall')

-- Boolean queries must not construct hit metadata or scan faces after a hit.
local first,second=face(2,-1),face(6,-1)
first.IsSkyBox=function() error('boolean trace requested sky metadata') end
first.GetTexInfo=function() error('unmasked boolean trace requested surface metadata') end
second.GetVertexs=function() error('boolean trace did not stop at first obstruction') end
assert(map({first,second}):SurfaceTraceBlocked(start,finish))

-- The full API must still find the closest hit, even when a farther face is first.
local near,far=face(2,-1),face(6,-1)
local mixed=map({far,near})
assert(equal(mixed,start,finish))
local full=mixed:SurfaceTraceLine(start,finish)
assert(full.Face==near and math.abs(full.HitPos.x-2)<1e-6 and math.abs(full.Fraction-.6)<1e-6)
assert(full.HitNormal.x==-1 and full.SurfaceFlags==1 and full.HitSky==false)

-- A real 2x2 displacement grid, shared by two leaves. Alternate APIs/directions
-- to catch reuse of an early-out distance/normal by a subsequent full trace.
local rec={xyz={0,-4,-4, 0,4,-4, 0,-4,4, 0,4,4},width=2,winding=1,flags=4,
    minx=0,miny=-4,minz=-4,maxx=0,maxy=4,maxz=4,traceId=-1,face=face(0,-1,4)}
local displaced=map({}, {[0]={rec},[1]={rec}})
assert(equal(displaced,start,finish),'displacement failed to block')
assert(not equal(displaced,start,finish,nil,true),'ignoreDisplacements was ignored')
assert(not equal(displaced,start,finish,1),'displacement mask was ignored')
assert(equal(displaced,start,finish,4),'matching displacement was missed')
assert(not equal(displaced,finish,start),'back-facing displacement blocked the ray')
assert(displaced:SurfaceTraceBlocked(start,finish))
local after=displaced:SurfaceTraceLine(start,finish)
assert(after.Hit and math.abs(after.Fraction-.5)<1e-6 and after.HitNormal.x==-1 and after.SurfaceFlags==4)
assert(not equal(displaced,Vector(-10,8,0),Vector(10,8,0)),'displacement bounds were ignored')

-- Deterministic rays across both child branches, outside and along polygon edges.
for y=-5,5 do for z=-5,5 do
    equal(mixed,Vector(-10,y,z),Vector(10,y,z))
    equal(displaced,Vector(-10,y,z),Vector(10,y,z))
end end
print('SurfaceTraceBlocked: masks, winding, endpoints, early exit, nearest-hit preservation and displacements passed')
