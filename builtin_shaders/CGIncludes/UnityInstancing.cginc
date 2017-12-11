// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_INSTANCING_INCLUDED
#define UNITY_INSTANCING_INCLUDED

#ifndef UNITY_SHADER_VARIABLES_INCLUDED
    // We will redefine some built-in shader params e.g. unity_ObjectToWorld and unity_WorldToObject.
    #error "Please include UnityShaderVariables.cginc first."
#endif

#ifndef UNITY_SHADER_UTILITIES_INCLUDED
    // We will redefine some built-in shader functions e.g.UnityObjectToClipPos.
    #error "Please include UnityShaderUtilities.cginc first."
#endif

#if SHADER_TARGET >= 35 && (defined(SHADER_API_D3D11) || defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE) || defined(SHADER_API_XBOXONE) || defined(SHADER_API_VULKAN) || (defined(SHADER_API_METAL) && defined(UNITY_COMPILER_HLSLCC)))
    #define UNITY_SUPPORT_INSTANCING
#endif

#if defined(SHADER_API_PSSL) || defined(SHADER_API_SWITCH)
    #define UNITY_SUPPORT_INSTANCING
#endif

#if defined(SHADER_API_D3D11)
    #define UNITY_SUPPORT_STEREO_INSTANCING
#endif

#if defined(SHADER_TARGET_SURFACE_ANALYSIS) && defined(UNITY_SUPPORT_INSTANCING)
    #undef UNITY_SUPPORT_INSTANCING
#endif

////////////////////////////////////////////////////////
// instancing paths
// - UNITY_INSTANCING_ENABLED               Defined if instancing path is taken.
// - UNITY_PROCEDURAL_INSTANCING_ENABLED    Defined if procedural instancing path is taken.
// - UNITY_STEREO_INSTANCING_ENABLED        Defined if stereo instancing path is taken.
#if defined(UNITY_SUPPORT_INSTANCING) && defined(INSTANCING_ON)
    #define UNITY_INSTANCING_ENABLED
#endif
#if defined(UNITY_SUPPORT_INSTANCING) && defined(PROCEDURAL_INSTANCING_ON)
    #define UNITY_PROCEDURAL_INSTANCING_ENABLED
#endif
#if defined(UNITY_SUPPORT_STEREO_INSTANCING) && defined(STEREO_INSTANCING_ON)
    #define UNITY_STEREO_INSTANCING_ENABLED
#endif

////////////////////////////////////////////////////////
// basic instancing setups
// - UNITY_VERTEX_INPUT_INSTANCE_ID     Declare instance ID field in vertex shader input / output struct.
// - UNITY_GET_INSTANCE_ID  (Internal) Get the instance ID from input struct.
#if defined(UNITY_INSTANCING_ENABLED) || defined(UNITY_PROCEDURAL_INSTANCING_ENABLED) || defined(UNITY_STEREO_INSTANCING_ENABLED)

    // A global instance ID variable that functions can directly access.
    static uint unity_InstanceID;

    GLOBAL_CBUFFER_START(UnityDrawCallInfo)
        int unity_BaseInstanceID;   // Where the current batch starts within the instanced arrays.
        int unity_InstanceCount;    // Number of instances before doubling for stereo.
    GLOBAL_CBUFFER_END

    #ifdef SHADER_API_PSSL
    #define DEFAULT_UNITY_VERTEX_INPUT_INSTANCE_ID uint instanceID;
        #define UNITY_GET_INSTANCE_ID(input)    _GETINSTANCEID(input)
    #else
    #define DEFAULT_UNITY_VERTEX_INPUT_INSTANCE_ID uint instanceID : SV_InstanceID;
        #define UNITY_GET_INSTANCE_ID(input)    input.instanceID
    #endif

#else
    #define DEFAULT_UNITY_VERTEX_INPUT_INSTANCE_ID
#endif // UNITY_INSTANCING_ENABLED || UNITY_PROCEDURAL_INSTANCING_ENABLED || UNITY_STEREO_INSTANCING_ENABLED

#if !defined(UNITY_VERTEX_INPUT_INSTANCE_ID)
#   define UNITY_VERTEX_INPUT_INSTANCE_ID DEFAULT_UNITY_VERTEX_INPUT_INSTANCE_ID
#endif

////////////////////////////////////////////////////////
// basic stereo instancing setups
// - UNITY_VERTEX_OUTPUT_STEREO             Declare stereo target eye field in vertex shader output struct.
// - UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO  Assign the stereo target eye.
// - UNITY_TRANSFER_VERTEX_OUTPUT_STEREO    Copy stero target from input struct to output struct. Used in vertex shader.
#ifdef UNITY_STEREO_INSTANCING_ENABLED
    #define DEFAULT_UNITY_VERTEX_OUTPUT_STEREO                          uint stereoTargetEyeIndex : SV_RenderTargetArrayIndex;
    #define DEFAULT_UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output)       output.stereoTargetEyeIndex = unity_StereoEyeIndex
    #define DEFAULT_UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input, output)  output.stereoTargetEyeIndex = input.stereoTargetEyeIndex;
    #define DEFAULT_UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input) unity_StereoEyeIndex = input.stereoTargetEyeIndex;
