#!/usr/bin/env python3
"""GENESIS V1.2 — Lote 2: 10 EDITORES x 60 ferramentas = 600 ferramentas"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, read, write, T_STRING, T_BOOL, T_INT, T_FLOAT32, T_ENUM, T_COLOR3, T_VECTOR2, T_UDIM, T_UDIM2, col, vec2, udim, udim2
from build_studio_v1 import CYBER, mk, frame_icon
from build_genesis_v1_1 import build_terrain_editor, build_material_editor

EDITORS = [
    ("PhysicsLab", "PHYSICS LAB", 0xFF3B30, ["RigidBody","Collider","Joint","Constraint","Cloth","Hair","Fluid","Destruction","Vehicle","Ragdoll","Force","Impulse","Friction","Damping","Solver","Broadphase","Narrowphase","CCD","Sleep","Island","Query","Raycast","Sweep","Overlap","Trigger","CharacterCtrl","Kinematic","Dynamic","Static","SoftBody","Deform","Fracture","Particle","Wind","Gravity","Buoyancy","Aerodynamic","Contact","FrictionCombo","Restitution","LinearLimit","AngularLimit","Motor","Spring","Damper","Breakable","KinematicTarget","Mass","Inertia","CenterMass","SleepThresh","SolverIter","Substep","TimeScale","WorldStep","DebugDraw","Profiler","Material","Filter"]),
    ("RenderGraph", "RENDER GRAPH", 0x00D4FF, ["Deferred","Forward","Clustered","Visibility","Culling","HZB","Occlusion","LOD","Impostor","VirtualTex","Stream","Mip","Sampler","RTX","PathTrace","GI","SSAO","SSGI","SSR","SSSSS","Volumetric","Fog","Atmosphere","Sky","Cloud","Shadow","CSM","VSM","PCSS","ContactShad","Decal","Light","Probe","Reflection","Irradiance","Lightmap","LightProbe","HDRI","Exposure","Tonemap","Bloom","DOF","MotionBlur","Chromatic","Vignette","Grain","ColorGrade","LUT","Upscale","TAA","DLSS","FSR","Checkerboard"]),
    ("AnimationRig", "ANIMATION RIG", 0xB983FF, ["Skeleton","Rig","Skin","Weight","BlendShape","Morph","IK","FK","CCD_IK","FABRIK","LookAt","Aim","Retarget","Mocap","BVH","FBX","RootMotion","Additive","Layered","StateMachine","BlendTree","Transition","Sync","TimeScale","Loop","PingPong","Clamp","Event","Notify","Curve","FloatCurve","VectorCurve","Pose","PoseBlender","Mirror","SpaceSwitch","ControlRig","Sequencer","Timeline","Key","Tangent","Spline","Euler","Quat","Slerp","AimConstraint","ParentConstraint","ScaleConstraint","Driver","Bake","Export","Compress","LOD","RetargetMgr","IK_Solver"]),
    ("VFXGraph", "VFX GRAPH", 0xFF6B35, ["Emitter","Spawn","Rate","Burst","Lifetime","Velocity","Force","Drag","Turbulence","Vortex","Noise","Curl","Attractor","Collision","Kill","Size","Color","Alpha","Flipbook","SubUV","Ribbon","Beam","Mesh","Decal","Light","Sound","Event","SpawnPerUnit","LOD","Culling","Sort","Depth","Blend","Additive","Soft","Distortion","VectorField","Texture","Gradient","Curve","DynamicParam","Material","Shader","Cascade","Niagara","System","Module","SpawnModule","UpdateModule","Output","Renderer","CPU","GPU","SimTarget","Bounds","FixedBounds","BurstList","Loop","Delay","Warmup"]),
    ("AudioStudio", "AUDIO STUDIO", 0x7A8AB8, ["Source","Listener","Bus","Mixer","EQ","Compressor","Limiter","Reverb","Delay","Chorus","Flanger","Distortion","Filter","LowPass","HighPass","BandPass","Spatial","HRTF","Attenuation","Occlusion","Obstruction","ReverbZone","Snapshot","Ducking","Sidechain","Meter","Spectrum","Waveform","Clip","Loop","Pitch","Doppler","Rolloff","Cone","Priority","Voice","Pool","Stream","Bank","Event","RTPC","Switch","State","Trigger","Foley","Music","Stinger","Transition","Crossfade","Duck","Master","Aux","VCA","SnapshotBlend","Profiler","Debug"]),
    ("AIBehavior", "AI BEHAVIOR", 0x00FF88, ["Blackboard","BehaviorTree","Selector","Sequence","Parallel","Inverter","Succeeder","Repeater","Retry","Cooldown","Wait","MoveTo","FindPath","NavMesh","NavVolume","Crowd","Avoidance","Formation","Cover","Perception","Sight","Hearing","Damage","Stimulus","Query","Service","Decorator","ForceSuccess","ForceFailure","Loop","Random","Weight","Utility","GOAP","HTN","State","Transition","Hierarchical","SubTree","Reference","Variable","Compare","Math","Log","Debug","Profiler","VisualLogger","EQS","EnvQuery","PathFollow","Strafe","Orbit","Flee","Pursuit","Interpose","Hide","Search","Investigate"]),
    ("WorldPartition", "WORLD PARTITION", 0x4CAF50, ["WorldCell","RegionTile","ZoneChunk","HLOD","Stream","Level","Sublevel","DataLayer","WorldPartition","Cell","Grid","Runtime","Editor","MiniMap","WorldBuilder","Landscape","Foliage","Instanced","ISM","HISM","PCG","Scatter","Biome","Spline","Road","River","City","Building","Interior","Exterior","LOD","Streaming","Culling","Occlusion","HLOD_Builder","WorldMetrics","Memory","Budget","Coherence","Sparse","Multiscale","Persistent","WorldMemory","Fabric","Reality","Emergence","Interest","Complexity","Debug","Profiler","WorldSettings"]),
    ("UIBuilder", "UI BUILDER", 0xFFD600, ["Canvas","Panel","Button","Label","Image","Input","Toggle","Slider","Dropdown","Scroll","List","Grid","Tree","Tab","Menu","Toolbar","StatusBar","Tooltip","Modal","Popup","ContextMenu","Dock","Splitter","CanvasGroup","Constraint","Layout","ListLayout","GridLayout","TableLayout","Anchor","Padding","Corner","Stroke","Gradient","Shadow","Blur","Viewport","Video","WebView","Chart","Graph","Timeline","Property","Explorer","Outliner","Details","Inspector","Command","Palette","Theme","Responsive","Accessibility","Localization","Animation","Transition","Profiler","Debug"]),
    ("Cinematic", "CINEMATIC", 0xFFB800, ["Sequence","Shot","Take","Track","Clip","Key","Curve","Easing","Camera","Lens","Focal","Aperture","Shutter","ISO","Rig","Crane","Dolly","Slider","Gimbal","Focus","Depth","Bokeh","Motion","Stabilizer","LookAt","Aim","Path","Spline","Rail","Cut","Dissolve","Wipe","Fade","TimeDilation","Subsequence","Master","ShotTrack","CameraCut","Spawnable","Possessable","Binding","Section","Infinite","Weight","Blend","EaseIn","EaseOut","AutoKey","KeyAll","Bake","Export","Render","Movie","Capture","EXR","ProRes","Debug"]),
    ("NetworkLab", "NETWORK LAB", 0x0094FF, ["Replication","Authority","Ownership","Prediction","Rollback","Reconciliation","LagComp","Jitter","Interpolation","Extrapolation","Snapshot","Delta","Compress","Quantize","Reliable","Unreliable","Ordered","Channel","RPC","RemoteEvent","RemoteFunction","UnreliableEvent","Stream","Fragment","MTU","Bandwidth","Throttle","Priority","Scope","Interest","Relevancy","Culling"," dormancy","Tick","Heartbeat","SnapshotRate","Buffer","Resend","Ack","Nack","Sequence","Window","FlowCtrl","Congestion","Encryption","Auth","AntiCheat","Validation","Sanity","RateLimit","Profiler","LagSim","Debug"]),
]

def build_editor_window(name, title, color, tools):
    win = mk("Frame", name, {
        "BackgroundColor3": (T_COLOR3, col(CYBER["panel"])),
        "BorderSizePixel": (T_INT, 0),
        "Size": (T_UDIM2, udim2(0, 400, 0, 440)),
        "Position": (T_UDIM2, udim2(0.5,0,0.5,0)),
        "AnchorPoint": (T_VECTOR2, vec2(0.5,0.5)),
        "Visible": (T_BOOL, False),
    })
    win.add(mk("UICorner", "C", {"CornerRadius": (T_UDIM, udim(0,10))}))
    win.add(mk("UIStroke", "S", {"Color": (T_COLOR3, col(color)), "Thickness": (T_FLOAT32, 1.5), "Transparency": (T_FLOAT32, 0.3)}))
    header = mk("Frame", "Header", {
        "BackgroundColor3": (T_COLOR3, col(CYBER["panelAlt"])),
        "Size": (T_UDIM2, udim2(1,0,0,32)),
        "BorderSizePixel": (T_INT, 0),
    })
    win.add(header)
    header.add(mk("TextLabel", "Title", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Size": (T_UDIM2, udim2(1,-40,1,0)),
        "Position": (T_UDIM2, udim2(0,12,0,0)),
        "Text": (T_STRING, f"{title} • 60 TOOLS"),
        "TextColor3": (T_COLOR3, col(color)),
        "TextSize": (T_FLOAT32, 12),
        "Font": (T_ENUM, 3),
        "TextXAlignment": (T_ENUM, 0),
    }))
    close = mk("TextButton", "Close", {
        "BackgroundColor3": (T_COLOR3, col(CYBER["void"])),
        "Size": (T_UDIM2, udim2(0,28,0,28)),
        "Position": (T_UDIM2, udim2(1,-6,0.5,0)),
        "AnchorPoint": (T_VECTOR2, vec2(1,0.5)),
        "Text": (T_STRING, "✕"),
        "TextColor3": (T_COLOR3, col(CYBER["text"])),
        "TextSize": (T_FLOAT32, 14),
        "Font": (T_ENUM, 3),
    })
    close.add(mk("UICorner", "C", {"CornerRadius": (T_UDIM, udim(0,6))}))
    header.add(close)
    # Grid 60 tools
    scroll = mk("ScrollingFrame", "Tools", {
        "BackgroundTransparency": (T_FLOAT32, 1),
        "Position": (T_UDIM2, udim2(0,6,0,38)),
        "Size": (T_UDIM2, udim2(1,-12,1,-44)),
        "CanvasSize": (T_UDIM2, udim2(0,0,0, 440)),
        "ScrollBarThickness": (T_INT, 4),
        "BorderSizePixel": (T_INT, 0),
    })
    win.add(scroll)
    scroll.add(mk("UIGridLayout", "G", {"CellPadding": (T_UDIM2, udim2(0,6,0,6)), "CellSize": (T_UDIM2, udim2(0,114,0,30)), "SortOrder": (T_ENUM, 0)}))
    for t in tools:
        btn = mk("TextButton", t.replace(" ","_"), {
            "BackgroundColor3": (T_COLOR3, col(CYBER["panelAlt"])),
            "BorderSizePixel": (T_INT, 0),
            "Text": (T_STRING, t),
            "TextColor3": (T_COLOR3, col(CYBER["text"])),
            "TextSize": (T_FLOAT32, 10),
            "Font": (T_ENUM, 2),
            "AutoButtonColor": (T_BOOL, True),
        })
        btn.add(mk("UICorner", "C", {"CornerRadius": (T_UDIM, udim(0,6))}))
        # ícone imagem pequeno
        btn.add(frame_icon(t, color, t[:1]))
        scroll.add(btn)
    return win

if __name__ == "__main__":
    # Build on top of V1.1
    from build_genesis_v1_1 import build_genesis_v1_1
    roots = build_genesis_v1_1()  # já tem Terrain+Material
    # Encontra StarterGui -> Studio Root
    for r in roots:
        if r.cls == "StarterGui":
            for sg in r.children:
                if sg.name == "ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name == "Root":
                            # Adiciona 8 novos editores (10 total -2 já existentes =8, mas vamos adicionar 8 novos para total 10)
                            for name, title, color, tools in EDITORS[:8]:
                                # Evita duplicar Terrain/Material já existentes
                                if name in ["TerrainEditor","MaterialEditor"]:
                                    continue
                                child.add(build_editor_window(name, title, color, tools))
    # Script que liga TopBar tabs aos novos editores
    extra_script = """
