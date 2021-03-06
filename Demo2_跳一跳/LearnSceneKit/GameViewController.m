//
//  GameViewController.m
//  LearnSceneKit
//
//  Created by loyinglin on 2018/12/31.
//  Copyright © 2018 ByteDance. All rights reserved.
//

#import "GameViewController.h"
#import "UIView+LYLayout.h"

#define kMaxPressDuration 2.5
#define kMaxPlatformRadius 5
#define kMinPlatformRadius 3
#define kGravityValue 50

typedef NS_ENUM(NSUInteger, LYRoleTypeMask) {
    LYRoleTypeMaskNone = 0,
    LYRoleTypeMaskFloor = 1 << 0,
    LYRoleTypeMaskPlatform = 1 << 1,
    LYRoleTypeMaskJumper = 1 << 2,
    LYRoleTypeMaskOldPlatform = 1 << 3,
};

typedef NS_ENUM(NSUInteger, LYGameStatus) {
    LYGameStatusReady,
    LYGameStatusRunning,
};

@interface GameViewController () <SCNPhysicsContactDelegate>
@property (strong, nonatomic) IBOutlet UIView *gameContainerView;
@property (nonatomic, strong) IBOutlet UILabel *gameStatusLabel;
@property (strong, nonatomic) IBOutlet UILabel *gameScoreLabel;

@property(nonatomic, strong) SCNView *sceneView;
@property(nonatomic, strong) SCNScene *scene;
@property(nonatomic, strong) SCNNode *floor;
@property(nonatomic, strong) SCNNode *lastPlatform, *platform, *nextPlatform;
@property(nonatomic, strong) SCNNode *jumper;
@property(nonatomic, strong) SCNNode *camera,*light;
@property(nonatomic) NSInteger score;
@end

@implementation GameViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initGame];
}


#pragma mark - init

#pragma mark - gameLogic

#pragma mark - node

-(void)addFirstPlatform {
    self.platform = [SCNNode node];
    self.platform.geometry = [SCNCylinder cylinderWithRadius:5 height:2]; //[SCNBox boxWithWidth:5 height:5 length:5 chamferRadius:2];
    self.platform.geometry.firstMaterial.diffuse.contents = UIColor.whiteColor;
    
    SCNPhysicsBody *body = [SCNPhysicsBody staticBody];
    body.restitution = 0;
    body.friction = 1;
    body.damping = 0;
    body.categoryBitMask = LYRoleTypeMaskPlatform;
    body.collisionBitMask = LYRoleTypeMaskJumper;
    self.platform.physicsBody = body;
    
    self.platform.position = SCNVector3Make(0, 1, 0);
    [self.scene.rootNode addChildNode:self.platform];
}
#pragma mark - ui action

- (IBAction)startGame {
    [self.view sendSubviewToBack:self.gameContainerView];
    self.score = 0;
    [self.sceneView removeFromSuperview];
    self.sceneView = nil;
    self.scene = nil;
    self.floor = nil;
    self.lastPlatform = nil;
    self.platform = nil;
    self.nextPlatform = nil;
    self.jumper = nil;
    self.camera = nil;
    self.light = nil;
    
    [self initGame];
}


-(void)accumulateStrength:(UILongPressGestureRecognizer *)recognizer {
    static NSDate *startDate;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        startDate = [NSDate date];
        [self updateStrengthStatus];
    }else if(recognizer.state == UIGestureRecognizerStateEnded) {
        NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:startDate];
        [self jumpWithPower:MIN(timeInterval, kMaxPressDuration)];
    }
}

#pragma mark - delegate

#pragma mark - private



/**
 力量显示
 
 @discussion 这里简单地用颜色表示，力量越大，小人越红
 */
-(void)updateStrengthStatus {
    SCNAction *action = [SCNAction customActionWithDuration:kMaxPressDuration actionBlock:^(SCNNode * node, CGFloat elapsedTime) {
        CGFloat percentage = elapsedTime/kMaxPressDuration;
        self.jumper.geometry.firstMaterial.diffuse.contents = [UIColor colorWithRed:1 green:1-percentage blue:1-percentage alpha:1];
    }];
    [self.jumper runAction:action];
}

#pragma mark 发力
/**
 根据力量值给小人一个力
 
 @param power 按的时间0~kMaxPressDuration秒
 @discussion 根据按的时间长短，对小人施加一个力，力由一个向上的力，和平面方向上的力组成，平面方向的力由小人的位置和目标台子的位置计算得出
 */
