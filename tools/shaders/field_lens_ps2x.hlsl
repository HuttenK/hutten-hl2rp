// Mild fixed lens optics. No animation, grain, exposure or centre blur.
sampler Scene : register(s0);
float4 Settings : register(c0); // intensity
float4 Screen : register(c1); // inverse dimensions
struct Input { float2 uv : TEXCOORD0; };
float4 main(Input i) : COLOR
{
    float amount = saturate(Settings.x);
    float2 q = i.uv * 2 - 1;
    float radius = dot(q,q) * .5;
    float edge = smoothstep(.08,.80,radius);
    // Inward sampling keeps all image borders covered, without a black rim.
    float2 uv = .5 + q * .5 * (1 - .09 * edge * amount);
    float2 margin = Screen.xy * 4;
    uv = clamp(uv,margin,1-margin);
    float4 centre = tex2D(Scene,uv);
    float2 fringe = q * Screen.xy * (2.4 * edge * amount);
    float3 colour = float3(tex2D(Scene,uv+fringe).r,centre.g,tex2D(Scene,uv-fringe).b);
    float2 offset = Screen.xy * (3.0 * edge * amount);
    float3 soft = (tex2D(Scene,uv+float2(offset.x,0)).rgb
        + tex2D(Scene,uv-float2(offset.x,0)).rgb
        + tex2D(Scene,uv+float2(0,offset.y)).rgb
        + tex2D(Scene,uv-float2(0,offset.y)).rgb) * .25;
    float4 result = float4(lerp(colour,soft,.50*edge*amount),1);
    // Explicit opt-in GPU probe: a draw submission alone proves no pixel output.
    return lerp(result,float4(i.uv.x,i.uv.y,.25,1),saturate(Settings.y));
}
