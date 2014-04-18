//
//  FMMyScene.m
//  Space Cannon
//
//  Created by Fredrick Myers on 4/15/14.
//  Copyright (c) 2014 Fredrick Myers. All rights reserved.
//

#import "FMMyScene.h"

@implementation FMMyScene
{
    SKNode *_mainLayer;
    SKSpriteNode *_cannon;
    SKSpriteNode *_ammoDisplay;
    BOOL _didShoot;
    
}

static const CGFloat SHOOT_SPEED = 1000.0f;
static const CGFloat kFMHaloLowAngle = 200.0 * M_PI / 180;
static const CGFloat kFMHaloHighAngle = 340.0 * M_PI / 180;
static const CGFloat kFMHaloSpeed = 100.0f;

static const uint32_t kFMHaloCatagory = 0x1 << 0;
static const uint32_t kFMBallCatagory = 0x1 << 1;
static const uint32_t kFMEdgeCatagory = 0x1 << 2;

static inline CGVector radiansToVector(CGFloat radians)
{
    CGVector vector;
    
    vector.dx = cosf(radians);
    vector.dy = sinf(radians);
    
    return vector;
}

static inline CGFloat randomInRange(CGFloat low, CGFloat high)
{
    CGFloat value = arc4random_uniform(UINT32_MAX) / (CGFloat)UINT32_MAX;
    return value * (high - low) + low;
}

-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
        
        self.physicsWorld.gravity = CGVectorMake(0.0, 0.0);
        self.physicsWorld.contactDelegate = self;
        
        //Add Background
        SKSpriteNode *background = [SKSpriteNode spriteNodeWithImageNamed:@"starfield"];
        background.position = CGPointZero;
        background.anchorPoint = CGPointZero;
        background.blendMode = SKBlendModeReplace;
        [self addChild:background];
        
        //Add Edges
        
        SKNode *leftEdge = [[SKNode alloc] init];
        leftEdge.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointZero toPoint:CGPointMake(0.0, self.size.height)];
        leftEdge.position = CGPointZero;
        leftEdge.physicsBody.categoryBitMask = kFMEdgeCatagory;
        [self addChild:leftEdge];
        
        SKNode *rightEdge = [[SKNode alloc] init];
        rightEdge.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointZero toPoint:CGPointMake(0.0, self.size.height)];
        rightEdge.position = CGPointMake(self.size.width, 0.0);
        rightEdge.physicsBody.categoryBitMask = kFMEdgeCatagory;
        [self addChild:rightEdge];
        
        //Add Main Layer
        _mainLayer = [[SKNode alloc] init];
        [self addChild:_mainLayer];
        
        //Add Cannon
        _cannon = [SKSpriteNode spriteNodeWithImageNamed:@"cannon"];
        _cannon.position = CGPointMake(self.size.width * 0.5, 0.0);
        [_mainLayer addChild:_cannon];
        
        // Create cannon rotation actions
        SKAction *rotateCannon = [SKAction sequence:@[[SKAction rotateByAngle:M_PI duration:2],
                                                      [SKAction rotateByAngle:-M_PI duration:2]]];
        [_cannon runAction:[SKAction repeatActionForever:rotateCannon]];
        
        //Create Spawn Halo Actions
        SKAction *spawnHalo = [SKAction sequence:@[[SKAction waitForDuration:2 withRange:1], [SKAction performSelector:@selector(spawnHalo) onTarget:self]]];
        
        [self runAction:[SKAction repeatActionForever:spawnHalo]];
        
        //Setup Ammo
        _ammoDisplay = [SKSpriteNode spriteNodeWithImageNamed:@"ammo5"];
        _ammoDisplay.anchorPoint = CGPointMake(0.5, 0.0);
        _ammoDisplay.position = _cannon.position;
        [_mainLayer addChild:_ammoDisplay];
        self.ammo = 5;
        
        SKAction *incrementAmmo = [SKAction sequence:@[[SKAction waitForDuration:1],
                                                       [SKAction runBlock:^{
            self.ammo ++;
        }]]];
        [self runAction:[SKAction repeatActionForever:incrementAmmo]];
    }
    return self;
}

