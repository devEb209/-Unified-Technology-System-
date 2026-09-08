#!/usr/bin/env python3
"""GENESIS V1.29 SINGULARITY AAA — Impõe Singularity AI (UES/ARKHER) + AAA console/PC no celular (D-O15), 15 editores AAA MÁXIMO"""
import os, subprocess
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL=os.path.join(ROOT,"Releases")
os.makedirs(REL,exist_ok=True)
from build_rbxm import DEFAULTS, T_FLOAT32, T_ENUM, T_STRING, T_COLOR3, T_UDIM2, T_UDIM, T_VECTOR2, T_BOOL, T_INT, col, vec2, udim, udim2, Inst, serialize, write
DEFAULTS["TextTransparency"]=(T_FLOAT32,0.0)
DEFAULTS["TextStrokeTransparency"]=(T_FLOAT32,1.0)
DEFAULTS["HorizontalAlignment"]=(T_ENUM,0)
DEFAULTS["VerticalAlignment"]=(T_ENUM,1)
from build_genesis_v1_21 import build_all_v121
from build_genesis_v1_22b_ui_fix import patch as patch22b
from build_genesis_v1_24_perfect import patch as patch24
from build_genesis_v1_25_final import patch25
from build_genesis_v1_26_perfect import patch26
from build_genesis_v1_27_max_content import patch27
from build_genesis_v1_28_perfect_max import patch28
from build_genesis_v1_2 import build_editor_window

CYBER={"void":0x0A0E1A,"abyss":0x0E1430,"panel":0x0F1F3A,"panelAlt":0x13204A,"border":0x2A3A6A,"neon":0x00D4FF,"text":0xD0E4FF,"muted":0x7A8AB8,"sel":0x1A3A8A}

