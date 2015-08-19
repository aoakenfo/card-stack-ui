//
//  Simulation.m
//  Physics2d
//
//  Created by Edward Oakenfold on 2015-04-23.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Box2D/Box2D.h>
#import "Simulation.h"

const float kPixelToMeter = 32.0f;

@interface Simulation() {
    b2World* _world;

}

@end

@implementation Simulation

#pragma mark -

- (instancetype)init {
    self = [super init];
    
    if (self) {
        b2Vec2 gravity = b2Vec2(0.0f, -9.8f);
        _world = new b2World(gravity);
        
        // TEMP: box test
        [self createBoxAtX:100.0f y:100.0f width:20.0f height:20.0f];
    }
    
    return self;
}

- (void)dealloc {
    delete _world;
}

#pragma mark -

- (b2Body*)createBoxAtX:(float)x y:(float)y width:(float)width height:(float)height {
    
    float32 horizontalExtent = (width/2)/kPixelToMeter;
    float32 verticalExtent = (height/2)/kPixelToMeter;
    
    // 1. body def
    b2BodyDef bodyDef;
    bodyDef.type = b2_dynamicBody;
    bodyDef.position.Set(x/kPixelToMeter,
                         y/kPixelToMeter);
    
    // 2. create body
    b2Body* body = _world->CreateBody(&bodyDef);
    
    // 3. create shape
    b2PolygonShape shape;
    shape.SetAsBox(horizontalExtent, verticalExtent);
    
    // 4. fixture def
    b2FixtureDef fixtureDef;
    fixtureDef.shape = &shape;
    fixtureDef.density = 1.0f; // no rotation if not set
    fixtureDef.friction = 0.3f;
    fixtureDef.restitution = 0.7f;
    
    // 5. create fixture
    body->CreateFixture(&fixtureDef);
    
    return body;
}

#pragma mark -

- (void)frameUpdate:(CFTimeInterval)deltaTime {
    
    static const float velocityIterations = 6.0f;
    static const float positionIterations = 2.0f;
    
    _world->Step(deltaTime,
                 velocityIterations,
                 positionIterations);
    
    for(b2Body* body = _world->GetBodyList(); body != NULL; body = body->GetNext())
    {
        // TEMP: box test
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
        float32 x = body->GetPosition().x * kPixelToMeter;
        float32 y = body->GetPosition().y * kPixelToMeter;
#pragma clang diagnostic pop
        //NSLog(@"(x,y) = (%f,%f)", x, y);
    }
}

@end
