Shader "Custom/HexGrid_Final_Complete"
{
   Properties
    {
        [Header(Base Grid Settings)]
        _GridColor ("Base Grid Color", Color) = (0.2, 0.4, 0.4, 1)
        _GridScale ("Grid Scale", Float) = 5.0
        _Thickness ("Grid Thickness", Range(0.01, 0.2)) = 0.05
        _BaseGridIntensity ("Base Grid Intensity", Range(0, 2)) = 0.5 
        
        [Header(Fill Geometry Settings)]
        _FillGap ("Fill Gap from Line", Range(0.0, 0.2)) = 0.05
        _FillSoftness ("Fill Edge Softness", Range(0.001, 0.1)) = 0.01

        [Header(World Visibility (Fog of War))]
        _WorldViewRadius ("World View Radius", Float) = 50.0
        _WorldViewFalloff ("World View Falloff", Float) = 20.0

        [Header(Player Highlight)]
        _PlayerColor ("Player Highlight Color", Color) = (0, 1, 1, 1)
        _PlayerPos ("Player World Position", Vector) = (0,0,0,0)
        _PlayerRadius ("Spotlight Radius", Float) = 10.0 
        _PlayerFalloff ("Spotlight Falloff", Float) = 5.0
        _PlayerBoost ("Spotlight Intensity", Float) = 5.0 

        [Header(Channel Colors (Glow Map))]
        [NoScaleOffset] _GlowMap ("Glow Map (Render Texture)", 2D) = "black" {}
        // IMPORTANT: This must match the Orthographic Size of your Fog Camera * 2
        _MapWorldSize ("Map World Size", Float) = 100.0 
        
        // RED CHANNEL
        _BulletColor ("Bullet Color (Red)", Color) = (1, 0.5, 0, 1)
        _BulletGlowMult ("Bullet Intensity", Float) = 10.0
        
        // BLUE CHANNEL
        _HighlightColor ("Highlight Color (Blue)", Color) = (1, 0.2, 0.2, 1)
        _HighlightBoost ("Highlight Intensity", Float) = 10.0
        _HighlightAlpha ("Highlight Alpha", Range(0, 1)) = 1.0

        // Green Channel is now purely for ALPHA CUTOUT (No Color Settings needed)

        [Header(Animation)]
        _EmissionStrength ("Global Emission", Float) = 1.0
        _WaveSpeed ("Wave Speed", Float) = 2.0
        _WaveFrequency ("Wave Frequency", Float) = 0.5
        _WaveAmplitude ("Wave Amplitude", Float) = 0.05
        _PulseSpeed ("Pulse Speed", Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata { float4 vertex : POSITION; };
            struct v2f {
                float4 vertex   : SV_POSITION;
                float2 gridPos  : TEXCOORD0;   
                float3 worldPos : TEXCOORD1;
            };

            // --- VARIABLES ---
            float4 _GridColor, _PlayerColor, _BulletColor, _HighlightColor;
            float4 _PlayerPos;
            
            float _GridScale, _Thickness, _BaseGridIntensity;
            float _FillGap, _FillSoftness;
            
            float _WorldViewRadius, _WorldViewFalloff;
            float _PlayerRadius, _PlayerFalloff, _PlayerBoost;
            
            float _BulletGlowMult, _HighlightBoost, _MapWorldSize;
            float _HighlightAlpha;
            
            float _EmissionStrength, _WaveSpeed, _WaveFrequency, _WaveAmplitude, _PulseSpeed;
            
            sampler2D _GlowMap;

            // --- HELPERS ---
            float HexEdgeDistance(float2 p) {
                float2 r = float2(1.0, 1.73205);
                float2 h = r * 0.5;
                float2 a = frac(p / r) * r - h;
                float2 b = frac((p - h) / r) * r - h;
                float2 gv = dot(a, a) < dot(b, b) ? a : b;
                float2 absGV = abs(gv);
                float c = dot(absGV, normalize(float2(1.0, 1.73205)));
                return 0.5 - max(c, absGV.x);
            }

            v2f vert (appdata v) {
                v2f o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.gridPos = o.worldPos.xz / _GridScale;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float distToPlayer = distance(i.worldPos.xz, _PlayerPos.xz);
                float pulse = (_PulseSpeed > 0) ? (0.8 + 0.2 * sin(_Time.y * _PulseSpeed)) : 1.0;

                // DISTORTION
                float ripple = sin(distToPlayer * _WaveFrequency - _Time.y * _WaveSpeed);
                float2 dir = normalize(i.worldPos.xz - _PlayerPos.xz + 0.001);
                float2 distortedGridPos = i.gridPos + (dir * ripple * _WaveAmplitude);

                // HEX GEOMETRY
                float edgeDist = HexEdgeDistance(distortedGridPos);
                
                // A. Grid Lines
                float lineMask = 1.0 - smoothstep(_Thickness, _Thickness + 0.02, edgeDist);

                // B. Fill Geometry
                float fillThreshold = _Thickness + _FillGap;
                float fillShapeMask = smoothstep(fillThreshold, fillThreshold + _FillSoftness, edgeDist);

                // DATA SAMPLING
                float2 relativeUV = (i.worldPos.xz - _PlayerPos.xz) / _MapWorldSize + 0.5;
                float4 glowData = tex2D(_GlowMap, relativeUV);
                
                float bulletMask = glowData.r;      
                float planetHoleValue = glowData.g
                float highlightMask = glowData.b;  

                // VISIBILITY MARKS
                float worldMask = 1.0 - smoothstep(_WorldViewRadius, _WorldViewRadius + _WorldViewFalloff, distToPlayer);
                // This is the mask for the area under the player
                float playerSpotlight = 1.0 - smoothstep(_PlayerRadius, _PlayerRadius + _PlayerFalloff, distToPlayer);

                // Green (1.0) = Transparent. Black (0.0) = Visible.
                float voidMask = saturate(1.0 - planetHoleValue);

                // COMPOSITOIN

                // THE GRID LINES
                float gridLineVis = saturate(worldMask + playerSpotlight + highlightMask + bulletMask);
                
                float4 finalGridColor = _GridColor;
                finalGridColor.rgb *= _BaseGridIntensity;
                
                // Add Colors to the LINES
                finalGridColor.rgb += _PlayerColor.rgb * (playerSpotlight * _PlayerBoost);
                finalGridColor.rgb += _HighlightColor.rgb * (highlightMask * _HighlightBoost);
                finalGridColor.rgb += _BulletColor.rgb * (bulletMask * _BulletGlowMult);
                
                // Apply VoidMask to lines
                finalGridColor.a *= lineMask * gridLineVis * voidMask;

                // FILL
                float3 activeFillColor = float3(0,0,0);
                float activeFillAlpha = 0;

                // PLAYER FILL
                // Uses the existing playerSpotlight mask to fill faces under player
                activeFillColor += _PlayerColor.rgb * (playerSpotlight * _PlayerBoost);
                activeFillAlpha += playerSpotlight;

                // Red
                activeFillColor += _BulletColor.rgb * (bulletMask * _BulletGlowMult);
                activeFillAlpha += bulletMask;

                // Blue
                activeFillColor += _HighlightColor.rgb * (highlightMask * _HighlightBoost);
                activeFillAlpha += highlightMask * _HighlightAlpha;

                // Apply geometry shape and VoidMask to all fills
                activeFillAlpha = saturate(activeFillAlpha) * fillShapeMask * voidMask;
                
                activeFillColor *= pulse;

                // FINAL COMBINE
                float finalAlpha = max(finalGridColor.a, activeFillAlpha * 0.8); 
                float3 finalRGB = lerp(finalGridColor.rgb, activeFillColor, activeFillAlpha);
                finalRGB *= _EmissionStrength;

                return float4(finalRGB, finalAlpha);
            }
            ENDHLSL
        }
    }
}
