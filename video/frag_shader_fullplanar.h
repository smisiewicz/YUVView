
#import <Foundation/Foundation.h>


#if TARGET_OS_OSX

char* frag_shader_c_string =
"uniform sampler2D yTexture;"
"uniform sampler2D uTexture;"
"uniform sampler2D vTexture;"
"varying vec2 texCoordVarying;"
""
"void main(void)"
"{"
"    float y, u, v, r, g, b;"
"    y=texture2D(yTexture, texCoordVarying.xy).r;"
"    u=texture2D(uTexture, texCoordVarying.xy).r;"
"    v=texture2D(vTexture, texCoordVarying.xy).r;"
""
"    y=1.1643*(y-0.0625);"
"    u=u-0.5;"
"    v=v-0.5;"
""
"    r = y + 1.5958  * v;"
"    g = y - 0.39173 * u - 0.81290 * v;"
"    b = y + 2.017   * u;"
""
"    gl_FragColor.rgba = vec4(b, g, r, 1.0);"
"}";

#else

char* frag_shader_c_string =
"uniform sampler2D yTexture;"
"uniform sampler2D uTexture;"
"uniform sampler2D vTexture;"
"varying highp vec2 texCoordVarying;"
""
"void main(void)"
"{"
"    highp float y, u, v, r, g, b;"
"    y=texture2D(yTexture, texCoordVarying.xy).r;"
"    u=texture2D(uTexture, texCoordVarying.xy).r;"
"    v=texture2D(vTexture, texCoordVarying.xy).r;"
""
"    y=1.1643*(y-0.0625);"
"    u=u-0.5;"
"    v=v-0.5;"
""
"    r = y + 1.5958  * v;"
"    g = y - 0.39173 * u - 0.81290 * v;"
"    b = y + 2.017   * u;"
""
"    gl_FragColor.rgba = vec4(b, g, r, 1.0);"
"}";

#endif
