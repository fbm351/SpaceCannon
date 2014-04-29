//
//  FMMyScene.m
//  Space Cannon
//
//  Created by Fredrick Myers on 4/15/14.
//  Copyright (c) 2014 Fredrick Myers. All rights reserved.
//

#import "FMMyScene.h"
#import "FMMenu.h"
#import "FMBall.h"
#import <AVFoundation/AVFoundation.h>

@implementation FMMyScene
{
    AVAudioPlayer *_audioPlayer;
    SKNode *_mainLayer;
    SKSpriteNode *_cannon;
    SKSpriteNode *_ammoDisplay;
    SKSpriteNode *_pauseButton;
    SKSpriteNode *_resumeButton;
    SKLabelNode *_scoreLabel;
    SKLabelNode *_pointLabel;
    BOOL _didShoot;
    int _killCount;
    SKAction *_bounceSound;
    SKAction *_deepExplosionSound;
    SKAction *_explosionSound;
    SKAction *_laserSound;
    SKAction *_zapSound;
    SKAction *_shieldUpSound;
    BOOL _gameOver;
    FMMenu *_menu;
    NSUserDefaults *_userDefualts;
    NSMutableArray *_shieldPool;
}

static const CGFloat SHOOT_SPEED = 1000.0f;
static const CGFloat kFMHaloLowAngle = 200.0 * M_PI / 180;
static const CGFloat kFMHaloHighAngle = 340.0 * M_PI / 180;
static const CGFloat kFMHaloSpeed = 100.0f;

static const uint32_t kFMHaloCatagory = 0x1 << 0;
static const uint32_t kFMBallCatagory = 0x1 << 1;
static const uint32_t kFMEdgeCatagory = 0x1 << 2;
static const uint32_t kFMShieldCatagory = 0x1 << 3;
static const uint32_t kFMLifeBarCatagory = 0x1 << 4;
static const uint32_t kFMShieldUpCatagory = 0x1 << 5;
static const uint32_t kFMShotUpCatagory = 0x1 << 6;