-(void)jumpWithPower:(double)power {
    power *= 30;
    SCNVector3 platformPosition = self.nextPlatform.presentationNode.position;
    SCNVector3 jumperPosition = self.jumper.presentationNode.position;
    double subtractionX = platformPosition.x-jumperPosition.x;
    double subtractionZ = platformPosition.z-jumperPosition.z;
    double proportion = fabs(subtractionX/subtractionZ);
    double x = sqrt(1 / (pow(proportion, 2) + 1)) * proportion;
    double z = sqrt(1 / (pow(proportion, 2) + 1));
    x*=subtractionX<0?-1:1;
    z*=subtractionZ<0?-1:1;
    SCNVector3 force = SCNVector3Make(x*power, 20, z*power);
    [self.jumper.physicsBody applyForce:force impulse:YES];
}

#pragma mark 跳跃会触发的事件
-(void)jumpCompleted {
    self.score++;
    self.lastPlatform = self.platform;
    self.platform = self.nextPlatform;
    [self moveCameraToCurrentPlatform];
    [self createNextPlatform];
    
    self.jumper.geometry.firstMaterial.diffuse.contents = UIColor.whiteColor;
    [self.jumper removeAllActions];
}

/**
 调整镜头以观察小人目前所在台子的位置
 */
-(void)moveCameraToCurrentPlatform {
    SCNVector3 position = self.platform.presentationNode.position;
    
    position.x += 20;
    position.y += 30;
    position.z += 20;
    SCNAction *move = [SCNAction moveTo:position duration:0.5];
    [self.camera runAction:move];
}

/**
 创建下一个台子
 */
-(void)createNextPlatform {
    self.nextPlatform = ({
        SCNNode *node = [SCNNode node];
        node.geometry = ({
            //随机大小
            int radius = (arc4random() % kMinPlatformRadius) + (kMaxPlatformRadius-kMinPlatformRadius);
            SCNCylinder *cylinder = [SCNCylinder cylinderWithRadius:radius height:2];
            //随机颜色
            cylinder.firstMaterial.diffuse.contents = ({
                CGFloat r = ((arc4random() % 255)+0.0)/255;
                CGFloat g = ((arc4random() % 255)+0.0)/255;
                CGFloat b = ((arc4random() % 255)+0.0)/255;
                UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1];
                color;
            });
            cylinder;
        });
        node.physicsBody = ({
            SCNPhysicsBody *body = [SCNPhysicsBody dynamicBody];
            //            body.mass = 100;
            body.restitution = 1;
            body.friction = 1;
            body.damping = 0;
            body.allowsResting = YES;
            body.categoryBitMask = LYRoleTypeMaskPlatform;
            body.collisionBitMask = LYRoleTypeMaskJumper|LYRoleTypeMaskFloor|LYRoleTypeMaskOldPlatform|LYRoleTypeMaskPlatform;
            body.contactTestBitMask = LYRoleTypeMaskJumper;
            body;
        });
        //随机位置
        node.position = ({
            SCNVector3 position = self.platform.presentationNode.position;
            int xDistance = (arc4random() % (kMaxPlatformRadius*3-1))+1;
            position.z -= ({
                double lastRadius = ((SCNCylinder *)self.platform.geometry).radius;
                double radius = ((SCNCylinder *)node.geometry).radius;
                double maxDistance = sqrt(pow(kMaxPlatformRadius*3, 2)-pow(xDistance, 2));
                double minDistance = (xDistance>lastRadius+radius)?xDistance:sqrt(pow(lastRadius+radius, 2)-pow(xDistance, 2));
                double zDistance = (((double) rand() / RAND_MAX) * (maxDistance-minDistance)) + minDistance;
                zDistance;
            });
            position.x -= xDistance;
            position.y += 5;
            position;
        });
        [self.scene.rootNode addChildNode:node];
        node;
    });
}

#pragma mark 游戏结束
-(void)gameDidOver {
    [self.view bringSubviewToFront:self.gameContainerView];
    [self.gameScoreLabel setText:[NSString stringWithFormat:@"游戏结束，当前分数:%d",(int)self.score]];
    [self.gameContainerView removeAllSubviews];
}

#pragma mark SCNPhysicsContactDelegate
/**
 碰撞事件监听
 
 @discussion 如果是小人与地板碰撞，游戏结束。取消地板对小人的监听。
 如果是小人与台子碰撞，则跳跃完成，进行状态刷新
 */
