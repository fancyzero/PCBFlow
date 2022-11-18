Shader "PCBFlow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _PCB ("pcb", 2D) = "white" {}
        _Blend("blend", range(-25,25)) = 0
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


            float hash( uint2 x )
            {
                uint2 q = 1103515245U * ( (x>>1U) ^ (x.yx   ) );
                uint  n = 1103515245U * ( (q.x  ) ^ (q.y>>3U) );
                return float(n) * (1.0/float(0xffffffffU));
            }
            fixed4 frag (v2f i) : SV_Target
            {
                float4 pcb = tex2D(_PCB, i.uv);
                float4 col = tex2D(_MainTex, i.uv);
                float mask = step(0.9991,col.r);
                return col.aaaa/409600;
                float2 startUV = saturate(col.yz/4096) + floor(i.uv);
                if ( startUV.y > i.uv.y)
                    startUV.y -=1;
                float3 startWPos = uv2world(startUV);
                
                float timeOfStart = 0;
                float currentTime = _Blend+startWPos.z + (hash(startWPos.xz*4096)*0.5-0.25);
                float progress = pow(col.a,1);
                return smoothstep(0.01,0.1,currentTime-progress)*pcb.g;
                // float2 startUV = col.yz/4096;
                // float d = length(startUV-0.5);
                // d = (d - _Blend);
                // d = smoothstep(0.,1,(d))*1.4;
                // // sample the texture
                
                
                
                // // apply fog
                
                // return step(d, col.aaaa)*pcb.g;
            }
            ENDCG
        }
    }
}
