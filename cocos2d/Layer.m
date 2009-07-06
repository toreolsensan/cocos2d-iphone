/* cocos2d for iPhone
 *
 * http://www.cocos2d-iphone.org
 *
 * Copyright (C) 2008,2009 Ricardo Quesada
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the 'cocos2d for iPhone' license.
 *
 * You will find a copy of this license within the cocos2d for iPhone
 * distribution inside the "LICENSE" file.
 *
 */


#import <OpenGLES/ES1/gl.h>
#import <stdarg.h>

#import "Layer.h"
#import "Director.h"
#import "TouchDispatcher.h"
#import "ccMacros.h"
#import "Support/CGPointExtension.h"

#pragma mark -
#pragma mark Layer

@implementation Layer

@synthesize isTouchEnabled, isAccelerometerEnabled;

-(id) init
{
	if( (self=[super init]) ) {
	
		CGSize s = [[Director sharedDirector] winSize];
		anchorPoint_ = ccp(0.5f, 0.5f);
		[self setContentSize:s];
		self.relativeTransformAnchor = NO;

		isTouchEnabled = NO;
		isAccelerometerEnabled = NO;
	}
	
	return self;
}

-(void) registerWithTouchDispatcher
{
	[[TouchDispatcher sharedDispatcher] addStandardDelegate:self priority:0];
}

-(void) onEnter
{
	// register 'parent' nodes first
	// since events are propagated in reverse order
	if (isTouchEnabled)
		[self registerWithTouchDispatcher];
	
	// then iterate over all the children
	[super onEnter];

	if( isAccelerometerEnabled )
		[[UIAccelerometer sharedAccelerometer] setDelegate:self];
}

-(void) onExit
{
	[[TouchDispatcher sharedDispatcher] removeDelegate:self];
	
	if( isAccelerometerEnabled )
		[[UIAccelerometer sharedAccelerometer] setDelegate:nil];
	
	[super onExit];
}
-(BOOL) ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event
{
	NSAssert(NO, @"Layer#ccTouchBegan override me");
	return YES;
}
@end

#pragma mark -
#pragma mark ColorLayer

@interface ColorLayer (Private)
-(void) updateColor;
@end

@implementation ColorLayer

// Opacity and RGB color protocol
@synthesize opacity=opacity_, color=color_;


- (id) init
{
	NSException* myException = [NSException
								exceptionWithName:@"ColorLayerInit"
								reason:@"Use ColorLayer initWithColor instead"
								userInfo:nil];
	@throw myException;	
}

+ (id) layerWithColor:(ccColor4B)color width:(GLfloat)w  height:(GLfloat) h
{
	return [[[self alloc] initWithColor:color width:w height:h] autorelease];
}

+ (id) layerWithColor:(ccColor4B)color
{
	return [[[self alloc] initWithColor:color] autorelease];
}

- (id) initWithColor:(ccColor4B)color width:(GLint)w  height:(GLint) h
{
	if( (self=[super init]) ) {
		color_.r = color.r;
		color_.g = color.g;
		color_.b = color.b;
		opacity_ = color.a;
		
		[self updateColor];
		
		[self initWidth:w height:h];
	}
	return self;
}

- (id) initWithColor:(ccColor4B)color
{
	CGSize s = [[Director sharedDirector] winSize];
	
	return [self initWithColor:color width:s.width height:s.height];
}

-(void) changeWidth: (GLfloat) w
{
	squareVertices[2] = w;
	squareVertices[6] = w;
}

-(void) changeHeight: (GLfloat) h
{
	squareVertices[5] = h;
	squareVertices[7] = h;
}

- (void) updateColor
{
	for( NSUInteger i=0; i < sizeof(squareColors) / sizeof(squareColors[0]);i++ )
	{
		if( i % 4 == 0 )
			squareColors[i] = color_.r;
		else if( i % 4 == 1)
			squareColors[i] = color_.g;
		else if( i % 4 ==2  )
			squareColors[i] = color_.b;
		else
			squareColors[i] = opacity_;
	}
}

