Shader "Hidden/PCBFlowFullScreen"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Swatch ("Swatch", 2D) = "white" {}
        _PCB ("pcb", 2D) = "white" {}
        _Blend("blend", range(0,2)) = 0        
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            sampler2D _PCB;
            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            uniform float4x4 _ViewProjInv;
            float4 GetWorldPositionFromDepth( float depth,float2 uv_depth )
            {    
                float4 H = float4(uv_depth.x*2.0-1.0, (uv_depth.y)*2.0-1.0, depth, 1.0);
                float4 D = mul(_ViewProjInv,H);
                return D/D.w;
            }


            float3 GetTriplanarWeights (float3 normal) {
                float3 triW = abs(normal);
                return triW / (triW.x + triW.y + triW.z);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float depth = tex2D(_MainTex, i.uv).r;
                if ( depth <= 0.0000001)
                return 0;
                float3 worldPos = GetWorldPositionFromDepth(depth, i.uv);
                float3 worldNormal ;
                float2 ts = _MainTex_TexelSize.xy;
                float3 pdx = GetWorldPositionFromDepth(tex2D(_MainTex, i.uv+float2(1,0)*ts).r, i.uv+float2(1,0)*ts) - worldPos;
                float3 pdy = GetWorldPositionFromDepth(tex2D(_MainTex,  i.uv+float2(0,1)*ts).r, i.uv+float2(0,1)*ts) - worldPos;
                worldNormal = (normalize( cross(pdx, pdy)));
                float4 mapx;
                float4 mapy;
                float4 mapz;
                
                mapx = tex2D(_PCB, worldPos.yz*0.02);
                
                mapy = tex2D(_PCB, worldPos.xz*0.02);
                
                mapz =tex2D(_PCB, worldPos.xy*0.02);

                float3 w = GetTriplanarWeights(worldNormal.xyz).xyz;


                

                if (w.x > w.y && w.x > w.z)
                return mapx;
                if (w.y > w.x && w.y > w.z)
                return mapy;
                if (w.z > w.y && w.z > w.x)
                return mapz;


                return mapx*w.x + mapy*w.y + mapz*w.z;
                
                //return frac(worldPos.xyzz);
                // just invert the colors
                
            }
            ENDCG
        }
    }
}
