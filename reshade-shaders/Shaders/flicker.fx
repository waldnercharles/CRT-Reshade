#include "Reshade.fxh"

uniform int framecount < source = "framecount"; >;

uniform float brightness <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "Interlacing Scanline Brightness [Flicker.fx]";
> = 0.99;

float fmod(float a, float b)
{
	float c = frac(abs(a / b)) * abs(b);
	return a < 0 ? -c : c;
}

float3 PS_Flicker(in float4 position : SV_Position, in float2 texcoord : TEXCOORD0) : SV_Target
{
	float y = texcoord.y + framecount;
	float3 col = tex2D(ReShade::BackBuffer, texcoord).rgb;
	
	if (fmod(y, 2) > 0.99999f)
	{
		return col;
	}
	else
	{
		return col * float3(brightness, brightness, brightness);
	}
}

technique Flicker {
	pass flicker {
		VertexShader=PostProcessVS;
		PixelShader=PS_Flicker;
	}
}