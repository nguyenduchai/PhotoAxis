#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" {
namespace coreimage {
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