#elif defined(UNITY_STEREO_MULTIVIEW_ENABLED)
    #define DEFAULT_UNITY_VERTEX_OUTPUT_STEREO float stereoTargetEyeIndex : BLENDWEIGHT0;
    // HACK: Workaround for Mali shader compiler issues with directly using GL_ViewID_OVR (GL_OVR_multiview). This array just contains the values 0 and 1.
    #define DEFAULT_UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output) output.stereoTargetEyeIndex = unity_StereoEyeIndices[unity_StereoEyeIndex].x;
    #define DEFAULT_UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input, output) output.stereoTargetEyeIndex = input.stereoTargetEyeIndex;
    #if defined(SHADER_STAGE_VERTEX)
        #define DEFAULT_UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
    #else
        #define DEFAULT_UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input) unity_StereoEyeIndex = (uint) input.stereoTargetEyeIndex;
    #endif
#else
    #define DEFAULT_UNITY_VERTEX_OUTPUT_STEREO
    #define DEFAULT_UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output)
    #define DEFAULT_UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input, output)
    #define DEFAULT_UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
#endif


#if !defined(UNITY_VERTEX_OUTPUT_STEREO)
#   define UNITY_VERTEX_OUTPUT_STEREO                           DEFAULT_UNITY_VERTEX_OUTPUT_STEREO
#endif
#if !defined(UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO)
#   define UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output)        DEFAULT_UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output)
#endif
#if !defined(UNITY_TRANSFER_VERTEX_OUTPUT_STEREO)
#   define UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input, output)   DEFAULT_UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input, output)
#endif
#if !defined(UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX)
#   define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)      DEFAULT_UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
#endif

////////////////////////////////////////////////////////
// - UNITY_SETUP_INSTANCE_ID        Should be used at the very beginning of the vertex shader / fragment shader,
//                                  so that succeeding code can have access to the global unity_InstanceID.
//                                  Also procedural function is called to setup instance data.
// - UNITY_TRANSFER_INSTANCE_ID     Copy instance ID from input struct to output struct. Used in vertex shader.

#if defined(UNITY_INSTANCING_ENABLED) || defined(UNITY_PROCEDURAL_INSTANCING_ENABLED) || defined(UNITY_STEREO_INSTANCING_ENABLED)
    void UnitySetupInstanceID(uint inputInstanceID)
    {
        #ifdef UNITY_STEREO_INSTANCING_ENABLED
            // stereo eye index is automatically figured out from the instance ID
            unity_StereoEyeIndex = inputInstanceID & 0x01;
            unity_InstanceID = unity_BaseInstanceID + (inputInstanceID >> 1);
        #else
            unity_InstanceID = inputInstanceID + unity_BaseInstanceID;
        #endif
    }
    void UnitySetupCompoundMatrices();
    #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
        #ifndef UNITY_INSTANCING_PROCEDURAL_FUNC
            #error "UNITY_INSTANCING_PROCEDURAL_FUNC must be defined."
        #else
            void UNITY_INSTANCING_PROCEDURAL_FUNC(); // forward declaration of the procedural function
            #define DEFAULT_UNITY_SETUP_INSTANCE_ID(input)      { UnitySetupInstanceID(UNITY_GET_INSTANCE_ID(input)); UNITY_INSTANCING_PROCEDURAL_FUNC(); UnitySetupCompoundMatrices(); }
        #endif
    #else
        #define DEFAULT_UNITY_SETUP_INSTANCE_ID(input)          { UnitySetupInstanceID(UNITY_GET_INSTANCE_ID(input)); UnitySetupCompoundMatrices(); }
    #endif
    #define UNITY_TRANSFER_INSTANCE_ID(input, output)   output.instanceID = UNITY_GET_INSTANCE_ID(input)
#else
    #define DEFAULT_UNITY_SETUP_INSTANCE_ID(input)
    #define UNITY_TRANSFER_INSTANCE_ID(input, output)
#endif

#if !defined(UNITY_SETUP_INSTANCE_ID)
#   define UNITY_SETUP_INSTANCE_ID(input) DEFAULT_UNITY_SETUP_INSTANCE_ID(input)
#endif