static NSString * const kFMKeyTopScore = @"TopScore";


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
        leftEdge.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointZero toPoint:CGPointMake(0.0, self.size.height + 100)];
        leftEdge.position = CGPointZero;
        leftEdge.physicsBody.categoryBitMask = kFMEdgeCatagory;
        [self addChild:leftEdge];
        
        SKNode *rightEdge = [[SKNode alloc] init];
        rightEdge.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointZero toPoint:CGPointMake(0.0, self.size.height + 100)];
        rightEdge.position = CGPointMake(self.size.width, 0.0);
        rightEdge.physicsBody.categoryBitMask = kFMEdgeCatagory;
        [self addChild:rightEdge];
        
        //Add Main Layer
        _mainLayer = [[SKNode alloc] init];
        [self addChild:_mainLayer];
        
        //Add Cannon
        _cannon = [SKSpriteNode spriteNodeWithImageNamed:@"cannon"];
        _cannon.position = CGPointMake(self.size.width * 0.5, 0.0);
        [self addChild:_cannon];
        
        // Create cannon rotation actions
        SKAction *rotateCannon = [SKAction sequence:@[[SKAction rotateByAngle:M_PI duration:2],
                                                      [SKAction rotateByAngle:-M_PI duration:2]]];
        [_cannon runAction:[SKAction repeatActionForever:rotateCannon]];
        
        //Create Spawn Halo Actions
        SKAction *spawnHalo = [SKAction sequence:@[[SKAction waitForDuration:2 withRange:1], [SKAction performSelector:@selector(spawnHalo) onTarget:self]]];
        
        [self runAction:[SKAction repeatActionForever:spawnHalo] withKey:@"SpawnHalo"];
        
        //Create Spawn Shield PowerUp Action
        
        SKAction *spawnShieldPowerUp = [SKAction sequence:@[[SKAction waitForDuration:15 withRange:4], [SKAction performSelector:@selector(spawnShieldPowerUp) onTarget:self]]];
        [self runAction:[SKAction repeatActionForever:spawnShieldPowerUp]];
        
        //Setup Ammo
        _ammoDisplay = [SKSpriteNode spriteNodeWithImageNamed:@"ammo5"];
        _ammoDisplay.anchorPoint = CGPointMake(0.5, 0.0);
        _ammoDisplay.position = _cannon.position;
        [self addChild:_ammoDisplay];
        
        SKAction *incrementAmmo = [SKAction sequence:@[[SKAction waitForDuration:1],
                                                       [SKAction runBlock:^{
            if (!self.multiMode)
            {
                self.ammo ++;
            }
            
        }]]];
        [self runAction:[SKAction repeatActionForever:incrementAmmo]];
        
        // Setup Shield Pool
        _shieldPool = [[NSMutableArray alloc] init];
        //Setup Shields
        for (int i = 0; i < 6; i++)
        {
            SKSpriteNode *shield = [SKSpriteNode spriteNodeWithImageNamed:@"block"];
            shield.name = @"shield";
            shield.position = CGPointMake(35 + (50 * i), 90);
            shield.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(42, 9)];
            shield.physicsBody.categoryBitMask = kFMShieldCatagory;
            shield.physicsBody.collisionBitMask = 0;
            [_shieldPool addObject:shield];
        }
        
        //Setup Pause Button
        
        _pauseButton = [SKSpriteNode spriteNodeWithImageNamed:@"PauseButton"];
        _pauseButton.position = CGPointMake(self.size.width - 30, 20);
        [self addChild:_pauseButton];
        
        //Setup Resume Button
        _resumeButton = [SKSpriteNode spriteNodeWithImageNamed:@"ResumeButton"];
        _resumeButton.position = CGPointMake(self.size.width * 0.5, self.size.height * 0.5);
        [self addChild:_resumeButton];
        
        
        //Setup Score Display
        _scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"DIN Alternate"];
        _scoreLabel.position = CGPointMake(15, 10);
        _scoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
        _scoreLabel.fontSize = 15;
        [self addChild:_scoreLabel];
        
        //Setup Multiplier Display
        
        _pointLabel = [SKLabelNode labelNodeWithFontNamed:@"DIN Alternate"];
        _pointLabel.position = CGPointMake(15, 30);
        _pointLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
        _pointLabel.fontSize = 15;
        [self addChild:_pointLabel];
        
        //Setup Sounds
        
        _bounceSound = [SKAction playSoundFileNamed:@"Bounce.caf" waitForCompletion:NO];
        _deepExplosionSound = [SKAction playSoundFileNamed:@"DeepExplosion.caf" waitForCompletion:NO];
        _explosionSound = [SKAction playSoundFileNamed:@"Explosion.caf" waitForCompletion:NO];
        _laserSound = [SKAction playSoundFileNamed:@"Laser.caf" waitForCompletion:NO];
        _zapSound = [SKAction playSoundFileNamed:@"Zap.caf" waitForCompletion:NO];
        _shieldUpSound = [SKAction playSoundFileNamed:@"ShieldUp.caf" waitForCompletion:NO];
        
        //Setup Menu
        _menu = [[FMMenu alloc] init];
        _menu.position = CGPointMake(self.size.width * 0.5, self.size.height - 220);
        [self addChild:_menu];
        
        _gameOver = YES;
        self.ammo = 5;
        self.score = 0;
        self.pointValue = 1;
        _scoreLabel.hidden = YES;
        _pointLabel.hidden = YES;
        _pauseButton.hidden = YES;
        _resumeButton.hidden = YES;
        
        
        //Load Top Score
        
        _userDefualts = [NSUserDefaults standardUserDefaults];
        _menu.topScore = [_userDefualts integerForKey:kFMKeyTopScore];
        
        
        //Load Music
        
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"ObservingTheStar" withExtension:@"caf"];
        NSError *error = nil;
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        
        if (!_audioPlayer)
        {
            NSLog(@"Error with audio player %@", error);
        }
        else
        {
            _audioPlayer.numberOfLoops = -1;
            _audioPlayer.volume = 0.8;
            [_audioPlayer play];
        }
        
    }
    return self;
}

- (void)newGame
{
    [_mainLayer removeAllChildren];
    
    while (_shieldPool.count > 0)
    {
        [_mainLayer addChild:[_shieldPool objectAtIndex:0]];
        [_shieldPool removeObjectAtIndex:0];
    }
    
    //Setup Life Bar
    
    SKSpriteNode *lifeBar = [SKSpriteNode spriteNodeWithImageNamed:@"lifebar"];
    lifeBar.position = CGPointMake(self.size.width * 0.5, 70);
    lifeBar.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointMake(-lifeBar.size.width * 0.5, 0.0) toPoint:CGPointMake(lifeBar.size.width * 0.5, 0)];
    lifeBar.physicsBody.categoryBitMask = kFMLifeBarCatagory;
    [_mainLayer addChild:lifeBar];
    
    //Setup Initial Values
    
    [self actionForKey:@"SpawnHalo"].speed = 1.0;
    self.ammo = 5;
    self.score = 0;
    self.pointValue = 1;
    self.multiMode = NO;
    _killCount = 0;
    _scoreLabel.hidden = NO;
    _pointLabel.hidden = NO;
    _pauseButton.hidden = NO;
    _gameOver = NO;
    [_menu hide];
}

