# RokinIdiot

**English** · [한국어](README.ko.md)

A Roblox Studio animation editor plugin built for VFX and cutscenes.

Character rigs, particles, property changes and method calls all live on one
timeline. In game you only hand over the objects to animate and press play.

```lua
const AnimationPlayer = require(ReplicatedStorage.RokinIdiotAnimationPlayer)

const track = AnimationPlayer:LoadAnimation(save, workspace.Hero, workspace.Villain)
track:Play(0.3)

track:GetMarkerReachedSignal("Impact"):Connect(function()
	hitbox:Fire()
end)
```

## Features

**Editor**

- Items → elements → tracks tree, bound to any object in the Explorer
- Property tracks for any animatable type (number, Color3, CFrame, UDim2,
  NumberSequence, ColorSequence, EnumItem, Instance references ...)
- Method tracks such as `:Emit()`, with per-keyframe arguments
- Rig poses: pose the rig in the viewport and capture every `Motor6D` at once
- Item positions relative to an origin item, so the same cutscene plays anywhere
- Easing per keyframe (every TweenService style, plus `Linear` and `Constant`)
- Named keyframes and markers, fired as signals at runtime
- Live preview with scrubbing, playback speed and looping — everything is
  restored when the preview is turned off
- Edit a selected keyframe by changing the property in the Properties panel
- Multi-select (Shift+drag / Shift+click), drag to move, snap grid, zoom
- One editor per place (heartbeat lock for Team Create)
- Dark / Light theme, English / 한국어 UI

**Runtime** (`RokinIdiotAnimationPlayer`)

- API shaped like Roblox's `AnimationTrack`: `Play`, `Stop`, fades, weight,
  speed (including reverse), looping, `Stopped` / `Ended` / `DidLoop`
- Several animations on the same object are arbitrated by priority and weight
- Touched values are restored when a track stops
- Shares the exact sampling code with the editor preview, so Studio and game
  never disagree

## Install

Build from source with [Rokit](https://github.com/rojo-rbx/rokit):

```bash
rokit install      # rojo, wally, stylua, luau-lsp
wally install      # runtime packages
rojo build default.project.json --plugin RokinIdiot.rbxm
```

`--plugin` writes the file straight into your Studio plugins folder. Restart
Studio (or reload plugins) and a **RokinIdiot** button appears in the toolbar.

## Usage

1. Open the widget from the toolbar and create a new animation.
2. Select an object in the Explorer and press **+ Item** to add and bind it.
3. Add elements (paths under the item, e.g. `HumanoidRootPart.RootAttachment.Sparks`)
   and tracks (`Enabled`, `Rate`, `:Emit()` ...).
4. Set values in Studio and add keyframes. Turn on **Preview** to watch it.
5. **Menu → Export Animation to Workspace** gives you a `StringValue` to ship.
6. **Menu → Export Player to Workspace** gives you the runtime module. Move it
   to `ReplicatedStorage` and require it from a LocalScript.

Run animations on the client. `Motor6D.Transform` does not replicate, and
property changes made on the server replicate every frame.

## Documentation

- Runtime API — inside the exported module: `Docs` (English) and `Docs/한국어`
- [docs/RUNTIME.md](docs/RUNTIME.md) — runtime design notes (Korean)
- [docs/PLAN.md](docs/PLAN.md) — editor design notes (Korean)

## Development

```bash
stylua src                                             # format
rojo sourcemap default.project.json -o sourcemap.json  # for luau-lsp
rojo build animationPlayer.project.json -o RokinIdiotAnimationPlayer.rbxm  # runtime only
```

`src/Core` is shared by the editor and the runtime. Both builds attach it, so
the preview and the game run the same code.

## Roadmap

- Bone masking (upper body only, keep the default walk on the legs)
- Curve editor for easing
- Undo / redo through Studio's `Ctrl+Z`

## License

[MIT](LICENSE)
