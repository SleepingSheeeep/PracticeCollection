// 表面着色器——水面效果
Shader "Custom/Shader_04"
{
    Properties
    {
        // 水体基础颜色
        _Color ("Color", Color) = (0,0,1,1)
        // 法线贴图
        _NormalTex ("NormalTex", 2D) = "white" {}
        // 法线贴图强度
        _NormalScale ("NormalScale", float) = 1
        // 法线贴图移动速度
        _NormalSpeed ("NormalSpeed", float) = 1
        // 泡沫纹理
        _FoamTex ("FoamTex", 2D) = "white" {}
        // 波浪高度
        _WaveHeight ("WaveHeight", float) = 1
        // 波浪速度
        _WaveSpeed ("WaveSpeed", float) = 1
        // 波浪间隔
        _WaveGap ("WaveGap", float) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent" // 渲染类型为透明
            "Queue" = "Transparent" // 渲染队列为透明
            "IgnoreProjector" = "True" // 忽略投影器
        }
        
        LOD 200 // 细节级别
        
        CGPROGRAM
        // 使用 Standard 光照模型，启用透明混合，保留透明度，启用全向阴影
        #pragma surface surf Standard alpha:fade keepalpha fullforwardshadows vertex:vertexDataFunc
        #pragma target 3.0
        
        sampler2D _mainTex;
        fixed4 _Color;
        sampler2D _NormalTex;
        float _NormalScale;
        float _NormalSpeed;
        float _WaveHeight;
        float _WaveSpeed;
        float _WaveGap;
        
        struct Input
        {
            float2 uv_FoamTex; // 泡沫纹理的 UV 坐标
            float4 screenPos; // 屏幕空间坐标
        };
        
        void vertexDataFunc(inout appdata_full v, out Input o)
        {
            // 初始化输出结构
            UNITY_INITIALIZE_OUTPUT(Input, o);
            // 计算波浪高度，使用正弦函数模拟波浪效果
            fixed height = sin(_Time.y * _WaveSpeed + v.vertex.z * _WaveGap + v.vertex.x) * _WaveHeight;
            v.vertex.xyz += v.normal * height;
        }
        
        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            // 根据时间偏移法线贴图的 UV 坐标
            float2 speed = _Time.x * float2(_WaveSpeed, _WaveSpeed) * _NormalSpeed;
            // 采样法线贴图，并解包法线
            fixed3 bump1 = UnpackNormal(tex2D(_NormalTex, IN.uv_FoamTex.xy + speed)).rgb;
            fixed3 bump2 = UnpackNormal(tex2D(_NormalTex, IN.uv_FoamTex.xy - speed)).rgb;
            // 扰动效果
            fixed3 bump = normalize(bump1 + bump2);
            // 调整法线强度
            bump.xy *= _NormalScale;
            bump = normalize(bump);
            o.Normal = bump;
            
            o.Albedo = _Color;
            o.Alpha = _Color.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
