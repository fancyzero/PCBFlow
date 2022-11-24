Shader "PCBFlow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Swatch ("Swatch", 2D) = "white" {}
        _PCB ("pcb", 2D) = "white" {}
        _Blend("blend", range(0,40)) = 0
        _LeadWidth("Lead Width", range(0,1)) = 0.1
        _StepsPerSec("Steps per second", float) = 1000
        [HDR] _GrowingColor("_GrowingColor", color) = (1,1,1,1)
        [HDR] _UnreachedColor("unreached Color", color) = (0.1,0.1,1,1)
        [HDR] _LeadColor("Lead Color", color) = (1,0,0,1)
        [HDR] _BloomColor("_BloomColor", color) = (2,2,0,1)
        [HDR] _CoolDownColor("_CoolDownColor", color) = (0.5,0.2,0,1)
        

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma enable_d3d11_debug_symbols
            
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos: TEXCOORD1;
            };

            float _Blend;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;

            float4 _GrowingColor;
            float4 _BloomColor;
            float4 _CoolDownColor;
            float4 _UnreachedColor;
            float4 _LeadColor;
            sampler2D _Swatch;
            
            sampler2D _PCB;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }
            
            float3 uv2world(float2 uv)
            {
                uv = (uv - 0.5*_MainTex_ST.xy) * 5;
                return float3(uv.x, 0, uv.y);
            }
            float2 world2uv(float3 world)
            {
                return (world/5).xz+0.5*_MainTex_ST.xy;
            }



            float3 hash33( uint3 x , uint seed)
            {
                const uint k = 1103515245U;  // GLIB C
                x += uint3(seed,seed,seed);
                x = ((x>>8U)^x.yzx)*k;
                x = ((x>>8U)^x.yzx)*k;
                x = ((x>>8U)^x.yzx)*k;
                
                return float3(x)*(1.0/float(0xffffffffU));
            }

            float hash( uint2 x )
            {
                uint2 q = 1103515245U * ( (x>>1U) ^ (x.yx   ) );
                uint  n = 1103515245U * ( (q.x  ) ^ (q.y>>3U) );
                return float(n) * (1.0/float(0xffffffffU));
            }

            struct PCBData
            {
                float2 startUV;
                float steps;
                float maxSteps;
            };

            PCBData DecodePCBData( float2 uv)
            {
                PCBData ret;
                float4 data = tex2D(_MainTex, uv);
                ret.startUV = data.xy + uv;
                float2 iuv = (floor(ret.startUV*_MainTex_TexelSize.zw) + 0.5)*_MainTex_TexelSize.xy;
                ret.maxSteps = data.b;//tex2D(_MainTex,iuv).b;
                ret.steps = data.a;
                return ret;
            }
            float _StepsPerSec;
            float _LeadWidth;
            float4 GetColor( PCBData pData, float currentTime )
            {
                float normalizedProgress = (currentTime*_StepsPerSec/pData.maxSteps);
                float growingTimespan = pData.maxSteps/_StepsPerSec;
                float progress = pData.steps/_StepsPerSec;
                float4 ret;

                ret = lerp( _GrowingColor, _LeadColor, smoothstep( _LeadWidth,_LeadWidth*0.7, currentTime - progress));
                
                
                ret = lerp( ret, _UnreachedColor, smoothstep(0.02,0,currentTime - progress));
                float4 bloomColor = lerp(_CoolDownColor,_BloomColor, saturate(exp(-(currentTime-growingTimespan)*0.4)));
                ret = lerp( ret,bloomColor, smoothstep(1.0,1.2,normalizedProgress));
                
                return ret;
                
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 sampleUV = i.uv;
                // sampleUV.y = 1- sampleUV.y;
                float4 pcb = tex2D(_PCB, i.uv);
                float4 col = tex2D(_MainTex, sampleUV);
                

                PCBData pData = DecodePCBData(i.uv);
                float t = _Time.y;
                float mask = step(pData.steps,0xfffff);
                return mask * GetColor(pData, t%10);
            }
            ENDCG
        }
    }
}
