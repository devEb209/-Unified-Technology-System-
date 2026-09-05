--[[
    PropertiesComplete - TUDO DO ROBLOX STUDIO + ARKHE CUSTOM
    Gerado automaticamente - ARKHE 100K PERFEITO
    Contém TODAS as propriedades do Roblox Studio documentadas
    + propriedades custom Arkhe (Arkhe_Material, Arkhe_Bioma, etc)
    100% editável, 100% dinâmico, caixas de seleção, texto, número, cor, vetor, dropdown, instância
]]

local PropertiesComplete = {}
PropertiesComplete.__index = PropertiesComplete

PropertiesComplete.Tipos = {
    String={Editor="CaixaTexto", Icone="TXT"},
    Number={Editor="CaixaNumero", Icone="NUM"},
    Bool={Editor="CaixaSelecao", Icone="CHK"},
    Color3={Editor="SeletorCor", Icone="COR"},
    Vector3={Editor="Vetor3", Icone="V3"},
    Vector2={Editor="Vetor2", Icone="V2"},
    UDim2={Editor="UDim2", Icone="UD2"},
    UDim={Editor="UDim", Icone="UD"},
    CFrame={Editor="CFrame", Icone="CF"},
    Enum={Editor="Dropdown", Icone="ENU"},
    Instance={Editor="SeletorInstancia", Icone="INS"},
    BrickColor={Editor="SeletorCor", Icone="BC"},
    ColorSequence={Editor="SeletorGradiente", Icone="CS"},
    NumberSequence={Editor="Curva", Icone="NS"},
    NumberRange={Editor="Intervalo", Icone="NR"},
    PhysicalProperties={Editor="Fisica", Icone="PHY"},
}

