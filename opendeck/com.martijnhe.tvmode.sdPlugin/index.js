// OpenDeck plugin for caelestia-tvmode.
// - "Toggle TV Mode" runs tv-mode.sh / desktop-mode.sh from the tvmode plugin.
// - "TV Mode Status" only shows the current mode.
// The mode is read from the same state file the Caelestia shell watches
// (~/.cache/tv-mode/state), so switching from the shell, a terminal or the
// deck keeps every button in sync. No npm dependencies: Node 22+ has WebSocket.

const fs = require("fs");
const path = require("path");
const os = require("os");
const { spawn, execFile } = require("child_process");
const tvSettings = require("./settings");

const args = {};
for (let i = 2; i < process.argv.length; i += 2) args[process.argv[i].replace(/^-/, "")] = process.argv[i + 1];
const { port, pluginUUID, registerEvent } = args;
if (!port || !pluginUUID || !registerEvent) {
  console.error("Missing -port, -pluginUUID or -registerEvent");
  process.exit(1);
}

const HOME = os.homedir();
const CONFIG = process.env.XDG_CONFIG_HOME || path.join(HOME, ".config");
const CACHE = process.env.XDG_CACHE_HOME || path.join(HOME, ".cache");
const STATE_DIR = path.join(CACHE, "tv-mode");
const STATE_FILE = path.join(STATE_DIR, "state");

// Where tv-mode.sh / desktop-mode.sh can live. TVMODE_SCRIPTS overrides; otherwise
// the link install.sh makes, then the usual checkout places.
const SCRIPT_DIRS = [
  process.env.TVMODE_SCRIPTS,
  path.join(CONFIG, "caelestia/plugins/tvmode/scripts"),
  path.join(HOME, ".local/src/tv-mode-caelestia/scripts"),
  path.join(HOME, "Projects/tv-mode-caelestia/scripts"),
].filter(Boolean);

function findScript(name) {
  for (const dir of SCRIPT_DIRS) {
    const p = path.join(dir, name);
    try {
      fs.accessSync(p, fs.constants.X_OK);
      return p;
    } catch {}
  }
  return null;
}

const TOGGLE = "com.martijnhe.tvmode.toggle";
const STATUS = "com.martijnhe.tvmode.status";
const SETTINGS = "com.martijnhe.tvmode.settings";

const contexts = new Map(); // context -> action UUID
let mode = readMode();
let busy = ""; // "tv" | "desktop" while a script runs

function readMode() {
  try {
    return fs.readFileSync(STATE_FILE, "utf8").trim() === "tv" ? "tv" : "desktop";
  } catch {
    return "desktop";
  }
}

const ws = new WebSocket(`ws://127.0.0.1:${port}`);
const send = (obj) => ws.readyState === WebSocket.OPEN && ws.send(JSON.stringify(obj));

ws.onopen = () => send({ event: registerEvent, uuid: pluginUUID });
ws.onclose = () => process.exit(0);
ws.onmessage = (msg) => {
  let data;
  try {
    data = JSON.parse(msg.data);
  } catch {
    return;
  }
  const { event, action, context } = data;
  if (event === "willAppear") {
    contexts.set(context, action);
    render(context);
  } else if (event === "willDisappear") {
    contexts.delete(context);
  } else if (event === "keyUp" && action === TOGGLE) {
    toggle(context);
  } else if (event === "keyUp" && action === STATUS) {
    refresh(true);
  } else if (event === "keyUp" && action === SETTINGS) {
    openDashboard(context);
  } else if (event === "sendToPlugin") {
    handlePI(action, context, data.payload || {});
  }
};

// The settings key opens the Caelestia dashboard (where the TV tab lives), unless it's already open.
function openDashboard(context) {
  execFile("caelestia", ["shell", "drawers", "isOpen", "dashboard"], { timeout: 5000 }, (err, out) => {
    if (err) {
      console.error(`caelestia shell: ${err.message}`);
      return send({ event: "showAlert", context });
    }
    if (out.trim() === "1") return send({ event: "showOk", context });
    execFile("caelestia", ["shell", "drawers", "toggle", "dashboard"], { timeout: 5000 }, (e) => {
      if (e) console.error(`caelestia shell: ${e.message}`);
      send({ event: e ? "showAlert" : "showOk", context });
    });
  });
}

// Settings panel (property inspector) requests.
async function handlePI(action, context, p) {
  const reply = (payload) => send({ event: "sendToPropertyInspector", action, context, payload });
  try {
    if (p.event === "getSettings") {
      reply({ event: "settings", settings: tvSettings.read(), ...(await tvSettings.hardware()) });
    } else if (p.event === "saveSettings") {
      reply({ event: "saved", settings: tvSettings.write(p.settings || {}) });
    }
  } catch (e) {
    console.error(`settings: ${e.message}`);
    reply({ event: "error", message: `Couldn't save: ${e.message}` });
  }
}

function render(context) {
  const action = contexts.get(context);
  send({ event: "setState", context, payload: { state: mode === "tv" ? 1 : 0 } });
  if (action === STATUS) {
    const title = busy ? "…" : mode === "tv" ? "TV" : "Desktop";
    send({ event: "setTitle", context, payload: { title, target: 0 } });
  } else if (action === TOGGLE) {
    send({ event: "setTitle", context, payload: { title: busy ? "…" : "", target: 0 } });
  }
}

function renderAll() {
  for (const ctx of contexts.keys()) render(ctx);
}

function refresh(force = false) {
  const next = readMode();
  if (force || next !== mode) {
    mode = next;
    renderAll();
  }
}

function toggle(context) {
  if (busy) return;
  const target = mode === "tv" ? "desktop" : "tv";
  const script = findScript(target === "tv" ? "tv-mode.sh" : "desktop-mode.sh");
  if (!script) {
    console.error(`tvmode scripts not found in: ${SCRIPT_DIRS.join(", ")}`);
    send({ event: "showAlert", context });
    return;
  }

  busy = target;
  renderAll();
  let lastErr = "";
  // Detached so a switch that closes windows or restarts things never takes the script down with us.
  const child = spawn(script, [], { detached: true, stdio: ["ignore", "ignore", "pipe"] });
  child.stderr.on("data", (d) => {
    const lines = d.toString().trim().split("\n");
    lastErr = lines[lines.length - 1] || lastErr;
  });
  const done = (code) => {
    if (!busy) return;
    busy = "";
    mode = readMode();
    renderAll();
    if (code === 0) send({ event: "showOk", context });
    else {
      console.error(`${path.basename(script)} failed (${code}): ${lastErr}`);
      send({ event: "showAlert", context });
    }
  };
  child.on("error", (e) => {
    lastErr = e.message;
    done(-1);
  });
  child.on("exit", (code) => done(code));
  child.unref();
}

// Follow mode changes made anywhere else (shell, terminal). Watch the directory since
// the scripts may replace the file; poll as a fallback when the directory doesn't exist yet.
function watchState() {
  try {
    fs.mkdirSync(STATE_DIR, { recursive: true });
    fs.watch(STATE_DIR, (_e, name) => {
      if (!name || name === "state") refresh();
    });
  } catch (e) {
    console.error(`watch failed: ${e.message}`);
  }
}
watchState();
setInterval(() => !busy && refresh(), 3000);
