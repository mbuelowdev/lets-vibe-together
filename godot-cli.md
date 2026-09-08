# Godot CLI for agents

Use the Godot **4.7 editor** binary (`godot`), not an export template. Run from the repo root (directory with `project.godot`). Always pass `--headless` and `--path .` so the process never waits on a window.

`--test` is engine self-tests. Do not use it. Do not use `--editor` / `-e` or `--debug` unattended (they hang or drop into a debugger).

## After clone, new assets, or missing `.godot/`

```bash
godot --headless --path . --import
```

**Expect:** exit 0; `.godot/` created/updated. Run this before any other command below.

## After editing a `.gd` file

```bash
godot --headless --path . --script res://path/to/script.gd --check-only
```

**Expect:** exit 0 and no `SCRIPT ERROR` / `Parse Error` / `Compile Error`. `--check-only` only works with `--script`. It does not load autoloads or scenes, so a clean parse is necessary, not sufficient.

All scripts:

```bash
find . -name '*.gd' -not -path './.godot/*' -print0 \
  | xargs -0 -n1 -I{} godot --headless --path . --script "{}" --check-only
```

## After editing a scene, script attached to a scene, or `project.godot`

```bash
godot --headless --path . --quit-after 60 --log-file /tmp/godot-run.log
```

Specific scene:

```bash
godot --headless --path . --scene res://path/to/scene.tscn --quit-after 60 --log-file /tmp/godot-scene.log
```

Then:

```bash
rg -n "SCRIPT ERROR|ERROR:|WARNING:|Parse Error|Compile Error" /tmp/godot-run.log
```

**Expect:** process exits (does not hang). Fail if exit ≠ 0 **or** the log contains `SCRIPT ERROR` / `ERROR:` / parse/compile errors. `--quit-after 60` loads `res://main.tscn` (or `--scene`) and runs ~60 frames.

If the failure is unclear:

```bash
godot --headless --path . --quit-after 60 --verbose --log-file /tmp/godot-verbose.log
```

## After resource, export, or packaging changes

Needs export templates installed. Preset name is `Web`. Output dir must exist.

```bash
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
test -f build/web/index.html && test -f build/web/index.wasm && test -f build/web/index.pck
```

**Expect:** exit 0 and those three files exist. This is the same check as the Dockerfile. `--export-*` already implies `--import`.

If release export fails, retry with `--export-debug Web build/web/index.html` for a clearer error.

## Loop

import → parse-check changed `.gd` → smoke-run (`--quit-after` or `--scene`) → grep log → Web export if scenes/resources/export config changed.