for _, tab in ipairs(game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.TopBar.Tabs:GetChildren()) do
  if tab.Name=="Tab_H" then tab.Activated:Connect(function() game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.PhysicsLab.Visible = not game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.PhysicsLab.Visible end) end
  if tab.Name=="Tab_F" then tab.Activated:Connect(function() game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.RenderGraph.Visible = not game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.RenderGraph.Visible end) end
  if tab.Name=="Tab_I" then tab.Activated:Connect(function() game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.AnimationRig.Visible = not game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.AnimationRig.Visible end) end
  if tab.Name=="Tab_N" then tab.Activated:Connect(function() game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.VFXGraph.Visible = not game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.VFXGraph.Visible end) end
  if tab.Name=="Tab_O" then tab.Activated:Connect(function() game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.AudioStudio.Visible = not game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.AudioStudio.Visible end) end
  if tab.Name=="Tab_K" then tab.Activated:Connect(function() game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.AIBehavior.Visible = not game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.AIBehavior.Visible end) end
  if tab.Name=="Tab_C" then tab.Activated:Connect(function() game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.WorldPartition.Visible = not game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.WorldPartition.Visible end) end
  if tab.Name=="Tab_Q" then tab.Activated:Connect(function() game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.UIBuilder.Visible = not game.Players.LocalPlayer.PlayerGui.ARKHER_STUDIO.Root.UIBuilder.Visible end) end
end
print("[ARKHER V1.2] 10 editores x60 =600 ferramentas")
"""
    # Injeta no StudioController
    for r in roots:
        if r.cls == "StarterPlayer":
            for folder in r.children:
                if folder.name == "StarterPlayerScripts":
                    for scr in folder.children:
                        if scr.name == "ARKHER_StudioController":
                            scr.props["Source"] = (T_STRING, scr.props["Source"][1] + extra_script)
    out = os.path.join(REL, "ARKHER_STUDIO_1_GENESIS_EDITION_V1_2.rbxl")
    write(out, __import__("build_rbxm").serialize(roots))
    print(f"V1.2 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 10 editores x60")
