sampler Scene : register(s0);
sampler NearGlow : register(s1);
sampler WideGlow : register(s2);
sampler DirectedDirt : register(s3);
float4 Settings : register(c0); // bloom, dirt, aspect ratio

float marks(float2 uv, float scale, float seed) {
    float2 p = uv * scale;
    float2 cell = floor(p);
    float2 random = frac(sin(float2(dot(cell,float2(127.1,311.7)),dot(cell,float2(269.5,183.3))) + seed) * 43758.5453);
    // Keep every mark inside its cell, with a fully faded boundary. The
    // pattern stays fixed on the lens; only illumination changes with the view.
    float2 delta = frac(p) - (.4 + random * .2);
    delta.x += delta.y * (random.y - .5) * .5;
    delta *= float2(.85 + .3 * random.y, 1.15 - .3 * random.y);
    float radius = .085 + .135 * random.x;
    float2 shape = delta / radius;
    // Asymmetric, gently lobed ellipses instead of perfect circular outlines.
    float d = length(shape) * (1 + .10 * sin(shape.x * 3 + random.y * 6)
        * sin(shape.y * 2 + random.x * 5));
    float soft = 1 - smoothstep(0, 1.25, d);
    return soft * soft * (.30 + .18 * random.x) * smoothstep(.18,.65,random.y);
}
float4 main(float2 uv : TEXCOORD0) : COLOR {
    float4 src = tex2D(Scene,uv);
    float3 nearLight = tex2D(NearGlow,uv).rgb;
    float3 wideLight = tex2D(WideGlow,uv).rgb;
    float2 p = uv * float2(Settings.z,1);
    float dirt = marks(p,5,1) + marks(p,10,7)*.45;
    float3 glow = (nearLight * 2.2 + wideLight * 3.2) * Settings.x;
    // Bias dirt toward the tight halo. Suppress the weak outer glow with a
    // continuous soft knee, rather than revealing marks across the whole wall.
    // This affects only lens dirt; the ordinary bloom keeps its wider halo.
    float3 dirtLight = tex2D(DirectedDirt,uv).rgb;
    float dirtPeak = max(dirtLight.r, max(dirtLight.g, dirtLight.b));
    float proximity = smoothstep(.008, .075, dirtPeak);
    glow += min(dirtLight * 18, .55) * proximity * dirt * Settings.y * float3(1,.91,.8);
    return float4(saturate(src.rgb + glow),1);
}
