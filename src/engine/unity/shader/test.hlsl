// DXBC ps_5_0 -> HLSL, literal translation. From test.dxbc. Hash: b763d45f-828a13cc-e38681f2-36a4353e
// cb0[387], cb1[16], t0-t5, s0-s5. Inputs: v1.xy, v2.xyz, v3.xyzw, v4.xyz, v5.x. Outputs: o0-o3.
// 纹理采样得到的向量分量用 .rgba 表示。

Texture2D<float4> T0 : register(t0);
Texture2D<float4> T1 : register(t1);
Texture2D<float4> T2 : register(t2);
Texture2D<float4> T3 : register(t3);
Texture2D<float4> T4 : register(t4);
Texture2D<float4> T5 : register(t5);

SamplerState S0 : register(s0);
SamplerState S1 : register(s1);
SamplerComparisonState S2 : register(s2);
SamplerState S3 : register(s3);
SamplerState S4 : register(s4);
SamplerState S5 : register(s5);

cbuffer CB0 : register(b0) { float4 cb0[387]; };
cbuffer CB1 : register(b1) { float4 cb1[16]; };

struct PSIn
{
  float2 v1_xy : TEXCOORD0;
  float3 v2_xyz : TEXCOORD1;
  float4 v3_xyzw : TEXCOORD2;
  float3 v4_xyz : TEXCOORD3;
  float  v5_x : TEXCOORD4;
};

struct PSOut
{
  float4 o0 : SV_Target0;
  float4 o1 : SV_Target1;
  float4 o2 : SV_Target2;
  float4 o3 : SV_Target3;
};

// 8-29 汇编等价。返回 (h, s, v)。
float3 RGBToHSV(float3 rgb)
{
  float ge_yz = (rgb.g >= rgb.b) ? 1.0 : 0.0;
  float2 t_zy = float2(rgb.b, rgb.g);
  float4 r3 = float4(t_zy, 0, -1);
  float4 r4 = float4(rgb.gb - t_zy, 1, -1);
  float4 r2 = ge_yz ? r4 : r3;
  float ge_x = (rgb.r >= r2.x) ? 1.0 : 0.0;
  r3 = float4(r2.xyw, rgb.r);
  r2.xyw = float3(r3.w, r3.y, r3.w);
  r2 = ge_x ? (r2 - r3).yxzw + r3.yxzw : r3.yxzw;
  float chroma = min(r2.x, r2.w);
  chroma = r2.y - chroma;
  float hue = r2.w - r2.x;
  float z = chroma * 6.0 + 0.0001;
  hue = hue / z + r2.z;
  z = r2.y + 0.0001;
  float sat = chroma / z;
  float v = r2.y;
  return float3(hue, sat, v);
}

// 30-39 中重建 RGB 的 frc/mad 部分
float3 HSVToRGB(float h, float s, float v)
{
  float3 r2 = h + float3(1, 0.666667, 0.333333);
  r2 = frac(r2);
  r2 = r2 * 6.0 - 3.0;
  r2 = saturate(abs(r2)) * 2.0 - 1.0;
  r2 = s * r2 + 1.0;
  return v * r2;
}

// 68-75 汇编等价。Reoriented Normal Mapping，见 lib/CommonMaterial.hlsl BlendNormalRNM
float3 BlendNormalRNM(float3 n1, float3 n2)
{
  float3 t = n1 + float3(0, 0, 1);
  float3 u = n2 * float3(-1, -1, 1);
  return (t / t.z) * dot(t, u) - u;
}

