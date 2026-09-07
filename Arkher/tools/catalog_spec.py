# ARKHER V1 :: catalog specification (round 1 = A, S, X; round 2 = B, U, Y)
# Each system = area x aspect. Aspect decides the kit (a real working machine) and the
# specialized methods emitted for that system.

ASPECTS_A = [
    ("Core Runtime",        "orchestrator", "runtime lifecycle and phase orchestration"),
    ("Registry",            "registry",     "typed record storage, tagging and querying"),
    ("Pipeline",            "pipeline",     "staged processing with isolation and retries"),
    ("Cache",               "cache",        "hot-path memoization with policy-driven eviction"),
    ("Adaptive Controller", "controller",   "closed-loop regulation of the subsystem"),
    ("Analytics",           "analyzer",     "statistical trend, anomaly and forecast analysis"),
    ("Budget Governor",     "budgeter",     "allocation of a scarce resource across consumers"),
    ("Access Guard",        "guard",        "capability checks and rate limiting"),
    ("Codec",               "codec",        "encode/decode/diff of the subsystem payloads"),
    ("Dependency Graph",    "graph",        "relationship modelling and shortest-path resolution"),
    ("Predictor",           "predictor",    "forecasting of future demand and state"),
    ("Audit Ledger",        "ledger",       "append-only journal with sealing and histograms"),
    ("Recovery",            "recovery",     "checkpointing and rollback of subsystem state"),
]

AREAS_A = [
    ("Module", "module"), ("Entity", "entity"), ("Component", "component"), ("Resource", "resource"),
    ("Scheduler", "scheduler"), ("Job", "job"), ("Event", "event"), ("Signal", "signal"),
    ("Dependency", "dependency"), ("Service", "service"), ("Lifecycle", "lifecycle"), ("State", "state"),
    ("Type", "type"), ("Reflection", "reflection"), ("Serialization", "serialization"), ("Memory", "memory"),
    ("Object Pool", "pool"), ("Async", "async"), ("Parallel Execution", "parallel"), ("Worker", "worker"),
    ("Error", "error"), ("Logging", "logging"), ("Diagnostics", "diagnostics"), ("Validation", "validation"),
    ("Configuration", "config"), ("Environment", "environment"), ("Feature Flag", "featureflag"),
    ("Capability", "capability"), ("Permission", "permission"), ("Sandbox", "sandbox"),
    ("API Gateway", "apigateway"), ("Extension", "extension"), ("Hot Reload", "hotreload"),
    ("Versioning", "versioning"), ("Migration", "migration"), ("Build Graph", "buildgraph"),
    ("Bootstrap", "bootstrap"), ("Math Kernel", "math"), ("Spatial Kernel", "spatial"), ("Time Kernel", "time"),
]

ASPECTS_S = [
    ("Profiler",             "analyzer",     "measurement and statistical profiling"),
    ("Budget Governor",      "budgeter",     "hard per-frame budget enforcement"),
    ("Adaptive Controller",  "controller",   "closed-loop quality regulation"),
    ("Bottleneck Analyzer",  "analyzer",     "detection of over-budget behaviour"),
    ("LOD Policy",           "policy",       "fidelity band selection and dispatch"),
    ("Dynamic Scaler",       "controller",   "runtime scaling of workload"),
    ("Predictive Optimizer", "predictor",    "ahead-of-time optimization from forecasts"),
    ("Result Cache",         "cache",        "reuse of expensive computations"),
    ("Streaming Governor",   "streamer",     "distance-driven load/unload of work"),
    ("Telemetry",            "ledger",       "counters, histograms and percentile export"),
    ("Fallback Recovery",    "recovery",     "safe degradation and restoration"),
    ("Quality Composer",     "composer",     "blending of quality signals into one output"),
    ("Scheduling Policy",    "policy",       "fair dispatch of the subsystem workload"),
    ("Compression Codec",    "codec",        "payload size reduction"),
    ("Throttle Guard",       "guard",        "rate limiting of expensive operations"),
    ("Spatial Index",        "index",        "spatial acceleration of the subsystem queries"),
    ("Cost Graph",           "graph",        "cost relationships and critical path"),
    ("Numeric Solver",       "solver",       "iterative convergence of the subsystem model"),
    ("Registry",             "registry",     "catalogued optimization records"),
    ("Optimization Pipeline","pipeline",     "ordered optimization passes"),
]

