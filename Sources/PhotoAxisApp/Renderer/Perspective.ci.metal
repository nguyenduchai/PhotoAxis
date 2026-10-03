#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" {
namespace coreimage {
// Local illumination division and adaptive thresholding in linear light.
// Alpha comes from the retained image, never from the blurred background.
float4 photoAxisScan(sample_t original, sample_t smooth, sample_t background,
                     float paper, float threshold, float mode) {
    float a = original.a;
    float3 rgb = a > 0.00001 ? smooth.rgb / max(smooth.a, 0.00001) : float3(0.0);
    float3 bg = background.rgb / max(background.a, 0.00001);
    float3 corrected = mix(rgb, clamp(rgb / max(bg, float3(0.12)), 0.0, 1.0), paper);
    float gray = dot(corrected, float3(0.2126, 0.7152, 0.0722));
    if (mode > 1.5) {
        float luma = dot(rgb, float3(0.2126, 0.7152, 0.0722));
        float mean = dot(bg, float3(0.2126, 0.7152, 0.0722));
        corrected = float3(luma >= mean - threshold ? 1.0 : 0.0);
    } else if (mode > 0.5) { corrected = float3(gray); }
    return float4(corrected * a, a);
}

// Bounded two-axis bow correction, with fixed boundaries. This is an
// interactive geometric model, not reconstruction of an arbitrary folded page.
float2 photoAxisScanCurve(float width, float height, float curveX, float curveY, destination dest) {
    float2 p = dest.coord();
    float u = clamp(p.x / width, 0.0, 1.0), v = clamp(p.y / height, 0.0, 1.0);
    return p + float2(curveX * width * 0.12 * 4.0*v*(1.0-v)*sin(3.14159265*u),
                     curveY * height * 0.12 * 4.0*u*(1.0-u)*sin(3.14159265*v));
}

// Inverse sampling bounds evaluation to the output canvas. Source pixels outside
// the local clip are transparent; a pole in discarded source pixels is harmless.
float2 photoAxisPerspective(float3 row0, float3 row1, float3 row2,
                            float outputHeight, float inputHeight, destination dest) {
    float2 d = dest.coord();
    float3 p = float3(d.x, outputHeight - d.y, 1.0);
    float w = dot(row2, p);
    float scale = dot(abs(row2), abs(p));
    if (abs(w) <= 1e-7 * scale) return float2(-1000000.0);
    float2 source = float2(dot(row0, p), dot(row1, p)) / w;
    if (!all(isfinite(source))) return float2(-1000000.0);
    return float2(source.x, inputHeight - source.y);
}
}
}
