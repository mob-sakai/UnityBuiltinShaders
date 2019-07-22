// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_UIE_INCLUDED
#define UNITY_UIE_INCLUDED

#ifndef UIE_SKIN_USING_CONSTANTS
    #if SHADER_TARGET < 45
        #define UIE_SKIN_USING_CONSTANTS
    #endif // SHADER_TARGET < 30
#endif // UIE_SKIN_USING_CONSTANTS

#ifndef UIE_SIMPLE_ATLAS
    #if SHADER_TARGET < 35
        #define UIE_SIMPLE_ATLAS
    #endif // SHADER_TARGET < 35
#endif // UIE_SIMPLE_ATLAS

// The value below is only used on older shader targets, and should be configurable for the app at hand to be the smallest possible
#ifndef UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS
#define UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS 20
#endif // UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS

#include "UnityCG.cginc"

#ifdef UIE_SIMPLE_ATLAS
sampler2D _MainTex;
#else
Texture2D _MainTex;
#endif
float4 _MainTex_ST;
float4 _MainTex_TexelSize;

SamplerState uie_point_clamp_sampler;
SamplerState uie_linear_clamp_sampler;

sampler2D _FontTex;
float4 _FontTex_ST;

sampler2D _CustomTex;
float4 _CustomTex_ST;
float4 _CustomTex_TexelSize;

sampler2D _GradientSettingsTex;
float4 _GradientSettingsTex_ST;
float4 _GradientSettingsTex_TexelSize;

fixed4 _Color;
float4 _1PixelClipInvView; // xy in clip space, zw inverse in view space
float4 _PixelClipRect; // In framebuffer space

#ifdef UIE_SKIN_USING_CONSTANTS

CBUFFER_START(UITransforms)
float4 _Transforms[UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS * 4]; // 3 float4s map to matrix 3 columns (the projection column is ignored), and a float4 representing a clip rectangle
CBUFFER_END

#else // !UIE_SKIN_USING_CONSTANTS

struct Transform3x4 { float4 v0, v1, v2, clipRect; };
StructuredBuffer<Transform3x4> _TransformsBuffer; // 3 float4s map to matrix 3 columns (the projection column is ignored), and a float4 representing a clip rectangle

#endif // UIE_SKIN_USING_CONSTANTS

struct appdata_t
{
    float4 vertex   : POSITION;
    float4 color    : COLOR;
    float2 uv       : TEXCOORD0;
    float4 xformIDsAndFlags : TEXCOORD1; // transformID,clipRectID,Flags,SettingIndex
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 vertex   : SV_POSITION;
    fixed4 color    : COLOR;
    float4 uvXY  : TEXCOORD0; // UV and ZW holds XY position in points
    nointerpolation fixed4 flags : TEXCOORD1;
    nointerpolation fixed3 svgFlags : TEXCOORD2;
    nointerpolation fixed4 clipRect : TEXCOORD3;
    UNITY_VERTEX_OUTPUT_STEREO
};

static const float kUIEVertexLastFlagValue = 8.0f; // Keep in track with UIR.VertexFlags

// Notes on UIElements Spaces (Local, Bone, Group, World and Clip)
//
// Consider the following example:
//      *     <- Clip Space (GPU Clip Coordinates)
//    Proj
//      |     <- World Space
//   VEroot
//      |
//     VE1 (RenderHint = Group)
//      |     <- Group Space
//     VE2 (RenderHint = Bone)
//      |     <- Bone Space
//     VE3
//
// A VisualElement always emits vertices in local-space. They do not embed the transform of the emitting VisualElement.
// The renderer transforms the vertices on CPU from local-space to bone space (if available), or to the group space (if available),
// or ultimately to world-space if there is no ancestor with a bone transform or group transform.
//
// The world-to-clip transform is stored in UNITY_MATRIX_P
// The group-to-world transform is stored in UNITY_MATRIX_V
// The bone-to-group transform is stored in uie_toWorldMat.
//
// In this shader, we consider that vertices are always in bone-space, and we always apply the bone-to-group and the group-to-world
// transforms. It does not matter because in the event where there is no ancestor with a Group or Bone RenderHint, these transform
// will be identities.

