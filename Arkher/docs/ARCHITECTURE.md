# ARKHER Architecture (V1)

## 1. Layers

```
+------------------------------------------------------------------+
|  Singularity AI  (agents operate the engine through the registry) |
+------------------------------------------------------------------+
|  ARKHER CATALOG   1,550 systems (A core / S D-O15 / X security)   |
+------------------------------------------------------------------+
|  ARKHER RUNTIME   engine.lua  ·  runtime/kits.lua                 |
+------------------------------------------------------------------+
|  UES KERNEL       ecs · scheduler · jobs · bus · resources · ...   |
+------------------------------------------------------------------+
|  PLATFORM ADAPTER  roblox.lua | headless.lua  (validated contract) |
+------------------------------------------------------------------+
|  HOST              Roblox runtime / Studio / Node+Lua VM          |
+------------------------------------------------------------------+
```

## 2. The module contract

Every ARKHER source file is a **factory**:

```lua
--@arkher-module
return function(A)
    local EventBus = A:import("arkher/kernel/eventbus")
    ...
    return Module
end
```

* In Roblox: `require(ModuleScript)(loader)`.
* Headless: the Node harness registers the same factories in a real Lua VM.
* The loader (`src/kernel/loader.lua`) caches instances, detects dependency cycles and records
  per-module load time. There is **no** `script.Parent.Parent.Parent` fragility anywhere.

## 3. Kits — why the catalog is real

A *kit* (`src/runtime/kits.lua`) is a complete working machine: registry, pipeline, cache,
controller, analyzer, budgeter, guard, index, codec, graph, field, predictor, ledger, recovery,
orchestrator, solver, streamer, composer, policy, synthesizer.

A *catalog system* = kit + area-specific configuration + specialized methods + integration hook +
its own executable `selfTest()`. That is why `engine:verify()` can prove all 1,550 systems work
rather than counting files.

## 4. Frame loop

```
Engine:step(dt)
  profiler:beginFrame()      -- hierarchical scoped timing
  budget:beginFrame()        -- per-frame budget reset
  sandbox:resetFrameQuotas() -- security quotas per frame
  bus:flush(n)               -- deferred events, bounded
  jobs:pump(2ms)             -- cooperative coroutine workers
  scheduler:frame(dt)        -- 11 phases, priority + interval + budget aware
  resources:pump(n)          -- streaming under a memory budget
  profiler:endFrame() -> D-O15 controller -> new quality preset every 6 frames
```

## 5. D-O15 (the 15 optimization dimensions)

`resolution · geometry · shadows · lighting · reflections · postfx · particles · textures ·
animation · physics · ai · audio · streaming · network · simulation`

The controller holds a single scalar quality level with a PID loop plus asymmetric response
(drop fast, recover slowly) and projects it onto the 15 dimensions weighted by *perceptual cost*,
so the least visible things degrade first. Device tiers (`potato → mobile → mobileHigh → desktop →
console → desktopHigh → vr`) define hard budgets in real units.

## 6. Security

Nothing privileged happens without a capability grant: `sandbox:invoke(principal, capability, fn)`.
Roles (`viewer`, `builder`, `scripter`, `aiAgent`, `optimizer`, `admin`) plus per-frame and total
call quotas, an audit log and trust scoring. AI agents are principals like everyone else.

## 7. Determinism

`bits.lua` (bit32 on Luau, arithmetic elsewhere) + `random.lua` (xoshiro128\*\*) + `noise.lua`
guarantee that the same seed generates the same world on a phone, on a PC and in CI.
