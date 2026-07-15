Shader"Shaders Book/Shadow"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1,1,1,1)
        _Specular ("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }

    SubShader
    {
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM
            #pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                SHADOW_COORDS(2)
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                // 将表面法线从模型空间转换到世界空间
                // o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                // 将顶点位置从模型空间转换到世界空间
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // 顶点着色器传递的法线
                fixed3 worldNormal = normalize(i.worldNormal);
                // 世界坐标下的光源向量，注意方向是由顶点指向光源
                // fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                // 计算漫反射
                // 环境光颜色 + 漫反射颜色 * 表面法线和光源的点积
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));

                // 世界坐标下的摄像机向量
                // fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

                // BlinnPhong公式
                // _LightColor0得到平行光的颜色和强度
                fixed3 halfDir = normalize(worldLightDir + viewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

                // 只能计算阴影
                // UNITY_SHADOW_ATTENUATION(atten);
                // 计算光照衰减和阴影
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                fixed3 color = ambient + (diffuse + specular) * atten;
                return fixed4(color, 1.0);
            }
            ENDCG
        }

        // Additional Pass
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardAdd"
            }

            Blend One One
            CGPROGRAM
            #pragma multi_compile_fwdadd

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                // 将表面法线从模型空间转换到世界空间
                // o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                // 将顶点位置从模型空间转换到世界空间
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // 顶点着色器传递的法线
                fixed3 worldNormal = normalize(i.worldNormal);

                #ifdef USING_DIRECTIONAL_LIGHT
                    fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                #else
                fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                #endif

                // 计算漫反射
                // 环境光颜色 + 漫反射颜色 * 表面法线和光源的点积
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));

                // 世界坐标下的摄像机向量
                // fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

                // BlinnPhong公式
                // _LightColor0得到平行光的颜色和强度
                fixed3 halfDir = normalize(worldLightDir + viewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

                #ifdef USING_DIRECTIONAL_LIGHT
                    fixed atten = 1.0;
                #else
                    #if defined (POINT) // 点光源
                        // 经过unity_WorldToLight变换后，在点光源中心处lightCoord为(0, 0, 0)，在点光源的范围边缘处lightCoord模为1
                        float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
                        // UNITY_ATTEN_CHANNEL是衰减值所在的纹理通道，可以在内置的HLSLSupport.cginc文件中查看。
                        // 一般PC和主机平台的话UNITY_ATTEN_CHANNEL是r通道，移动平台的话是a通道
                        fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
                    #elif defined (SPOT) // 聚光灯
                        // 经过unity_WorldToLight变换后，在聚光灯光源中心处或聚光灯范围外的lightCoord为(0, 0, 0)，在点光源的范围边缘处lightCoord模为1
                        float4 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1));
                        // 与点光源不同，由于聚光灯有更多的角度等要求，
                        // 因此为了得到衰减值，除了需要对衰减纹理采样外，还需要对聚光灯的范围、张角和方向进行判断
                        // 此时衰减纹理存储到了_LightTextureB0中，这张纹理和点光源中的_LightTexture0是等价的
                        // 聚光灯的_LightTexture0存储的不再是基于距离的衰减纹理，而是一张基于张角范围的衰减纹理
                        fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w *
                            tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
                    #else
                        fixed atten = 1.0;
                    #endif
                #endif
                
                fixed3 color = ambient + (diffuse + specular) * atten;
                return fixed4(color, 1.0);
            }
            ENDCG
        }
    }

    Fallback "Specular"
}