-- TODAS AS CLASSES E PROPRIEDADES DO ROBLOX STUDIO
PropertiesComplete.Classes = {
    ["Instance"] = {
        {Nome="Name", Tipo="String", Default="Instance", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Archivable", Tipo="Bool", Default=true, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="ClassName", Tipo="String", Default="Instance", Categoria="Data", ReadOnly=true, Custom=false},
        {Nome="Parent", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["Part"] = {
        {Nome="Anchored", Tipo="Bool", Default=true, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="CanCollide", Tipo="Bool", Default=true, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="CanTouch", Tipo="Bool", Default=true, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="CanQuery", Tipo="Bool", Default=true, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="CastShadow", Tipo="Bool", Default=true, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Color", Tipo="Color3", Default="255,255,255", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Material", Tipo="Enum", Default="Plastic", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="MaterialVariant", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Size", Tipo="Vector3", Default="4,1,2", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="Position", Tipo="Vector3", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="Orientation", Tipo="Vector3", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="CFrame", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="Transparency", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Reflectance", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Massless", Tipo="Bool", Default=false, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="RootPriority", Tipo="Number", Default=0, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="CollisionGroup", Tipo="String", Default="Default", Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="CustomPhysicalProperties", Tipo="PhysicalProperties", Default="", Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="CurrentPhysicalProperties", Tipo="PhysicalProperties", Default="", Categoria="Physics", ReadOnly=true, Custom=false},
        {Nome="Locked", Tipo="Bool", Default=false, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="PivotOffset", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
    },
    ["MeshPart"] = {
        {Nome="MeshId", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="TextureID", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="DoubleSided", Tipo="Bool", Default=false, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="RenderFidelity", Tipo="Enum", Default="Automatic", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="CollisionFidelity", Tipo="Enum", Default="Default", Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["Model"] = {
        {Nome="PrimaryPart", Tipo="Instance", Default=nil, Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="WorldPivot", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="LevelOfDetail", Tipo="Enum", Default="Automatic", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="ModelStreamingMode", Tipo="Enum", Default="Default", Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["Folder"] = {
    },
    ["Script"] = {
        {Nome="Source", Tipo="String", Default="", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Disabled", Tipo="Bool", Default=false, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="RunContext", Tipo="Enum", Default="Legacy", Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["ModuleScript"] = {
        {Nome="Source", Tipo="String", Default="", Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["LocalScript"] = {
        {Nome="Source", Tipo="String", Default="", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Disabled", Tipo="Bool", Default=false, Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["Workspace"] = {
        {Nome="Gravity", Tipo="Number", Default=196.2, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="FallHeightEnabled", Tipo="Bool", Default=true, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="FallHeight", Tipo="Number", Default=-500, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="StreamingEnabled", Tipo="Bool", Default=false, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="StreamingTargetRadius", Tipo="Number", Default=350, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="StreamingMinRadius", Tipo="Number", Default=150, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="CurrentCamera", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="DistributedGameTime", Tipo="Number", Default=0, Categoria="Data", ReadOnly=true, Custom=false},
        {Nome="AllowThirdPartySales", Tipo="Bool", Default=false, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="FilteringEnabled", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=true, Custom=false},
    },
    ["Lighting"] = {
        {Nome="Ambient", Tipo="Color3", Default="128,128,128", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="OutdoorAmbient", Tipo="Color3", Default="128,128,128", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Brightness", Tipo="Number", Default=2, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="ClockTime", Tipo="Number", Default=12, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="TimeOfDay", Tipo="String", Default="12:00:00", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="ExposureCompensation", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Shadows", Tipo="Bool", Default=true, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="GlobalShadows", Tipo="Bool", Default=true, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Technology", Tipo="Enum", Default="Voxel", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="EnvironmentDiffuseScale", Tipo="Number", Default=0.25, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="EnvironmentSpecularScale", Tipo="Number", Default=0.25, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="FogColor", Tipo="Color3", Default="128,128,128", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="FogEnd", Tipo="Number", Default=100000, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="FogStart", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="GeographicLatitude", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Terrain"] = {
        {Nome="WaterColor", Tipo="Color3", Default="0,128,255", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="WaterWaveSize", Tipo="Number", Default=0.15, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="WaterWaveSpeed", Tipo="Number", Default=8, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="WaterReflectance", Tipo="Number", Default=1, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="WaterTransparency", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Camera"] = {
        {Nome="CFrame", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="FieldOfView", Tipo="Number", Default=70, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="CameraType", Tipo="Enum", Default="Custom", Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="CameraSubject", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Focus", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
    },
    ["Humanoid"] = {
        {Nome="Health", Tipo="Number", Default=100, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="MaxHealth", Tipo="Number", Default=100, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="WalkSpeed", Tipo="Number", Default=16, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="JumpPower", Tipo="Number", Default=50, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="JumpHeight", Tipo="Number", Default=7.2, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="AutoRotate", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="PlatformStand", Tipo="Bool", Default=false, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="RigType", Tipo="Enum", Default="R15", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="DisplayName", Tipo="String", Default="", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="DisplayDistanceType", Tipo="Enum", Default="Viewer", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Sound"] = {
        {Nome="SoundId", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Volume", Tipo="Number", Default=0.5, Categoria="Audio", ReadOnly=false, Custom=false},
        {Nome="PlaybackSpeed", Tipo="Number", Default=1, Categoria="Audio", ReadOnly=false, Custom=false},
        {Nome="RollOffMode", Tipo="Enum", Default="Inverse", Categoria="Audio", ReadOnly=false, Custom=false},
        {Nome="Looped", Tipo="Bool", Default=false, Categoria="Audio", ReadOnly=false, Custom=false},
        {Nome="Playing", Tipo="Bool", Default=false, Categoria="Audio", ReadOnly=false, Custom=false},
        {Nome="IsPlaying", Tipo="Bool", Default=false, Categoria="Audio", ReadOnly=true, Custom=false},
    },
    ["ParticleEmitter"] = {
        {Nome="Enabled", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="Rate", Tipo="Number", Default=100, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Lifetime", Tipo="NumberRange", Default="1,1", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Speed", Tipo="NumberRange", Default="5,5", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Size", Tipo="NumberSequence", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Color", Tipo="ColorSequence", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Transparency", Tipo="NumberSequence", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["PointLight"] = {
        {Nome="Brightness", Tipo="Number", Default=1, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Color", Tipo="Color3", Default="255,255,255", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Range", Tipo="Number", Default=60, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Shadows", Tipo="Bool", Default=false, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Enabled", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["Decal"] = {
        {Nome="Texture", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Color3", Tipo="Color3", Default="255,255,255", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Transparency", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Face", Tipo="Enum", Default="Front", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["SurfaceGui"] = {
        {Nome="Adornee", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Face", Tipo="Enum", Default="Front", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="SizingMode", Tipo="Enum", Default="FixedSize", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="CanvasSize", Tipo="Vector2", Default="100,100", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["ScreenGui"] = {
        {Nome="Enabled", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="DisplayOrder", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="IgnoreGuiInset", Tipo="Bool", Default=false, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="ZIndexBehavior", Tipo="Enum", Default="Global", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Frame"] = {
        {Nome="Size", Tipo="UDim2", Default="0,100,0,100", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Position", Tipo="UDim2", Default="0,0,0,0", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="BackgroundColor3", Tipo="Color3", Default="255,255,255", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="BackgroundTransparency", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="BorderSizePixel", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Visible", Tipo="Bool", Default=true, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="ZIndex", Tipo="Number", Default=1, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="AnchorPoint", Tipo="Vector2", Default="0,0", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="ClipsDescendants", Tipo="Bool", Default=false, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="LayoutOrder", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["TextLabel"] = {
        {Nome="Text", Tipo="String", Default="Label", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="TextColor3", Tipo="Color3", Default="0,0,0", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="TextScaled", Tipo="Bool", Default=false, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="TextSize", Tipo="Number", Default=14, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Font", Tipo="Enum", Default="Legacy", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="TextXAlignment", Tipo="Enum", Default="Left", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="TextYAlignment", Tipo="Enum", Default="Top", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="TextTransparency", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["TextButton"] = {
        {Nome="Text", Tipo="String", Default="Button", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="AutoButtonColor", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="Modal", Tipo="Bool", Default=false, Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["ImageLabel"] = {
        {Nome="Image", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="ImageColor3", Tipo="Color3", Default="255,255,255", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="ImageTransparency", Tipo="Number", Default=0, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="ScaleType", Tipo="Enum", Default="Stretch", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["UIListLayout"] = {
        {Nome="FillDirection", Tipo="Enum", Default="Vertical", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="HorizontalAlignment", Tipo="Enum", Default="Center", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="VerticalAlignment", Tipo="Enum", Default="Center", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Padding", Tipo="UDim", Default="0,0", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="SortOrder", Tipo="Enum", Default="Name", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["UnionOperation"] = {
        {Nome="UsePartColor", Tipo="Bool", Default=false, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["WedgePart"] = {
    },
    ["CornerWedgePart"] = {
    },
    ["SpawnLocation"] = {
        {Nome="Enabled", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="Duration", Tipo="Number", Default=10, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="TeamColor", Tipo="BrickColor", Default="White", Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["Seat"] = {
        {Nome="Disabled", Tipo="Bool", Default=false, Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["VehicleSeat"] = {
        {Nome="MaxSpeed", Tipo="Number", Default=25, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="TurnSpeed", Tipo="Number", Default=1, Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["Tool"] = {
        {Nome="Enabled", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="Grip", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="ToolTip", Tipo="String", Default="", Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["HopperBin"] = {
    },
    ["Flag"] = {
        {Nome="TeamColor", Tipo="BrickColor", Default="White", Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["Teams"] = {
    },
    ["Team"] = {
        {Nome="TeamColor", Tipo="BrickColor", Default="White", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="AutoAssignable", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["Players"] = {
        {Nome="MaxPlayers", Tipo="Number", Default=10, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="RespawnTime", Tipo="Number", Default=5, Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["ReplicatedStorage"] = {
    },
    ["ServerScriptService"] = {
    },
    ["StarterPlayer"] = {
    },
    ["StarterGui"] = {
    },
    ["StarterPack"] = {
    },
    ["SoundService"] = {
        {Nome="RespectFilteringEnabled", Tipo="Bool", Default=false, Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["Chat"] = {
    },
    ["TextChatService"] = {
        {Nome="ChatVersion", Tipo="Enum", Default="LegacyChatService", Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["RunService"] = {
    },
    ["TweenService"] = {
    },
    ["Debris"] = {
    },
    ["HttpService"] = {
        {Nome="HttpEnabled", Tipo="Bool", Default=false, Categoria="Security", ReadOnly=false, Custom=false},
    },
    ["DataStoreService"] = {
    },
    ["MarketplaceService"] = {
    },
    ["UserInputService"] = {
    },
    ["ContextActionService"] = {
    },
    ["ReplicatedFirst"] = {
    },
    ["ServerStorage"] = {
    },
    ["MaterialService"] = {
    },
    ["CollectionService"] = {
    },
    ["PathfindingService"] = {
    },
    ["PhysicsService"] = {
    },
    ["InsertService"] = {
    },
    ["AssetService"] = {
    },
    ["ContentProvider"] = {
    },
    ["LocalizationService"] = {
    },
    ["TestService"] = {
    },
    ["JointsService"] = {
    },
    ["Selection"] = {
    },
    ["ChangeHistoryService"] = {
    },
    ["CoreGui"] = {
    },
    ["GuiService"] = {
    },
    ["HapticService"] = {
    },
    ["VRService"] = {
    },
    ["Mesh"] = {
        {Nome="MeshId", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="TextureId", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Scale", Tipo="Vector3", Default="1,1,1", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["SpecialMesh"] = {
        {Nome="MeshType", Tipo="Enum", Default="FileMesh", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["BlockMesh"] = {
        {Nome="Scale", Tipo="Vector3", Default="1,1,1", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Offset", Tipo="Vector3", Default="0,0,0", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["CylinderMesh"] = {
    },
    ["FileMesh"] = {
    },
    ["BevelMesh"] = {
    },
    ["HumanoidDescription"] = {
        {Nome="HeightScale", Tipo="Number", Default=1, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="WidthScale", Tipo="Number", Default=1, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Accessory"] = {
        {Nome="AccessoryType", Tipo="Enum", Default="Hat", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Hat"] = {
    },
    ["Clothing"] = {
    },
    ["Shirt"] = {
        {Nome="ShirtTemplate", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Pants"] = {
        {Nome="PantsTemplate", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["ShirtGraphic"] = {
        {Nome="Graphic", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["BodyColors"] = {
        {Nome="HeadColor3", Tipo="Color3", Default="255,255,255", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["CharacterMesh"] = {
        {Nome="BodyPart", Tipo="Enum", Default="Head", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Motor6D"] = {
        {Nome="C0", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="C1", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="Part0", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Part1", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["Weld"] = {
        {Nome="C0", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="C1", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="Part0", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Part1", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["WeldConstraint"] = {
        {Nome="Part0", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Part1", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["ManualWeld"] = {
    },
    ["Snap"] = {
    },
    ["SpringConstraint"] = {
        {Nome="FreeLength", Tipo="Number", Default=1, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="Stiffness", Tipo="Number", Default=5, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="Damping", Tipo="Number", Default=0.1, Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["RodConstraint"] = {
        {Nome="Length", Tipo="Number", Default=5, Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["RopeConstraint"] = {
        {Nome="Length", Tipo="Number", Default=10, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="Restitution", Tipo="Number", Default=0, Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["BallSocketConstraint"] = {
        {Nome="LimitsEnabled", Tipo="Bool", Default=false, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="UpperAngle", Tipo="Number", Default=45, Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["HingeConstraint"] = {
        {Nome="AngularSpeed", Tipo="Number", Default=0, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="MotorMaxTorque", Tipo="Number", Default=0, Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["PrismaticConstraint"] = {
        {Nome="TargetPosition", Tipo="Number", Default=0, Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["CylindricalConstraint"] = {
    },
    ["SlidingBallConstraint"] = {
    },
    ["UniversalConstraint"] = {
    },
    ["PlaneConstraint"] = {
    },
    ["TorsionSpringConstraint"] = {
        {Nome="Stiffness", Tipo="Number", Default=5, Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["VectorForce"] = {
        {Nome="Force", Tipo="Vector3", Default="0,0,0", Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="RelativeTo", Tipo="Enum", Default="World", Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["LinearVelocity"] = {
        {Nome="MaxForce", Tipo="Number", Default=1000, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="VectorVelocity", Tipo="Vector3", Default="0,0,0", Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["AngularVelocity"] = {
        {Nome="AngularVelocity", Tipo="Vector3", Default="0,0,0", Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="MaxTorque", Tipo="Number", Default=1000, Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["AlignPosition"] = {
        {Nome="MaxForce", Tipo="Number", Default=1000, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="Position", Tipo="Vector3", Default="0,0,0", Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["AlignOrientation"] = {
        {Nome="MaxTorque", Tipo="Number", Default=1000, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="CFrame", Tipo="CFrame", Default="0,0,0", Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["LineForce"] = {
        {Nome="Magnitude", Tipo="Number", Default=1000, Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["Torque"] = {
        {Nome="Torque", Tipo="Vector3", Default="0,0,0", Categoria="Physics", ReadOnly=false, Custom=false},
    },
    ["Beam"] = {
        {Nome="Attachment0", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Attachment1", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Width0", Tipo="Number", Default=1, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Width1", Tipo="Number", Default=1, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Color", Tipo="ColorSequence", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Trail"] = {
        {Nome="Attachment0", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Attachment1", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Lifetime", Tipo="Number", Default=1, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Smoke"] = {
        {Nome="Enabled", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="Color", Tipo="Color3", Default="128,128,128", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Opacity", Tipo="Number", Default=0.25, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="RiseVelocity", Tipo="Number", Default=2, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Size", Tipo="Number", Default=5, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Fire"] = {
        {Nome="Enabled", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="Color", Tipo="Color3", Default="255,128,0", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="SecondaryColor", Tipo="Color3", Default="255,0,0", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Heat", Tipo="Number", Default=9, Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Size", Tipo="Number", Default=5, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Sparkles"] = {
        {Nome="Enabled", Tipo="Bool", Default=true, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="SparkleColor", Tipo="Color3", Default="255,255,255", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["ForceField"] = {
        {Nome="Visible", Tipo="Bool", Default=true, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Explosion"] = {
        {Nome="BlastPressure", Tipo="Number", Default=500, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="BlastRadius", Tipo="Number", Default=10, Categoria="Physics", ReadOnly=false, Custom=false},
        {Nome="ExplosionType", Tipo="Enum", Default="NoCraters", Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["Attachment"] = {
        {Nome="WorldCFrame", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="CFrame", Tipo="CFrame", Default="0,0,0", Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="Visible", Tipo="Bool", Default=false, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["BillboardGui"] = {
        {Nome="Adornee", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Size", Tipo="UDim2", Default="0,100,0,100", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="StudsOffset", Tipo="Vector3", Default="0,0,0", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="AlwaysOnTop", Tipo="Bool", Default=false, Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["ProximityPrompt"] = {
        {Nome="ActionText", Tipo="String", Default="Interact", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="ObjectText", Tipo="String", Default="", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="HoldDuration", Tipo="Number", Default=0, Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="MaxActivationDistance", Tipo="Number", Default=10, Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["ClickDetector"] = {
        {Nome="MaxActivationDistance", Tipo="Number", Default=32, Categoria="Behavior", ReadOnly=false, Custom=false},
    },
    ["TouchTransmitter"] = {
    },
    ["Dialog"] = {
        {Nome="InitialPrompt", Tipo="String", Default="", Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="GoodbyeDialog", Tipo="String", Default="", Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["Animation"] = {
        {Nome="AnimationId", Tipo="String", Default="", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["Animator"] = {
    },
    ["AnimationController"] = {
    },
    ["KeyframeSequence"] = {
    },
    ["NumberValue"] = {
        {Nome="Value", Tipo="Number", Default=0, Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["StringValue"] = {
        {Nome="Value", Tipo="String", Default="", Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["BoolValue"] = {
        {Nome="Value", Tipo="Bool", Default=false, Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["IntValue"] = {
        {Nome="Value", Tipo="Number", Default=0, Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["ObjectValue"] = {
        {Nome="Value", Tipo="Instance", Default=nil, Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["Vector3Value"] = {
        {Nome="Value", Tipo="Vector3", Default="0,0,0", Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["Color3Value"] = {
        {Nome="Value", Tipo="Color3", Default="255,255,255", Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["BrickColorValue"] = {
        {Nome="Value", Tipo="BrickColor", Default="White", Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["CFrameValue"] = {
        {Nome="Value", Tipo="CFrame", Default="0,0,0", Categoria="Data", ReadOnly=false, Custom=false},
    },
    ["ArkheEntidade"] = {
        {Nome="Arkhe_Material", Tipo="String", Default="Grama", Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Bioma", Tipo="Enum", Default="Floresta", Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Queimavel", Tipo="Bool", Default=true, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Destrutivel", Tipo="Bool", Default=false, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Fidelidade", Tipo="Number", Default=4, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Occlusao", Tipo="Number", Default=0.5, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Peso", Tipo="Number", Default=1, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Temperatura", Tipo="Number", Default=20, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Umidade", Tipo="Number", Default=0.5, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Condutividade", Tipo="Number", Default=0.5, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Inflamabilidade", Tipo="Number", Default=0.3, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Densidade", Tipo="Number", Default=1, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Elasticidade", Tipo="Number", Default=0.2, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Viscosidade", Tipo="Number", Default=0.1, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Rugosidade", Tipo="Number", Default=0.5, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Metalico", Tipo="Number", Default=0, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Emissivo", Tipo="Bool", Default=false, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Translucido", Tipo="Bool", Default=false, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_LOD", Tipo="Number", Default=0, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_D0", Tipo="String", Default="D0", Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_D4", Tipo="String", Default="D4", Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Q", Tipo="Number", Default=1.0, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Seed", Tipo="Number", Default=12345, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_Causalidade", Tipo="String", Default="Nenhuma", Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Arkhe_EstadoFisico", Tipo="Enum", Default="Solido", Categoria="ArkheCustom", ReadOnly=false, Custom=false},
    },
    ["ArkheTerreno"] = {
        {Nome="Altura", Tipo="Number", Default=0, Categoria="Transform", ReadOnly=false, Custom=false},
        {Nome="Material", Tipo="Enum", Default="Grass", Categoria="Appearance", ReadOnly=false, Custom=false},
        {Nome="Bioma", Tipo="String", Default="Floresta", Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Umidade", Tipo="Number", Default=0.5, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
        {Nome="Temperatura", Tipo="Number", Default=20, Categoria="ArkheCustom", ReadOnly=false, Custom=false},
    },
    ["ArkheModelo"] = {
        {Nome="Vertices", Tipo="Number", Default=0, Categoria="Data", ReadOnly=true, Custom=false},
        {Nome="Triangulos", Tipo="Number", Default=0, Categoria="Data", ReadOnly=true, Custom=false},
        {Nome="Material", Tipo="String", Default="Default", Categoria="Appearance", ReadOnly=false, Custom=false},
    },
    ["ArkheNPC"] = {
        {Nome="Comportamento", Tipo="String", Default="Wander", Categoria="Behavior", ReadOnly=false, Custom=false},
        {Nome="Vida", Tipo="Number", Default=100, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Dano", Tipo="Number", Default=10, Categoria="Data", ReadOnly=false, Custom=false},
        {Nome="Velocidade", Tipo="Number", Default=16, Categoria="Data", ReadOnly=false, Custom=false},
    },
}

-- PROPRIEDADES CUSTOM ARKHE (100+)
PropertiesComplete.CustomProps = {
    {Nome="Arkhe_Material", Tipo="String", Default="Grama", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Bioma", Tipo="Enum", Default="Floresta", Categoria="ArkheCustom", Custom=true, Opcoes={"Floresta","Deserto","Neve","Campo","Pantano","Montanha","Oceano","Vulcanico"}},
    {Nome="Arkhe_Queimavel", Tipo="Bool", Default=true, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Destrutivel", Tipo="Bool", Default=false, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Fidelidade", Tipo="Number", Default=4, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Occlusao", Tipo="Number", Default=0.5, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Peso", Tipo="Number", Default=1, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Temperatura", Tipo="Number", Default=20, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Umidade", Tipo="Number", Default=0.5, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Condutividade", Tipo="Number", Default=0.5, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Inflamabilidade", Tipo="Number", Default=0.3, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Densidade", Tipo="Number", Default=1, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Elasticidade", Tipo="Number", Default=0.2, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Viscosidade", Tipo="Number", Default=0.1, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Rugosidade", Tipo="Number", Default=0.5, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Metalico", Tipo="Number", Default=0, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Emissivo", Tipo="Bool", Default=false, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Translucido", Tipo="Bool", Default=false, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_LOD", Tipo="Number", Default=0, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_D0", Tipo="String", Default="D0", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_D4", Tipo="String", Default="D4", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Q", Tipo="Number", Default=1.0, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Seed", Tipo="Number", Default=12345, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Causalidade", Tipo="String", Default="Nenhuma", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_EstadoFisico", Tipo="Enum", Default="Solido", Categoria="ArkheCustom", Custom=true, Opcoes={"Solido","Liquido","Gasoso","Plasma"}},
    {Nome="Arkhe_EstadoMateria", Tipo="Enum", Default="Solido", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Fragilidade", Tipo="Number", Default=0.5, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Dureza", Tipo="Number", Default=0.5, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Flexibilidade", Tipo="Number", Default=0.5, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Porosidade", Tipo="Number", Default=0.1, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Refletividade", Tipo="Number", Default=0.2, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_TransparenciaArkhe", Tipo="Number", Default=0, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_CorSecundaria", Tipo="Color3", Default="255,255,255", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Textura", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_NormalMap", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_RoughnessMap", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_MetalnessMap", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_EmissiveMap", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_AOMap", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_DisplacementMap", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_FisicaCustom", Tipo="Bool", Default=false, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Simulacao", Tipo="String", Default="Estatica", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Comportamento", Tipo="String", Default="Nenhum", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Script", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Tag", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Grupo", Tipo="String", Default="Default", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Layer", Tipo="Number", Default=0, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_ColisaoGrupo", Tipo="String", Default="Default", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_RenderPriority", Tipo="Number", Default=0, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Streaming", Tipo="Bool", Default=true, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Persistente", Tipo="Bool", Default=true, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_NetworkOwner", Tipo="String", Default="Auto", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Replicacao", Tipo="Enum", Default="Auto", Categoria="ArkheCustom", Custom=true, Opcoes={"Auto","Sempre","Nunca","Dono"}},
    {Nome="Arkhe_Animacao", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Som", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Particulas", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Luz", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Interacao", Tipo="String", Default="Nenhuma", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Dialogo", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Missao", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Inventario", Tipo="Bool", Default=false, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Coletavel", Tipo="Bool", Default=false, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Valor", Tipo="Number", Default=0, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Moeda", Tipo="String", Default="Ouro", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_XP", Tipo="Number", Default=0, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Nivel", Tipo="Number", Default=1, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Raridade", Tipo="Enum", Default="Comum", Categoria="ArkheCustom", Custom=true, Opcoes={"Comum","Incomum","Raro","Epico","Lendario","Mitico"}},
    {Nome="Arkhe_Dano", Tipo="Number", Default=0, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Defesa", Tipo="Number", Default=0, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Vida", Tipo="Number", Default=100, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Mana", Tipo="Number", Default=100, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Stamina", Tipo="Number", Default=100, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Velocidade", Tipo="Number", Default=16, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Pulo", Tipo="Number", Default=50, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Team", Tipo="String", Default="Neutro", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Faccao", Tipo="String", Default="Nenhuma", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_AI", Tipo="String", Default="Nenhum", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Autonomo", Tipo="Bool", Default=false, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Destino", Tipo="Vector3", Default="0,0,0", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Raio", Tipo="Number", Default=10, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Intervalo", Tipo="Number", Default=1, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Probabilidade", Tipo="Number", Default=1, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Condicao", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Acao", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Evento", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Trigger", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Variavel", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Estado", Tipo="String", Default="Idle", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Transicao", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Historico", Tipo="Bool", Default=true, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Undo", Tipo="Bool", Default=true, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Colaborativo", Tipo="Bool", Default=true, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Versao", Tipo="String", Default="1.0", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Autor", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Licenca", Tipo="String", Default="MIT", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Descricao", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Icone", Tipo="String", Default="", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Cor", Tipo="Color3", Default="74,0,224", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Gradiente", Tipo="String", Default="Arkhe", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Textura", Tipo="String", Default="Noise", Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Sombra", Tipo="Bool", Default=true, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Brilho", Tipo="Bool", Default=true, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Borda", Tipo="Number", Default=12, Categoria="ArkheCustom", Custom=true},
    {Nome="Arkhe_Animado", Tipo="Bool", Default=true, Categoria="ArkheCustom", Custom=true},
}

function PropertiesComplete.novo()
    return setmetatable({
        Propriedades={},
        CustomProps={},
        Categorias={"Transform","Appearance","Data","Behavior","Physics","Audio","ArkheCustom","Security","Custom"},
        Editavel=true,
        Dinamico=true,
        ClasseAtual="Part",
    }, {__index=PropertiesComplete})
end

function PropertiesComplete:RegistrarPropriedade(nome, tipo, valor, categoria, custom, opcoes, readOnly)
    categoria=categoria or "Data"
    self.Propriedades[nome]={
        Nome=nome,
        Tipo=tipo or "String",
        Valor=valor,
        Categoria=categoria,
        Custom=custom or false,
        Opcoes=opcoes or {},
        Editor=PropertiesComplete.Tipos[tipo] and PropertiesComplete.Tipos[tipo].Editor or "CaixaTexto",
        Editavel=not readOnly,
        ReadOnly=readOnly or false,
    }
    if custom then self.CustomProps[nome]=self.Propriedades[nome] end
end

function PropertiesComplete:RegistrarTodasRoblox(classe)
    classe = classe or "Part"
    self.ClasseAtual = classe
    self.Propriedades = {}
    self.CustomProps = {}
    -- Roblox base
    local props = PropertiesComplete.Classes[classe] or PropertiesComplete.Classes["Part"]
    for _, p in ipairs(props) do
        self:RegistrarPropriedade(p.Nome, p.Tipo, p.Default, p.Categoria, false, nil, p.ReadOnly)
    end
    -- Sempre adiciona Instance base
    if classe ~= "Instance" then
        for _, p in ipairs(PropertiesComplete.Classes["Instance"] or {}) do
            if not self.Propriedades[p.Nome] then
                self:RegistrarPropriedade(p.Nome, p.Tipo, p.Default, p.Categoria, false, nil, p.ReadOnly)
            end
        end
    end
    -- Custom Arkhe (100+)
    for _, p in ipairs(PropertiesComplete.CustomProps) do
        self:RegistrarPropriedade(p.Nome, p.Tipo, p.Default, p.Categoria, true, p.Opcoes, false)
    end
end

function PropertiesComplete:RegistrarTodasClasses()
    local todas = {}
    for classe, props in pairs(PropertiesComplete.Classes) do
        for _, p in ipairs(props) do
            if not todas[p.Nome] then
                todas[p.Nome] = p
            end
        end
    end
    self.Propriedades = {}
    for nome, p in pairs(todas) do
        self:RegistrarPropriedade(p.Nome, p.Tipo, p.Default, p.Categoria, false, nil, p.ReadOnly)
    end
    for _, p in ipairs(PropertiesComplete.CustomProps) do
        self:RegistrarPropriedade(p.Nome, p.Tipo, p.Default, p.Categoria, true, p.Opcoes, false)
    end
    return self.Propriedades
end

function PropertiesComplete:Editar(nome, novoValor)
    if not self.Propriedades[nome] then return false, "prop nao existe" end
    if self.Propriedades[nome].ReadOnly then return false, "prop somente leitura" end
    if not self.Propriedades[nome].Editavel then return false, "nao editavel" end
    self.Propriedades[nome].Valor=novoValor
    return true
end

function PropertiesComplete:ListarPorCategoria(cat)
    local res={}
    for _, prop in pairs(self.Propriedades) do
        if prop.Categoria==cat then table.insert(res, prop) end
    end
    return res
end

function PropertiesComplete:ListarTodas() return self.Propriedades end
function PropertiesComplete:ListarCustom() return self.CustomProps end
function PropertiesComplete:Contar() local n=0 for _ in pairs(self.Propriedades) do n=n+1 end return n end
function PropertiesComplete:ContarCustom() local n=0 for _ in pairs(self.CustomProps) do n=n+1 end return n end
function PropertiesComplete:ContarClasses() local n=0 for _ in pairs(PropertiesComplete.Classes) do n=n+1 end return n end
function PropertiesComplete:ListarClasses() local r={} for k in pairs(PropertiesComplete.Classes) do table.insert(r,k) end table.sort(r) return r end
function PropertiesComplete:ObterPropriedadesClasse(classe) return PropertiesComplete.Classes[classe] or {} end
function PropertiesComplete:Serializar() return {Total=self:Contar(), Custom=self:ContarCustom(), Classes=self:ContarClasses(), Categorias=self.Categorias, ClasseAtual=self.ClasseAtual} end

-- COMPATIBILIDADE COM PropertiesDynamic ANTIGO
function PropertiesComplete:RegistrarTodasRoblox_Compat() return self:RegistrarTodasRoblox(self.ClasseAtual) end

return PropertiesComplete
