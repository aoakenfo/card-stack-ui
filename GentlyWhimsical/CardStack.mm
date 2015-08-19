//
//  CardStack.m
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-25.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import "Quad.h"
#import "CardStack.h"

#define ARC4RANDOM_MAX 0x100000000

@interface CardStack() {
    float _cardOffsetZ;
}
@end

@implementation CardStack

- (float)selectedCardOffsetZForIndex:(int)i {
    return (i * _cardOffsetZ) ;
}

- (void)setX:(float)value {
    _x = value;
    for(Quad* q in _cards) {
        q.x = value;
    }
}

- (void)setY:(float)value {
    _y = value;
    for(Quad* q in _cards) {
        q.y = value;
    }
}

- (void)setZ:(float)value {
    _z = value;
    for(int i = 0; i < _cards.count; ++i) {
        Quad* q = [_cards objectAtIndex:i];
        q.z = (i * _cardOffsetZ)+value;
    }
}

- (void)setSx:(float)value {
    _sx = value;
    for(Quad* q in _cards) {
        q.sx = value;
    }
}

- (void)setSy:(float)value {
    _sy = value;
    for(Quad* q in _cards) {
        q.sy = value;
    }
}

- (void)shiftCards:(ShiftDir)shiftDir {
    
    if(shiftDir == ShiftDir_Forward) {
        Quad* q = (Quad*)[_cards lastObject];
        [_cards removeLastObject];
        [_cards insertObject:q atIndex:0];
    }
    else {
        Quad* q = (Quad*)[_cards objectAtIndex:0];
        [_cards removeObjectAtIndex:0];
        [_cards addObject:q];
    }
    
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library {
    
    self = [super init];
    
    if(self) {
        _cardOffsetZ = 0.3f;
        
        _cards = [[NSMutableArray alloc]init];
        
        for(int i = 8; i >= 0; --i) {
            Quad* q = [[Quad alloc]initWithDevice:device
                                            layer:layer
                        numInflightCommandBuffers:numInflightCommandBuffers
                                          library:library
                                           params:@{
                                                    kIsTextured:@1,
                                                    kTextureName:[NSString stringWithFormat:@"%i", i],
                                                    kIsFullscreen:@0,
                                                    kCornerRadius:@5,
                                                    kAspectWidth:@4,
                                                    kAspectHeight:@3
                                                    }];
            
            [q setGradientStops:MTLClearColorMake(1, 1, 1, 1) b:MTLClearColorMake(1, 1, 1, 1) isHorizontal:NO];
            
            q.z = i * _cardOffsetZ;
            
            [_cards insertObject:q atIndex:0];
        }
    }
    
    return self;
}

@end
