// uv扰动
Shader "Custom/Shader_01"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {} // 主纹理
        _DistortTex("Distortion Texture", 2D) = "white" {} // 扭曲纹理
		_DistortAmount("Distortion Amount", Range(0,2)) = 0.5 // 扭曲强度
		_DistortTexXSpeed("Scroll speed X", Range(-50,50)) = 5 // 扭曲纹理在X方向上的滚动速度
		_DistortTexYSpeed("Scroll speed Y", Range(-50,50)) = 5 // 扭曲纹理在Y方向上的滚动速度
        [HideInInspector] _RandomSeed("_MaxYUV", Range(0, 10000)) = 0.0 // 隐藏在Inspector中，随机种子值
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent" // 会在不透明对象之后渲染，数值越大越后渲染
            "RenderType" = "Transparent"
        }
        Blend SrcAlpha OneMinusSrcAlpha
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct a2v
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                half2 uvDistTex : TEXCOORD3;
            };

            sampler2D _MainTex; // 主纹理采样器
            float4 _MainTex_ST; // 主纹理的缩放和偏移
            sampler2D _DistortTex; // 扭曲纹理采样器
			half4 _DistortTex_ST; // 扭曲纹理的缩放和偏移
			half _DistortTexXSpeed, _DistortTexYSpeed, _DistortAmount; // 扭曲相关的参数
            // 定义实例化属性，随机种子，这个宏用于在着色器代码中定义一个实例化的属性。
            // 实例化属性意味着每个渲染实例（比如每个物体或每个渲染单元）都可以有不同的属性值，而不是共享一个值。
            UNITY_DEFINE_INSTANCED_PROP(float, _RandomSeed)

            v2f vert(a2v v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.uvDistTex = TRANSFORM_TEX(v.uv, _DistortTex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                half randomSeed = UNITY_ACCESS_INSTANCED_PROP(Props, _RandomSeed);
                
                // 根据时间和随机种子值滚动扭曲纹理的UV
                // uv值在0~1之间，所以要%1
                i.uvDistTex.x += (_Time.x + randomSeed) * _DistortTexXSpeed % 1;
                i.uvDistTex.y += (_Time.x + randomSeed) * _DistortTexYSpeed % 1;

                // tex2D获取颜色值
                // 计算扭曲的强度，并对主纹理的UV坐标进行扰动
                half distortAmnt = (tex2D(_DistortTex, i.uvDistTex).r - 0.5) * 0.2 * _DistortAmount;
                i.uv.x += distortAmnt;
                i.uv.y += distortAmnt;
                
                fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDCG
        }
    }
}