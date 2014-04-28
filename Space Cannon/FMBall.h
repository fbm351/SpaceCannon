//
//  FMBall.h
//  Space Cannon
//
//  Created by Fredrick Myers on 4/19/14.
//  Copyright (c) 2014 Fredrick Myers. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface FMBall : SKSpriteNode

@property (nonatomic) SKEmitterNode *trail;
@property (nonatomic) int bounces;

- (void)updateTrail;

@end