- (void)setAmmo:(int)ammo
{
    if (ammo >= 0 && ammo <= 5) {
        _ammo = ammo;
        _ammoDisplay.texture = [SKTexture textureWithImageNamed:[NSString stringWithFormat:@"ammo%d", ammo]];
    }
}

- (void)setScore:(int)score
{
    _score = score;
    _scoreLabel.text = [NSString stringWithFormat:@"Score: %d", score];
}

- (void)setPointValue:(int)pointValue
{
    _pointValue = pointValue;
    _pointLabel.text = [NSString stringWithFormat:@"Muliplier: x%d", pointValue];
}

- (void)setMultiMode:(BOOL)multiMode
{
    _multiMode = multiMode;
    if (multiMode)
    {
        _cannon.texture = [SKTexture textureWithImageNamed:@"GreenCannon"];
    }
    else
    {
        _cannon.texture = [SKTexture textureWithImageNamed:@"cannon"];
    }
}

- (void)setGamePaused:(BOOL)gamePaused
{
    if (!_gameOver)
    {
        _gamePaused = gamePaused;
        _pauseButton.hidden = gamePaused;
        _resumeButton.hidden = !gamePaused;
        self.paused = gamePaused;
    }
    
}

- (void)shoot
{
    
    FMBall *ball = [FMBall spriteNodeWithImageNamed:@"ball"];
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
    ball.physicsBody.contactTestBitMask = kFMEdgeCatagory | kFMShieldUpCatagory | kFMShotUpCatagory;
    [self runAction:_laserSound];
    
    // Create Trail
    NSString *ballTrailPath = [[NSBundle mainBundle] pathForResource:@"BallTrail" ofType:@"sks"];
    SKEmitterNode *ballTrail = [NSKeyedUnarchiver unarchiveObjectWithFile:ballTrailPath];
    ballTrail.targetNode = _mainLayer;
    [_mainLayer addChild:ballTrail];
    ball.trail = ballTrail;
    [ball updateTrail];
    
    
}

- (void)spawnHalo
{
    SKAction *spawnHaloAction = [self actionForKey:@"SpawnHalo"];
    if (spawnHaloAction.speed < 1.5)
    {
        spawnHaloAction.speed += 0.01;
    }
    
    SKSpriteNode *halo = [SKSpriteNode spriteNodeWithImageNamed:@"halo"];
    halo.name = @"halo";
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
    halo.physicsBody.contactTestBitMask = kFMBallCatagory | kFMShieldCatagory | kFMEdgeCatagory | kFMLifeBarCatagory;
    
    int haloCount = 0;
    for (SKNode *node in _mainLayer.children) {
        if ([node.name isEqualToString:@"halo"])
        {
            haloCount ++;
        }
    }
    
    if (haloCount == 4)
    {
        // Bomb spawn
        halo.texture = [SKTexture textureWithImageNamed:@"HaloBomb"];
        halo.userData = [[NSMutableDictionary alloc] init];
        [halo.userData setValue:@YES forKey:@"Bomb"];
    }
    else if (!_gameOver  && arc4random_uniform(6) == 0)
    {
        // Random point multiplier
        halo.texture = [SKTexture textureWithImageNamed:@"HaloX"];
        halo.userData = [[NSMutableDictionary alloc] init];
        [halo.userData setValue:@YES forKey:@"Multiplier"];
    }
    
    
    
    
    [_mainLayer addChild:halo];
}

- (void)spawnShieldPowerUp
{
    if (_shieldPool.count> 0)
    {
        SKSpriteNode *shieldUp = [SKSpriteNode spriteNodeWithImageNamed:@"block"];
        shieldUp.name = @"shieldUp";
        shieldUp.position = CGPointMake(self.size.width + shieldUp.size.width, randomInRange(150, self.size.height - 100));
        shieldUp.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(42, 9)];
        shieldUp.physicsBody.categoryBitMask = kFMShieldUpCatagory;
        shieldUp.physicsBody.collisionBitMask = 0;
        shieldUp.physicsBody.velocity = CGVectorMake(-100, randomInRange(-40, 40));
        shieldUp.physicsBody.angularVelocity = M_PI;
        shieldUp.physicsBody.linearDamping = 0;
        shieldUp.physicsBody.angularDamping = 0;
        
        [_mainLayer addChild:shieldUp];
    }
}

