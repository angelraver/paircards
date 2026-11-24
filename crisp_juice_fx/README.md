# Crisp Juice Particles - Free Sampler

This sampler has 5 of the 41 effects (hit_impact, coin_pickup, smoke_puff, magic_sparkles, fire). Get the full pack: https://anipixels.itch.io/crisp-juice-particles

41 real-time VFX for Godot 4.3+ - every effect as a 2D scene and a 3D scene (82 scenes),
built from GPUParticles2D / GPUParticles3D and the addon's own shaders. Works in Forward+, Mobile and
Compatibility (tested in all three on Godot 4.7). No sprite sheets to slice, no third-party assets.

## Install

Copy `crisp_juice_fx` into your project (keep the path: scenes point at `res://crisp_juice_fx`).
Nothing to enable - the scripts register the `CrispFx2D` and `CrispFx3D` classes on their own.

## Use

Drag a scene from `crisp_juice_fx/fx2d` or `fx3d` into your level. It plays as soon as it enters the
tree. One-shot effects free themselves when they finish; looping effects (fire, rain, portal...) keep going.

From code:

```gdscript
const HIT := preload("res://crisp_juice_fx/fx2d/combat/hit_impact_2d.tscn")

func _on_enemy_hit(enemy: Node2D) -> void:
	CrispFx2D.spawn(HIT, get_tree().current_scene, enemy.global_position)

# or by hand, with options:
var fx := HIT.instantiate()
fx.recolor = Color.RED      # shift the effect's hues to red (keeps white-hot cores)
fx.fx_scale = 1.5           # bigger
add_child(fx)
fx.play()                   # restart any time
```

3D is the same with `CrispFx3D` and the scenes in `fx3d` (`spawn()` takes a Vector3).

### Inspector options (every effect)

| Property | What it does |
|---|---|
| `autoplay` | Play when the node enters the tree (default on). Off: call `play()` yourself. |
| `free_on_finish` | One-shots delete themselves when done (default on). Off: keep the node and `play()` again. |
| `color` | Multiply tint over the whole effect (alpha fades it). |
| `recolor` | Re-hue the effect to this colour, keeping whites and shading. Alpha 0 = original colours. |
| `fx_scale` | Size multiplier (sets the node's scale). |
| `amount` | Fraction of particles to emit (0-1). Lower it for mobile or busy scenes. |
| `speed` | Playback speed of the particles and shader animation. |
| `editor_preview` | In the editor, replays one-shots every couple of seconds so you can tweak while watching. |

Methods: `play()`, `stop()` (loops fade out), `is_playing()`, `get_duration()`, signal `finished`.

### Trails

`dash_trail`, `magic_missile`, `dust_trail` and `sparkle_trail` are meant to ride on something that moves:
make them a child of your player / projectile. The ribbon trails (`CrispTrail2D`, a Line2D; `CrispTrail3D`, an
ImmediateMesh) record the parent's path, so they also work in the Compatibility renderer, where particle trails
do not.

### Weather

`rain`, `snow`, `leaves_falling`, `petals` and `fireflies` cover about 7 x 6 m (700 x 600 px in 2D) above
their origin. Put the node at the bottom-centre of the area (in 2D: of the screen; make it a child of your
Camera2D to follow the view). Scale the node to cover more, or duplicate it.

### Units

3D effects are sized for a ~1.8 m character. 2D effects use 100 px per metre (a hit spark is ~150 px across).
Change `fx_scale` to fit your game.

## Showcase

Open this folder as a project and press Play: `showcase/showcase_2d.tscn` shows every 2D effect in a grid
(click a cell to replay it, B toggles a light background, C cycles recolors). Tab switches to
`showcase_3d.tscn`, which shows the 3D effects row by row (B: day / night).

## What is inside

- **combat** (10): hit_impact, hit_crit, slash_arc, muzzle_flash, explosion, ground_crack, lightning_zap, shockwave, dash_trail, magic_missile
- **rewards** (8): coin_pickup, coin_burst, gem_pickup, level_up, star_burst, heart_burst, confetti_burst, hearts_loop
- **magic** (9): magic_sparkles, heal, buff_aura, portal, shield_bubble, teleport, poison_bubbles, sleepy_zzz, dizzy_stars
- **elements** (5): fire, smoke_puff, smoke_column, water_splash, bubbles
- **movement** (4): dust_trail, footstep_puff, jump_land, sparkle_trail
- **weather** (5): rain, snow, leaves_falling, petals, fireflies

Loops: dash_trail, magic_missile, hearts_loop, magic_sparkles, buff_aura, portal, shield_bubble, poison_bubbles, sleepy_zzz, dizzy_stars, fire, smoke_column, bubbles, dust_trail, sparkle_trail, rain, snow, leaves_falling, petals, fireflies.

Folders: `fx2d/` and `fx3d/` (scenes by category), `shaders/` (10 effect shaders + a ribbon shader, each with a
2D and 3D version, shared helpers in `crisp_common.gdshaderinc`), `textures/` (24 small greyscale textures and
flip-books, drawn by code), `scripts/` (CrispFx2D, CrispFx3D, CrispTrail2D, CrispTrail3D), `showcase/`.

## Performance

Each effect uses 1-5 emitters and a few hundred particles at most (rain: 220). One-shots free themselves. In the
Compatibility renderer GPU particles are simulated with transform feedback; if you spawn dozens of effects per
frame on low-end mobile, lower `amount`.

## Licence

See LICENSE.txt. Use in any project, commercial or not; do not resell or redistribute the pack itself.

Claude (an AI assistant) designed everything in this pack: it is made procedurally by code it wrote. No AI image generators,
no third-party art or code.