static float3x4 uie_toWorldMat;
static float4 uie_clipRect;

// Returns the view-space offset that must be applied to the vertex to satisfy a minimum displacement constraint.
// vertex               Coordinates of the vertex, in vertex-space.
// embeddedDisplacement Displacement vector that is embedded in vertex, in vertex-space.
// minDisplacement      Minimum length of the displacement that must be observed, in pixels.
float2 uie_get_border_offset(float4 vertex, float2 embeddedDisplacement, float minDisplacement)
{
    // Compute the displacement length in framebuffer space (unit = 1 pixel).
    float2 viewDisplacement = mul(uie_toWorldMat, float4(embeddedDisplacement, 0, 0)).xy;
    float frameDisplacementLength = length(viewDisplacement * _1PixelClipInvView.zw);

    // We need to meet the minimum displacement requirement before rounding so that we can simply add 1 after rounding
    // if we don't meet it anymore.
    float newFrameDisplacementLength = max(minDisplacement, frameDisplacementLength);
    newFrameDisplacementLength = round(newFrameDisplacementLength);
    newFrameDisplacementLength += step(newFrameDisplacementLength, minDisplacement - 0.001);

    // Convert the resulting displacement into an offset.
    float changeRatio = newFrameDisplacementLength / (frameDisplacementLength + 0.000001);
    float2 viewOffset = (changeRatio - 1) * viewDisplacement;

    return viewOffset;
}

float2 uie_snap_to_integer_pos(float2 clipSpaceXY)
{
    return ((int2)((clipSpaceXY+1)/_1PixelClipInvView.xy+0.51f)) * _1PixelClipInvView.xy-1;
}

void uie_fragment_clip(v2f IN)
{
    float2 pointPos = IN.uvXY.zw;
    float2 pixelPos = IN.vertex.xy;
    float2 s = step(IN.clipRect.xy,   pointPos) + step(pointPos, IN.clipRect.zw) +
               step(_PixelClipRect.xy, pixelPos)  + step(pixelPos, _PixelClipRect.zw);
    clip(dot(float3(s,1),float3(1,1,-7.95f)));
}

void uie_vert_load_payload(appdata_t v)
{
#ifdef UIE_SKIN_USING_CONSTANTS

    uie_toWorldMat = float3x4(
        _Transforms[v.xformIDsAndFlags.x * 4 + 0],
        _Transforms[v.xformIDsAndFlags.x * 4 + 1],
        _Transforms[v.xformIDsAndFlags.x * 4 + 2]);
    uie_clipRect = _Transforms[v.xformIDsAndFlags.y * 4 + 3];

#else // !UIE_SKIN_USING_CONSTANTS

    Transform3x4 transform = _TransformsBuffer[v.xformIDsAndFlags.x];
    uie_toWorldMat = float3x4(transform.v0, transform.v1, transform.v2);
    uie_clipRect = _TransformsBuffer[v.xformIDsAndFlags.y].clipRect;

#endif // UIE_SKIN_USING_CONSTANTS
}

float2 uie_unpack_float2(fixed4 c)
{
    return float2(c.r*255 + c.g, c.b*255 + c.a);
}

float2 uie_ray_unit_circle_first_hit(float2 rayStart, float2 rayDir)
{
    float tca = dot(-rayStart, rayDir);
    float d2 = dot(rayStart, rayStart) - tca * tca;
    float thc = sqrt(1.0f - d2);
    float t0 = tca - thc;
    float t1 = tca + thc;
    float t = min(t0, t1);
    if (t < 0.0f)
        t = max(t0, t1);
    return rayStart + rayDir * t;
}

float uie_radial_address(float2 uv, float2 focus)
{
    uv = (uv - float2(0.5f, 0.5f)) * 2.0f;
    float2 pointOnPerimeter = uie_ray_unit_circle_first_hit(focus, normalize(uv - focus));
    float2 diff = pointOnPerimeter - focus;
    if (abs(diff.x) > 0.0001f)
        return (uv.x - focus.x) / diff.x;
    if (abs(diff.y) > 0.0001f)
        return (uv.y - focus.y) / diff.y;
    return 0.0f;
}

