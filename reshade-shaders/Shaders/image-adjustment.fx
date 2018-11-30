#include "Reshade.fxh"

uniform int framecount < source = "framecount"; >;

uniform float monitorGamma <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 5.0;
	ui_step = 0.1;
	ui_label = "Monitor Gamma [image-adjustment.fx]";
> = 2.5;

uniform float targetGamma <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 5.0;
	ui_step = 0.1;
	ui_label = "Target Gamma [image-adjustment.fx]";
> = 2.5;

uniform float saturation <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 5.0;
	ui_step = 0.1;
	ui_label = "Saturation [image-adjustment.fx]";
> = 1.0;

uniform float contrast <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 5.0;
	ui_step = 0.1;
	ui_label = "Contrast [image-adjustment.fx]";
> = 1.0;

uniform float luminance <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 5.0;
	ui_step = 0.1;
	ui_label = "Luminance [image-adjustment.fx]";
> = 1.0;

uniform float brightness <
	ui_type = "drag";
	ui_min = -1.0;
	ui_max = 1.0;
	ui_step = 0.1;
	ui_label = "Brightness Boost [image-adjustment.fx]";
> = 0.0;

uniform float R <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_step = 0.05;
	ui_label = "Red Channel [image-adjustment.fx]";
> = 1.0;

uniform float G <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_step = 0.05;
	ui_label = "Green Channel [image-adjustment.fx]";
> = 1.0;

uniform float B <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_step = 0.05;
	ui_label = "Blue Channel [image-adjustment.fx]";
> = 1.0;

float3 grayscale(float3 col)
{
   // ATSC grayscale standard
   float gray = dot(col, float3(0.2126, 0.7152, 0.0722));
   return float3(gray, gray, gray);
}

float3 PS_ImageCorrect(in float4 position : SV_Position, in float2 texcoord : TEXCOORD0) : SV_Target
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float gammaRatio = monitorGamma/targetGamma;
	float3 gamma = float3(gammaRatio, gammaRatio, gammaRatio);
	float3 avgLum = float3(0.5, 0.5, 0.5);
	float3 intensity = grayscale(color);
	float3 saturationColor = lerp(intensity, color, saturation);
	float3 contrastColor = lerp(avgLum, saturationColor, contrast);
	contrastColor = pow(contrastColor, 1.0 / gamma);
	contrastColor = saturate(contrastColor * luminance);
	contrastColor += float3(brightness, brightness, brightness);
	contrastColor *= float3(R,G,B);
	
	return contrastColor;
}

technique ImageAdjustment {
	pass ImageAdjustment {
		VertexShader=PostProcessVS;
		PixelShader=PS_ImageCorrect;
	}
}