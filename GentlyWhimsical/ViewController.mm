//
//  ViewController.mm
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-04-22.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import "Renderer.h"
#import "ViewController.h"

// ----------------
// view controller
//  - manages display link for render/sim loop
//  - responds to app notifications, pausing display link which pauses render/sim loop
//  - forwards orientation changes
//  - fullscreen landscape mode
// ----------------
// renderer:
//  - creates metal layer
//  - maintains dispatch semaphore
//  - loads initial scene
//  - provides render hooks for scene
// ----------------
// scenes:
//  - dictates what is drawn and how
//  - gallery scene:
//      - renders custom 3d ui
//      - handles input, determines if ui element clicked
//      - handles logic for maintaining a gallery of images (new, delete, duplicate)
//          - as well as streaming to/from disk?
//      - updates animations
//      - transitions to canvas scene
//  - canvas scene:
//      - instances physics system
//      - exposes ui for brush settings (configures render and physics systems directly in response)
//      - transitions back to gallery scene
// ----------------
//  simulation:
//  - handles physics
//  - is given touch input and delta time to perform simulation
//  - returns list of bodies to render but doesn't dictate their appearance
//  - list of bodies is abstract, no b2d specific data types

@interface ViewController () {
    CADisplayLink* _displayLink;
    UIDeviceOrientation _lastOrientation;
    
    Renderer* _renderer;
}

@end

// great refreshers:
//  http://learnxinyminutes.com/

@implementation ViewController

#pragma mark -

// called when loaded from storyboard
// should never be loaded any other way, and therefore the only init supported
- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self) {
        NSLog(@"initWithCoder");
        
        // add display link
        _displayLink = [[UIScreen mainScreen] displayLinkWithTarget:self selector:@selector(frameUpdate)];
        _displayLink.paused = YES; // set to NO in applicationDidBecomeActive
        // NSRunLoopCommonModes is actually a combination of UITrackingRunLoopMode and NSDefaultRunLoopMode
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        
        _lastOrientation = [UIDevice currentDevice].orientation;
        
        _renderer = [[Renderer alloc]init];
    }
    
    return self;
}

// simulate on device from lldb:
//  expr (void)[[UIApplication sharedApplication] performSelector:@selector(_performMemoryWarning)];
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    NSLog(@"didReceiveMemoryWarning");
    
    // Memory warnings are a signal to you that you should dispose of any resources which aren't absolutely critical. Most of your controllers will be hanging onto data caches, intermediary data, or other bits and pieces, often to save recalculation. When they receive memory warnings, they should begin flushing anything they don't immediately need in order to operate.
    
    // How you determine what is "critical" depends entirely on your application's design. An OpenGL game, for example, may determine that textures currently on-screen are valuable and flush textures which aren't visible, or level data which is outside the bounds of the current play area. An application with extensive session logs (like an IRC client) may flush them out of memory and onto disk.
    
    // As you observed, the warning is sent to each controller in your hierarchy, so each piece needs to determine individually what data constitutes "critical for operation" and what constitutes "expendable". If you've optimized them all and are still getting out of memory warnings, it's unfortunately time to revisit your core application design, because you're exceeding the limits of the hardware.
}

#pragma mark -

- (BOOL)prefersStatusBarHidden {
    return YES;
}

# pragma mark -

// view call order:
//  1. viewDidLoad
//  2. viewWillAppear
//  3. viewWillLayoutSubviews
//  4. viewDidLayoutSubviews
//  5. viewDidAppear
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSLog(@"viewDidLoad");
    
    CGFloat nativeScale = [UIScreen mainScreen].nativeScale;
    self.view.contentScaleFactor = nativeScale;
    [_renderer updateLayerSize:self.view.frame
                        bounds:self.view.bounds
            contentScaleFactor:self.view.contentScaleFactor];
    [self.view.layer addSublayer:_renderer.metalLayer];
    
    // TODO: double check settings used in metal sample code
    self.view.opaque = YES;
    self.view.backgroundColor = nil;
    
    [self.view addSubview:_renderer.rootView];
}

// will *not* be called after appWillEnterForeground
- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"viewWillAppear");
}

- (void)viewWillLayoutSubviews {
    NSLog(@"viewWillLayoutSubviews");
}

- (void)viewDidLayoutSubviews {
    NSLog(@"viewDidLayoutSubviews");
}

- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"viewDidAppear");
}

#pragma mark -

// will *not* be called before appWillEnterBackground
- (void)viewWillDisappear:(BOOL)animated {
    NSLog(@"viewWillDisappear");
    _displayLink.paused = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    NSLog(@"viewDidDisappear");
}

#pragma mark -

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:
    
    // removes the object from all runloop modes (releasing the receiver if it has been implicitly retained) and
    // releases the 'target' object
    [_displayLink invalidate];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    NSLog(@"applicationWillEnterForeground");
    [self startDeviceOrientationNotifications];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    NSLog(@"applicationDidEnterBackground");
    _displayLink.paused = YES;
    [self stopDeviceOrientationNotifications];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    NSLog(@"applicationDidBecomeActive");
    [self startDeviceOrientationNotifications];
    _displayLink.paused = NO;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    NSLog(@"applicationWillResignActive");
    _displayLink.paused = YES;
    [self stopDeviceOrientationNotifications];
}

#pragma mark -

- (void)startDeviceOrientationNotifications {
    NSLog(@"startDeviceOrientationNotifications");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
}

- (void)stopDeviceOrientationNotifications {
    NSLog(@"stopDeviceOrientationNotifications");
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)orientationChanged {
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    if (orientation != _lastOrientation) {
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                NSLog(@"UIDeviceOrientationPortrait");
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                NSLog(@"UIDeviceOrientationPortraitUpsideDown");
                break;
            case UIDeviceOrientationLandscapeLeft:
                NSLog(@"UIDeviceOrientationLandscapeLeft");
                break;
            case UIDeviceOrientationLandscapeRight:
                NSLog(@"UIDeviceOrientationLandscapeRight");
                break;
                
            default: return; // nop
        }
        _lastOrientation = orientation;
    }
}

#pragma mark -

- (void)frameUpdate {
    @autoreleasepool {
        // 60 Hz = 16.6 ms to process each frame
        // make sure CPU/GPU in FPS Debug Navigator is always balanced, under 16.6 ms
        [_renderer frameUpdate:_displayLink.duration];
    }
}

@end
