# Hex Grid Shader

> Procedural HLSL shader that renders an animated hex grid surface driven by a RenderTexture glow map.

<img width="390" height="312" alt="Planet masks" src="https://github.com/user-attachments/assets/5248cbeb-4bc9-4e1e-8d46-b1bd226e7d2e" /><img width="390" height="312" alt="Grid colors" src="https://github.com/user-attachments/assets/499aa13d-729e-4ce0-a9c1-bf6b92f009a2" />

![opt_maskGridgif](https://github.com/user-attachments/assets/13e825f8-8e8b-430b-b6fa-7023c9ede661)

---

## What it does

Renders a transparent hex grid overlay on any mesh. The shader samples a RenderTexture (glow map) to dynamically light up hex cells. Used in-game to show bullet trails, player spotlight, fog-of-war, and build highlights in real time.

---

## Files

```
Shader/
├── HexGrid.shader        – HLSL shader source
└── m_HexagonShader.mat   – Tuned material (assign a RenderTexture to _GlowMap)
```

---

## How it works

### Hex SDF — `HexEdgeDistance(p)`
The core of the shader. For any pixel on the surface, this function returns how far that pixel is from the nearest hex edge — no textures, pure math.

It works by tiling space with two offset hex grids, picking whichever grid the pixel falls closest to, then measuring the distance to that hex's boundary. That distance value is what everything else (lines, fills, glow) is built on top of.

```hlsl
float HexEdgeDistance(float2 p) {
    float2 r = float2(1.0, 1.73205);
    float2 h = r * 0.5;
    float2 a = frac(p / r) * r - h;
    float2 b = frac((p - h) / r) * r - h;
    float2 gv = dot(a, a) < dot(b, b) ? a : b;
    float2 absGV = abs(gv);
    float c = dot(absGV, normalize(float2(1.0, 1.73205)));
    return 0.5 - max(c, absGV.x);
}
```

### Layers
| Layer | What it is |
|---|---|
| **Grid lines** | `smoothstep` on edge distance, modulated by visibility masks |
| **Fill geometry** | Inner hex fill, activated only where glow map has data |
| **Fog of war** | World-space radius falloff centered on player position |
| **Player spotlight** | Tight radial glow around `_PlayerPos` |
| **Glow map channels** | R = bullets, G = alpha cutout (planet holes), B = build highlights |

### Glow Map
The shader samples `_GlowMap` (a RenderTexture) relative to the player's world position. An orthographic camera renders game events into this texture each frame — bullets, highlights, etc. The shader reads back the RGB channels to colorize the corresponding hex cells.

> **Note:** `m_HexagonShader.mat` references a RenderTexture by GUID that is not included here. Assign any RenderTexture (or the built-in `black` texture) to `_GlowMap` for a baseline look.

---

## Key properties

| Property | Purpose |
|---|---|
| `_GridScale` | World-space size of each hex cell |
| `_Thickness` | Line width |
| `_PlayerPos` | World position of the player (set from script each frame) |
| `_PlayerRadius / _PlayerFalloff` | Spotlight size and softness |
| `_WorldViewRadius` | Fog-of-war outer radius |
| `_GlowMap` | RenderTexture input (bullets / highlights / holes) |
| `_MapWorldSize` | World size the RenderTexture covers |
| `_WaveAmplitude / _WaveFrequency` | Ripple distortion strength |

---

## Dependencies

- Unity **Built-in Render Pipeline** or **URP** (uses `UnityCG.cginc`)
- A RenderTexture for the glow map (optional for basic use)
