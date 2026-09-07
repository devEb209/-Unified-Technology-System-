/* ARKHER headless harness — loads every ARKHER Lua module inside a real Lua VM
 * (fengari, Lua 5.3) using the exact same loader/factory contract Roblox uses.
 * This is how ARKHER is tested outside of Roblox Studio. */
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

const ROOT = path.resolve(__dirname, "..");

function collect(dir, base, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) collect(p, base, out);
    else if (entry.name.endsWith(".lua")) {
      const rel = path.relative(base, p).replace(/\\/g, "/").replace(/\.lua$/, "");
      out.push({ id: "arkher/" + rel, file: p });
    }
  }
  return out;
}

function newVM() {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  return L;
}

function run(L, code, chunkname) {
  const status = lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(chunkname));
  if (status !== lua.LUA_OK) {
    const err = to_jsstring(lua.lua_tostring(L, -1));
    lua.lua_pop(L, 1);
    throw new Error("load error " + chunkname + ": " + err);
  }
  const r = lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0);
  if (r !== lua.LUA_OK) {
    const err = to_jsstring(lua.lua_tostring(L, -1));
    lua.lua_pop(L, 1);
    throw new Error("runtime error " + chunkname + ": " + err);
  }
}

function main() {
  const modules = collect(path.join(ROOT, "src"), path.join(ROOT, "src"), []);
  const L = newVM();

  // bootstrap: build loader from the loader module itself
  const loaderSrc = fs.readFileSync(path.join(ROOT, "src/kernel/loader.lua"), "utf8");
  run(L, `ARKHER_FACTORIES = {}\nARKHER_LOADER_SRC = nil`, "@bootstrap");

  // register every factory
  for (const m of modules) {
    const src = fs.readFileSync(m.file, "utf8");
    run(L, `ARKHER_FACTORIES["${m.id}"] = (function() ${src} end)()`, "@" + m.id);
  }

  const entry = process.argv[2] || "tests/run_all.lua";
  const bootSrc = `
local Loader = ARKHER_FACTORIES["arkher/kernel/loader"](nil)
local A = Loader.new({ timeFn = os.clock })
for id, factory in pairs(ARKHER_FACTORIES) do A:define(id, factory) end
ARKHER = A
`;
  run(L, bootSrc, "@arkher-boot");
  const testSrc = fs.readFileSync(path.join(ROOT, entry), "utf8");
  run(L, testSrc, "@" + entry);
  console.log(`\n[harness] modules registered: ${modules.length}`);
}

try { main(); } catch (e) { console.error(String(e.message || e)); process.exit(1); }
