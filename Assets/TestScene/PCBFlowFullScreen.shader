Shader "Hidden/PCBFlowFullScreen"
{
    Properties
    {
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
        _FlowMap ("Texture", 2D) = "white" {}
        _Swatch ("Swatch", 2D) = "white" {}
        _PCB ("pcb", 2D) = "white" {}
        _Blend("blend", range(0,1)) = 0
        _LeadWidth("Lead Width", range(0,1)) = 0.1
        _UVScale("uv scale", range(0,1)) = 0.1
        
        _SobelStep("sobel step", range(0,10)) = 1
        _StepsPerSec("Steps per second", float) = 1000
        [HDR] _GrowingColor("_GrowingColor", color) = (1,1,1,1)
        [HDR] _UnreachedColor("unreached Color", color) = (0.1,0.1,1,1)
        [HDR] _LeadColor("Lead Color", color) = (1,0,0,1)
        [HDR] _BloomColor("_BloomColor", color) = (2,2,0,1)
        [HDR] _CoolDownColor("_CoolDownColor", color) = (0.5,0.2,0,1)     
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
            #pragma vertex vert
            #pragma fragment frag
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
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            float _Blend;
            float _UVScale;
            sampler2D _FlowMap;
            sampler2D _MainTex;
            float4 _FlowMap_ST;
            float4 _FlowMap_TexelSize;
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;
            float4 _GrowingColor;
            float4 _BloomColor;
            float4 _CoolDownColor;
            float4 _UnreachedColor;
            float4 _LeadColor;
            sampler2D _Swatch;
            sampler2D _SceneTexture;
            sampler2D _PCB;
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
                float4 data = tex2D(_FlowMap, uv);
                ret.startUV = data.xy + uv;
                ret.maxSteps = data.b;
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

                float4 growing = lerp( _GrowingColor, _LeadColor, smoothstep( _LeadWidth,_LeadWidth*0.7, currentTime - progress));
                growing = lerp( growing, _UnreachedColor, smoothstep(0.02,0,currentTime - progress));
                float4 blooming = lerp(_CoolDownColor,_BloomColor, saturate(exp(-(currentTime-growingTimespan)*2.4)));
                ret =  lerp( growing,blooming, smoothstep(0.0,.1,currentTime-growingTimespan));
                
                return ret;
                
            }
            sampler2D _CameraDepthTexture;
            float4 GetPCBColor(float2 uv, float3 worldPos,float2 XXX, float2 YYY, float2 ZZZ)
            {
                PCBData pData = DecodePCBData(uv);
                float3 worldStartPos = 0;
                worldStartPos.xyz = worldPos + float3(dot(pData.startUV-uv,XXX),dot(pData.startUV-uv,YYY),dot(pData.startUV-uv,ZZZ))/_UVScale;
                float t = _Time.y;
                float toffset = length(worldStartPos-_WorldSpaceCameraPos)*.2;
                float mask = step(pData.steps,20000);
                return mask * GetColor(pData, ((t%30)-toffset));
            }
            float intensity(in float4 color){
                color = Linear01Depth(color)*100;
                return sqrt((color.x*color.x)+(color.y*color.y)+(color.z*color.z)+(color.w*color.w)*1.5);
            }

            float3 sobel(float stepx, float stepy, float2 center){
                // get samples around pixel
                float tleft = intensity(tex2D(_CameraDepthTexture,center + float2(-stepx,stepy)).xyzw);
                float left = intensity(tex2D(_CameraDepthTexture,center + float2(-stepx,0)).xyzw);
                float bleft = intensity(tex2D(_CameraDepthTexture,center + float2(-stepx,-stepy)).xyzw);
                float top = intensity(tex2D(_CameraDepthTexture,center + float2(0,stepy)).xyzw);
                float bottom = intensity(tex2D(_CameraDepthTexture,center + float2(0,-stepy)).xyzw);
                float tright = intensity(tex2D(_CameraDepthTexture,center + float2(stepx,stepy)).xyzw);
                float right = intensity(tex2D(_CameraDepthTexture,center + float2(stepx,0)).xyzw);
                float bright = intensity(tex2D(_CameraDepthTexture,center + float2(stepx,-stepy)).xyzw);
                
                float x = tleft + 2.0*left + bleft - tright - 2.0*right - bright;
                float y = -tleft - 2.0*top - tright + bleft + 2.0 * bottom + bright;
                float color = sqrt((x*x) + (y*y));
                return float3(color,color,color);
            }         

            float _SobelStep;   

            fixed4 frag (v2f i) : SV_Target
            {
                
                float depth = tex2D(_CameraDepthTexture, i.uv).r;
                if ( depth <= 0.0000001)
                return 0;
                float3 worldPos = GetWorldPositionFromDepth(depth, i.uv);
                float3 worldNormal ;
                float2 ts = _MainTex_TexelSize.xy;
                float3 pdx = GetWorldPositionFromDepth(tex2D(_CameraDepthTexture, i.uv+float2(1,0)*ts).r, i.uv+float2(1,0)*ts) - worldPos;
                float3 pdy = GetWorldPositionFromDepth(tex2D(_CameraDepthTexture,  i.uv+float2(0,1)*ts).r, i.uv+float2(0,1)*ts) - worldPos;
                worldNormal = (normalize( cross(pdx, pdy)));
                float4 mapx;
                float4 mapy;
                float4 mapz;

                mapx = GetPCBColor(worldPos.yz*_UVScale,worldPos,0,float2(1,0),float2(0,1));
                mapy = GetPCBColor(worldPos.xz*_UVScale,worldPos,float2(1,0),0,float2(0,1));
                mapz = GetPCBColor(worldPos.xy*_UVScale,worldPos,float2(1,0),float2(0,1),0);

                float3 w = GetTriplanarWeights(worldNormal.xyz).xyz;

                float4 ret;
                if (w.x > w.y && w.x > w.z)
                ret =  mapx;
                if (w.y > w.x && w.y > w.z)
                ret =  mapy;
                if (w.z > w.y && w.z > w.x)
                ret =  mapz;

                //get outline
                float sobelValue = saturate(pow(sobel(_SobelStep*_MainTex_TexelSize.x, _SobelStep*_MainTex_TexelSize.y, i.uv).x,10));
                return sobelValue *_Blend+ ret ;//+ tex2D(_MainTex, i.uv)* _Blend;
                
                //return frac(worldPos.xyzz);
                // just invert the colors
                
            }
            ENDCG
        }
    }
}
