//
//  PTYUVView.m
//  LiveManagerTestOSX
//
//  Created by Bastek on 1/23/18.
//

#import "PTYUVView.h"

#import "frag_shader_fullplanar.h"
#import "vertex_shader.h"
#import "PTLogger.h"

#if TARGET_OS_OSX
    #import <GLKit/GLKit.h>
    #import <OpenGL/OpenGL.h>

    #define GL_RED_EXT 0x1903
#else
    #import <OpenGLES/EAGL.h>
    #import <OpenGLES/ES2/glext.h>
    #import <OpenGLES/ES2/gl.h>
#endif


static const CGFloat ASPECT_RATIO_H = 3.0;
static const CGFloat ASPECT_RATIO_V = 4.0;
static const CGFloat ASPECT_RATIO = (ASPECT_RATIO_H / ASPECT_RATIO_V);


@interface PTYUVView() {
    GLuint program;
    
    GLuint lumaTexture;
    GLuint uChromaTexture;
    GLuint vChromaTexture;
    
    GLuint indexVBO;
    GLuint positionVBO;
    GLuint texcoordVBO;
    
    GLsizei gl_width;
    GLsizei gl_height;
    
    BOOL hasLoadedGL;
}

@property(nonatomic, strong) NSData* pixel;
@property(nonatomic) uint32_t width;
@property(nonatomic) uint32_t height;

@end


@implementation PTYUVView

/*
 * PRAGMA MARK: -
 */
+ (instancetype)mirrored {
    PTYUVView *view = [PTYUVView new];
    view.mirror = YES;
    return view;
}


/*
 * PRAGMA MARK: - Setup/Teardown
 */

- (instancetype)init {
    return [self initWithFrame:CGRectZero];
}


- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    [NSException raise:(@"InitializationException")
                format:@"[PTYUVView initWithCoder:] not available. Internal class - not meant to be used within Storyboard/Nib."];
    return nil;
}


#if TARGET_OS_OSX
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setup];
    }
    return self;
}

#else

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame
                       context:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2]];
}


- (instancetype)initWithFrame:(CGRect)frame context:(EAGLContext *)context {
    self = [super initWithFrame:frame context:context];
    if (self) {
        [EAGLContext setCurrentContext:self.context];
        [self setup];
    }
    return self;
}
#endif


- (void)setup {
     PTLogDebug(@"Setting up YUV view...");
    
    // defaults:
    _scaleBehavior = PTVideoScaleBehaviorFill;
}


// Uniform index.
enum {
    UNIFORM_MVP,
    UNIFORM_Y,
    UNIFORM_U,
    UNIFORM_V,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};


- (void)setupBuffers {
    float x1 = -1.0;
    float y1 = -1.0;
    float x2 = 1.0;
    float y2 = 1.0;
    
    float u1 = 0.0;
    float v1 = 0.0;
    float u2 = 1.0;
    float v2 = 1.0;
    
    GLfloat vertices[] = {
        x1, y1,
        x1, y2,
        x2, y2,
        x2, y1
    };
    
    GLfloat texCoords[] = {
        u1, v1,
        u1, v2,
        u2, v2,
        u2, v1
    };
    
    GLushort indices[] = {
        0, 1, 2, 3
    };
    
    glGenBuffers(1, &indexVBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexVBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &positionVBO);
    glBindBuffer(GL_ARRAY_BUFFER, positionVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2*sizeof(GLfloat), 0);
    
    glGenBuffers(1, &texcoordVBO);
    glBindBuffer(GL_ARRAY_BUFFER, texcoordVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(texCoords), texCoords, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 2*sizeof(GLfloat), 0);
}


- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type cstring:(char *)shader_string {
    PTLogDebug(@"Compiling YUV view shaders...");
    GLint status;
    const GLchar *source = shader_string;
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        PTLogDebug(@"Shader compile log:\n%s", log);
        free(log);
    }
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        PTLogError(@"Shader compilation failed with status==0, releasing resources and exiting.");
        glDeleteShader(*shader);
        return NO;
    }
    
    PTLogDebug(@"Shader compilation successful");
    return YES;
}