- (void)physicsWorld:(SCNPhysicsWorld *)world didBeginContact:(SCNPhysicsContact *)contact{
    SCNPhysicsBody *bodyA = contact.nodeA.physicsBody;
    SCNPhysicsBody *bodyB = contact.nodeB.physicsBody;
    if (bodyA == self.jumper.physicsBody) {
        NSLog(@"bodyA:jumper");
    }
    else if (bodyA == self.floor.physicsBody) {
        NSLog(@"bodyA:floor");
    }
    else if (bodyA == self.platform.physicsBody) {
        NSLog(@"bodyA:platform");
    }
    if (bodyA.categoryBitMask==LYRoleTypeMaskJumper) {
        if (bodyB.categoryBitMask==LYRoleTypeMaskFloor) {
            bodyB.contactTestBitMask = LYRoleTypeMaskNone;
            [self performSelectorOnMainThread:@selector(gameDidOver) withObject:nil waitUntilDone:NO];
        }else if (bodyB.categoryBitMask==LYRoleTypeMaskPlatform) {
            //这里有个小bug，我在第一次收到碰撞后进行如下配置，按理说不应该收到碰撞回调了。可实际上还是会来。于是我直接将跳过的台子的categoryBitMask改为LYRoleTypeMaskOldPlatform，保证每个台子只会收到一次。上面的掉落又没有这个bug。
            //bodyB.contactTestBitMask = LYRoleTypeMaskNone;
            bodyB.categoryBitMask = LYRoleTypeMaskOldPlatform;
            [self jumpCompleted];
        }
    }
}

#pragma mark - gameLogic

- (void)initGame {
    [self.gameContainerView addSubview:self.sceneView]; // 添加整个世界显示view
    [self.scene.rootNode addChildNode:self.floor]; // 添加地板
    [self.scene.rootNode addChildNode:self.jumper]; // 添加小方块
    
    [self addFirstPlatform];
    [self moveCameraToCurrentPlatform];
    [self createNextPlatform];
}

#pragma mark - getter

-(SCNScene *)scene {
    if (!_scene) {
        _scene = [SCNScene new];
        _scene.physicsWorld.contactDelegate = self;
        _scene.physicsWorld.gravity = SCNVector3Make(0, -kGravityValue, 0); // 重力
    }
    return _scene;
}

-(SCNView *)sceneView {
    if (!_sceneView) {
        _sceneView = [[SCNView alloc] initWithFrame:self.gameContainerView.bounds];
        _sceneView.scene = self.scene;
        _sceneView.allowsCameraControl = NO;
        _sceneView.autoenablesDefaultLighting = NO;
        UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(accumulateStrength:)];
        longPressGesture.minimumPressDuration = 0;
        _sceneView.gestureRecognizers = @[longPressGesture];
    }
    return _sceneView;
}

-(SCNNode *)floor {
    if (!_floor) {
        _floor = [SCNNode node];
        
        // floor
        SCNFloor *floor = [SCNFloor floor];
        floor.firstMaterial.diffuse.contents = UIColor.whiteColor;
        _floor.geometry = floor;
        
        // body
        SCNPhysicsBody *body = [SCNPhysicsBody staticBody];
        body.restitution = 0;
        body.friction = 1;
        body.damping = 0.3;
        body.categoryBitMask = LYRoleTypeMaskFloor;
        body.collisionBitMask = LYRoleTypeMaskJumper|LYRoleTypeMaskPlatform|LYRoleTypeMaskOldPlatform;
        body.contactTestBitMask = LYRoleTypeMaskJumper;
        
        _floor.physicsBody = body;
    }
    return _floor;
}

/**
 初始化小人
 
 @discussion 小人是动态物体，自由落体到第一个台子中心，会受重力影响，会与台子和地板碰撞
 */
-(SCNNode *)jumper {
    if (!_jumper) {
        _jumper = [SCNNode node];
        
        SCNBox *box = [SCNBox boxWithWidth:1 height:1 length:1 chamferRadius:0];
        box.firstMaterial.diffuse.contents = UIColor.whiteColor;
        _jumper.geometry = box;
        
        SCNPhysicsBody *body = [SCNPhysicsBody dynamicBody];
        body.restitution = 0;
        body.friction = 1;
        body.rollingFriction = 1;
        body.damping = 0.3;
        body.allowsResting = YES;
        body.categoryBitMask = LYRoleTypeMaskJumper;
        body.collisionBitMask = LYRoleTypeMaskPlatform|LYRoleTypeMaskFloor|LYRoleTypeMaskOldPlatform;
        _jumper.physicsBody = body;
        
        _jumper.position = SCNVector3Make(0, 12.5, 0);
    }
    return _jumper;
}

/**
 初始化相机
 
 @discussion 光源随相机移动，所以将光源设置成相机的子节点
 */
-(SCNNode *)camera {
    if (!_camera) {
        _camera = ({
            SCNNode *node = [SCNNode node];
            node.camera = [SCNCamera camera];
            node.camera.zFar = 200.f;
            node.camera.zNear = .1f;
            [self.scene.rootNode addChildNode:node];
            node.eulerAngles = SCNVector3Make(-0.7, 0.6, 0);
            node;
        });
        [_camera addChildNode:self.light];
    }
    return _camera;
}

-(SCNNode *)light {
    if (!_light) {
        _light = ({
            SCNNode *node = [SCNNode node];
            node.light = ({
                SCNLight *light = [SCNLight light];
                light.color = UIColor.whiteColor;
                light.type = SCNLightTypeOmni;
                light;
            });
            node;
        });
    }
    return _light;
}

@end
