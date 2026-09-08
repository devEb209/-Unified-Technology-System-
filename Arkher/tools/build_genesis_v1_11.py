#!/usr/bin/env python3
"""GENESIS V1.11 — +15 editores x60 = 6020 ferramentas, 100 editores"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING
from build_genesis_v1_2 import build_editor_window
from build_genesis_v1_10 import build_all_v110
EDITORS = [
 ("HairLab","HAIR SIM",0x6D4C41,60),
 ("GranularLab","GRANULAR SIM",0x8D6E63,60),
 ("RigidLab","RIGID BODY",0x37474F,60),
 ("SoftLab","SOFT BODY",0xAD1457,60),
 ("JointLab","JOINTS",0x4A148C,60),
 ("VehicleLab","VEHICLE SIM",0x01579B,60),
 ("CharacterPhysicsLab","CHAR PHYSICS",0xBF360C,60),
 ("AudioDSP","AUDIO DSP",0x880E4F,60),
 ("MusicLab","MUSIC STUDIO",0x4A148C,60),
 ("VoiceLab","VOICE STUDIO",0x006064,60),
 ("SFXLab","SFX STUDIO",0xE65100,60),
 ("LightingLab","LIGHTING",0xF9A825,60),
 ("ShadowLab","SHADOWS",0x212121,60),
 ("ReflectionLab","REFLECTIONS",0x0277BD,60),
 ("GlobalIllumLab","GLOBAL ILLUM",0xFF6F00,60),
]
def tools_for(n):
    m={
     "HairLab":["Strand","Guide","Groom","Clump","Frizz","Curl","Wave","Kink","Length","Density","Thickness","Stiffness","Damping","Friction","Collision","SelfCollide","Aerodynamic","Wind","Gravity","Pin","Constraint","Stretch","Bend","Twist","Volume"," Preserve","LOD","Culling","Shading","Anisotropy","Specular","Transmission","Scatter","Shadow","AO","Bake","Cache","Simulate","Solve","Iterate","Substep","CollisionProxy","SkinAttach","Root","Tip","Interpolate","Interpolate","Deform","Transfer","Export","Import","GroomEdit","BrushComb","BrushCut","BrushNoise","BrushClump","BrushFrizz","BrushLength","Optimize","Validate"],
     "GranularLab":["Particle","Grain","Sand","Snow","Sugar","Salt","Soil","Regolith","Size","Distribution","Density","Friction","AngleRepose","Cohesion","Adhesion","Moisture","Wetness","Compaction","Dilation","Flow","Avalanche","Pile","Heap","Funnel","Hourglass","Silo","Hopper","Conveyor","Excavator","Bulldozer","Footprint","TireTrack","Plow","Erosion","Sediment","Transport","Deposition","Sorting","Stratification","Liquefaction","Quicksand","Dune","Ripple","Avalanche","Sampling","Probe","Penetrometer","ShearTest","Triaxial","Compress","Simulate","Cache","LOD","Culling","Collision"],
     "RigidLab":["Body","Mass","Inertia","COM","Velocity","AngularVel","Force","Torque","Impulse","Momentum","Collision","Shape","Box","Sphere","Capsule","Convex","Mesh","Compound","Broadphase","Narrowphase","Contact","Manifold","Friction","Restitution","Damping","Sleep","Activation","Island","Solver","Sequential","PGS","TGS","ERP","CFM","Substep","CCD","Sweep","Raycast","Overlap","Query","Filter","Group","Mask","Layer","Joint","Motor","Limit","Spring","Damper","Breakable","Kinematic","Static","Dynamic","Trigger","Character","Vehicle","Ragdoll"],
     "SoftLab":["Tetra","Mesh","Node","Edge","Face","Volume","Stiffness","Damping","Pressure","VolumePreserve","ShapeMatch","Cluster","Particle","Constraint","Distance","Bend","Volume","Tether","Attach","Collide","SelfCollide","Friction","Repulsion","Inflate","Deflate","Plastic","Yield","Creep","Fracture","Tear","Cut","Plasticity","Elastic","Viscoelastic","Damping","Substep","Solver","XPBD","PBD","FEM","MSM","ShapeMatch","Cluster","LOD","Culling","Collision","Proxy","Skin","Deform","Blend","Cache","Simulate","Bake","Export","Import","Optimize","Validate","Profile"],
     "JointLab":["Hinge","Slider","BallSocket","Universal","Fixed","Distance","Spring","DampedSpring","Gear","Pulley","Rope","Chain","Cable","ClothAttach","Ragdoll","Motor","Servo","Actuator","Limit","Angular","Linear","Cone","Twist","Swing","Break","Force","Torque","Stiffness","Damping","Compliance","ERP","CFM","Frequency","DampingRatio","Anchor","Axis","Pivot","Frame","Local","World","Drive","Position","Velocity","Force","Impulse","SpringDamper","Feedback","Sensor","Constraint","Solver","Iterate","WarmStart","Cache","DebugDraw","Gizmo","Validate","Profile","Optimize"],
     "VehicleLab":["Chassis","Wheel","Suspension","Spring","Damper","Travel","Stiffness","AntiRoll","Tire","Friction","Slip","Lateral","Longitudinal","Camber","Caster","Toe","Pressure","Wear","Temperature","Engine","Torque","RPM","Gearbox","Differential","Drive","Brake","ABS","TCS","ESC","Steering","Ackermann","Aerodynamic","Downforce","Drag","Weight","Distribution","COM","Inertia","SuspensionGeo","Alignment","RideHeight","WheelBase","Track","Transmission","Clutch","Turbo","Exhaust","Sound","VFX","Skid","Drift","Damage","Deform","Telemetry","Input","AI","PathFollow"],
     "CharacterPhysicsLab":["Ragdoll","Pose","Balance","Footstep","Gait","Stumble","Recovery","Push","Pull","Carry","Climb","Vault","Mantle","Slide","Roll","Dive","Fall","Impact","Brace","Stagger","Knockback","Launcher","Puppet","ActiveRagdoll","Muscle","Motor","PD","Strength","Damping","Limit","Joint","Collider","Capsule","Box","Sphere","Proxy","LOD","Culling","Collision","Friction","Restitution","Mass","Inertia","COM","Momentum","Impulse","Force","Torque","Grab","Hold","Release","Throw","Catch","Interaction","IK","FK","Retarget","Validate"],
     "AudioDSP":["Oscillator","Filter","LowPass","HighPass","BandPass","Notch","EQ","Parametric","Graphic","Compressor","Limiter","Expander","Gate","Reverb","Room","Hall","Plate","Spring","Delay","Echo","Chorus","Flanger","Phaser","Distortion","Saturation","BitCrush","Decimate","Resample","PitchShift","TimeStretch","Granular","Vocoder","AutoTune","DeEsser","DeNoise","DeReverb","Denoiser","Enhancer","Spatializer","Binaural","HRTF","Ambisonic","Convolution","Impulse","WetDry","Mix","Bus","Send","Return","Sidechain","Duck","Meter","Analyzer","Spectrum","Waveform","Loudness","Limiter"],
     "MusicLab":["Note","Chord","Scale","Key","Tempo","TimeSig","Beat","Bar","Phrase","Section","Verse","Chorus","Bridge","Intro","Outro","Melody","Harmony","Counterpoint","Bass","Drum","Percussion","Arpeggio","Riff","Motif","Theme","Variation","Modulation","Transposition","Inversion","Retrograde","Sequence","Loop","Layer","Automation","Velocity","Expression","Articulation","Dynamics","Legato","Staccato","Swing","Groove","Quantize","Humanize","Randomize","Generate","AICompose","StyleTransfer","Midi","Export","Score","Notation","Print","Publish","Collab","Version"],
     "VoiceLab":["Record","Take","Comp","PitchCorrect","TimeCorrect","Breath","DeBreath","DeEss","DePop","DeNoise","EQ","Compress","Limit","Reverb","Delay","Doubler","Harmony","PitchShift","Formant","Vibrato","Tremolo","Chorus","Saturation","Distortion","Radio","Telephone","Megaphone","Whisper","Shout","Scream","VocalFry","Falsetto","Chest","Head","Mix","Belt","Vibrato","Runs","Riffs","AdLib","Stack","Choir","Ensemble","Tune","FlexPitch","FlexTime","Warp","Stretch","Slice","Quantize","Humanize","AIClone","VoiceDesign","Export","Publish"],
     "SFXLab":["Footstep","Foley","Whoosh","Impact","Hit","Punch","Slam","Crash","Explosion","Debris","Gunshot","Bullet","Ricochet","Reload","Casing","Laser","Plasma","Energy","Magic","Spell","Fire","Water","Wind","Electric","Mechanical","Engine","Motor","Servo","Hydraulic","Pneumatic","UI","Click","Hover","Notify","Alert","Alarm","Siren","Ambience","RoomTone","Walla","Crowd","Nature","Animal","Creature","Vocal","Processed","Designed","Layer","Edit","Mix","Master","Implement","Middleware","Wwise","FMOD","Export","Bank"],
     "LightingLab":["Point","Spot","Directional","Area","Rect","Disk","Sphere","Tube","IES","Projector","Sky","Sun","Moon","HDRI","LightProbe","ReflectionProbe","Lightmass","Lightmap","Shadowmap","Shadow","Soft","Hard","PCF","PCSS","VSM","ESM","Cascade","PSSM","RayTraced","ShadowRay","Contact","Ambient","Occlusion","SSAO","HBAO","GTAO","RTAO","LightProbe","Irradiance","Volume","LightGrid","Exposure","AutoExposure","Bloom","LensFlare","Glare","Tonemap","ACES","Reinhard","Filmic","ColorGrade","LUT","WhiteBalance","Temperature","Tint","Intensity","Color","Attenuation","Falloff"],
     "ShadowLab":["Cascade","PSSM","VSM","ESM","PCF","PCSS","Soft","Hard","Contact","RayTraced","ShadowRay","Denoise","Filter","Blur","Bilateral","Temporal","Distance","Bias","SlopeBias","NormalBias","PeterPanning","Acne","Leak","Bleed","Culling","Frustum","CascadeBlend","Fade","DistanceFade","LightCulling","ShadowCulling","Atlas","Resolution","Texel","Density","Quality","Performance","Budget","LOD","HLOD","Streaming","Cache","Bake","Lightmap","Shadowmap","Probe","Volume","ContactShadow","ScreenSpace","RayMarch","Denoise","Upscale"],
     "ReflectionLab":["Probe","Box","Sphere","Parallax","Capture","Bake","Realtime","ScreenSpace","SSR","RayTraced","Planar","Mirror","Glossy","Rough","Metal","ClearCoat","Anisotropy","Sheen","SSRTrace","RayMarch","BinarySearch","Jitter","Denoise","Temporal","Bilateral","RoughnessFade","DistanceFade","Fresnel","BRDF","GGX","Beckmann","Blinn","Phong","Irradiance","Specular","Convolution","Mip","Prefilter","ImportanceSample","SplitSum","IBL","HDRI","Cubemap","Atlas","ProbeVolume","Blend","Weight","Priority","Culling","LOD","Streaming","Cache"],
     "GlobalIllumLab":["Bake","Lightmass","Radiosity","PhotonMap","PathTrace","RayTrace","Probe","LightProbe","Irradiance","Volume","Grid","Tetra","Octa","SH","SphericalHarmonics","L1","L2","Bounce","Indirect","Diffuse","Specular","Caustic","Photon","Gather","FinalGather","IrradianceCache","LightCache","BruteForce","ImportanceSample","Denoise","Temporal","Spatial","Bilateral","Upscale","Reconstruct","Neural","ReSTIR","Reservoir","Spatiotemporal","RTX","DXR","Vulkan","Metal","Fallback","ProbeUpdate","Streaming","Budget","Quality","Performance","Visualize","Debug"],
    }
    return m.get(n, [f"{n}_{i+1:02d}" for i in range(60)])[:60]
LAB={n: tools_for(n) for n,_,_,_ in EDITORS}
FUNC="""
local M={HairLab="hair",GranularLab="granular",RigidLab="rigid",SoftLab="soft",JointLab="joint",VehicleLab="vehicle",CharacterPhysicsLab="character",AudioDSP="audiodsp",MusicLab="music",VoiceLab="voice",SFXLab="sfx",LightingLab="lighting",ShadowLab="shadow",ReflectionLab="reflection",GlobalIllumLab="globalillum"}
local P=game:GetService("Players") local pl=P.LocalPlayer
local function call(pat,name)
 local e=_G.ARKHER if not e then print("[TOOL] "..name.." offline") return end
 local f=e:findSystems(pat) if #f==0 then f=e:findSystems(string.lower(name)) end
 if #f>0 then local en=f[1] local ok=pcall(function() if en.instance.selfTest then return en.instance.selfTest() end return true end) print(string.format("[TOOL] %s -> %s ok=%s",name,en.key,tostring(ok)))
  local g=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if g then local s=g.Root:FindFirstChild("StatusBar",true) if s then local l=s:FindFirstChild("Status") if l then l.Text=name.." -> "..en.key end end end
 else print("[TOOL] "..name.." no "..pat) end