struct GradientLocation
{
    float2 uv;
    float4 location;
};

GradientLocation uie_sample_gradient_location(float settingIndex, float2 uv, sampler2D settingsTex, float2 texelSize)
{
    // Gradient settings are stored in 3 consecutive texels:
    // - texel 0: (float4, 1 byte per float)
    //    x = gradient type (0 = tex/linear, 1 = radial)
    //    y = address mode (0 = wrap, 1 = clamp, 2 = mirror)
    //    z = radialFocus.x
    //    w = radialFocus.y
    // - texel 1: (float2, 2 bytes per float) atlas entry position
    //    xy = pos.x
    //    zw = pos.y
    // - texel 2: (float2, 2 bytes per float) atlas entry size
    //    xy = size.x
    //    zw = size.y

    float2 settingUV = float2(0.5f, settingIndex+0.5f) * texelSize;
    fixed4 gradSettings = tex2D(settingsTex, settingUV);
    if (gradSettings.x > 0.0f)
    {
        // Radial texture case
        float2 focus = (gradSettings.zw - float2(0.5f, 0.5f)) * 2.0f; // bring focus in the (-1,1) range
        uv = float2(uie_radial_address(uv, focus), 0.0);
    }

    int addressing = gradSettings.y * 255;
    uv.x = (addressing == 0) ? fmod(uv.x,1.0f) : uv.x; // Wrap
    uv.x = (addressing == 1) ? max(min(uv.x,1.0f), 0.0f) : uv.x; // Clamp
    float w = fmod(uv.x,2.0f);
    uv.x = (addressing == 2) ? (w > 1.0f ? 1.0f-fmod(w,1.0f) : w) : uv.x; // Mirror

    GradientLocation grad;
    grad.uv = uv;

    // Adjust UV to atlas position
    float2 nextUV = float2(texelSize.x, 0);
    grad.location.xy = (uie_unpack_float2(tex2D(settingsTex, settingUV+nextUV) * 255) + float2(0.5f, 0.5f));
    grad.location.zw = uie_unpack_float2(tex2D(settingsTex, settingUV+nextUV*2) * 255);

    return grad;
}

float TestForValue(float value, inout float flags)
{
#if SHADER_API_GLES
    float result = saturate(flags - value + 1.0);
    flags -= result * value;
    return result;
#else
    return flags == value;
#endif
}

float sdf(float sdf_sample)
{
    const float threshold = 0.5;
    const float smoothness = 0.5;
    float sdfValue = (sdf_sample - threshold) / (1.0 - threshold);
    float2 sdfGrad = float2(ddx(sdfValue), ddy(sdfValue));
    float afwidth = smoothness * length(sdfGrad);
    return smoothstep(-afwidth, afwidth, sdfValue);
}