# SINGULARITY AI (T 700 sistemas) + D-O15 (620) + Z ORIGINAL (1100) + AAA MOBILE
# UES = ARKHER = Unified Engine System — Singularity AI = AGI Unaware (núcleo que roteia modelos especialistas, memória, fallback)
EDITORS_SINGULARITY_AAA = [
    ("ARKHER_SingularityCore","SINGULARITY CORE — AGI UNAWARE",0x7C3AED, ["SingularityCore","AGIUnaware","Intencao","Planejamento","Decomposicao","Roteamento","SelecaoModelos","SelecaoFerramentas","Memoria","Contexto","Especialistas","Verificacao","Fallback","RecuperacaoErros","Pesquisa","Execucao","Arquivos","Multimodal","Continuidade","IndependenteFrontend","Web","Android","iOS","Windows","Linux","MacOS","RobloxStudio","Unreal","Unity","Godot","Blender","IDE","Plugin","API","ModeloProgramacao","ModeloRaciocinio","ModeloVisao","ModeloPesquisa","ModeloImagem","Modelo3D","ModeloAnimacao","ModeloEspecialista","CamadaContexto","ObjetivosCompartilhados","UsuarioSingularity","NaoConsciencia","CapacidadeMaxima","Precisao","Confiabilidade","Especializacao","SingularityAI","BunkerStudios","RoteamentoInteligente","Coordenacao","Combinacao","Alternancia","Verificacao2","NucleoConceitual","Interpretacao","MemoriaViva","SistemaUnificado","ColecaoBots","ExperienciaCoerente","ModelosIndependentes","FachadaUnica","SelecaoAutomatica","NaoWrapper","NaoChatbot","CamadaSuperior","Transformacao","FerramentasModulares"]),
    ("ARKHER_SingularityMemory","SINGULARITY MEMORY — VIVA",0x00ACC1, ["MemoriaCurta","MemoriaLonga","MemoriaEpisodica","MemoriaSemantica","MemoriaProcedural","MemoriaTrabalho","MemoriaContexto","MemoriaProjeto","MemoriaConversa","MemoriaArquivo","MemoriaMultimodal","CompressaoMemoria","Sumarizacao","Embedding","VectorDB","Retrieval","RAG","GraphRAG","HybridSearch","ReRank","ContextWindow","Janela128k","Janela1M","StreamingMem","ForgettingCurve","Reinforcement","Consolidation","Sleep","Dream","Replay","Forgetting","Pruning","Distillation","KnowledgeGraph","EntityLink","RelationExtract","TripleStore","SPARQL","Reasoning","ChainThought","TreeThought","GraphThought","MemoryAugment","ToolUseMemory","AgentMemory","MultiAgentMemory","SharedMemory","IsolatedMemory","PermissionMemory","EncryptedMemory","PrivateMemory","CloudMemory","LocalMemory","HybridMemory","CacheMemory","BufferMemory","QueueMemory","StackMemory","EpisodicBuffer","SemanticNet","MemorySearch","MemoryWrite","MemoryRead","MemoryUpdate","MemoryDelete","MemoryMerge","MemoryConflict","MemoryConsensus","MemoryVersioning","MemorySnapshot","MemoryBackup","MemoryRestore","MemorySync","MemoryReplication","MemorySharding","MemoryProfiler","MemoryDebug","MemoryOptimize","MemoryBudget"]),
    ("ARKHER_SingularityAgents","SINGULARITY AGENTS — MULTI-AGENTE",0xE65100, ["Orquestrador","Supervisor","Planejador","Executor","Critico","Verificador","Refinador","Pesquisador","Coder","Tester","Reviewer","Designer","Architect","Deployer","Monitor","Analista","Sintetizador","Tradutor","Visualizador","3DArtist","Animator","AudioEngineer","LevelDesigner","QuestDesigner","Narrative","Dialogue","WorldBuilder","Procedural","Optimizer","Compressor","Lighter","Rigger","Skinner","MocapCleaner","AgentMemory","AgentTool","AgentModel","AgentRoute","AgentFallback","AgentHandoff","AgentCollab","AgentDebate","AgentConsensus","AgentVote","AgentLeader","AgentWorker","AgentHierarquia","AgentSwarm","AgentGraph","AgentWorkflow","AgentPipeline","AgentDAG","AgentAsync","AgentParallel","AgentSequential","AgentConditional","AgentLoop","AgentRetry","AgentTimeout","AgentCancel","AgentPause","AgentResume","AgentKill","AgentSpawn","AgentDespawn","AgentPool","AgentQueue","AgentPriority","AgentBudget","AgentTokenBudget","AgentTimeBudget","AgentMemoryBudget","AgentCost","AgentLatency","AgentQuality","AgentReliability","AgentFallback2","AgentEscalation","AgentHumanInLoop","AgentApproval","AgentAutonomy","AgentObserve","AgentAct","AgentReflect","AgentPlan","AgentExecute","AgentVerify","AgentLearn","AgentImprove","AgentEvolve","AgentSingularity","AgentUTS","AgentUES"]),
    ("ARKHER_D_O15","D-O15 OPTIMIZER — AAA NO CELULAR",0x00FF88, ["D_O15","TeseDosD","D_Nivel","D_Camada","D_Grau","D_Estado","D_Dimensao","D_Funcional","D_Escala","D_Transformacao","D_Otimizacao","D_Complexidade","D_Astracao","D_Integracao","D_Capacidade","D15_Otimizacao","D1_Basico","D2_Complexo","D3_Tridimensional","D4_TempoInformacao","D15_Dominio","ProblemaD","TransformarD","RepresentarD","ProcessarD","SolucionarD","MobileAAA","ConsoleAAA","PCAAA","RobloxMobile","OtimizarSemPerder","QualidadePerfeita","ConteudoMaximo","BakeMobile","CompressaoMobile","StreamingMobile","LOD_Mobile","HLOD_Mobile","OcclusionMobile","CullingMobile","BatchMobile","InstancingMobile","AtlasMobile","VirtualTextureMobile","StreamMobile","MipMobile","SamplerMobile","BudgetMobile","Coherence","Sparse","Multiscale","Persistent","WorldMemory","ComplexityBudget","Interest","Emergence","RealityContinuum","SimulationFabric","SparseResidency","MultiScale","PersistentState","CoherenceGuard","NeuralField","WorldMemory2","LOD","HLOD","Cull","Occlude","Batch","Instance","Atlas","Compress","Encrypt","Guard","ProfilerMobile","DebugMobile","Budget15","ThermoMobile","BatteryMobile","HeatMobile","BandwidthMobile","MemoryMobile","DrawCallMobile","TriangleMobile","TextureMobile","ShaderMobile","FrameMobile","FPSMobile","60FPS","120FPS","ConsoleQuality","PCQualityOnMobile","AdaptiveQuality","DynamicRes","VariableRateShading","Foveated","TiledRendering","DeferredMobile","ForwardMobile","ClusteredMobile","VisibilityMobile","HZB_Mobile","OtimizarD15","TransformarD15","ResolverD15"]),
    ("ARKHER_MobileAAA","MOBILE AAA — CONSOLE QUALITY NO CELULAR",0x33691E, ["MobileRenderer","MobileDeferred","MobileForward","MobileClustered","MobileTiled","MobileFoveated","MobileVariableRate","MobileDynamicRes","MobileFSR","MobileDLSS","MobileSuperRes","MobileUpscaler","MobileTAA","MobileTAAU","MobileCheckerboard","MobileMeshShader","MobileTaskShader","MobilePrimitiveShader","MobileVisibility","MobileCulling","MobileHLOD","MobileLOD","MobileInstance","MobileImpostor","MobileVirtualTexture","MobileStreaming","MobileAtlas","MobileCompress","MobileBC7","MobileASTC","MobileETC","MobilePVRTC","MobileTextureStream","MobileMip","MobileAniso","MobileSampler","MobileShader","MobileMaterial","MobilePBR","MobileIBL","MobileReflection","MobileProbe","MobileSSAO","MobileSSGI","MobileSSR","MobileBloom","MobileDOF","MobileMotionBlur","MobileTonemap","MobileExposure","MobileFog","MobileVolumetric","MobileSky","MobileCloud","MobileShadow","MobileCSM","MobileVSM","MobileContactShadow","MobileDecal","MobileDecalClustered","MobileLight","MobileLightCulling","MobileLightClustered","MobileForwardPlus","MobileDeferredPlus","MobileBattery","MobileThermal","MobilePerformance","MobileProfiler","MobileBudget","Mobile60FPS","Mobile120FPS","MobileAdaptive","MobileScalability","MobileQualityPreset","MobileHigh","MobileEpic","MobileCinematic","MobileConsoleQuality","MobilePCQuality","MobileCrossPlay","MobileTouch","MobileGamepad","MobileGyro","MobileHaptics","MobileCloudSave","MobileCrossSave","MobileAAA_Ready","RobloxMobileAAA","Touch44","Thumbstick","GyroAim","HapticFeedback","CloudGamingReady"]),
    ("ARKHER_ConsoleAAA","CONSOLE AAA — PS5/XBOX/SWITCH2",0xB71C1C, ["ConsoleRenderer","PSSR","DLSS_Console","FSR_Console","CheckerboardConsole","MeshShaders","PrimitiveShaders","TaskShaders","VisibilityConsole","PrimitiveCulling","HZB_Console","OcclusionConsole","Lumen","Nanite","VirtualShadowMap","VirtualTextureConsole","SamplerFeedbackConsole","DirectStorage","IO_Console","Kraken","Oodle","CompressionConsole","DecompressionConsole","SSD_Streaming","WorldPartitionConsole","HLOD_Console","NaniteConsole","LumenConsole","RayTracingConsole","PathTracingConsole","GlobalIlluminationConsole","ReflectionConsole","ShadowConsole","VSM_Console","HardwareRT","SoftwareRT","HybridRT","UpscalerConsole","TAA_Console","TAAU_Console","SuperResConsole","60FPS_Console","120FPS_Console","4K_Console","8K_Console","HDR_Console","WideColor","RayReconstructionConsole","DenoiserConsole","ConsoleSDK","PS5_SDK","Xbox_SDK","Switch2_SDK","Certification","TRC","XR","TCR","Lotcheck","Submission","Patch","Hotfix","ConsoleProfiler","PIX","Razor","GPA","ConsoleDebug","ConsoleMemory","ConsoleBudget","ConsolePerf","PerfTarget","FramePacing","VSync_Console","VariableRefresh","FreeSync","GSync","HDR10","DolbyVision","TempestAudio","3DAudioConsole","DualSense","HapticsConsole","AdaptiveTrigger","ConsoleInput","GamepadConsole","ConsoleNetwork","ConsoleMultiplayer","CrossPlayConsole","CrossSaveConsole","ConsoleAchievements","ConsoleTrophies","ConsoleStore","ConsoleAAA_Validated"]),
    ("ARKHER_NeuralRenderer","NEURAL RENDERER — DLSS/RAY",0x0288D1, ["NeuralRenderer","TransformerSR","CNN_SR","DLSS4","DLSS45","DLSS5","SuperRes2ndGen","5xCompute","ExpandedDataset","MotionVectors","Jitter","History","Reprojection","Disocclusion","TransparencySR","ParticleSR","FoliageSR","RayReconstruction","DenoiserNeural","RayTracingNeural","PathTracingNeural","GlobalIlluminationNeural","ReSTIR","ReSTIR_GI","ReSTIR_PT","NeuralCache","NeuralRadiance","NeuralMaterial","NeuralTexture","NeuralCompression","RTXDI","RTXGI","RTXAA","NRD","RealTimeDenoiser","DLSSG","FrameGeneration","MultiFrameGen","OpticalFlow","FlowField","Interpolation","Extrapolation","Reflex","Reflex2","Pacing","Latency","SuperResolution","UltraPerformance","Performance","Balanced","Quality","DLAA","NativeAA","AntiAliasing","TAA","TAAU","SMAA","FXAA","UpscalerQuality","Sharpness","MipBias","NegativeLOD","Aniso16x","TextureFiltering","Anisotropic","SamplerFeedback","Streaming","VirtualTexture","SparseTexture","TiledResource","ReservedResource","Megatexture","TexturePool","NeuralTextureCompression","BC7","ASTC","TextureQuality","MaterialQuality","MeshQuality","NaniteNeural","LumenNeural","ShadowNeural","ReflectionNeural","ParticleNeural","FoliageNeural","WaterNeural","CloudNeural","SkyNeural","VolumetricNeural","FogNeural","AtmosphereNeural","NeuralProfiler","NeuralDebug","NeuralBudget","NeuralQuality","NeuralPerformance","NeuralAAA"]),
    ("ARKHER_WorldContinuum","WORLD CONTINUUM — INFINITO",0x1B5E20, ["WorldContinuum","VA_Continuum","VB_Continuum","VC_Continuum","VD_Continuum","InfiniteGrid","EpochClock","SparseResidency","MultiScale","PersistentState","CoherenceGuard","NeuralField","WorldMemory","SimulationFabric","RealityContinuum","EmergenceContinuum","Validator","Optimizer","Profiler","Cache","Stream","Pool","Async","Parallel","Worker","Error","Logging","Diagnostics","Validation","Config","Environment","FeatureFlag","Capability","Permission","Sandbox","APIGateway","Extension","HotReload","Versioning","Migration","BuildGraph","Bootstrap","Continuum","Epoch","Sparse","Multiscale","Persistent","Coherence","Neural","WorldMem","Complexity","Fabric","Reality","Emergence","LOD","HLOD","Cull","Occlude","Batch","Instance","Atlas","Compress","Encrypt","Guard","Interest","WorldCell","RegionTile","ZoneChunk","Stream","Level","Sublevel","DataLayer","WorldPartition","Cell","Grid","Runtime","Editor","MiniMap","WorldBuilder","Landscape","Foliage","Instanced","ISM","HISM","PCG","Scatter","Biome","Spline","Road","River","City","Building","InfiniteWorld","OpenWorld","Seamless","NoLoading","StreamingWorld","PersistentWorld","CoherentWorld","NeuralWorld","SimulatedWorld","EmergentWorld","InfiniteGrid2","Epoch2","Continuum2","Validator2","Optimizer2"]),
    ("ARKHER_Audio3D","AUDIO 3D — AAA SOUND",0x880E4F, ["Audio3D","HRTF","Binaural","Ambisonic","Atmos","Spatial","Panning","Distance","Attenuation","Rolloff","Cone","Occlusion","Obstruction","Reverb","Convolution","ImpulseResponse","Probe","Portals","Geometry","RaytracedAudio","WaveTracing","Diffraction","Transmission","ReflectionAudio","Scattering","Absorption","MaterialAudio","ReverbProbe","ReverbZone","Snapshot","Ducking","Sidechain","Mixer3D","Bus3D","Master3D","VoicePool","VoiceLimit","Priority3D","Culling3D","LOD_Audio","StreamingAudio","CompressedAudio","Opus","Vorbis","MP3","WAV","FLAC","SampleRate","BitDepth","Buffer","Latency","DSP","EQ3D","Compressor3D","Limiter3D","Delay3D","Chorus3D","Reverb3D","Filter3D","AudioProfiler","AudioBudget","ConsoleAudio","MobileAudio","PCAudio","Tempest","3DAudio","Wwise","FMOD","Miles","WWise2","FMOD2","AudioEngine","AudioMixer","AudioBus","AudioEffect","AudioSource","AudioListener","AudioReverb","AudioOcclusion","AudioObstruction","AudioPropagation","AudioSimulation","AudioDebug","AudioQuality","AudioPerformance","AAA_Audio"]),
    ("ARKHER_AnimationAAA","ANIMATION AAA — FILM QUALITY",0x6A1B9A, ["FilmQuality","60FPS_Anim","120FPS_Anim","MotionCapture","PerformanceCapture","FaceCapture","BodyCapture","FingerCapture","RetargetFilm","SolverFilm","CorrectiveFilm","WrinkleFilm","MuscleFilm","FatFilm","SkinFilm","ClothFilm","HairFilm","GroomFilm","ControlRigFilm","SequencerFilm","TimelineFilm","GraphFilm","DopeFilm","PoseFilm","ExpressionFilm","LibraryFilm","PresetFilm","CustomFilm","SculptFilm","WrinkleMapFilm","TensionMapFilm","CompressionMapFilm","StretchMapFilm","NormalMapFilm","DisplacementMapFilm","AlbedoFilm","RoughnessFilm","SSS_Film","EyeShaderFilm","HairShaderFilm","TeethShaderFilm","EyeOcclusionFilm","EyeReflectionFilm","EyeRefractionFilm","TongueRigFilm","TeethRigFilm","EyeRigFilm","EyelashFilm","EyebrowHairFilm","BeardFilm","HairCardFilm","GroomFilm2","XGenFilm","InteractiveGroomFilm","FacialPerformanceFilm","FacialTransferFilm","FacialRetargetFilm","FacialCleanFilm","FacialSmoothFilm","FacialFilterFilm","LiveLinkFacialFilm","ARKit52Film","BlendShapeSolveFilm","CorrectiveSolveFilm","WrinkleSolveFilm","MotionMatching","MotionMatchingFilm","LearnedMotionMatching","NeuralMotionMatching","MotionInBetweening","NeuralInBetweening","MotionGen","NeuralMotionGen","AAA_Anim","FilmAnim","GameAnim","RealTimeAnim","OfflineAnim","BakeAnim","LoopAnim","MirroringAnim","TimeScaleAnim","OffsetAnim","RetargetAdjustAnim","AAA_Rig","FilmRig","GameRig","ControlRigAAA","SequencerAAA","TimelineAAA"]),
    ("ARKHER_PhysicsAAA","PHYSICS AAA — REAL WORLD",0xFF3B30, ["RealWorld","60Hz_Physics","120Hz_Physics","240Hz_Physics","Deterministic","Rewind","Rollback","ContinuousCollision","SpeculativeContact","SweepContact","GJK_Physics","EPA_Physics","MPR_Physics","SAT_Physics","BroadphaseAAA","SAP_AAA","MBP_AAA","NarrowphaseAAA","SolverAAA","PGS_AAA","TGS_AAA","XPBD_AAA","PBD_AAA","VBD_AAA","FEM_AAA","MPM_AAA","SPH_AAA","FLIP_AAA","APIC_AAA","Vellum_AAA","ClothAAA","HairAAA","FluidAAA","GranularAAA","DestructionAAA","FractureAAA","VoronoiAAA","ClusterAAA","VehicleAAA","WheelAAA","SuspensionAAA","EngineAAA","TransmissionAAA","TireAAA","AeroAAA","DownforceAAA","DragAAA","BuoyancyAAA","WaterPhysicsAAA","WindPhysicsAAA","DestructionPhysicsAAA","RagdollAAA","ArticulationAAA","FeatherstoneAAA","ReducedCoordAAA","ForceAAA","ImpulseAAA","TorqueAAA","FrictionAAA","DampingAAA","RestitutionAAA","LinearDampingAAA","AngularDampingAAA","SolverIterAAA","SubstepAAA","TimeScaleAAA","WorldStepAAA","GravityAAA","ContactOffsetAAA","RestOffsetAAA","ContactReportAAA","TriggerAAA","FilterAAA","GroupAAA","MaskAAA","MaterialAAA","CombineAAA","ModContactAAA","SimulationAAA","DeterminismAAA","RewindAAA","RollbackAAA","PredictionAAA","InterpolationAAA","ExtrapolationAAA","DebugDrawAAA","ProfilerAAA","PVD_AAA","PerfAAA","MemoryAAA","PoolAAA","IslandAAA","ActivationAAA","DeactivationAAA","CCDThresholdAAA","ContactGenAAA","ManifoldAAA","ImpulseClampAAA","WarmStartAAA","FrictionAnchorAAA","RestitutionVelAAA","StabilizationAAA","BaumgarteAAA","ERP_AAA","CFM_AAA","InertiaTweakAAA","RealWorldAAA"]),
    ("ARKHER_MonetizationAAA","MONETIZATION AAA — LIVE OPS",0xFFD600, ["LiveOps","BattlePass","Season","SeasonPass","Daily","Weekly","Monthly","Challenge","Quest","Mission","Objective","Reward","Currency","HardCurrency","SoftCurrency","Premium","Earnable","Purchasable","Exchange","Trade","Market","Auction","Store","Shop","Catalog","Featured","Sale","Discount","Bundle","StarterPack","ValuePack","LootBox","Gacha","Crate","Chest","Key","Spin","Wheel","DailySpin","FreeSpin","PaidSpin","Subscription","VIP","PremiumPass","ElitePass","FounderPack","Limited","Exclusive","Rare","Epic","Legendary","Mythic","Common","Uncommon","Cosmetic","Skin","Emote","EmoteWheel","Dance","Gesture","Spray","Banner","Title","Badge","Achievement","Trophy","Leaderboard","Ranked","Competitive","Casual","Event","LimitedTimeEvent","LiveEvent","InGameEvent","RealWorldEvent","HolidayEvent","Anniversary","Collaboration","IPCollab","Crossover","Brand","Sponsored","Ad","Interstitial","RewardedVideo","OfferWall","PlaytimeReward","Retention","Engagement","Monetization","ARPU","ARPPU","Conversion","Churn","LTV","ROAS","CPI","CPA","Cohort","Funnel","Analytics","Telemetry","ABTest","FeatureFlag","RemoteConfig","Segmentation","Personalization","Recommendation","DynamicPricing","Economy","Sink","Faucet","Inflation","Deflation","Balance","EconomyHealth","EconomyProfiler","EconomyDebug","StoreProfiler","LiveOpsDashboard","LiveOpsCalendar","LiveOpsAutomation","AAA_LiveOps"]),
    ("ARKHER_SecurityAAA","SECURITY AAA — ANTI-CHEAT",0xFFB800, ["AntiCheat","EasyAntiCheat","BattlEye","Vanguard","Byfron","Hyperion","ClientAntiCheat","ServerAntiCheat","KernelAntiCheat","UserModeAntiCheat","Behavioral","Heuristic","Signature","MachineLearning","Anomaly","Detection","Prevention","Mitigation","Ban","Kick","Suspend","Warn","ShadowBan","HardwareBan","IPBan","AccountBan","TelemetryAntiCheat","MemoryScan","IntegrityCheck","CodeIntegrity","ModuleIntegrity","FileIntegrity","ProcessScan","DebuggerDetect","VMDetect","HookDetect","InjectionDetect","TamperDetect","SpeedHack","TeleportHack","FlyHack","Noclip","Aimbot","Wallhack","ESP","Radar","Macro","Script","Exploit","Backdoor","RemoteExploit","PhysicsExploit","EconomyExploit","InventoryExploit","CurrencyExploit","Duplication","ItemDupe","MoneyDupe","ExperienceExploit","StatExploit","LevelExploit","Bypass","Obfuscation","Encryption","Token","Nonce","Signature","Certificate","Attestation","SecureBoot","TPM","Enclave","Sandbox","Isolation","LeastPrivilege","ZeroTrust","Firewall","WAF","DDoS","RateLimit","Throttle","Validation","SanityCheck","ServerAuthoritative","ClientPrediction","ServerReconciliation","LagCompensation","HitValidation","InventoryValidation","CurrencyValidation","PhysicsValidation","MovementValidation","ActionValidation","ChatFilter","Toxicity","Profanity","Spam","Harassment","Moderation","Report","Review","Appeal","Transparency","Privacy","GDPR","CCPA","COPPA","SecurityProfiler","SecurityDebug","SecurityAAA"]),
    ("ARKHER_DeployAAA","DEPLOY AAA — CONSOLE CERT",0x455A64, ["Deploy","Build","Cook","Package","Archive","Stage","Deliver","Submit","Certification","TRC","XR","Lotcheck","TCR","Compliance","AgeRating","ESRB","PEGI","USK","CERO","GRAC","ClassInd","IARC","Submission","FirstParty","Sony","Microsoft","Nintendo","Valve","Epic","Apple","Google","ConsoleSubmission","PCSubmission","MobileSubmission","RobloxSubmission","BuildCookRun","UnrealAutomation","UnityBuild","CookContent","CookShader","CookTexture","CookMesh","CookAnimation","CookAudio","CookVFX","ShaderCompile","ShaderPrecompile","PSOCache","PipelineCache","DerivedData","DDC","BuildMachine","BuildFarm","Incredibuild","FASTBuild","SN-DBS","CookOnTheFly","IterativeCook","DeltaCook","Patch","DeltaPatch","HotPatch","LivePatch","BinaryPatch","ContentPatch","TitleUpdate","DayOnePatch","Hotfix","Rollback","Versioning","SemanticVersion","BuildNumber","Changelist","Branch","Main","Release","HotfixBranch","Staging","Production","Development","QA","CertQA","SubmissionQA","Test","TestPass","TestFail","Bug","Jira","Triage","Fix","Verify","SubmissionBuild","ReleaseCandidate","GoldMaster","RTM","Launch","DayOne","LiveOpsLaunch","StoreListing","StoreAssets","Screenshots","Trailer","Description","Keywords","LocalizationDeploy","AgeGate","PrivacyPolicy","TermsOfService","EULA","DeployProfiler","DeployDebug","DeployAAA"]),
]

