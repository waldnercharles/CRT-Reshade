#include "ReShade.fxh"

/* COMPATIBILITY
   - HLSL compilers
   - Cg   compilers
*/

uniform float d <
	ui_type = "drag";
	ui_min = 0.1;
	ui_max = 3.0;
	ui_step = 0.1;
	ui_label =  "Distance [CRT-Geom]";
> = 1.5;

uniform float CURVATURE <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 1.0;
	ui_label = "Curvature Toggle [CRT-Geom]";
> = 1.0;

uniform float R <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.1;
	ui_label = "Curvature Radius [CRT-Geom]";
> = 2.0;

uniform float cornersize <
	ui_type = "drag";
	ui_min = 0.001;
	ui_max = 1.0;
	ui_step = 0.005;
	ui_label = "Corner Size [CRT-Geom]";
> = 0.03;

uniform float cornersmooth <
	ui_type = "drag";
	ui_min = 80.0;
	ui_max = 2000.0;
	ui_step = 100.0;
	ui_label = "Corner Smoothness [CRT-Geom]";
> = 1000.0;

uniform float x_tilt <
	ui_type = "drag";
	ui_min = -0.5;
	ui_max = 0.5;
	ui_step = 0.05;
	ui_label = "Horizontal Tilt [CRT-Geom]";
> = 0.0;

uniform float y_tilt <
	ui_type = "drag";
	ui_min = -0.5;
	ui_max = 0.5;
	ui_step = 0.05;
	ui_label = "Vertical Tilt [CRT-Geom]";
> = 0.0;

uniform float aspect_x <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 64.0;
	ui_step = 1.0;
	ui_label = "Aspect Ratio Width [CRT-Geom]";
> = 4.0;

uniform float aspect_y <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 64.0;
	ui_step = 1.0;
	ui_label = "Aspect Ratio Height [CRT-Geom]";
> = 3.0;

uniform bool OVERSAMPLE <
	ui_tooltip = "Enable 3x oversampling of the beam profile; improves moire effect caused by scanlines+curvature";
> = true;

uniform bool INTERLACED <
	ui_tooltip = "Use interlacing detection; may interfere with other shaders if combined";
> = true;

#define FIX(c) max(abs(c), 1e-5);
#define PI 3.141592653589

#define TEX2D(c) tex2D(ReShade::BackBuffer, (c))
#define texture_size float2(BUFFER_WIDTH, BUFFER_HEIGHT)

static float2 aspect;
static float2 video_size;

uniform int framecount < source = "framecount"; >;

float fmod(float a, float b)
{
  float c = frac(abs(a/b))*abs(b);
  return (a < 0) ? -c : c;   /* if ( a < 0 ) c = 0-c */
}

float intersect(float2 xy, float2 sinangle, float2 cosangle)
{
    float A = dot(xy,xy)+d*d;
    float B = 2.0*(R*(dot(xy,sinangle)-d*cosangle.x*cosangle.y)-d*d);
    float C = d*d + 2.0*R*d*cosangle.x*cosangle.y;
    return (-B-sqrt(B*B-4.0*A*C))/(2.0*A);
}

float2 bkwtrans(float2 xy, float2 sinangle, float2 cosangle)
{
    float c = intersect(xy, sinangle, cosangle);
	float2 pnt = float2(c,c)*xy;
	pnt -= float2(-R,-R)*sinangle;
	pnt /= float2(R,R);
	float2 tang = sinangle/cosangle;
	float2 poc = pnt/cosangle;
	float A = dot(tang,tang)+1.0;
	float B = -2.0*dot(poc,tang);
	float C = dot(poc,poc)-1.0;
	float a = (-B+sqrt(B*B-4.0*A*C))/(2.0*A);
	float2 uv = (pnt-a*sinangle)/cosangle;
	float r = FIX(R*acos(a));
	return uv*r/sin(r/R);
}

