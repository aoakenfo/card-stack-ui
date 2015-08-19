//
//  Misc.h
//  GentlyWhimsical
//
//  Created by Edward Oakenfold on 2015-06-16.
//  Copyright © 2015 conceptual inertia. All rights reserved.
//

#ifndef Misc_h
#define Misc_h

#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))
#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)

float randomFloat(float min, float max)
{
    double mix = (double)random() / RAND_MAX;
    return min + (max - min) * mix;
}

MTL_INLINE MTLClearColor MTLClearColorMake(uint hexValue, double alpha)
{
    double red   = ((hexValue & 0xFF0000) >> 16) / 255.0f;
    double green = ((hexValue & 0x00FF00) >>  8) / 255.0f;
    double blue  =  (hexValue & 0x0000FF)        / 255.0f;
    
    MTLClearColor result;
    result.red = red;
    result.green = green;
    result.blue = blue;
    result.alpha = alpha;
    return result;
}

#endif /* Misc_h */
