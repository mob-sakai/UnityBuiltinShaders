// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

    Shader "Hidden/TerrainEngine/BrushPreview" {

    Properties { _MainTex ("Texture", any) = "" {} }

    SubShader {

        ZTest Always Cull Back ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        CGINCLUDE

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;      // 1/width, 1/height, width, height

            sampler2D _BrushTex;
            float4 _BrushParams;

            #define BRUSH_STRENGTH      (_BrushParams[0])
            #define HEIGHT_SCALE        (_BrushParams[1])
            #define BRUSH_STAMPHEIGHT   (_BrushParams[2])

            float4 _TexScaleOffet;

            struct appdata_t {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
            };

        ENDCG

        Pass    // 0
        {
            Name "DrawMeshPresent"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            v2f vert(appdata_t v)
            {
                v2f o;
                o.texcoord = _TexScaleOffet.xy * v.vertex.xz + _TexScaleOffet.zw;
                v.vertex.y = HEIGHT_SCALE * UnpackHeightmap(tex2Dlod(_MainTex, float4(o.texcoord, 0, 0)));
                o.vertex = UnityObjectToClipPos(v.vertex);

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                return float4(0.5f,0.5f,1.0f,0.65f)*UnpackHeightmap(tex2D(_BrushTex, i.texcoord));
            }
        ENDCG
        }


        Pass    // 1
            {
                Name "DrawMeshFuture"

                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                sampler2D _GridTexture;

            v2f vert(appdata_t v)
            {
                v2f o;

                o.texcoord = _TexScaleOffet.xy * v.vertex.xz + _TexScaleOffet.zw;
                float height = UnpackHeightmap(tex2Dlod(_MainTex, float4(o.texcoord, 0, 0)));
                float brushStrength = BRUSH_STRENGTH * UnpackHeightmap(tex2Dlod(_BrushTex, float4(o.texcoord,0,0)));
                v.vertex.y = HEIGHT_SCALE* clamp((brushStrength+height), 0, 0.5f);
                o.vertex = UnityObjectToClipPos(v.vertex);

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 color = (BRUSH_STRENGTH < 0) ? float4(0.8f,0.3f,0.3f,0.65f) : float4(1.0f,0.5f,0.5f,0.75f);
                return color*UnpackHeightmap(tex2D(_BrushTex, i.texcoord));
            }
            ENDCG
        }

    }
    Fallback Off
}
