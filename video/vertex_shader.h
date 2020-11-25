/*
     File: Shader.vsh
 Abstract: Vertex shader that passes attributes through to fragment shader.
  Version: 1.0
 Copyright (C) 2013 Apple Inc. All Rights Reserved. 
 */

char* vertex_shader_c_string = 
    "attribute vec4 position;"
    "attribute vec2 texCoord;"
    "uniform mat4 mvp;"
    ""
    "varying vec2 texCoordVarying;"
    ""
    "void main()"
    "{"
    "    gl_Position = mvp * position;"
    "    texCoordVarying = texCoord;"
    "}";