////////////////////////////////////////////////////////
// instanced property arrays
#if defined(UNITY_INSTANCING_ENABLED)

    // The maximum number of instances a single instanced draw call can draw.
    // You can define your custom value before including this file.
    #ifndef UNITY_MAX_INSTANCE_COUNT
        #define UNITY_MAX_INSTANCE_COUNT 500
    #endif
    #if (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE) || defined(SHADER_API_METAL)) && !defined(UNITY_MAX_INSTANCE_COUNT_GL_SAME)
        // Many devices have max UBO size of 16kb
        #define UNITY_INSTANCED_ARRAY_SIZE (UNITY_MAX_INSTANCE_COUNT / 4)
    #else
        // On desktop, this assumes max UBO size of 64kb
        #define UNITY_INSTANCED_ARRAY_SIZE UNITY_MAX_INSTANCE_COUNT
    #endif

    // Every per-instance property must be defined in a specially named constant buffer.
    // Use this pair of macros to define such constant buffers.

    #if defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE) || defined(SHADER_API_METAL) || defined(SHADER_API_VULKAN)
        // GLCore and ES3 have constant buffers disabled normally, but not here.
        #define UNITY_INSTANCING_CBUFFER_START(name)    cbuffer UnityInstancing_##name {
        #define UNITY_INSTANCING_CBUFFER_END            }
    #else
        #define UNITY_INSTANCING_CBUFFER_START(name)    CBUFFER_START(UnityInstancing_##name)
        #define UNITY_INSTANCING_CBUFFER_END            CBUFFER_END
    #endif

    // Define a per-instance shader property. Must be used inside a UNITY_INSTANCING_CBUFFER_START / END block.
    #define UNITY_DEFINE_INSTANCED_PROP(type, name) type name[UNITY_INSTANCED_ARRAY_SIZE];

    // Access a per-instance shader property.
    #define UNITY_ACCESS_INSTANCED_PROP(name)       name[unity_InstanceID]

    // Redefine some of the built-in variables / macros to make them work with instancing.
    UNITY_INSTANCING_CBUFFER_START(PerDraw0)
        float4x4 unity_ObjectToWorldArray[UNITY_INSTANCED_ARRAY_SIZE];
        float4x4 unity_WorldToObjectArray[UNITY_INSTANCED_ARRAY_SIZE];
    UNITY_INSTANCING_CBUFFER_END

    #define unity_ObjectToWorld     unity_ObjectToWorldArray[unity_InstanceID]
    #define unity_WorldToObject     unity_WorldToObjectArray[unity_InstanceID]

    inline float4 UnityObjectToClipPosInstanced(in float3 pos)
    {
        return mul(UNITY_MATRIX_VP, mul(unity_ObjectToWorldArray[unity_InstanceID], float4(pos, 1.0)));
    }
    inline float4 UnityObjectToClipPosInstanced(float4 pos)
    {
        return UnityObjectToClipPosInstanced(pos.xyz);
    }
    #define UnityObjectToClipPos UnityObjectToClipPosInstanced

    #ifdef UNITY_INSTANCED_LOD_FADE
        // the quantized fade value (unity_LODFade.y) is automatically used for cross-fading instances
        UNITY_INSTANCING_CBUFFER_START(PerDraw1)
            float unity_LODFadeArray[UNITY_INSTANCED_ARRAY_SIZE];
        UNITY_INSTANCING_CBUFFER_END
        #define unity_LODFade unity_LODFadeArray[unity_InstanceID].xxxx
    #endif

#else // UNITY_INSTANCING_ENABLED

    #ifdef UNITY_MAX_INSTANCE_COUNT
        #undef UNITY_MAX_INSTANCE_COUNT
    #endif

    // in procedural mode we don't need cbuffer, and properties are not uniforms
    #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
        #define UNITY_INSTANCING_CBUFFER_START(name)
        #define UNITY_INSTANCING_CBUFFER_END
        #define UNITY_DEFINE_INSTANCED_PROP(type, name) static type name;
    #else
        #define UNITY_INSTANCING_CBUFFER_START(name)    CBUFFER_START(name)
        #define UNITY_INSTANCING_CBUFFER_END            CBUFFER_END
        #define UNITY_DEFINE_INSTANCED_PROP(type, name) type name;
    #endif

    #define UNITY_ACCESS_INSTANCED_PROP(name)       name

#endif // UNITY_INSTANCING_ENABLED

#if defined(UNITY_INSTANCING_ENABLED) || defined(UNITY_PROCEDURAL_INSTANCING_ENABLED) || defined(UNITY_STEREO_INSTANCING_ENABLED)
    // The following matrix evaluations depend on the static var unity_InstanceID & unity_StereoEyeIndex. They need to be initialized after UnitySetupInstanceID.
    static float4x4 unity_MatrixMVP_Instanced;
    static float4x4 unity_MatrixMV_Instanced;
    static float4x4 unity_MatrixTMV_Instanced;
    static float4x4 unity_MatrixITMV_Instanced;
    void UnitySetupCompoundMatrices()
    {
        unity_MatrixMVP_Instanced = mul(unity_MatrixVP, unity_ObjectToWorld);
        unity_MatrixMV_Instanced = mul(unity_MatrixV, unity_ObjectToWorld);
        unity_MatrixTMV_Instanced = transpose(unity_MatrixMV_Instanced);
        unity_MatrixITMV_Instanced = transpose(mul(unity_WorldToObject, unity_MatrixInvV));
    }
    #undef UNITY_MATRIX_MVP
    #undef UNITY_MATRIX_MV
    #undef UNITY_MATRIX_T_MV
    #undef UNITY_MATRIX_IT_MV
    #define UNITY_MATRIX_MVP    unity_MatrixMVP_Instanced
    #define UNITY_MATRIX_MV     unity_MatrixMV_Instanced
    #define UNITY_MATRIX_T_MV   unity_MatrixTMV_Instanced
    #define UNITY_MATRIX_IT_MV  unity_MatrixITMV_Instanced
#endif

#endif // UNITY_INSTANCING_INCLUDED
