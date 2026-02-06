Shader"Shaders Book/Diffuse Pixel-Level"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1,1,1,1)
    }
    
    SubShader
    {
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"

            fixed4 _Diffuse;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                // 将表面法线从模型空间转换到世界空间
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // 顶点着色器传递的法线
                fixed3 worldNormal = normalize(i.worldNormal);
                // 世界坐标下的光源向量
                fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
                // 计算漫反射
                // 环境光颜色 + 漫反射颜色 * 表面法线和光源的点积
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight));

                fixed3 color = ambient + diffuse;
                
                return fixed4(color, 1.0);
            }

            ENDCG
        }
    }
    
    Fallback "Diffuse"
}