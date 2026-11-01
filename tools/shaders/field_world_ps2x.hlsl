// Original Fieldlink world pass. Display-space input/output; no depth dependency.
sampler Scene : register(s0);
float4 Settings : register(c0); // strength, detail, inverse width, inverse height
struct Input { float2 uv : TEXCOORD0; };
float4 main(Input i) : COLOR
{
    float4 src = tex2D(Scene, i.uv);
    float2 px = Settings.zw;
    float3 blur = (tex2D(Scene, i.uv + float2(px.x,0)).rgb
        + tex2D(Scene, i.uv - float2(px.x,0)).rgb
        + tex2D(Scene, i.uv + float2(0,px.y)).rgb
        + tex2D(Scene, i.uv - float2(0,px.y)).rgb) * .25;
    // Limit detail correction to avoid bright halos at silhouettes.
    float3 c = saturate(src.rgb + clamp(src.rgb-blur,-.025,.025) * Settings.y);
    float l = dot(c,float3(.2126,.7152,.0722));
    float mid = 4*l*(1-l);
    c = lerp(l.xxx,c,.86);
    // Lift illuminated surfaces instead of obtaining contrast by darkening
    // the room. Deep shadows stay unchanged; the lift rolls off toward white.
    float lightMask = smoothstep(.10,.65,l);
    float contrasted = l + .24 * lightMask * (1-l);
    c *= contrasted / max(l,.0001);
    // Cool midtones/shadows, tapering off at black and at white so lights
    // retain their own colour. Never add a grey veil to unlit areas.
    c += float3(-.020,.004,.020)*mid*(1-l)*lightMask;
    return float4(lerp(src.rgb,saturate(c),saturate(Settings.x)),1);
}