- (void)setAmmo:(int)ammo
{
    if (ammo >= 0 && ammo <= 5) {
        _ammo = ammo;
        _ammoDisplay.texture = [SKTexture textureWithImageNamed:[NSString stringWithFormat:@"ammo%d", ammo]];
    }
}

- (void)shoot
{
    if (self.ammo > 0) {
        self.ammo--;
        SKSpriteNode *ball = [SKSpriteNode spriteNodeWithImageNamed:@"ball"];
        ball.name = @"ball";
        CGVector rotationVector = radiansToVector(_cannon.zRotation);
        ball.position = CGPointMake(_cannon.position.x + (_cannon.size.width * 0.5 * rotationVector.dx),
                                    _cannon.position.y + (_cannon.size.width * 0.5 * rotationVector.dy));
        [_mainLayer addChild:ball];
        
        ball.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:6.0];
        ball.physicsBody.velocity = CGVectorMake(rotationVector.dx * SHOOT_SPEED, rotationVector.dy * SHOOT_SPEED);
        ball.physicsBody.restitution = 1.0;
        ball.physicsBody.linearDamping = 0.0;
        ball.physicsBody.friction = 0.0;
        ball.physicsBody.categoryBitMask = kFMBallCatagory;
        ball.physicsBody.collisionBitMask = kFMEdgeCatagory;
    }
    
}

- (void)spawnHalo
{
    SKSpriteNode *halo = [SKSpriteNode spriteNodeWithImageNamed:@"halo"];
    halo.position = CGPointMake(randomInRange(halo.size.width * 0.5, self.size.width - (halo.size.width * 0.5)),
                                self.size.height + (halo.size.height * 0.5));
    halo.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:16.0];
    CGVector direction = radiansToVector(randomInRange(kFMHaloLowAngle, kFMHaloHighAngle));
    halo.physicsBody.velocity = CGVectorMake(direction.dx * kFMHaloSpeed, direction.dy * kFMHaloSpeed);
    halo.physicsBody.restitution = 1.0;
    halo.physicsBody.linearDamping = 0.0;
    halo.physicsBody.friction = 0.0;
    halo.physicsBody.categoryBitMask = kFMHaloCatagory;
    halo.physicsBody.collisionBitMask = kFMEdgeCatagory;
    halo.physicsBody.contactTestBitMask = kFMBallCatagory;
    [_mainLayer addChild:halo];
}

- (void)didBeginContact:(SKPhysicsContact *)contact
{
    SKPhysicsBody *firstBody;
    SKPhysicsBody *secondBody;
    
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask) {
        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
    }
    else
    {
        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
    }
    
    if (firstBody.categoryBitMask == kFMHaloCatagory  && secondBody.categoryBitMask == kFMBallCatagory) {
        [self addExplosion:firstBody.node.position];
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
        
    }
}

- (void)addExplosion:(CGPoint)position
{
    NSString *explosionPath = [[NSBundle mainBundle] pathForResource:@"HaloExplosion" ofType:@"sks"];
    SKEmitterNode *explosion = [NSKeyedUnarchiver unarchiveObjectWithFile:explosionPath];
    explosion.position = position;
    [_mainLayer addChild:explosion];
    
    SKAction *removeExplosion = [SKAction sequence:@[[SKAction waitForDuration:1.5], [SKAction removeFromParent]]];
    [explosion runAction:removeExplosion];
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    
    for (UITouch *touch in touches)
    {
        _didShoot = YES;
        
    }
}

-(void)didSimulatePhysics
{
    if (_didShoot)
    {
        [self shoot];
        _didShoot = NO;
    }
    
    [_mainLayer enumerateChildNodesWithName:@"ball" usingBlock:^(SKNode *node, BOOL *stop) {
        if (!CGRectContainsPoint(self.frame, node.position)) {
            [node removeFromParent];
        }
    }];
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
}

@end