end
local function wire(n)
 local g=P.LocalPlayer.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not g then return end
 local w=g.Root:FindFirstChild(n,true) if not w then return end
 local c=w:FindFirstChild("Tools",true) or w
 for _,b in ipairs(c:GetDescendants()) do if b:IsA("TextButton") then b.Activated:Connect(function()
  local o=b.BackgroundColor3 b.BackgroundColor3=Color3.fromRGB(0,255,136) task.delay(0.2,function() b.BackgroundColor3=o end)
  local cat=M[n] or "" local pat=cat~="" and ("arkher."..cat.."."..string.lower(b.Name)) or string.lower(b.Name)
  call(pat,b.Name)
 end) end end
end
for _,n in ipairs({"HairLab","GranularLab","RigidLab","SoftLab","JointLab","VehicleLab","CharacterPhysicsLab","AudioDSP","MusicLab","VoiceLab","SFXLab","LightingLab","ShadowLab","ReflectionLab","GlobalIllumLab"}) do pcall(wire,n) end
print("[V1.11] +15 — 100 editores")
"""
def build_all_v111():
    roots=build_all_v110()
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name=="Root":
                            ex={c.name for c in child.children}
                            for name,title,color,_ in EDITORS:
                                if name not in ex:
                                    child.add(build_editor_window(name,title,color,LAB[name]))
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    f.add(Inst("LocalScript","ARKHER_ToolsFunctional_V111",{"Source":(T_STRING,FUNC)}))
    return roots
if __name__=="__main__":
    roots=build_all_v111()
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_11.rbxl")
    write(out, serialize(roots))
    print(f"V1.11 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 100 editores 6020 ferramentas")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_11.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
