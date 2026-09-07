# ARKHER V1 :: catalog specification (round 1 = categories A, S, X)
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

CATEGORIES = {
    "A": dict(family="UES / CORE", prefix="core", areas=AREAS_A, aspects=ASPECTS_A,
              doc="Kernel-level engine capability: the UES foundation every other ARKHER framework stands on."),
    "S": dict(family="D-O15 OPTIMIZATION", prefix="do15", areas=AREAS_S, aspects=ASPECTS_S,
              doc="D-O15 optimization capability: measure, budget, predict, degrade gracefully, restore."),
    "X": dict(family="SECURITY / RELIABILITY", prefix="security", areas=AREAS_X, aspects=ASPECTS_X,
              doc="Security and reliability capability: nothing enters the engine unvalidated or ungoverned."),
}
