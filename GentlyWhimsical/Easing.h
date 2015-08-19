//
//  Easing.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-04.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef __gently_whimsical__Easing__
#define __gently_whimsical__Easing__

typedef float (*EasingFunction)(float, float, float, float);

float linear(float t, float b, float c,float d) {
    
    // t=0, b=0, c=100, d=2
    
    // t(0)  = 100 * 0   / 2 + 0 = 0
    // t(0.5 = 100 * 0.5 / 2 + 0 = 25
    // t(1   = 100 * 1   / 2 + 0 = 50
    // t(1.5 = 100 * 1.5 / 2 + 0 = 75
    // t(2)  = 100 * 2   / 2 + 0 = 100
    
    return c*t/d + b;
}

float backEaseIn(float t, float b, float c, float d) {
    static float s = 1.70158f;
    float postFix = t/=d;
    return c*(postFix)*t*((s+1)*t - s) + b;
}

float backEaseOut(float t, float b, float c, float d) {
    static float s = 1.70158f;
    t=t/d-1;
    return c*(t*t*((s+1)*t + s) + 1) + b;
}

float backEaseInOut(float t, float b, float c, float d) {
    float s = 1.70158f;
    t/=d/2;
    if (t < 1) {
        s*=(1.525f);
        return c/2*(t*t*(((s)+1)*t - s)) + b;
    }
    float postFix = t-=2;
    s*=(1.525f);
    return c/2*((postFix)*t*(((s)+1)*t + s) + 2) + b;
}

float bounceEaseOut(float t,float b , float c, float d) {
    if ((t/=d) < (1/2.75f)) {
        return c*(7.5625f*t*t) + b;
    } else if (t < (2/2.75f)) {
        float postFix = t-=(1.5f/2.75f);
        return c*(7.5625f*(postFix)*t + .75f) + b;
    } else if (t < (2.5/2.75)) {
        float postFix = t-=(2.25f/2.75f);
        return c*(7.5625f*(postFix)*t + .9375f) + b;
    } else {
        float postFix = t-=(2.625f/2.75f);
        return c*(7.5625f*(postFix)*t + .984375f) + b;
    }
}

float bounceEaseIn(float t,float b , float c, float d) {
    return c - bounceEaseOut (d-t, 0, c, d) + b;
}
float bounceEaseInOut(float t,float b , float c, float d) {
    if (t < d/2) return bounceEaseIn (t*2, 0, c, d) * .5f + b;
    else return bounceEaseOut (t*2-d, 0, c, d) * .5f + c*.5f + b;
}

float circEaseIn (float t, float b, float c, float d)
{
    t/=d;
    return -c * (sqrt(1 - t*t) - 1) + b;
}
float circEaseOut (float t, float b, float c, float d)
{
    t=t/d-1;
    return c * sqrt(1 - t*t) + b;
}
float circEaseInOut (float t, float b, float c, float d)
{
    float t2 = t/(d/2);
    if (t2 < 1) return -c/2 * (sqrt(1 - t*t) - 1) + b;
    
    t -= 2;
    return c/2 * (sqrt(1 - (t)*t) + 1) + b;
}

float cubicEaseIn(float t,float b , float c, float d) {
    t/=d;
    return c*(t)*t*t + b;
}
float cubicEaseOut(float t,float b , float c, float d) {
    t=t/d-1;
    return c*((t)*t*t + 1) + b;
}

float cubicEaseInOut(float t,float b , float c, float d) {
    if ((t/=d/2) < 1) return c/2*t*t*t + b;
    t-=2;
    return c/2*((t)*t*t + 2) + b;
}

float elasticEaseIn(float t,float b , float c, float d) {
    if (t==0) return b;  if ((t/=d)==1) return b+c;
    float p=d*.3f;
    float a=c;
    float s=p/4;
    float postFix =a*pow(2,10*(t-=1));
    return -(postFix * sin((t*d-s)*(2*M_PI)/p )) + b;
}

float elasticEaseOut(float t,float b , float c, float d) {
    if (t==0) return b;  if ((t/=d)==1) return b+c;
    float p=d*.3f;
    float a=c;
    float s=p/4;
    return (a*pow(2,-10*t) * sin( (t*d-s)*(2*M_PI)/p ) + c + b);
}

