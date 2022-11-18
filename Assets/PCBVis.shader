Shader "PCBVisualization"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_PCB ("pcb", 2D) = "white" {}
		_Blend("blend", range(0,1)) = 0
		_Alpha("alphaView", range(0,1000)) = 0
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
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			float _Blend;
			sampler2D _MainTex;
			float _Alpha;
			float4 _MainTex_ST;
			sampler2D _PCB;
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				float4 col = tex2D(_MainTex, i.uv);
				float4 pcb = tex2D(_PCB, i.uv);
				// apply fog
				
				// return lerp(float4(col.xy*col.z*col.a,0,1) ,float4(-col.xy*col.z*col.a,0,1),_Blend);
				return col.a/_Alpha;
				return float4((col.xy),0,1) ;
			}
			ENDCG
		}
	}
}
