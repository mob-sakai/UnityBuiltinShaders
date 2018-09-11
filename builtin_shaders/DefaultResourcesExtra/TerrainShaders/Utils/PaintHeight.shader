// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

    Shader "Hidden/TerrainEngine/PaintHeight" {

    Properties { _MainTex ("Texture", any) = "" {} }

    SubShader {

        ZTest Always Cull Off ZWrite Off

        CGINCLUDE

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;      // 1/width, 1/height, width, height

            sampler2D _BrushTex;

            float4 _BrushParams;
            #define BRUSH_STRENGTH      (_BrushParams[0])
            #define BRUSH_TARGETHEIGHT  (_BrushParams[1])
            #define BRUSH_STAMPHEIGHT   (_BrushParams[2])

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

            float ApplyBrush(float height, float brushStrength)
            {
                float targetHeight = BRUSH_TARGETHEIGHT;
                if (targetHeight > height)
                {
                    height += brushStrength;
                    height = height < targetHeight ? height : targetHeight;
                }
                else
                {
                    height -= brushStrength;
                    height = height > targetHeight ? height : targetHeight;
                }
                return height;
            }

        ENDCG

        Pass    // 0 raise/lower heights
        {
            Name "Raise/Lower Heights"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment RaiseHeight

            float4 RaiseHeight(v2f i) : SV_Target
            {
                float height = UnpackHeightmap(tex2D(_MainTex, i.texcoord));
                float brushShape = UnpackHeightmap(tex2D(_BrushTex, i.texcoord));
                return PackHeightmap(clamp(height + BRUSH_STRENGTH * brushShape, 0, 0.5f));
            }
            ENDCG
        }

        Pass    // 1 stamp heights
        {
            Name "Stamp Heights"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment StampHeight

            float SmoothMax(float a, float b, float p)
            {
                // calculates a smooth maximum of a and b, using an intersection power p
                // higher powers produce sharper intersections, approaching max()
                return log2(exp2(a * p) + exp2(b * p) - 1.0f) / p;
            }

            float4 StampHeight(v2f i) : SV_Target
            {
                float height = UnpackHeightmap(tex2D(_MainTex, i.texcoord));
                float brushPattern = UnpackHeightmap(tex2D(_BrushTex, i.texcoord));
                float brushHeight = brushPattern * BRUSH_STAMPHEIGHT;
                float targetHeight = max(height, brushHeight);
                float brushIntersection = saturate(1.0f - BRUSH_STRENGTH * 100.0f);     // convert to 0..1 range, then invert

                {
                    // TODO:  get rid of this hack to convert brush strength into a smooth factor -- make this an explicit control instead
                    float brushSmooth = exp2(brushIntersection * 8.0f);
                    targetHeight = SmoothMax(height, brushHeight, brushSmooth);
                }

                targetHeight = clamp(targetHeight, 0.0f, 0.5f);                         // Keep in valid range (0..0.5f)  TODO
                height = targetHeight;  // lerp(height, targetHeight, brushOpacity);           // TODO: do we want to obey actual opacity as well?
                return PackHeightmap(height);
            }
            ENDCG
        }

        Pass    // 2 set height (flatten)
        {
            Name "Set Heights"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment SetHeight

            float4 SetHeight(v2f i) : SV_Target
            {
                float height = UnpackHeightmap(tex2D(_MainTex, i.texcoord));
                float brushStrength = BRUSH_STRENGTH * UnpackHeightmap(tex2D(_BrushTex, i.texcoord));

                // smooth set
                float targetHeight = BRUSH_TARGETHEIGHT;

                // have to do this check to ensure strength 0 == no change (code below makes a super tiny change even with strength 0)
                if (brushStrength > 0.0f)
                {
                    float deltaHeight = height - targetHeight;

                    // see https://www.desmos.com/calculator/880ka3lfkl
                    float p = saturate(brushStrength);
                    float w = (1.0f - p) / (p + 0.000001f);
//                  float w = (1.0f - p*p) / (p + 0.000001f);       // alternative TODO test and compare
                    float fx = clamp(w * deltaHeight, -1.0f, 1.0f);
                    float g = fx * (0.5f * fx * sign(fx) - 1.0f);

                    deltaHeight = deltaHeight + g / w;

                    height = targetHeight + deltaHeight;
                }

                return PackHeightmap(height);
            }
            ENDCG
        }

        Pass    // 3 smooth terrain
        {
            Name "Smooth Heights"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment SmoothHeight

            float4 SmoothHeight(v2f i) : SV_Target
            {
                float height = UnpackHeightmap(tex2D(_MainTex, i.texcoord));
                float brushStrength = BRUSH_STRENGTH * UnpackHeightmap(tex2D(_BrushTex, i.texcoord));

                float h = 0.0F;
                float xoffset = _MainTex_TexelSize.x;
                float yoffset = _MainTex_TexelSize.y;

                h += UnpackHeightmap(tex2D(_MainTex, i.texcoord                             ));
                h += UnpackHeightmap(tex2D(_MainTex, i.texcoord + float2( xoffset,  0      )));
                h += UnpackHeightmap(tex2D(_MainTex, i.texcoord + float2(-xoffset,  0      )));
                h += UnpackHeightmap(tex2D(_MainTex, i.texcoord + float2( xoffset,  yoffset))) * 0.75F;
                h += UnpackHeightmap(tex2D(_MainTex, i.texcoord + float2(-xoffset,  yoffset))) * 0.75F;
                h += UnpackHeightmap(tex2D(_MainTex, i.texcoord + float2( xoffset, -yoffset))) * 0.75F;
                h += UnpackHeightmap(tex2D(_MainTex, i.texcoord + float2(-xoffset, -yoffset))) * 0.75F;
                h += UnpackHeightmap(tex2D(_MainTex, i.texcoord + float2( 0,        yoffset)));
                h += UnpackHeightmap(tex2D(_MainTex, i.texcoord + float2( 0,       -yoffset)));
                h /= 8.0F;

                return PackHeightmap(lerp(height, h, brushStrength));
            }
            ENDCG
        }

        Pass    // 4 paint splat alphamap
        {
            Name "Paint Texture"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment PaintSplatAlphamap

            float4 PaintSplatAlphamap(v2f i) : SV_Target
            {
                float brushStrength = BRUSH_STRENGTH * UnpackHeightmap(tex2D(_BrushTex, i.texcoord));
                float alphaMap = tex2D(_MainTex, i.texcoord).r;
                return ApplyBrush(alphaMap, brushStrength);
            }

            ENDCG
        }

    }
    Fallback Off
}