float2 fwtrans(float2 uv, float2 sinangle, float2 cosangle)
{
	float r = FIX(sqrt(dot(uv,uv)));
	uv *= sin(r/R)/r;
	float x = 1.0-cos(r/R);
	float D = d/R + x*cosangle.x*cosangle.y+dot(uv,sinangle);
	return d*(uv*cosangle-x*sinangle)/D;
}

float3 maxscale(float2 sinangle, float2 cosangle)
{
	float2 c = bkwtrans(-R * sinangle / (1.0 + R/d*cosangle.x*cosangle.y), sinangle, cosangle);
	float2 a = float2(0.5,0.5)*aspect;
	float2 lo = float2(fwtrans(float2(-a.x,c.y), sinangle, cosangle).x,
						fwtrans(float2(c.x,-a.y), sinangle, cosangle).y)/aspect;
	float2 hi = float2(fwtrans(float2(+a.x,c.y), sinangle, cosangle).x,
						fwtrans(float2(c.x,+a.y), sinangle, cosangle).y)/aspect;
	return float3((hi+lo)*aspect*0.5,max(hi.x-lo.x,hi.y-lo.y));
}

float4 PS_CRTGeom(float4 vpos : SV_Position, float2 uv : TexCoord) : SV_Target
{

	aspect = float2(aspect_x, aspect_y) / max(aspect_x, aspect_y);
	
	float imageRatio = aspect_x / aspect_y;
	float screenRatio = texture_size.x / texture_size.y;
	
	video_size = screenRatio > imageRatio ?
		float2(aspect_x*texture_size.y/aspect_y, texture_size.y) :
		float2(texture_size.x, aspect_y*texture_size.x/aspect_x);

	float2 TextureSize = float2(1.0 * texture_size.x, texture_size.y);
	float mod_factor = uv.x * texture_size.x * ReShade::ScreenSize.x / video_size.x;
	float2 ilfac = float2(1.0,clamp(floor(video_size.y/(1.0/200.0)),1.0,2.0));
	float2 sinangle = sin(float2(x_tilt, y_tilt));
	float2 cosangle = cos(float2(x_tilt, y_tilt));
	float3 stretch = maxscale(sinangle, cosangle);
	float2 one = ilfac / TextureSize;

	// Texture coordinates of the texel containing the active pixel.
	float2 xy = 0.0;
	if (CURVATURE > 0.5){
		float2 cd = uv;
		cd = cd - float2((texture_size.x-video_size.x)/2.0/texture_size.x, (texture_size.y-video_size.y)/2.0/texture_size.y);
		cd *= texture_size / video_size;
		cd = (cd-float2(0.5,0.5))*aspect*stretch.z+stretch.xy;
		xy =  (bkwtrans(cd, sinangle, cosangle)/aspect+float2(0.5,0.5)) * video_size / texture_size;
	} else {
		xy = uv;
		//cd2 = cd2 - float2((texture_size.x-video_size.x)/2.0/texture_size.x, (texture_size.y-video_size.y)/2.0/texture_size.y);
	}

	float2 cd2 = xy;
	cd2 *= texture_size / video_size;
	cd2 = min(cd2, float2(1.0,1.0)-cd2) * aspect;
	float2 cdist = float2(cornersize,cornersize);
	cd2 = (cdist - min(cd2,cdist));
	float dist = sqrt(dot(cd2,cd2));
	float cval = clamp((cdist.x-dist)*cornersmooth,0.0, 1.0);

	float2 ratio_scale = (xy * TextureSize);

	xy = (floor(ratio_scale)) / TextureSize;
	//xy = xy - float2((texture_size.x-video_size.x)/2.0/texture_size.x, (texture_size.y-video_size.y)/2.0/texture_size.y);

	// Color the texel.
	return float4(TEX2D(xy / (video_size / texture_size)).rgb * float3(cval,cval,cval), 1.0);
}

technique GeomCRT {
	pass CRT_Geom {
		VertexShader=PostProcessVS;
		PixelShader=PS_CRTGeom;
	}
}