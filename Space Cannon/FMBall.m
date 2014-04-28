//
//  FMBall.m
//  Space Cannon
//
//  Created by Fredrick Myers on 4/19/14.
//  Copyright (c) 2014 Fredrick Myers. All rights reserved.
//

#import "FMBall.h"

@implementation FMBall

- (void)updateTrail
{
    if (self.trail)
    {
        self.trail.position = self.position;
    }
}

- (void)removeFromParent
{
    if (self.trail)
    {
        self.trail.particleBirthRate = 0;
        
        SKAction *removeTrail = [SKAction sequence:@[[SKAction waitForDuration:self.trail.particleLifetime + self.trail.particleLifetimeRange], [SKAction removeFromParent]]];
        [self runAction:removeTrail];
    }
    [super removeFromParent];
}

@end