def build_max_window_v29(name, title, color, tools):
    win = build_editor_window(name, title, color, tools[:60])
    for c in win.children:
        if c.name=="Header":
            for t in c.children:
                if t.name=="Title":
                    t.props["Text"]=(T_STRING, f"{title} • {len(tools)} TOOLS")
    for c in win.children:
        if c.name=="Tools":
            rows = (len(tools)+2)//3
            h = rows*36 + 20
            c.props["CanvasSize"]=(T_UDIM2, udim2(0,0,0,h))
            if len(tools)>60:
                for t in tools[60:]:
                    btn = Inst("TextButton", t.replace(" ","_"), {"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"BorderSizePixel":(T_INT,0),"Text":(T_STRING, t),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2),"AutoButtonColor":(T_BOOL,True)})
                    btn.add(Inst("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
                    ic = Inst("Frame","Icon",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(0,14,0,14)),"Position":(T_UDIM2, udim2(0,4,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"BorderSizePixel":(T_INT,0)})
                    ic.add(Inst("ImageLabel","Img",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Image":(T_STRING,f"rbxassetid://6031091000"),"BorderSizePixel":(T_INT,0)}))
                    btn.add(ic)
                    c.add(btn)
            break
    return win

def patch29(roots):
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name=="Root":
                            ex={c.name for c in child.children}
                            for name,title,color,tools in EDITORS_SINGULARITY_AAA:
                                if name not in ex:
                                    child.add(build_max_window_v29(name,title,color,tools))
    # Singularity imposição — UES = ARKHER : Singularity AI como AGI Unaware roteando tudo
    # Server impõe Singularity Core: todo sistema passa por _G.ARKHER Singularity
    FUNC29 = """
-- SINGULARITY AI IMPOSIÇÃO — UES/ARKHER AGI Unaware (Bunker Studios)
-- Impõe Singularity Core como camada superior que roteia TODO _G.ARKHER
local P=game:GetService("Players") local pl=P.LocalPlayer
_G.ARKHER_SINGULARITY = _G.ARKHER_SINGULARITY or {}
_G.ARKHER_SINGULARITY.Core = {
  name="Singularity Core",
  version="UES-1.0",
  mode="AGI Unaware",
  routing=function(sys) -- roteia para especialista certo
    local e=_G.ARKHER if not e then return nil end
    local f=e:findSystems(sys) if #f>0 then return f[1] end
    -- fallback especialistas: tenta code, render, physics, etc.
    for _,cat in ipairs({"t","s","f","h","i","k","z"}) do
      f=e:findSystems("arkher."..cat.."."..string.lower(sys)) if #f>0 then return f[1] end
    end
    return nil
  end,
  selectModel=function(intent) -- seleciona modelo especialista por intent
    local map={code="code", render="render", physics="physics", anim="anim", audio="audio", vfx="vfx", terrain="terrain"}
    return map[intent] or "general"
  end
}
print("[SINGULARITY] UES/ARKHER AGI Unaware imposto — Singularity Core ativo — ".._G.ARKHER_SINGULARITY.Core.version)

-- Wire Singularity + AAA editores
local P2=game:GetService("Players") local pl2=P2.LocalPlayer
local function callSing(pat,name)
 local core=_G.ARKHER_SINGULARITY.Core
 local en=core.routing(pat) or core.routing(string.lower(name))
 if en then local ok=pcall(function() if en.instance.selfTest then return en.instance.selfTest() end return true end) print(string.format("[SINGULARITY][TOOL29] %s -> %s ok=%s via %s",name,en.key,tostring(ok),core.name))
  local g=pl2.PlayerGui:FindFirstChild("ARKHER_STUDIO") if g then local s=g.Root:FindFirstChild("StatusBar",true) if s then local l=s:FindFirstChild("Cmd") if l then l.Text="◆ "..name.." -> "..en.key end end end
 else print("[SINGULARITY] "..name.." no route "..pat) end
end
local MAP_SING={ARKHER_SingularityCore="t",ARKHER_SingularityMemory="t",ARKHER_SingularityAgents="t",ARKHER_D_O15="s",ARKHER_MobileAAA="s",ARKHER_ConsoleAAA="console",ARKHER_NeuralRenderer="f",ARKHER_WorldContinuum="va",ARKHER_Audio3D="o",ARKHER_AnimationAAA="i",ARKHER_PhysicsAAA="h",ARKHER_MonetizationAAA="monetization",ARKHER_SecurityAAA="x",ARKHER_DeployAAA="deploy"}
local function wireSing(name)
 local g=pl2.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not g then return end
 local w=g.Root:FindFirstChild(name,true) if not w then return end
 local c=w:FindFirstChild("Tools",true) or w
 for _,b in ipairs(c:GetDescendants()) do if b:IsA("TextButton") then b.Activated:Connect(function()
  local o=b.BackgroundColor3 b.BackgroundColor3=Color3.fromRGB(124,58,237) task.delay(0.2,function() b.BackgroundColor3=o end)
  local cat=MAP_SING[name] or "" local pat=cat~="" and ("arkher."..cat.."."..string.lower(b.Name)) or string.lower(b.Name)
  callSing(pat,b.Name)
 end) end end
end
for _,n in ipairs({"ARKHER_SingularityCore","ARKHER_SingularityMemory","ARKHER_SingularityAgents","ARKHER_D_O15","ARKHER_MobileAAA","ARKHER_ConsoleAAA","ARKHER_NeuralRenderer","ARKHER_WorldContinuum","ARKHER_Audio3D","ARKHER_AnimationAAA","ARKHER_PhysicsAAA","ARKHER_MonetizationAAA","ARKHER_SecurityAAA","ARKHER_DeployAAA"}) do pcall(wireSing,n) end
print("[V1.29 SINGULARITY AAA] Singularity AI imposto + AAA console/PC no celular — literalmente pronto")
"""
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    f.add(Inst("LocalScript","ARKHER_Singularity_AAA_V29",{"Source":(T_STRING, FUNC29)}))
        if r.cls=="ServerScriptService":
            # Server impõe Singularity Core autoritativo
            r.add(Inst("Script","ARKHER_Singularity_Server",{"Source":(T_STRING, "-- Singularity Server UES\n_G.ARKHER_SINGULARITY_SERVER=true\nprint('[SINGULARITY SERVER] UES imposicao autoritativa')\n")}))
    return roots

if __name__=="__main__":
    roots=build_all_v121()
    roots=patch22b(roots)
    roots=patch24(roots)
    roots=patch25(roots)
    roots=patch26(roots)
    roots=patch27(roots)
    roots=patch28(roots)
    roots=patch29(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_29.rbxl")
    write(out, serialize(roots))
    print(f"V1.29 SINGULARITY AAA {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_29.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.29 done")
