// TV mode settings for the property inspector: reads and writes the same
// ~/.config/caelestia/tvmode.json the Caelestia shell and the scripts use,
// and lists the outputs/audio devices to choose from.

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execFile } = require("child_process");

const CONFIG = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
const SETTINGS_FILE = path.join(CONFIG, "caelestia/tvmode.json");

// Same defaults as the shell's TvMode service.
const DEFAULTS = {
  desktopMonitors: ["DP-1", "DP-3"],
  tv: "HDMI-A-1",
  tvMode: "3840x2160@60",
  tvScale: 1,
  tvAudioMatch: "SAMSUNG",
  closeWindows: true,
  keepClassRegex: "caelestia|quickshell|steam",
  tvInDesktop: false,
  steamCommand: "steam -gamepadui",
  keepAwake: true,
};

function read() {
  try {
    return { ...DEFAULTS, ...JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf8")) };
  } catch {
    return { ...DEFAULTS };
  }
}

// Only known keys with the right type are written; other keys already in the file are kept.
function write(patch) {
  const current = (() => {
    try {
      return JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf8"));
    } catch {
      return {};
    }
  })();
  const next = { ...DEFAULTS, ...current };
  for (const [key, def] of Object.entries(DEFAULTS)) {
    if (!(key in patch)) continue;
    const v = patch[key];
    if (Array.isArray(def) ? Array.isArray(v) && v.every((s) => typeof s === "string") : typeof v === typeof def) next[key] = v;
  }
  fs.mkdirSync(path.dirname(SETTINGS_FILE), { recursive: true });
  const tmp = `${SETTINGS_FILE}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(next, null, 4) + "\n");
  fs.renameSync(tmp, SETTINGS_FILE);
  return next;
}

const run = (cmd, args) =>
  new Promise((resolve) => execFile(cmd, args, { timeout: 5000 }, (err, out) => resolve(err ? "" : out)));

// [{ name, description, modes: ["3840x2160@60", ...] }] for every output Hyprland knows,
// plus [audio device descriptions] for the TV audio match.
async function hardware() {
  let outputs = [];
  try {
    outputs = JSON.parse(await run("hyprctl", ["monitors", "all", "-j"])).map((m) => ({
      name: m.name,
      description: m.description || "",
      modes: [...new Set((m.availableModes || []).map((s) => s.replace(/\.\d+Hz$|Hz$/, "")))],
    }));
  } catch {}
  let audio = [];
  try {
    audio = JSON.parse(await run("pactl", ["-f", "json", "list", "sinks"])).map((s) => s.description).filter(Boolean);
  } catch {}
  return { outputs, audio };
}

module.exports = { read, write, hardware, SETTINGS_FILE };