PSOut PS(PSIn i)
{
  PSOut o;
  float4 r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10;

  // 0-1
  float2 uv_t4 = i.v1_xy * cb1[1].xy + cb1[1].zw;
  r0 = T4.SampleBias(S4, uv_t4, cb0[386].y);

  // 2-7
  r1 = lerp(cb1[4], cb1[7], r0.b);
  r1 = lerp(r1, cb1[6], r0.g);
  r1 = lerp(r1, cb1[5], r0.r);

  // 8-39  RGBToHSV + cb1[8]/r0.a 调整 + HSVToRGB
  float3 hsv = RGBToHSV(r1.rgb);
  r1.x = cb1[8].x * r0.a + abs(hsv.x);
  r1.yz = saturate((cb1[8].yz * r0.aa + float2(0, 1)) * hsv.yy);
  r3.xyz = HSVToRGB(r1.x, r1.y, r1.z);

  // 40-42
  r1.x = min(cb1[8].w * r0.a + r1.w, 0.99);
  r1.yw = i.v1_xy * cb1[2].xy + cb1[2].zw;

  // 43-50
  r4.xyz = T3.SampleBias(S3, r1.yw, cb0[386].z).rga;
  r4.r *= r4.b;
  r4.rg = r4.rg * 2.0 - 1.0;
  r4.rg *= cb1[10].zz;
  r1.y = min(dot(r4.rg, r4.rg), 1.0);
  r4.b = sqrt(1.0 - r1.y);

  // 51-67
  r1.yw = i.v1_xy * cb1[3].xy + cb1[3].zw;
  r5.xyz = T5.SampleBias(S5, r1.yw, cb0[386].z).rga;
  r1.y = lerp(cb1[12].x, cb1[11].w, r0.b);
  r1.y = lerp(r1.y, cb1[11].z, r0.g);
  r1.y = lerp(r1.y, cb1[11].y, r0.r);
  r0.a = (1.0 - r0.a) * r1.y;
  r5.r *= r5.b;
  r5.rg = r5.rg * 2.0 - 1.0;
  r5.rg *= r0.aa;
  r0.w = min(dot(r5.rg, r5.rg), 1.0);
  r5.b = sqrt(1.0 - r0.w);
  // 68-75  Reoriented Normal Mapping -> BlendNormalRNM(n1, n2) + normalize
  float3 n1 = r4.rgb;
  float3 n2 = r5.rgb;
  r5.xyz = normalize(BlendNormalRNM(n1, n2));

  // 76-88
  float lt_v5 = (0 < i.v5_x) ? 1.0 : 0.0;
  r1.w = exp(log(i.v5_x) * cb1[11].x) * cb1[10].w;
  r1.y = r1.w * lt_v5;
  r0.b = lerp(cb1[9].w, cb1[9].z, r0.b);
  r0.b = lerp(r0.b, cb1[9].y, r0.g);
  r0.r = lerp(r0.r, r0.b, r0.r);
  r0.x = r0.r * cb1[13].x + r1.y;

  // 89-91
  r6.xyz = i.v2_xyz.zxy * i.v3_xyzw.yzx - i.v2_xyz.yzx * i.v3_xyzw.zxy;
  r6.xyz *= i.v3_xyzw.www;

  // 92-101
  r0.y = max(max(r3.y, r3.x), r3.z);
  r0.x *= r0.y;
  float lt_0z = (0 < r0.y) ? 1.0 : 0.0;
  r0.y = max(r0.y, 0.0001);
  r7.xyz = (r3.xyz / r0.yyy) * lt_0z;
  r0.y = saturate(r0.x);
  r1.yzw = -r1.zzz * r2.xyz + r7.xyz;
  r1.yzw = r0.y * r1.yzw + r3.xyz;

  // 102-165
  if (cb0[53].y < 0.5)
  {
    r2.xyz = i.v2_xyz * 0.45 + i.v4_xyz;
    r0.b = r2.x * cb0[31].w + cb0[33].w;
    r2.x = r2.z * cb0[32].w + cb0[34].w;
    r2.y = r2.y + 0.05 - cb0[55].z + 100.0;
    r2.y *= 0.003333;
    r3.x = r0.b * cb0[33].x;
    r3.y = r2.x * cb0[34].x;
    r2.xz = r3.xy + float2(0.5, 0.5);
    r2.xz = floor(r2.xz);
    r3.xy = r3.xy - r2.xz;
    r7.xyzw = r3.xxyy + float4(0.5, 1, 0.5, 1);
    r8.xw = r7.xz * r7.xz;
    r3.zw = r8.xw * 0.5 - r3.xy;
    r7.xz = float2(1, 1) - r3.xy;
    r9.xy = min(r3.xy, 0);
    r7.xz -= r9.xy * r9.xy;
    r3.xy = max(r3.xy, 0);
    r3.xy = r7.yw - r3.xy * r3.xy;
    r9.y = r7.x;
    r9.xz = r3.zx;
    r9.w = r8.x;
    r9 *= float4(0.44444, 0.44444, 0.44444, 0.22222);
    r8.y = r7.z;
    r8.xz = r3.wy;
    r8 *= float4(0.44444, 0.44444, 0.44444, 0.22222);
    r7.xyzw = r9.ywyw + r9.xzxz;
    r8.xyzw = r8.yyww + r8.xxzz;
    r3.xz = r9.yw / r7.zw;
    r3.yw = r8.yw / r8.yw;
    r3.xyzw = r3.xyzw + float4(-1.5, -1.5, 0.5, 0.5);
    r9.xy = r3.xz * cb0[31].xx;
    r9.zw = r3.yw * cb0[32].xx;
    r3.xy = float2(cb0[31].x, cb0[32].x);
    r10.xyzw = r2.xzxz * r3.xyxy + r9.xzyz;
    r3.xyzw = r2.xzxz * r3.xyxy + r9.xwyw;
    r7.xyzw *= r8.xyzw;
    r0.b = T1.SampleCmpLevelZero(S2, r10.xy, r2.y).r * r7.x;
    r0.b += T1.SampleCmpLevelZero(S2, r10.zw, r2.y).r * r7.y;
    r0.b += T1.SampleCmpLevelZero(S2, r3.xy, r2.y).r * r7.z;
    r0.b += T1.SampleCmpLevelZero(S2, r3.zw, r2.y).r * r7.w;
    r2.x = saturate(i.v2_xyz.y);
    r2.y = sqrt(1.0 - r2.x);
    r2.z = r2.x * (-0.018729) + 0.074261;
    r2.z = r2.z * r2.x + (-0.212114);
    r2.x = r2.z * r2.x + 1.570729;
    r2.x = -r2.x * r2.y + 1.570796;
    r2.x = r2.x * 2.0 - 1.570796;
    r2.x = sin(r2.x) + 1.0;
    r0.b *= r2.x * 0.5;
  }
  else
  {
    r0.b = 1.0;
  }

  // 166-184
  r2.xy = i.v4_xyz.xz * cb0[35].yy;
  r2.x = T0.Sample(S1, r2.xy).r * cb0[36].y + cb0[37].y;
  float lt_y1 = (cb0[31].z < i.v4_xyz.y) ? 1.0 : 0.0;
  float lt_y2 = (i.v4_xyz.y < cb0[32].z) ? 1.0 : 0.0;
  if (lt_y1 && lt_y2)
  {
    r3.x = i.v4_xyz.x * cb0[31].y + cb0[33].y;
    r3.y = i.v4_xyz.z * cb0[32].y + cb0[34].y;
    r2.y = dot(T2.Sample(S0, r3.xy).rgba, float4(0.25, 0.25, 0.25, 0.25));
  }
  else
    r2.y = 0;
  r2.y = saturate(r2.y * 1.010101 - 0.010101);
  r2.x = saturate(max(r2.y, r2.x));
  r2.x = min(r2.x, 1.0) * cb0[37].x;
  r0.b = saturate(r0.b * r2.x);
  r2.x = r1.x * cb0[36].x + cb0[35].x;
  r2.x *= r0.b;
  r2.yzw = r1.yzw * r1.yzw - r1.yzw;
  o1.xyz = r2.x * r2.yzw + r1.yzw;
  o1.w = 0;

  // 189-195
  r1.y = r0.b * cb1[15].y;
  r0.b = (r0.y != 0) ? r1.y : r0.b;
  r1.y = saturate((r0.b - cb0[51].y) / (1.0 - cb0[51].y));
  r1.z = cb0[52].y - r1.x;
  o2.y = r1.y * r1.z + r1.x;
  r0.b = (r0.b - 0.45) * 2.0;
  r0.b = saturate(r0.b);

  // 198-211
  r1.xyz = -r5.xyz + float3(0, 0, 1);
  r1.xyz = r0.bbb * r1.xyz + r5.xyz;
  r0.yzw = r0.y ? r1.xyz : r5.xyz;
  r1.xyz = r6.xyz * r0.bbb;
  r1.xyz = r0.yyy * i.v3_xyzw.xyz + r1.xyz;
  r0.yzw = r0.www * i.v2_xyz.xyz + r1.xyz;
  r1.x = dot(r0.yzw, r0.yzw);
  r1.x = rsqrt(r1.x);
  r0.yzw *= r1.xxx;
  o2.x = min(sqrt(r0.x * cb0[41].z) * 0.05, 1.0);
  o3.xyz = r0.yzw * 0.5 + 0.5;
  o0.xyzw = float4(0, 0, 0, 1);
  o2.z = cb1[10].x;
  o2.w = 0.67;
  o3.w = 0;

  return o;
}
