sampler Scene : register(s0);
float4 Settings : register(c0); // directed dirt mask, aspect ratio
float peakOf(float3 c) { return max(c.r, max(c.g,c.b)); }
float4 main(float2 uv : TEXCOORD0) : COLOR {
    float3 c = tex2D(Scene, uv).rgb;
    float peak = max(c.r, max(c.g, c.b));
    // Soft knee: ordinary dark surfaces contribute nothing.
    // Dirt requires a compact highlight near the viewing axis. A broad sky
    // or uniformly lit wall has no local prominence, even when very bright.
    float2 radius = float2(.045 / max(Settings.y,1), .045);
    float horizontal = (peakOf(tex2D(Scene,saturate(uv+float2(radius.x,0))).rgb)
        + peakOf(tex2D(Scene,saturate(uv-float2(radius.x,0))).rgb)) * .5;
    float vertical = (peakOf(tex2D(Scene,saturate(uv+float2(0,radius.y))).rgb)
        + peakOf(tex2D(Scene,saturate(uv-float2(0,radius.y))).rgb)) * .5;
    float prominence = smoothstep(.035,.18,peak-max(horizontal,vertical));
    float axis = length((uv-.5)*float2(Settings.y,1));
    float facing = 1-smoothstep(.035,.14,axis);
    return float4(c * smoothstep(.58, .92, peak)
        * lerp(1, prominence*facing, saturate(Settings.x)), 1);
}