- (void)spawnMutliShotPowerUp
{
    SKSpriteNode *shotUp = [SKSpriteNode spriteNodeWithImageNamed:@"MultiShotPowerUp"];
    shotUp.name = @"shotUp";
    shotUp.position = CGPointMake(- shotUp.size.width, randomInRange(150, self.size.height - 100));
    shotUp.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:12.0];
    shotUp.physicsBody.categoryBitMask = kFMShotUpCatagory;
    shotUp.physicsBody.collisionBitMask = 0;
    shotUp.physicsBody.velocity = CGVectorMake(100, randomInRange(-40, 40));
    shotUp.physicsBody.angularVelocity = M_PI;
    shotUp.physicsBody.linearDamping = 0;
    shotUp.physicsBody.angularDamping = 0;
    
    [_mainLayer addChild:shotUp];
    
}

- (void)didBeginContact:(SKPhysicsContact *)contact
{
    SKPhysicsBody *firstBody;
    SKPhysicsBody *secondBody;
    
    // Makes sure that firstBody is always the halo.
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask)
    {
        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
    }
    else
    {
        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
    }
    
    if (firstBody.categoryBitMask == kFMHaloCatagory  && secondBody.categoryBitMask == kFMBallCatagory)
    {
        // Collision between halo and ball
        self.score += self.pointValue;
        [self addExplosion:firstBody.node.position andName:@"HaloExplosion"];
        [self runAction:_explosionSound];
        
        if ([[firstBody.node.userData valueForKey:@"Multiplier"] boolValue])
        {
            self.pointValue++;
        }
        else if ([[firstBody.node.userData valueForKey:@"Bomb"] boolValue])
        {
            firstBody.node.name = nil;
            [_mainLayer enumerateChildNodesWithName:@"halo" usingBlock:^(SKNode *node, BOOL *stop) {
                [self addExplosion:node.position andName:@"HaloExplosion"];
                [node removeFromParent];
            }];
        }
        
        _killCount ++;
        if (_killCount % 10 == 0)
        {
            [self spawnMutliShotPowerUp];
        }
        
        firstBody.categoryBitMask = 0;
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
        
        
    }
    
    if (firstBody.categoryBitMask == kFMHaloCatagory  && secondBody.categoryBitMask == kFMShieldCatagory)
    {
        // Collision between halo and shield

        [self addExplosion:firstBody.node.position andName:@"HaloExplosion"];
        [self runAction:_explosionSound];
        
        if ([[firstBody.node.userData valueForKey:@"Bomb"] boolValue])
        {
            // Remove all shields.
            [_mainLayer enumerateChildNodesWithName:@"shield" usingBlock:^(SKNode *node, BOOL *stop) {
                [node removeFromParent];
            }];
        }
        
        firstBody.categoryBitMask = 0;
        [firstBody.node removeFromParent];
        [_shieldPool addObject:secondBody.node];
        [secondBody.node removeFromParent];
    }
    
    if (firstBody.categoryBitMask == kFMHaloCatagory  && secondBody.categoryBitMask == kFMLifeBarCatagory)
    {
        // Collision between halo and lifebar
        [self runAction:_deepExplosionSound];
        [self addExplosion:secondBody.node.position andName:@"LifeBarExplosion"];
        [secondBody.node removeFromParent];
        [self gameOver];
    }
    
    if (firstBody.categoryBitMask == kFMHaloCatagory  && secondBody.categoryBitMask == kFMEdgeCatagory)
    {
        // Collision between halo and wall
        if (!_gameOver) {
            [self runAction:_zapSound];
        }
    }
    
    if (firstBody.categoryBitMask == kFMBallCatagory  && secondBody.categoryBitMask == kFMEdgeCatagory)
    {
        // Collision between ball and wall
        
        if ([firstBody.node isKindOfClass:[FMBall class]])
        {
            ((FMBall *)firstBody.node).bounces++;
            if (((FMBall *)firstBody.node).bounces > 3)
            {
                [firstBody.node removeFromParent];
                self.pointValue = 1;
            }
        }
        
        [self runAction:_bounceSound];
        //[self addExplosion:contact.contactPoint andName:@"BallExplosion"];
    }
    
    if (firstBody.categoryBitMask == kFMBallCatagory && secondBody.categoryBitMask == kFMShieldUpCatagory)
    {
        if (_shieldPool.count > 0)
        {
            int randomIndex = arc4random_uniform((int)_shieldPool.count);
            [_mainLayer addChild:[_shieldPool objectAtIndex:randomIndex]];
            [_shieldPool removeObjectAtIndex:randomIndex];
            [self runAction:_shieldUpSound];
        }
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
    }
    
    if (firstBody.categoryBitMask == kFMBallCatagory && secondBody.categoryBitMask == kFMShotUpCatagory)
    {
        self.multiMode = YES;
        [self runAction:_shieldUpSound];
        self.ammo = 5;
        
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
    }
}

