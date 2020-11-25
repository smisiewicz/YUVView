//
//  PTYUVView.h
//  LiveManagerTestOSX
//
//  Created by Bastek on 1/23/18.
//

#import <Foundation/Foundation.h>
#import "PTVideoScaleBehavior.h"

#if TARGET_OS_OSX
    #import <AppKit/NSOpenGLView.h>
#else
    #import <GLKit/GLKit.h>
#endif


#if TARGET_OS_OSX
@interface PTYUVView : NSOpenGLView
#else
@interface PTYUVView : GLKView
#endif

@property(nonatomic) bool mirror;
@property(nonatomic) PTVideoScaleBehavior scaleBehavior;

- (void)setPixel:(NSData *)pixel
           width:(uint32_t)width
          height:(uint32_t)height;
- (void)cleanup;

+ (instancetype)mirrored;

@end
