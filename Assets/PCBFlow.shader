Shader "PCBFlow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _PCB ("pcb", 2D) = "white" {}
        _Blend("blend", range(0,2)) = 0
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
                float2 sampleUV = i.uv;
                // sampleUV.y = 1- sampleUV.y;
                float4 pcb = tex2D(_PCB, i.uv);
                float4 col = tex2D(_MainTex, sampleUV);
                float steps = col.a;
                float speed = 1000;//1000 steps per second.
                
                float mask = step(0.5,col.b);

                float2 startUV = col.xy + (i.uv);
                _Blend = (_Time.y*0.3 % 2)*speed - length(startUV.xy - float2(0,0)) * 100 ;
                // float3 startWPos = uv2world(startUV);
                
                
                // float currentTime = _Blend ;//+ (hash(startWPos.xz*100000)-0.5)*2;
                // float timeOfStart  = c + currentTime;
                // float currentSteps = (timeOfStart - currentTime)*speed;
                if ( _Blend > 200)
                    return 0;
                if ( _Blend > 100)
                    return mask*float4(1,0,0,1);
                return step(steps*0.1,_Blend )*mask;//*pcb.g;

            }
            ENDCG
        }
    }
}
