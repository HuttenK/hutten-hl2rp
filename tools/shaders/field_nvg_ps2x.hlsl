// Original Fieldlink image intensifier: bounded gain, phosphor and sensor noise.
sampler Scene : register(s0);
float4 Settings : register(c0); // gain, white phosphor, noise strength, phase
float4 Screen : register(c1); // inverse width, inverse height
struct Input { float2 uv : TEXCOORD0; };
float4 main(Input i) : COLOR
{
    float4 src = tex2D(Scene,i.uv);
    float l = dot(src.rgb,float3(.2126,.7152,.0722));
    float nearby = dot((tex2D(Scene,i.uv+Screen.xy*2).rgb
        +tex2D(Scene,i.uv-Screen.xy*2).rgb)*.5,float3(.2126,.7152,.0722));
    float gain = 1.15 + Settings.x*.85;
    float exposed = l*gain;
    // Soft shoulder retains bright detail instead of clipping to a white screen.
    float signal = exposed/(1+exposed*.65)*1.3;
    signal += max(nearby-.78,0)*.10;
    // Fine sensor cells with a bounded, sine-free hash. The former large-angle
    // sine hash is precision-sensitive on older shader-model-2 hardware.
    float2 cell = floor(i.uv/Screen.xy/1.5);
    cell = frac((cell + Settings.w*float2(47,113))/256)*256;
    float noise = frac(52.9829189*frac(dot(cell,float2(.06711056,.00583715))))-.5;
    signal += noise*Settings.z*(.35+.65*(1-saturate(signal)));
    float3 phosphor = lerp(float3(.24,1,.34),float3(.82,.95,1),Settings.y);
    float2 edge = i.uv*2-1;
    float falloff = 1-.10*saturate(dot(edge,edge)*.5);
    return float4(saturate(signal*phosphor*falloff),1);
}