float elasticEaseInOut(float t,float b , float c, float d) {
    if (t==0) return b;  if ((t/=d/2)==2) return b+c;
    float p=d*(.3f*1.5f);
    float a=c;
    float s=p/4;
    
    if (t < 1) {
        float postFix =a*pow(2,10*(t-=1));
        return -.5f*(postFix* sin( (t*d-s)*(2*M_PI)/p )) + b;
    }
    float postFix =  a*pow(2,-10*(t-=1));
    return postFix * sin( (t*d-s)*(2*M_PI)/p )*.5f + c + b;
}

float expoEaseIn(float t,float b , float c, float d) {
    return (t==0) ? b : c * pow(2, 10 * (t/d - 1)) + b;
}
float expoEaseOut(float t,float b , float c, float d) {
    return (t==d) ? b+c : c * (-pow(2, -10 * t/d) + 1) + b;
}

float expoEaseInOut(float t,float b , float c, float d) {
    if (t==0) return b;
    if (t==d) return b+c;
    if ((t/=d/2) < 1) return c/2 * pow(2, 10 * (t - 1)) + b;
    return c/2 * (-pow(2, -10 * --t) + 2) + b;
}

float quadEaseIn(float t,float b , float c, float d) {
    t/=d;
    return c*(t)*t + b;
}
float quadEaseOut(float t,float b , float c, float d) {
    t/=d;
    return -c *(t)*(t-2) + b;
}

float quadEaseInOut(float t,float b , float c, float d) {
    if ((t/=d/2) < 1) return ((c/2)*(t*t)) + b;
    float v = t-1;
    return -c/2 * (((t-2)*(v)) - 1) + b;
}

float quartEaseIn(float t,float b , float c, float d) {
    t/=d;
    return c*(t)*t*t*t + b;
}
float quartEaseOut(float t,float b , float c, float d) {
    t=t/d-1;
    return -c * ((t)*t*t*t - 1) + b;
}

float quartEaseInOut(float t,float b , float c, float d) {
    if ((t/=d/2) < 1) return c/2*t*t*t*t + b;
    t-=2;
    return -c/2 * ((t)*t*t*t - 2) + b;
}

float quintEaseIn(float t,float b , float c, float d) {
    t/=d;
    return c*(t)*t*t*t*t + b;
}
float quintEaseOut(float t,float b , float c, float d) {
    t=t/d-1;
    return c*((t)*t*t*t*t + 1) + b;
}

float quintEaseInOut(float t,float b , float c, float d) {
    if ((t/=d/2) < 1) return c/2*t*t*t*t*t + b;
    t-=2;
    return c/2*((t)*t*t*t*t + 2) + b;
}

float sineEaseIn(float t,float b , float c, float d) {
    return -c * cos(t/d * (M_PI/2)) + c + b;
}
float sineEaseOut(float t,float b , float c, float d) {
    return c * sin(t/d * (M_PI/2)) + b;
}

float sineEaseInOut(float t,float b , float c, float d) {
    return -c/2 * (cos(M_PI*t/d) - 1) + b;
}

EasingFunction easingFunctions[] = {
    &linear,
    &backEaseIn,
    &backEaseOut,
    &backEaseInOut,
    &bounceEaseIn,
    &bounceEaseOut,
    &bounceEaseInOut,
    &circEaseIn,
    &circEaseOut,
    &circEaseInOut,
    &cubicEaseIn,
    &cubicEaseOut,
    &cubicEaseInOut,
    &elasticEaseIn,
    &elasticEaseOut,
    &elasticEaseInOut,
    &expoEaseIn,
    &expoEaseOut,
    &expoEaseInOut,
    &quartEaseIn,
    &quartEaseOut,
    &quartEaseInOut,
    &quintEaseIn,
    &quintEaseOut,
    &quintEaseInOut,
    &sineEaseIn,
    &sineEaseOut,
    &sineEaseInOut
};

#endif /* defined(__gently_whimsical__Easing__) */
