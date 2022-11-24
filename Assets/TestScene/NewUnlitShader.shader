Shader "Hidden/Internal-DeferredFog" {
    Properties {
        _Density ("Fog Density", Float) = 0.001
        _MainTex ("Texture", 2D) = "white" {}
        //_DstBlend ("", Float) = 1
    }
    SubShader {

        // Adds fog color to the main rt
        Pass
        {
            ZWrite Off
            ZTest off
            Blend SrcAlpha OneMinusSrcAlpha
            
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma enable_d3d11_debug_symbols

            #include "UnityCG.cginc"
            float _Density;
            sampler2D _MainTex;
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            struct v2f {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
            };

            v2f vert (float4 vertex : POSITION)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(vertex);
                o.uv = ComputeScreenPos (o.pos).xy;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 c = 1;
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                float eyeDepth = Linear01Depth(depth)*1000;
                float alpha = exp(-eyeDepth*_Density);
                float4 col = tex2D(_MainTex, i.uv);
                return float4(col.rgb, alpha);
            }
            ENDCG
        }

    }
    Fallback Off
}