- (BOOL)loadGL {
    PTLogDebug(@"Setting up GL for YUV view");
    
    GLuint vertShader, fragShader;
    program = glCreateProgram();
    
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER cstring:vertex_shader_c_string]) {
        PTLogError(@"Failed to compile vertex shader");
        return NO;
    }
    
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER cstring:frag_shader_c_string]) {
        PTLogError(@"Failed to compile fragment shader");
        return NO;
    }
    
    glAttachShader(program, vertShader);
    glAttachShader(program, fragShader);
    glBindAttribLocation(program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(program, ATTRIB_TEXCOORD, "texCoord");
    
    // Link Program
    GLint status;
    glLinkProgram(program);
    
    GLint logLength;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        PTLogDebug(@"Program link log:\n%s", log);
        free(log);
    }
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    
    // ok to clean up shaders now
    if (vertShader) {
        glDetachShader(program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(program, fragShader);
        glDeleteShader(fragShader);
    }
    
    if (status == 0) {
        [self unloadGL];
        return NO;
    }
    uniforms[UNIFORM_MVP] = glGetUniformLocation(program, "mvp");
    uniforms[UNIFORM_Y] = glGetUniformLocation(program, "yTexture");
    uniforms[UNIFORM_U] = glGetUniformLocation(program, "uTexture");
    uniforms[UNIFORM_V] = glGetUniformLocation(program, "vTexture");
    
    [self setupBuffers];
    return YES;
}


- (void)unloadGL {
    PTLogDebug(@"Cleaning up textures and GL for YUV view");

#if TARGET_OS_OSX
    //do nothing
#else
    [EAGLContext setCurrentContext:self.context];
#endif

    [self cleanUpTextures];
    
    if (program) {
        glDeleteProgram(program);
        program = 0;
    }
}


- (void)cleanUpTextures {
    glDeleteTextures(1, &lumaTexture);
    glDeleteTextures(1, &uChromaTexture);
    glDeleteTextures(1, &vChromaTexture);
}


- (void)cleanup {
    [self setPixel:nil width:0 height:0];
    [self unloadGL];
}


/*
 * PRAGMA MARK: -
 */
- (void)setPixel:(NSData *)pixel
           width:(uint32_t)width
          height:(uint32_t)height
{
    _pixel = pixel;
    _width = width;
    _height = height;
    
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_OSX
        [self setNeedsDisplay:YES];
#else
        [self setNeedsDisplay];
#endif
    });
}

#if TARGET_OS_OSX
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    [self postDrawRect];
}
#else
- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    [self postDrawRect];
}
#endif