AREAS_S = [
    ("CPU", "cpu"), ("GPU", "gpu"), ("Memory", "memory"), ("Network", "network"),
    ("Rendering", "rendering"), ("Physics", "physics"), ("AI", "ai"), ("Animation", "animation"),
    ("Audio", "audio"), ("Terrain", "terrain"), ("Asset", "asset"), ("Texture", "texture"),
    ("Geometry", "geometry"), ("Particle", "particle"), ("UI", "ui"), ("Streaming", "streaming"),
    ("Scripting", "scripting"), ("NPC", "npc"), ("World Simulation", "world"), ("Lighting", "lighting"),
    ("Shadow", "shadow"), ("Reflection Probe", "reflection"), ("Post Process", "postfx"),
    ("Occlusion", "occlusion"), ("Culling", "culling"), ("LOD", "lod"), ("Thermal", "thermal"),
    ("Battery", "battery"), ("Mobile", "mobile"), ("Console", "console"), ("VR", "vr"),
]

ASPECTS_X = [
    ("Validator",     "pipeline",     "multi-stage validation of inputs"),
    ("Guard",         "guard",        "capability enforcement and rate limiting"),
    ("Registry",      "registry",     "record keeping of security decisions"),
    ("Audit Ledger",  "ledger",       "tamper-evident audit journal"),
    ("Recovery",      "recovery",     "state protection and rollback"),
    ("Policy Engine", "policy",       "ordered application of security policy"),
    ("Analyzer",      "analyzer",     "behavioural anomaly analysis"),
    ("Integrity Codec","codec",       "checksummed encoding of protected data"),
    ("Trust Controller","controller", "adaptive trust scoring"),
    ("Orchestrator",  "orchestrator", "incident state machine"),
]

AREAS_X = [
    ("Runtime Validation", "runtime"), ("Input Validation", "input"), ("Asset Validation", "asset"),
    ("Project Validation", "project"), ("Script Isolation", "script"), ("Plugin Isolation", "plugin"),
    ("Network Validation", "network"), ("Replication Safety", "replication"), ("Datastore Safety", "datastore"),
    ("Player Safety", "player"), ("Permission", "permission"), ("Capability", "capability"),
    ("Sandbox", "sandbox"), ("Process Isolation", "isolation"), ("Integrity", "integrity"),
    ("Checksum", "checksum"), ("Crash Recovery", "crash"), ("State Recovery", "staterecovery"),
    ("Error Containment", "error"), ("Watchdog", "watchdog"), ("Health Check", "health"),
    ("Telemetry Privacy", "privacy"), ("Anti Exploit", "antiexploit"), ("Rate Limit", "ratelimit"),
    ("Quota", "quota"), ("Dependency Validation", "dependency"), ("Version Validation", "version"),
    ("Schema Enforcement", "schema"), ("Serialization Safety", "serialization"), ("Memory Safety", "memorysafety"),
    ("Resource Guard", "resourceguard"), ("API Gateway", "apigateway"), ("Trust Model", "trust"),
    ("Content Safety", "content"), ("Collaboration Permission", "collab"), ("Build Validation", "build"),
    ("Deployment Gate", "deployment"), ("Rollback", "rollback"), ("Incident Response", "incident"),
    ("Compliance Report", "compliance"), ("Access Review", "accessreview"),
]


# ---------------------------------------------------------------- ROUND 2 (B, U, Y)
ASPECTS_B = [
    ("Document Model",     "document",   "transactional editing state with dirty tracking and revisions"),
    ("Command Stack",      "commands",   "undoable operations with grouping and coalescing"),
    ("Selection Model",    "selection",  "multi-selection with primary item and filters"),
    ("Panel Layout",       "layout",     "dockable panel tree with persistence"),
    ("Widget Surface",     "widget",     "retained-mode UI tree with data bindings"),
    ("Property Inspector", "inspector",  "reflection-driven property editing"),
    ("Node Editor",        "nodegraph",  "typed node graph authoring and compilation"),
    ("Registry",           "registry",   "catalogued editor records, tags and queries"),
    ("Tool Pipeline",      "pipeline",   "staged tool execution with isolation"),
    ("Preview Cache",      "cache",      "reuse of expensive editor previews"),
    ("Session Sync",       "session",    "multi-user editing of this editor surface"),
    ("Task Runner",        "taskgraph",  "incremental background work for the editor"),
    ("Telemetry",          "ledger",     "editor interaction journal and histograms"),
    ("Recovery",           "recovery",   "crash-safe checkpointing of editor state"),
]