- (void) initWidth: (GLfloat) w height:(GLfloat) h
{
	for (NSUInteger i=0; i<sizeof(squareVertices) / sizeof( squareVertices[0]); i++ )
		squareVertices[i] = 0.0f;
	
	squareVertices[2] = w;
	squareVertices[5] = h;
	squareVertices[6] = w;
	squareVertices[7] = h;
	
}

- (void)draw
{		
	glVertexPointer(2, GL_FLOAT, 0, squareVertices);
	glEnableClientState(GL_VERTEX_ARRAY);
	glColorPointer(4, GL_UNSIGNED_BYTE, 0, squareColors);
	glEnableClientState(GL_COLOR_ARRAY);
	
	if( opacity_ != 255 )
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	if( opacity_ != 255 )
		glBlendFunc(CC_BLEND_SRC, CC_BLEND_DST);
	
	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);
}
/** XXX Deprecated **/
-(void) changeColor: (GLuint) aColor
{
	CCLOG(@"ColorLayer:changeColor is deprecated. using setRGB::: instead");
	color_.r = (aColor >> 24) & 0xff;
	color_.g = (aColor >> 16) & 0xff;
	color_.b = (aColor >> 8) & 0xff;
	opacity_ = (aColor) & 0xff;	
	[self updateColor];
}

//-(void) setColor:(GLuint)aColor
//{
//	return [self changeColor:aColor];
//}

#pragma mark Protocols
// Color Protocol

-(void) setColor:(ccColor3B)color
{
	color_ = color;
	[self updateColor];
}
-(void) setRGB: (GLubyte)r :(GLubyte)g :(GLubyte)b
{
	[self setColor:ccc3(r,g,b)];
}

// Opacity Protocol
-(void) setOpacity: (GLubyte) o
{
	opacity_ = o;
	[self updateColor];
}

// Size protocol
-(CGSize) contentSize
{
	CGSize ret;
	ret.width = squareVertices[2];
	ret.height = squareVertices[5];
	return ret;
}
@end

#pragma mark -
#pragma mark MultiplexLayer

@implementation MultiplexLayer
+(id) layerWithLayers: (Layer*) layer, ... 
{
	va_list args;
	va_start(args,layer);
	
	id s = [[[self alloc] initWithLayers: layer vaList:args] autorelease];
	
	va_end(args);
	return s;
}

-(id) initWithLayers: (Layer*) layer vaList:(va_list) params
{
	if( ! (self=[super init]) )
		return nil;
	
	layers = [[NSMutableArray array] retain];
	
	[layers addObject: layer];
	
	Layer *l = va_arg(params,Layer*);
	while( l ) {
		[layers addObject: l];
		l = va_arg(params,Layer*);
	}
	
	enabledLayer = 0;
	[self addChild: [layers objectAtIndex: enabledLayer]];		
	
	return self;
}

-(void) dealloc
{
	[layers release];
	[super dealloc];
}

-(void) switchTo: (unsigned int) n
{
	if( n >= [layers count] ) {
		NSException* myException = [NSException
									exceptionWithName:@"MultiplexLayerInvalidIndex"
									reason:@"Invalid index in MultiplexLayer switchTo message"
									userInfo:nil];
		@throw myException;		
	}
		
	[self removeChild: [layers objectAtIndex:enabledLayer] cleanup:NO];
	
	enabledLayer = n;
	
	[self addChild: [layers objectAtIndex:n]];		
}

-(void) switchToAndReleaseMe: (unsigned int) n
{
	if( n >= [layers count] ) {
		NSException* myException = [NSException
									exceptionWithName:@"MultiplexLayerInvalidIndex"
									reason:@"Invalid index in MultiplexLayer switchTo message"
									userInfo:nil];
		@throw myException;		
	}
	
	[self removeChild: [layers objectAtIndex:enabledLayer] cleanup:NO];
	
	[layers replaceObjectAtIndex:enabledLayer withObject:[NSNull null]];
	
	enabledLayer = n;
	
	[self addChild: [layers objectAtIndex:n]];		
}

@end
