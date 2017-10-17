// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "AR/TangoARRender"
{
    Properties
    {
        _ScreenOrientation("Screen Orientation", FLOAT) = 0.0
        _ScreenWidth("Screen Width", FLOAT) = 0.0
        _ScreenHeight("Screen Height", FLOAT) = 0.0
        _ImageWidth("Image Width", FLOAT) = 0.0
        _ImageHeight("Image Height", FLOAT) = 0.0
    }

    // For GLES3
    SubShader
    {
        Pass
        {
            ZWrite Off

            GLSLPROGRAM

            #pragma only_renderers gles3

            #ifdef SHADER_API_GLES3
            #extension GL_OES_EGL_image_external_essl3 : require
            #endif

            uniform vec4 _MainTex_ST;

            #ifdef VERTEX

            #define kPortrait 1.0
            #define kPortraitUpsideDown 2.0
            #define kLandscapeLeft 3.0
            #define kLandscapeRight 4.0

            varying vec2 textureCoord;
            uniform float _ScreenOrientation;
            uniform float _ScreenWidth;
            uniform float _ScreenHeight;
            uniform float _ImageWidth;
            uniform float _ImageHeight;

            void main()
            {
                #ifdef SHADER_API_GLES3
                textureCoord = gl_MultiTexCoord0.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                float scale = 1.0;

                // This looks funny but it's due to the fact that the image dimensions assume landscape and
                // the screen dimensions assume portrait
                scale = _ScreenHeight / _ImageWidth;

                mat4 Scale_Matrix = mat4(1.0);

                if (_ScreenOrientation == kPortrait)
                {
                    float origX = textureCoord.x;
                    textureCoord.x = 1.0 - textureCoord.y;
                    textureCoord.y = 1.0 - origX;
                    Scale_Matrix[0][0] = scale;
                }
                else if (_ScreenOrientation == kPortraitUpsideDown)
                {
                    float origX = textureCoord.x;
                    textureCoord.x = textureCoord.y;
                    textureCoord.y = origX;
                    Scale_Matrix[0][0] = scale;
                }
                else if (_ScreenOrientation == kLandscapeLeft)
                {
                    textureCoord.y = 1.0 - textureCoord.y;
                    Scale_Matrix[1][1] = scale;
                }
                else if (_ScreenOrientation == kLandscapeRight)
                {
                    textureCoord.x = 1.0 - textureCoord.x;
                    Scale_Matrix[1][1] = scale;
                }

                gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex * Scale_Matrix;
                #endif
            }

            #endif

            #ifdef FRAGMENT
            varying vec2 textureCoord;
            uniform samplerExternalOES _MainTex;

            void main()
            {
                #ifdef SHADER_API_GLES3
                gl_FragColor = texture(_MainTex, textureCoord);
                #endif
            }

            #endif

            ENDGLSL
        }
    }

    FallBack Off
}