- (void)gameOver
{
    [_mainLayer enumerateChildNodesWithName:@"halo" usingBlock:^(SKNode *node, BOOL *stop) {
        [self addExplosion:node.position andName:@"HaloExplosion"];
        [node removeFromParent];
    }];
    
    [_mainLayer enumerateChildNodesWithName:@"ball" usingBlock:^(SKNode *node, BOOL *stop) {
        [node removeFromParent];
    }];
    
    [_mainLayer enumerateChildNodesWithName:@"shieldUp" usingBlock:^(SKNode *node, BOOL *stop) {
        [node removeFromParent];
    }];
    
    [_mainLayer enumerateChildNodesWithName:@"shotUp" usingBlock:^(SKNode *node, BOOL *stop) {
        [node removeFromParent];
    }];
     
    
    [_mainLayer enumerateChildNodesWithName:@"shield" usingBlock:^(SKNode *node, BOOL *stop) {
        [_shieldPool addObject:node];
        [node removeFromParent];
    }];

    _menu.score = self.score;
    if (self.score >_menu.topScore) {
        _menu.topScore = self.score;
        [_userDefualts setInteger:self.score forKey:kFMKeyTopScore];
        [_userDefualts synchronize];
    }
    _scoreLabel.hidden = YES;
    _pointLabel.hidden = YES;
    _pauseButton.hidden = YES;
    _gameOver = YES;
    [self runAction:[SKAction waitForDuration:1.0] completion:^{
        [_menu show];
    }];
}

- (void)addExplosion:(CGPoint)position andName:(NSString *)name
{
    NSString *explosionPath = [[NSBundle mainBundle] pathForResource:name ofType:@"sks"];
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
        if (!_gameOver && !self.gamePaused)
        {
            if (![_pauseButton containsPoint:[touch locationInNode:_pauseButton.parent]])
            {
                _didShoot = YES;
            }
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
        if (_gameOver && _menu.touchable) {
            SKNode *n = [_menu nodeAtPoint:[touch locationInNode:_menu]];
            if ([n.name isEqualToString:@"play"]) {
                [self newGame];
                
            }
        }
        else if (!_gameOver)
        {
            if (self.gamePaused)
            {
                if ([_resumeButton containsPoint:[touch locationInNode:_resumeButton.parent]])
                {
                    self.gamePaused = NO;
                }
            }
            else
            {
                if ([_pauseButton containsPoint:[touch locationInNode:_pauseButton.parent]])
                {
                    self.gamePaused = YES;
                }
            }
        }
    }
}

-(void)didSimulatePhysics
{
    if (_didShoot)
    {
        if (self.ammo > 0)
        {
            self.ammo --;
            [self shoot];
            if (self.multiMode)
            {
                for (int i = 1; i < 5; i++)
                {
                    [self performSelector:@selector(shoot) withObject:nil afterDelay:0.1 * i];
                }
                if (self.ammo == 0)
                {
                    self.multiMode = NO;
                    self.ammo = 5;
                }
            }
        }
        _didShoot = NO;
    }
    
    [_mainLayer enumerateChildNodesWithName:@"ball" usingBlock:^(SKNode *node, BOOL *stop) {
        if ([node respondsToSelector:@selector(updateTrail)]) {
            [node performSelector:@selector(updateTrail) withObject:nil afterDelay:0.0];
        }
        
        if (!CGRectContainsPoint(self.frame, node.position)) {
            [node removeFromParent];
            self.pointValue = 1;
        }
    }];
    
    [_mainLayer enumerateChildNodesWithName:@"shieldUp" usingBlock:^(SKNode *node, BOOL *stop) {
        if (node.position.x + node.frame.size.width < 0)
        {
            [node removeFromParent];
        }
    }];
    
    [_mainLayer enumerateChildNodesWithName:@"shotUp" usingBlock:^(SKNode *node, BOOL *stop) {
        if (node.position.x - node.frame.size.width > self.size.width)
        {
            [node removeFromParent];
        }
    }];
    
    [_mainLayer enumerateChildNodesWithName:@"halo" usingBlock:^(SKNode *node, BOOL *stop) {
        if (node.position.y + node.frame.size.height < 0)
        {
            [node removeFromParent];
        }
    }];
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
}

@end
