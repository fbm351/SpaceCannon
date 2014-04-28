//
//  FMMyScene.h
//  Space Cannon
//

//  Copyright (c) 2014 Fredrick Myers. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface FMMyScene : SKScene <SKPhysicsContactDelegate>

@property (nonatomic) int ammo;
@property (nonatomic) int score;
@property (nonatomic) int pointValue;

@end
