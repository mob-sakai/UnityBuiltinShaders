// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_EDITOR_UIE_INCLUDED
#define UNITY_EDITOR_UIE_INCLUDED

fixed _EditorColorSpace; // 1 for Linear, 0 for Gamma

fixed4 uie_editor_frag(v2f IN)
{
    // Postpone the application of the tint after the linear-to-gamma conversion.
    fixed4 tint = IN.color;
    IN.color = (fixed4)1;
    fixed4 stdColor = uie_std_frag(IN);

    // Only use the gamma conversion for an atlas or custom texture with an editor in linear space.
    fixed4 gammaColor = fixed4(LinearToGammaSpace(stdColor.rgb), stdColor.a);
    fixed convertToGamma = _EditorColorSpace * (abs(IN.flags.y) /* isTextured */ + IN.flags.z /* isCustom */);
    fixed4 result = lerp(stdColor, gammaColor, convertToGamma);

    // Apply the tint.
    return result * tint;
}

#endif // UNITY_EDITOR_UIE_INCLUDED