v2f uie_std_vert(appdata_t v)
{
    v2f OUT;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

    uie_vert_load_payload(v);
    float flags = v.xformIDsAndFlags.z;
    // Keep the descending order for GLES2
    const float isCustomSVGGradients = TestForValue(7.0, flags);
    const float isSVGGradients = TestForValue(6.0, flags);
    const float isEdge = TestForValue(5.0, flags);
    const float isCustomTex = TestForValue(4.0, flags);
    const float isAtlasTexBilinear = TestForValue(3.0, flags);
    const float isAtlasTexPoint = TestForValue(2.0, flags);
    const float isText = TestForValue(1.0, flags);
    const float isAtlasTex = isAtlasTexBilinear + isAtlasTexPoint;
    const float isSolid = 1 - saturate(isText + isAtlasTex + isCustomTex + isSVGGradients + isCustomSVGGradients);

    float2 viewOffset = float2(0, 0);
    if (isEdge == 1)
        viewOffset = uie_get_border_offset(v.vertex, v.uv, 1);

    v.vertex.xyz = mul(uie_toWorldMat, v.vertex);
    v.vertex.xy += viewOffset;

    OUT.uvXY.zw = v.vertex.xy;
    OUT.vertex = UnityObjectToClipPos(v.vertex);

#ifndef UIE_SDF_TEXT
    if (isText == 1)
        OUT.vertex.xy = uie_snap_to_integer_pos(OUT.vertex.xy);
#endif

    OUT.uvXY.xy = TRANSFORM_TEX(v.uv, _MainTex);
    if (isAtlasTex == 1.0f && isCustomTex == 0.0f && isSVGGradients == 0.0f && isCustomSVGGradients == 0.0f)
        OUT.uvXY.xy *= _MainTex_TexelSize.xy;
    OUT.color = v.color * _Color;

#ifdef UIE_SIMPLE_ATLAS
    OUT.flags = fixed4(isText, isAtlasTex, isCustomTex, isSolid);
#else
    OUT.flags = fixed4(isText, isAtlasTexBilinear - isAtlasTexPoint, isCustomTex, isSolid);
#endif
    OUT.svgFlags = fixed3(isSVGGradients, isCustomSVGGradients, v.xformIDsAndFlags.w);
    OUT.clipRect = uie_clipRect; // In points

    return OUT;
}

fixed4 uie_std_frag(v2f IN)
{
    uie_fragment_clip(IN);

    // Extract the flags.
    fixed isText               = IN.flags.x;
#ifdef UIE_SIMPLE_ATLAS
    fixed isAtlasTex           = IN.flags.y;
#else
    fixed isAtlasTexPoint      = saturate(-IN.flags.y);
    fixed isAtlasTexBilinear   = saturate(IN.flags.y);
#endif
    fixed isCustomTex          = IN.flags.z;
    fixed isSolid              = IN.flags.w;
    fixed isSVGGradients       = IN.svgFlags.x;
    fixed isCustomSVGGradients = IN.svgFlags.y;
    float settingIndex         = IN.svgFlags.z;

    float2 uv = IN.uvXY.xy;

    half4 texColor = (half4)isSolid;
#ifdef UIE_SIMPLE_ATLAS
    texColor += tex2D(_MainTex, uv) * isAtlasTex;
#else
    texColor += _MainTex.Sample(uie_point_clamp_sampler, uv) * isAtlasTexPoint;
    texColor += _MainTex.Sample(uie_linear_clamp_sampler, uv) * isAtlasTexBilinear;
#endif
#ifdef UIE_SDF_TEXT
    texColor += half4(1, 1, 1, sdf(tex2D(_FontTex, uv).a)) * isText;
#else
    texColor += half4(1, 1, 1, tex2D(_FontTex, uv).a) * isText;
#endif
    texColor += tex2D(_CustomTex, uv) * isCustomTex;

    if (isSVGGradients == 1.0f || isCustomSVGGradients == 1.0f)
    {
        float2 texelSize = isCustomSVGGradients == 1.0f ? _CustomTex_TexelSize.xy : _MainTex_TexelSize.xy;
        GradientLocation grad = uie_sample_gradient_location(settingIndex, uv, _GradientSettingsTex, _GradientSettingsTex_TexelSize.xy);
        grad.location *= texelSize.xyxy;
        grad.uv *= grad.location.zw;
        grad.uv += grad.location.xy;

#ifdef UIE_SIMPLE_ATLAS
        texColor += tex2D(_MainTex, grad.uv) * isSVGGradients;
#else
        texColor += _MainTex.Sample(uie_linear_clamp_sampler, grad.uv) * isSVGGradients;
#endif
        texColor += tex2D(_CustomTex, grad.uv) * isCustomSVGGradients;
    }

    half4 color = texColor * IN.color;
    return color;
}

#ifndef UIE_CUSTOM_SHADER

v2f vert(appdata_t v) { return uie_std_vert(v); }
fixed4 frag(v2f IN) : SV_Target { return uie_std_frag(IN); }

#endif // UIE_CUSTOM_SHADER

#endif // UNITY_UIE_INCLUDED
