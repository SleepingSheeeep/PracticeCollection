// 火焰效果
Shader "Custom/Shader_02"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {} // 主纹理
        _Color ("Main Color", Color) = (1,1,1,1)

        [Space] // 空格，用于分隔属性
        _OutlineTex("Outline Texture", 2D) = "white" {} // 轮廓纹理，默认为白色纹理
        _OutlineTexXSpeed("Texture scroll speed X", Range(-50,50)) = 10 // 轮廓纹理在X轴上的滚动速度
        _OutlineTexYSpeed("Texture scroll speed Y", Range(-50,50)) = 0 // 轮廓纹理在Y轴上的滚动速度

        [Space]
        _OutlineDistortTex("Outline Distortion Texture", 2D) = "white" {} // 轮廓失真纹理，默认为白色纹理
        _OutlineDistortAmount("Outline Distortion Amount", Range(0,2)) = 0.5 // 轮廓失真强度
        _OutlineDistortTexXSpeed("Distortion scroll speed X", Range(-50,50)) = 5 // 失真纹理在X轴的滚动速度
        _OutlineDistortTexYSpeed("Distortion scroll speed Y", Range(-50,50)) = 5 // 失真纹理在Y轴的滚动速度

        [Space]
        _OutlineWidth("Outline Base Width", Range(0,0.2)) = 0.004 // 轮廓宽度

        [HideInInspector] _RandomSeed("_MaxYUV", Range(0, 10000)) = 0.0 // 随机种子，影响轮廓随机效果
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
                half4 color : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                half4 color : COLOR;
                half2 uvOutTex : TEXCOORD1; // outline
                half2 uvOutDistTex : TEXCOORD2; // outline distort
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex; // 主纹理采样器
            // _MainTex_TexelSize是贴图 _MainTex 的像素尺寸大小，值: Vector4(1 / width, 1 / height, width, height)
            float4 _MainTex_ST, _MainTex_TexelSize, _Color;

            sampler2D _OutlineTex; // 轮廓纹理
            half4 _OutlineTex_ST; // 轮廓纹理的变换
            half _OutlineTexXSpeed, _OutlineTexYSpeed; // 轮廓纹理滚动速度

            sampler2D _OutlineDistortTex; // 轮廓失真纹理
            half4 _OutlineDistortTex_ST; // 轮廓失真纹理的变换
            half _OutlineDistortTexXSpeed, _OutlineDistortTexYSpeed, _OutlineDistortAmount; // 失真纹理的滚动速度和强度

            half _OutlineWidth;

            // 定义实例化属性，随机种子，这个宏用于在着色器代码中定义一个实例化的属性。
            // 实例化属性意味着每个渲染实例（比如每个物体或每个渲染单元）都可以有不同的属性值，而不是共享一个值。
            UNITY_DEFINE_INSTANCED_PROP(float, _RandomSeed)

            v2f vert(a2v v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.color = v.color;
                o.uvOutTex = TRANSFORM_TEX(v.uv, _OutlineTex);
                o.uvOutDistTex = TRANSFORM_TEX(v.uv, _OutlineDistortTex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 1. 获得主纹理信息
                half4 col = tex2D(_MainTex, i.uv);
                half originalAlpha = col.a;

                half randomSeed = UNITY_ACCESS_INSTANCED_PROP(float, _RandomSeed);

                // 2. 计算轮廓偏移
                i.uvOutDistTex.x += (_Time.x + randomSeed) * _OutlineDistortTexXSpeed % 1;
                i.uvOutDistTex.y += (_Time.x + randomSeed) * _OutlineDistortTexYSpeed % 1;

                half outDistortAmnt = (tex2D(_OutlineDistortTex, i.uvOutDistTex).r - 0.5) * 0.2 * _OutlineDistortAmount;
                half2 destUv = half2(_OutlineWidth * _MainTex_TexelSize.x * 200,
                                     _OutlineWidth * _MainTex_TexelSize.y * 200);

                // 这里是为了给轮廓增加扰动，产生类似锯齿的不规则效果
                destUv.x += outDistortAmnt; // 应用X轴失真
                destUv.y += outDistortAmnt; // 应用Y轴失真

                // 3. 计算轮廓区域
                // 查看主纹理每个像素上下左右是否透明
                half spriteLeft = tex2D(_MainTex, i.uv + half2(destUv.x, 0)).a;
                half spriteRight = tex2D(_MainTex, i.uv - half2(destUv.x, 0)).a;
                half spriteBottom = tex2D(_MainTex, i.uv + half2(0, destUv.y)).a;
                half spriteTop = tex2D(_MainTex, i.uv - half2(0, destUv.y)).a;
                half result = spriteLeft + spriteRight + spriteBottom + spriteTop;
                // saturate(x)的作用是如果x取值小于0，则返回值为0。如果x取值大于1，则返回值为1。若x在0到1之间，则直接返回x的值
                // step(edge,x)：当x>edge时返回1，否则返回0
                result = step(0.05, saturate(result)); // 通过saturate和step函数生成轮廓区域

                // 4. 计算轮廓纹理滚动
                i.uvOutTex.x += (_Time.x + randomSeed) * _OutlineTexXSpeed % 1;
                i.uvOutTex.y += (_Time.x + randomSeed) * _OutlineTexYSpeed % 1;
                half4 tempOutColor = tex2D(_OutlineTex, i.uvOutTex); // 获取轮廓纹理的颜色

                half4 outline = tempOutColor;
                result *= 1 - originalAlpha;
                outline.a = result;

                // lerp用于得出两个状态(两个值, 两个点, 两种颜色, 两个角度等)的中间状态, 插值一般取0~1,
                // 靠近0时接近第一个状态, 靠近1时接近第二个状态
                col = lerp(col, outline, result); // 将主纹理与轮廓纹理混合
                col *= _Color;

                return col;
            }
            ENDCG
        }
    }
}