- (void)postDrawRect {
    if (!hasLoadedGL) {
        hasLoadedGL = [self loadGL];
        
        glUseProgram(program);
        glUniform1i(uniforms[UNIFORM_Y], 0);
        glUniform1i(uniforms[UNIFORM_U], 1);
        glUniform1i(uniforms[UNIFORM_V], 2);
        
        glActiveTexture(GL_TEXTURE0);
        glGenTextures(1, &lumaTexture);
        glBindTexture(GL_TEXTURE_2D, lumaTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glActiveTexture(GL_TEXTURE1);
        glGenTextures(1, &uChromaTexture);
        glBindTexture(GL_TEXTURE_2D, uChromaTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        
        glActiveTexture(GL_TEXTURE2);
        glGenTextures(1, &vChromaTexture);
        glBindTexture(GL_TEXTURE_2D, vChromaTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    
    GLKMatrix4 mvpMatrix = GLKMatrix4Make(1.0f, 0.0f, 0.0f, 0.0f,
                                          0.0f, 1.0f, 0.0f, 0.0f,
                                          0.0f, 0.0f, 1.0f, 0.0f,
                                          0.0f, 0.0f, 0.0f, 1.0f);
    mvpMatrix = GLKMatrix4Scale(mvpMatrix, 1.0, -1.0, 1.0); // flip image in Y
    if (self.mirror) {
        mvpMatrix = GLKMatrix4Scale(mvpMatrix, -1.0, 1.0, 1.0); // mirror image in X
    }
    glUniformMatrix4fv(uniforms[UNIFORM_MVP], 1, 0, mvpMatrix.m);
    
    if (self.pixel) {
        [self paintYUV420p:[self.pixel bytes]
                     width:self.width
                    height:self.height];
    }
}


- (void)setScaleBehavior:(PTVideoScaleBehavior)scaleBehavior {
    PTLogDebug(@"Setting scale behavior to: %@", @(scaleBehavior));
    _scaleBehavior = scaleBehavior;
    
    // need to reposition with a direct frame setter:
    CGRect frame = (self.superview ? self.superview.bounds : self.frame);
    self.frame = frame;
}

#if TARGET_OS_OSX
- (void)setFrame:(NSRect)frame {
    super.frame = NSRectFromCGRect([self adjustedFrame:NSRectToCGRect(frame)]);
}
#else
- (void)setFrame:(CGRect)frame {
    super.frame = [self adjustedFrame:frame];
}
#endif

- (CGRect)adjustedFrame:(CGRect)frame {
    CGFloat width = roundf(frame.size.width);
    CGFloat height = roundf(frame.size.height);
    CGFloat curAspectRatio = width / height;
    
    if (curAspectRatio > ASPECT_RATIO) {
        // too wide
        if (_scaleBehavior == PTVideoScaleBehaviorFit) {
            frame = [self adjustedFrameToHeight:frame];
        } else {
            // default, since there are only two values here
            frame = [self adjustedFrameToWidth:frame];
        }
    } else if (curAspectRatio < ASPECT_RATIO) {
        // too narrow
        if (_scaleBehavior == PTVideoScaleBehaviorFit) {
            frame = [self adjustedFrameToWidth:frame];
        } else {
            // default, since there are only two values here
            frame = [self adjustedFrameToHeight:frame];
        }
    }
    return frame;
}

- (CGRect)adjustedFrameToHeight:(CGRect)frame {
    PTLogDebug(@"Adjusting YUV view frame to height: %@", @(frame));
    CGFloat width = roundf(frame.size.width);
    CGFloat height = roundf(frame.size.height);
    CGFloat newHeight = height + (ASPECT_RATIO_H - fmodf(height, ASPECT_RATIO_H));
    CGFloat newWidth = newHeight * ASPECT_RATIO;
    CGFloat diffX = (width - newWidth) * 0.5;
    return CGRectMake(frame.origin.x + diffX, frame.origin.y, newWidth, newHeight);
}

- (CGRect)adjustedFrameToWidth:(CGRect)frame {
    PTLogDebug(@"Adjusting YUV view frame to width: %@", @(frame));
    CGFloat width = roundf(frame.size.width);
    CGFloat height = roundf(frame.size.height);
    CGFloat newWidth = width + (ASPECT_RATIO_H - fmodf(width, ASPECT_RATIO_H));
    CGFloat newHeight = newWidth / ASPECT_RATIO;
    CGFloat diffY = (height - newHeight) * 0.5;
    return CGRectMake(frame.origin.x, frame.origin.y + diffY, newWidth, newHeight);
}


-(void)paintYUV420p:(const void*)pixelBuffer width:(int)width height:(int)height {
    gl_width = width & INT_MAX; // reduce to int32
    gl_height = height & INT_MAX;
    
    // Y-plane
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, lumaTexture);
    glTexImage2D(GL_TEXTURE_2D,
                 0, // mipmap level of reduction?
                 GL_RED_EXT,
                 gl_width,
                 gl_height,
                 0,
                 GL_RED_EXT,
                 GL_UNSIGNED_BYTE,
                 pixelBuffer);
    // U-Plane
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, uChromaTexture);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RED_EXT,
                 gl_width/2,
                 gl_height/2,
                 0,
                 GL_RED_EXT,
                 GL_UNSIGNED_BYTE,
                 pixelBuffer + (width * height));
    // V-Plane
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, vChromaTexture);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RED_EXT,
                 gl_width/2,
                 gl_height/2,
                 0,
                 GL_RED_EXT,
                 GL_UNSIGNED_BYTE,
                 pixelBuffer + (width * height) + ((width/2) * (height/2)));
    
    // flush it out
    glFlush();
    
    glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_SHORT, 0);
}

@end

