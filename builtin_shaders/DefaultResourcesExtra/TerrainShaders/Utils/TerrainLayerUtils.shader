// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

    Shader "Hidden/TerrainEngine/TerrainLayerUtils" {

    Properties { _MainTex ("Texture", any) = "" {} }

    SubShader {

        ZTest Always Cull Off ZWrite Off

        CGINCLUDE

            #include "UnityCG.cginc"

            float4 _LayerMask;
            sampler2D _MainTex;
            float4 _MainTex_TexelSize;      // 1/width, 1/height, width, height

        ENDCG

        Pass    // Select one channel and copy it into R channel
        {
            Name "Get Terrain Layer Channel"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment GetLayer

            struct appdata_t {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
            };
            struct v2f {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
            };
            v2f vert(appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = v.texcoord;
                return o;
            }
            float4 GetLayer(v2f i) : SV_Target
            {
                float4 layerWeights = tex2D(_MainTex, i.texcoord);
                return dot(layerWeights, _LayerMask);
            }
            ENDCG
        }

        Pass    // Copy the R channel of the input into a specific channel in the output
        {
            Name "Set Terrain Layer Channel"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment SetLayer

            sampler2D _AlphaMapTexture;
            sampler2D _OldAlphaMapTexture;

            struct appdata_t {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float2 texcoord2 : TEXCOORD1;
            };


            struct v2f {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
                float2 texcoord2 : TEXCOORD1;
            };

            v2f vert(appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = v.texcoord;
                o.texcoord2 = v.texcoord2;
                return o;
            }

            float4 SetLayer(v2f i) : SV_Target
            {
                float4 alphaMap = tex2D(_AlphaMapTexture, i.texcoord2);
                float oldAlpha = tex2D(_OldAlphaMapTexture, i.texcoord).r;

                float totalAlphaOthers = 1 - oldAlpha;
                if (totalAlphaOthers > 0.01f)
                {
                    float newAlpha = tex2D(_MainTex, i.texcoord).r;
                    float4 othersNormalized = alphaMap *(1 - _LayerMask)*(1.0f - newAlpha) / totalAlphaOthers;
                    return othersNormalized + (_LayerMask * newAlpha);
                }
                return _LayerMask;
            }
            ENDCG
        }

    }
    Fallback Off
}