AREAS_B = [
    ("Viewport", "viewport"), ("Scene Outliner", "outliner"), ("Property Panel", "properties"),
    ("Asset Browser", "assetbrowser"), ("Material Editor", "materialeditor"), ("Terrain Editor", "terraineditor"),
    ("Animation Editor", "animationeditor"), ("Particle Editor", "particleeditor"), ("Audio Editor", "audioeditor"),
    ("Script Editor", "scripteditor"), ("Visual Script Editor", "visualeditor"), ("Timeline", "timeline"),
    ("Curve Editor", "curveeditor"), ("Blueprint Library", "blueprint"), ("Prefab Editor", "prefab"),
    ("Tool Palette", "toolpalette"), ("Gizmo", "gizmo"), ("Grid And Snapping", "grid"),
    ("Camera Bookmark", "camerabookmark"), ("Layer Manager", "layers"), ("Tag Manager", "tags"),
    ("Search And Filter", "search"), ("Command Palette", "palette"), ("Shortcut Map", "shortcuts"),
    ("Theme", "theme"), ("Localization", "localization"), ("Preferences", "preferences"),
    ("Project Browser", "projectbrowser"), ("Package Manager", "packages"), ("Plugin Host", "pluginhost"),
    ("Console", "console"), ("Log Viewer", "logviewer"), ("Profiler View", "profilerview"),
    ("Debugger View", "debuggerview"), ("Memory View", "memoryview"), ("Network View", "networkview"),
    ("Statistics HUD", "statshud"), ("Notification Center", "notifications"), ("Wizard", "wizard"),
    ("Template Gallery", "templates"), ("Import Dialog", "importer"), ("Export Dialog", "exporter"),
    ("Version Panel", "versionpanel"), ("Review Panel", "reviewpanel"), ("Comment Thread", "comments"),
    ("Onboarding Tour", "onboarding"), ("Accessibility", "accessibility"), ("Touch Input", "touch"),
    ("Gamepad Navigation", "gamepad"), ("Undo History", "undohistory"),
]

ASPECTS_U = [
    ("Source Model",          "source",       "tokenizing, symbol extraction and diagnostics"),
    ("Symbol Registry",       "registry",     "declaration records, tags and lookup"),
    ("Analysis Pipeline",     "pipeline",     "staged static analysis of the subsystem"),
    ("Graph Authoring",       "nodegraph",    "visual authoring compiled to real Luau"),
    ("Compile Cache",         "cache",        "reuse of compiled and analyzed artifacts"),
    ("Diagnostics Ledger",    "ledger",       "append-only journal of code events"),
    ("Reference Graph",       "graph",        "symbol relationships and reachability"),
    ("Refactor Commands",     "commands",     "undoable code transformations"),
    ("Completion Predictor",  "predictor",    "ranking of the next likely symbol"),
    ("Sandbox Guard",         "guard",        "capability limits on executed code"),
    ("Execution Orchestrator","orchestrator", "state machine of the execution lifecycle"),
    ("Buffer Document",       "document",     "transactional text and metadata buffer"),
    ("Build Tasks",           "taskgraph",    "incremental compile and test tasks"),
    ("Codegen Codec",         "codec",        "encode and diff of generated code payloads"),
    ("Failure Recovery",      "recovery",     "checkpointing and rollback of code state"),
]

AREAS_U = [
    ("Lexer", "lexer"), ("Parser", "parser"), ("Syntax Tree", "ast"), ("Symbol Table", "symtable"),
    ("Type Inference", "typeinference"), ("Diagnostics", "diagnostics"), ("Linter", "linter"),
    ("Formatter", "formatter"), ("Completion", "completion"), ("Signature Help", "signature"),
    ("Hover Documentation", "hover"), ("Go To Definition", "definition"), ("Find References", "references"),
    ("Rename Refactor", "rename"), ("Extract Function", "extract"), ("Code Action", "codeaction"),
    ("Snippet", "snippet"), ("Template Codegen", "codegen"), ("Module Resolver", "resolver"),
    ("Import Manager", "imports"), ("Dependency Analysis", "depanalysis"), ("Dead Code", "deadcode"),
    ("Complexity Metrics", "complexity"), ("Test Runner", "testrunner"), ("Coverage", "coverage"),
    ("Breakpoint", "breakpoint"), ("Step Execution", "stepping"), ("Watch Expression", "watch"),
    ("Call Stack", "callstack"), ("Hot Reload", "hotreload"), ("Script Sandbox", "scriptsandbox"),
    ("Bytecode Cache", "bytecode"), ("Visual Script Graph", "visualgraph"), ("Node Library", "nodelibrary"),
    ("Graph Compiler", "graphcompiler"), ("Event Binding", "eventbinding"), ("Coroutine Scheduler", "coroutine"),
    ("API Surface", "apisurface"), ("Documentation Generator", "docgen"), ("Script Profiler", "scriptprofiler"),
]

