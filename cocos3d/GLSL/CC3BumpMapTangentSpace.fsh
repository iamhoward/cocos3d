/*
 * CC3BumpMapTangentSpace.fsh
 *
 * cocos3d 2.0.0
 * Author: Bill Hollings
 * Copyright (c) 2011-2013 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * http://en.wikipedia.org/wiki/MIT_License
 */

/**
 * This fragment shader performs tangent-space bump-mapping.
 *
 * The texture in texture unit 0 contains a map of tangent-space normals, encoded in the
 * texel RGB colors.
 *
 * An optional second texture in texture unit 1 contains the visible texture to be applied on
 * top of the bump-mapped texture. If this texture is not available, the fragment color is used.
 *
 * CC3Texturable.vsh is the vertex shader paired with this fragment shader.
 *
 * The semantics of the variables in this shader can be mapped using a
 * CC3ShaderProgramSemanticsByVarName instance.
 */

// Increase this if more textures are desired.
#define MAX_TEXTURES			2

precision mediump float;

//-------------- UNIFORMS ----------------------

uniform bool		u_cc3FogIsEnabled;				/**< Whether scene fogging is enabled. */
uniform lowp vec4	u_cc3FogColor;					/**< Fog color. */
uniform int			u_cc3FogAttenuationMode;		/**< Fog attenuation mode (one of GL_LINEAR, GL_EXP or GL_EXP2). */
uniform highp float	u_cc3FogDensity;				/**< Fog density. */
uniform highp float	u_cc3FogStartDistance;			/**< Distance from camera at which fogging effect starts. */
uniform highp float	u_cc3FogEndDistance;			/**< Distance from camera at which fogging effect ends. */

uniform lowp int	u_cc3TextureCount;				/**< Number of textures. */
uniform sampler2D	s_cc3Textures[MAX_TEXTURES];	/**< Texture samplers. */

//-------------- VARYING VARIABLE INPUTS ----------------------
varying vec2		v_texCoord[MAX_TEXTURES];		/**< Fragment texture coordinates. */
varying lowp vec4	v_color;						/**< Fragment front-face color. */
varying lowp vec4	v_colorBack;					/**< Fragment back-face color. */
varying highp float	v_distEye;						/**< Fragment distance in eye coordinates. */
varying vec3		v_bumpMapLightDir;				/**< Direction to the first light in tangent space. */

//-------------- FUNCTIONS ----------------------

/** 
 * Returns the texel modulation from the normal retrieved from the bump map texture. Transforms
 * the normal from range [0, 1] to [-1, 1], takes dot product with light direction for interaction
 * between normal and light vector, and returns the result.
 */
float bumpMapModulation(vec4 texNormal) {
	return 2.0 * dot((texNormal.xyz - 0.5), v_bumpMapLightDir);
}

/** Applies fog to the specified color and returns the adjusted color. */
lowp vec4 fogify(lowp vec4 aColor) {
	
#	define k_GL_LINEAR                 0x2601
#	define k_GL_EXP                    0x0800
#	define k_GL_EXP2                   0x0801
	
	if ( !u_cc3FogIsEnabled ) return aColor;
	
	// Determine visibility based on fog attentuation characteristics and distance through fog
	float visibility = 1.0;
	if (u_cc3FogAttenuationMode == k_GL_LINEAR) {
		visibility = (u_cc3FogEndDistance - v_distEye) / (u_cc3FogEndDistance - u_cc3FogStartDistance);
	} else if (u_cc3FogAttenuationMode == k_GL_EXP) {
		float d = u_cc3FogDensity * v_distEye;
		visibility = exp(-d);
	} else if (u_cc3FogAttenuationMode == k_GL_EXP2) {
		float d = u_cc3FogDensity * v_distEye;
		visibility = exp(-(d * d));
	}
	visibility = clamp(visibility, 0.0, 1.0);
	
	// Mix alpha-adjusted fog color into fragment color based on visibility.
	aColor.rgb = mix(u_cc3FogColor.rgb * aColor.a, aColor.rgb, visibility);
	return aColor;
}

//-------------- ENTRY POINT ----------------------
void main() {
	lowp vec4 fragColor = gl_FrontFacing ? v_color : v_colorBack;

	if (u_cc3TextureCount > 1) fragColor *= texture2D(s_cc3Textures[1], v_texCoord[1]);
	fragColor.rgb *= bumpMapModulation(texture2D(s_cc3Textures[0], v_texCoord[0]));

	gl_FragColor = fogify(fragColor);
}
