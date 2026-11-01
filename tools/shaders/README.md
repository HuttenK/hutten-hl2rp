# Fieldlink screen shaders

Original HLSL targeting ps_2_b, compiled to Source VCS using SCell555's standalone
ShaderCompile distributed in https://github.com/ficool2/sdk_screenspace_shaders.
Compiler downloads/build products belong on E:, not in the game or repository.

Build from repository root:

```powershell
node tools/build-field-shaders.cjs E:\Codex-Archives\ShaderTools\sdk_screenspace_shaders\shadersrc\bin\ShaderCompile.exe E:\Codex-Archives\HL2RP-shaders-2026-09-27\build
```

This regenerates `cl_shader_payload.lua`. Commit/distribute that generated file
with the other plugin Lua. Its small embedded GMA contains five VCS files;
clients receive it through AddCSLuaFile and mount it using the same approach as
the existing UI shader library. No server DLL or client injector is involved.
Content-derived names avoid Source's shader cache when rebuilding.

World pass: five scene samples, bounded detail enhancement, mild saturation and
contrast shaping, restrained split toning, highlight compression. Black stays
black. The strength setting blends with the original; zero bypasses the pass.
NVG pass: three scene samples, adaptive gain from the existing NVG controller,
green/white phosphor, bounded sensor noise, mild edge falloff and highlight bleed.
Neither pass is ray tracing, global illumination, or new geometry lighting.

Both operate in display space with linear read/write flags to avoid an extra
gamma conversion. No depth texture is required. Menus and normal/NVG grades
remain mutually exclusive. Thermal goggles retain their original renderer.
DX levels below 95, failed mounting/material creation, or disabling the shader
option use the prior built-in effects. Material creation cannot establish that
a particular GPU driver rendered correctly; `ix_shader_status` reports loading
only. Native Linux/macOS rendering still requires an in-engine acceptance test.

Offline checks: HLSL compilation, VCS header checks, GMA extraction using gmad,
Lua syntax and mocked routing/loading tests. Live acceptance: compare daylight,
dark interiors and blackout; switch NVG types; open TAB/character menu; resize;
disable shaders and verify fallback. Check frame time on target hardware.

Bloom/lens dirt: bright extraction, narrow/wide native blur, then composite.
BlurRenderTarget changes the active target without restoring it; keep all blur
calls within PushRenderTarget/PopRenderTarget. Match the engine scratch texture
dimensions and viewport exactly. Full-screen shaders output alpha 1; captured
framebuffer alpha is not an opacity mask. The regression mock must reproduce
the native blur target side effect, not treat it as a state-free function.