ASPECTS_Y = [
    ("Live Session",       "session",   "presence, locks and operation log"),
    ("Merge Engine",       "merge",     "three-way reconciliation and conflict handling"),
    ("Change Ledger",      "ledger",    "auditable journal of production changes"),
    ("Review Commands",    "commands",  "undoable review and approval actions"),
    ("Production Tasks",   "taskgraph", "incremental production and release tasks"),
    ("Permission Guard",   "guard",     "role checks and rate limiting"),
    ("Record Registry",    "registry",  "catalogued production records"),
    ("Working Set",        "selection", "the set of items currently being worked on"),
    ("Release Recovery",   "recovery",  "checkpoint and rollback of production state"),
    ("Progress Analyzer",  "analyzer",  "throughput, trend and risk analysis"),
]

AREAS_Y = [
    ("Multiuser Session", "multiuser"), ("Presence", "presence"), ("Live Cursor", "cursor"),
    ("Object Lock", "objectlock"), ("Change Feed", "changefeed"), ("Operational Transform", "ot"),
    ("Branch", "branch"), ("Commit", "commit"), ("Merge", "merge"), ("Conflict Resolution", "conflict"),
    ("Review Request", "reviewrequest"), ("Code Review", "codereview"), ("Asset Review", "assetreview"),
    ("Comment", "comment"), ("Annotation", "annotation"), ("Approval", "approval"),
    ("Permission Role", "role"), ("Team Directory", "team"), ("Task Board", "taskboard"),
    ("Milestone", "milestone"), ("Sprint", "sprint"), ("Issue Tracker", "issues"), ("Bug Report", "bugreport"),
    ("Playtest Session", "playtest"), ("Feedback Capture", "feedback"), ("Analytics Report", "analytics"),
    ("Release Channel", "channel"), ("Build Pipeline", "buildpipeline"), ("Continuous Validation", "validation"),
    ("Deployment Gate", "deploygate"), ("Rollback Plan", "rollbackplan"), ("Changelog", "changelog"),
    ("Version Tag", "versiontag"), ("Artifact Registry", "artifacts"), ("Localization Workflow", "locworkflow"),
    ("Content Approval", "contentapproval"), ("Audit Trail", "audittrail"), ("Handoff Package", "handoff"),
    ("Studio Metrics", "studiometrics"), ("Knowledge Base", "knowledge"),
]

CATEGORIES = {
    "A": dict(family="UES / CORE", prefix="core", areas=AREAS_A, aspects=ASPECTS_A,
              doc="Kernel-level engine capability: the UES foundation every other ARKHER framework stands on."),
    "S": dict(family="D-O15 OPTIMIZATION", prefix="do15", areas=AREAS_S, aspects=ASPECTS_S,
              doc="D-O15 optimization capability: measure, budget, predict, degrade gracefully, restore."),
    "X": dict(family="SECURITY / RELIABILITY", prefix="security", areas=AREAS_X, aspects=ASPECTS_X,
              doc="Security and reliability capability: nothing enters the engine unvalidated or ungoverned."),
    "B": dict(family="ARKHER STUDIO / IDE", prefix="studio", areas=AREAS_B, aspects=ASPECTS_B,
              doc="ARKHER Studio capability: the authoring environment, its documents, panels, tools and history."),
    "U": dict(family="SCRIPTING / CODE INTELLIGENCE", prefix="code", areas=AREAS_U, aspects=ASPECTS_U,
              doc="Scripting capability: reading, understanding, transforming, generating and running ARKHER code."),
    "Y": dict(family="COLLABORATION / PRODUCTION", prefix="collab", areas=AREAS_Y, aspects=ASPECTS_Y,
              doc="Collaboration capability: many creators, one project, with review, merge, release and audit."),
}
