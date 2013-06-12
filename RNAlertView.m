//
//  RNAlertView.m
//  RNAlertView
//
//  Created by Ryan Nystrom on 6/11/13.
//  Copyright (c) 2013 Ryan Nystrom. All rights reserved.
//

#import "RNAlertView.h"
#import <QuartzCore/QuartzCore.h>

CGFloat const kRNAlertViewDefaultDuration = 0.25f;
CGFloat const kRNAlertViewDefaultBlur = 0.3f;
CGFloat const kRNAlertViewDefaultWidth = 280;

@implementation UIView (Screenshot)

- (UIImage*)screenshot {
    UIGraphicsBeginImageContext(self.bounds.size);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // helps w/ our colors when blurring
    // feel free to adjust jpeg quality (lower = higher perf)
    NSData *imageData = UIImageJPEGRepresentation(image, 0.75);
    image = [UIImage imageWithData:imageData];
    
    return image;
}

@end

#import <Accelerate/Accelerate.h>

@implementation UIImage (Blur)

-(UIImage *)boxblurImageWithBlur:(CGFloat)blur {
    if (blur < 0.f || blur > 1.f) {
        blur = 0.5f;
    }
    int boxSize = (int)(blur * 40);
    boxSize = boxSize - (boxSize % 2) + 1;
    
    CGImageRef img = self.CGImage;
    
    vImage_Buffer inBuffer, outBuffer;
    
    vImage_Error error;
    
    void *pixelBuffer;
    
    
    //create vImage_Buffer with data from CGImageRef
    CGDataProviderRef inProvider = CGImageGetDataProvider(img);
    CFDataRef inBitmapData = CGDataProviderCopyData(inProvider);
    
    
    inBuffer.width = CGImageGetWidth(img);
    inBuffer.height = CGImageGetHeight(img);
    inBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    inBuffer.data = (void*)CFDataGetBytePtr(inBitmapData);
    
    //create vImage_Buffer for output
    pixelBuffer = malloc(CGImageGetBytesPerRow(img) * CGImageGetHeight(img));
    
    if(pixelBuffer == NULL)
        NSLog(@"No pixelbuffer");
    
    outBuffer.data = pixelBuffer;
    outBuffer.width = CGImageGetWidth(img);
    outBuffer.height = CGImageGetHeight(img);
    outBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    // Create a third buffer for intermediate processing
    void *pixelBuffer2 = malloc(CGImageGetBytesPerRow(img) * CGImageGetHeight(img));
    vImage_Buffer outBuffer2;
    outBuffer2.data = pixelBuffer2;
    outBuffer2.width = CGImageGetWidth(img);
    outBuffer2.height = CGImageGetHeight(img);
    outBuffer2.rowBytes = CGImageGetBytesPerRow(img);
    
    //perform convolution
    error = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer2, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    error = vImageBoxConvolve_ARGB8888(&outBuffer2, &inBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    error = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    
    if (error) {
        NSLog(@"error from convolution %ld", error);
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(outBuffer.data,
                                             outBuffer.width,
                                             outBuffer.height,
                                             8,
                                             outBuffer.rowBytes,
                                             colorSpace,
                                             kCGImageAlphaNoneSkipLast);
    CGImageRef imageRef = CGBitmapContextCreateImage (ctx);
    UIImage *returnImage = [UIImage imageWithCGImage:imageRef];
    
    //clean up
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    
    free(pixelBuffer);
    CFRelease(inBitmapData);
    
    CGImageRelease(imageRef);
    
    return returnImage;
}

@end

@interface RNAlertOptionView : UIView
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) NSInteger optionIndex;
@end

@implementation RNAlertOptionView

- (id)init {
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        
        self.imageView = [[UIImageView alloc] init];
        self.imageView.backgroundColor = [UIColor clearColor];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.imageView];
        
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:self.titleLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect frame = self.bounds;
    CGFloat inset = floorf(CGRectGetHeight(frame) * 0.1f);
    
    BOOL hasImage = self.imageView.image != nil;
    BOOL hasText = [self.titleLabel.text length] > 0;
    
    if (hasImage) {
        CGFloat y = 0;
        CGFloat height = CGRectGetHeight(frame);
        if (hasText) {
            y = inset / 2;
            height = floorf(CGRectGetHeight(frame) * 2/3.f);
        }
        self.imageView.frame = CGRectInset(CGRectMake(0, y, CGRectGetWidth(frame), height), inset, inset);
    }
    else {
        self.imageView.frame = CGRectZero;
    }
    
    if (hasText) {
        CGFloat y = 0;
        CGFloat height = CGRectGetHeight(frame);
        CGFloat left = 0;
        if (hasImage) {
            y = floorf(CGRectGetHeight(frame) * 2/3.f) - inset / 2;
            height = floorf(CGRectGetHeight(frame) / 3.f);
        }
        if (self.titleLabel.textAlignment == NSTextAlignmentLeft) {
            left = 10;
        }
        self.titleLabel.frame = CGRectMake(left, y, CGRectGetWidth(frame), height);
    }
    else {
        self.titleLabel.frame = CGRectZero;
    }
}

@end

@interface RNAlertView()

@property (nonatomic, strong, readwrite) NSArray *options;
@property (nonatomic, strong, readwrite) NSArray *images;
@property (nonatomic, strong) NSMutableArray *optionViews;
@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, strong) UITapGestureRecognizer *superviewTapGesture;
@property (nonatomic, assign) BOOL viewHasLoaded;

@end

static RNAlertView *displayedAlertView;

@implementation RNAlertView

static void RNAlertViewInit(RNAlertView *self) {
    self.itemSize = CGSizeMake(100, 100);
    self.blurLevel = kRNAlertViewDefaultBlur;
    self.animationDuration = kRNAlertViewDefaultDuration;
    self.itemTextColor = [UIColor whiteColor];
    self.itemFont = [UIFont boldSystemFontOfSize:14];
    self.highlightColor = [UIColor colorWithRed:.02 green:.549 blue:.961 alpha:1];
    self.alertViewStyle = RNAlertViewStyleGrid;
    self.itemTextAlignment = NSTextAlignmentCenter;
    
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    self.view.opaque = NO;
    self.view.clipsToBounds = YES;
    self.view.layer.cornerRadius = 8;
    self.view.autoresizingMask = UIViewAutoresizingNone;
    
    CGFloat m34 = 1 / 300.f;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = m34;
    self.view.layer.transform = transform;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeOrientationNotification:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
}

#pragma mark - View Controller

- (id)init {
    if (self = [super init]) {
        RNAlertViewInit(self);
    }
    return self;
}

- (id)initWithOptions:(NSArray *)options delegate:(id <RNAlertViewDelegate>)delegate {
    if (self = [self init]) {
        self.alertViewStyle = RNAlertViewStyleList;
        self.options = options;
        self.delegate = delegate;
        [self initializeOptionsAndImages];
    }
    return self;
}

- (id)initWithImages:(NSArray *)images delegate:(id <RNAlertViewDelegate>)delegate {
    if (self = [self init]) {
        self.images = images;
        self.delegate = delegate;
        [self initializeOptionsAndImages];
    }
    return self;
}

- (id)initWithOptions:(NSArray *)options images:(NSArray *)images delegate:(id <RNAlertViewDelegate>)delegate {
    if (options || images) NSAssert([options count] == [images count], @"Alert view must have the same number of option strings and images.");
    if (self = [self init]) {
        self.options = options;
        self.images = images;
        self.delegate = delegate;
        [self initializeOptionsAndImages];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.viewHasLoaded = YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown | UIInterfaceOrientationLandscapeLeft | UIInterfaceOrientationLandscapeRight);
}

#pragma mark - Actions

- (void)initializeOptionsAndImages {
    self.optionViews = [NSMutableArray array];
    
    NSInteger itemCount = self.options ? [self.options count] : [self.images count];
    for (NSInteger i = 0; i < itemCount; i++) {
        UIImage *image = self.images[i];
        NSString *option = self.options[i];
        
        RNAlertOptionView *optionView = [[RNAlertOptionView alloc] init];
        optionView.imageView.image = image;
        optionView.titleLabel.text = option;
        optionView.optionIndex = i;
        
        [self.view addSubview:optionView];
        [self.optionViews addObject:optionView];
    }
}

#pragma mark - Layout

- (void)layoutBlurAndOptions {
    CGRect bounds = self.view.superview.bounds;
    self.blurView.frame = bounds;
    
    [self styleOptionViews];
    if (self.alertViewStyle == RNAlertViewStyleGrid) {
        [self layoutAsGrid];
    }
    else if (self.alertViewStyle == RNAlertViewStyleList) {
        [self layoutAsList];
    }
}

- (void)styleOptionViews {
    [self.optionViews enumerateObjectsUsingBlock:^(RNAlertOptionView *optionView, NSUInteger idx, BOOL *stop) {
        optionView.titleLabel.textColor = self.itemTextColor;
        optionView.titleLabel.textAlignment = self.itemTextAlignment;
        optionView.titleLabel.font = self.itemFont;
    }];
}

- (void)layoutAsList {
    CGRect bounds = self.view.superview.bounds;
    NSInteger itemCount = self.options ? [self.options count] : [self.images count];
    CGFloat height = self.itemSize.height * itemCount;
    CGFloat width = self.itemSize.width;
    CGRect frame = CGRectMake(CGRectGetMidX(bounds) - width / 2, CGRectGetMidY(bounds) - height / 2, width, height);
    self.view.frame = frame;
    
    [self.optionViews enumerateObjectsUsingBlock:^(RNAlertOptionView *optionView, NSUInteger idx, BOOL *stop) {
        optionView.frame = CGRectMake(0, idx * self.itemSize.height, self.itemSize.width, self.itemSize.height);
    }];
}

- (void)layoutAsGrid {
    CGRect bounds = self.view.superview.bounds;
    NSInteger itemCount = self.options ? [self.options count] : [self.images count];
    NSInteger rowCount = floorf(sqrtf(itemCount));
    
    CGFloat height = self.itemSize.height * rowCount;
    CGFloat width = self.itemSize.width * ceilf(itemCount / (CGFloat)rowCount);
    CGRect frame = CGRectMake(CGRectGetMidX(bounds) - width / 2, CGRectGetMidY(bounds) - height / 2, width, height);
    self.view.frame = frame;
    
    CGFloat itemHeight = floorf(height / (CGFloat)rowCount);
    
    for (NSInteger i = 0; i < rowCount; i++) {
        NSInteger rowLength = ceilf(itemCount / (CGFloat)rowCount);
        NSInteger offset = 0;
        if ((i + 1) * rowLength > itemCount) {
            rowLength = itemCount - i * rowLength;
            offset++;
        }
        NSArray *subOptions = [self.optionViews subarrayWithRange:NSMakeRange(i * rowLength + offset, rowLength)];
        CGFloat itemWidth = floorf(width / (CGFloat)rowLength);
        [subOptions enumerateObjectsUsingBlock:^(RNAlertOptionView *optionView, NSUInteger idx, BOOL *stop) {
            optionView.frame = CGRectMake(idx * itemWidth, i * itemHeight, itemWidth, itemHeight);
        }];
    }
}

- (void)createScreenshotAndLayout {
    self.view.alpha = 0;
    self.blurView.alpha = 0;
    UIImage *screenshot = [[UIApplication sharedApplication].keyWindow.rootViewController.view screenshot];
    self.view.alpha = 1;
    self.blurView.alpha = 1;
    UIImage *blur = [screenshot boxblurImageWithBlur:self.blurLevel];
    self.blurView.layer.contents = (id) blur.CGImage;
    
    [self layoutBlurAndOptions];
}

#pragma mark - Notifications

- (void)didChangeOrientationNotification:(NSNotification *)notification {
    if (self.viewHasLoaded && self.view.superview) {
        [self performSelector:@selector(createScreenshotAndLayout) withObject:nil afterDelay:0.01];
    }
}

#pragma mark - Gestures

- (void)superviewTapGestureHandler:(UITapGestureRecognizer *)recognizer {
    if (recognizer == self.superviewTapGesture) {
        RNAlertOptionView *selectedView = nil;
        CGPoint point = [recognizer locationInView:self.view.superview];
        if (CGRectContainsPoint(self.view.frame, point)) {
            CGPoint localPoint = [recognizer locationInView:self.view];
            for (RNAlertOptionView *optionView in self.optionViews) {
                if (CGRectContainsPoint(optionView.frame, localPoint)) {
                    selectedView = optionView;
                    break;
                }
            }
        }
        if (selectedView) {
            if ([self.delegate respondsToSelector:@selector(alertView:willDismissWithButtonIndex:option:)]) {
                [self.delegate alertView:self willDismissWithButtonIndex:selectedView.optionIndex option:self.options[selectedView.optionIndex]];
            }
            [UIView animateWithDuration:0.1f
                                  delay:0
                                options:UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 selectedView.backgroundColor = self.highlightColor;
                             }
                             completion:^(BOOL finished){
                                 [self dismiss];
                             }];
        }
        else {
            [self dismiss];
        }
    }
}

#pragma mark - Animations

- (void)show {
    [self performSelector:@selector(showAfterScreenshotDelay) withObject:nil afterDelay:0.05];
}

- (void)showAfterScreenshotDelay {
    displayedAlertView = self;
    
    UIWindow * window = [UIApplication sharedApplication].keyWindow;
    if (!window)
        window = [[UIApplication sharedApplication].windows objectAtIndex:0];
    
    UIImage *screenshot = [[UIApplication sharedApplication].keyWindow.rootViewController.view screenshot];
    UIImage *blur = [screenshot boxblurImageWithBlur:self.blurLevel];
        
    self.blurView = [[UIView alloc] initWithFrame:[UIApplication sharedApplication].keyWindow.rootViewController.view.bounds];
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.blurView.layer.contents = (id) blur.CGImage;
    
    if(self.addsToWindow) {
        [window addSubview:self.blurView];
    }
    else {
        UIView *view = [window subviews][0];
        [view addSubview:self.blurView];
    }
    
    [self.blurView addSubview:self.view];
    
    self.superviewTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(superviewTapGestureHandler:)];
    [self.view.superview addGestureRecognizer:self.superviewTapGesture];
    
    [self layoutBlurAndOptions];
    
    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @(0);
    opacityAnimation.toValue = @(1);
    opacityAnimation.duration = self.animationDuration * 0.5f;
    [self.blurView.layer addAnimation:opacityAnimation forKey:@"opacityAnimation"];
    
    CAKeyframeAnimation *alertScaleAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    
    CATransform3D startingScale = CATransform3DScale(self.view.layer.transform, 0, 0, 0);
    CATransform3D overshootScale = CATransform3DScale(self.view.layer.transform, 1.1, 1.1, 1.0);
    CATransform3D undershootScale = CATransform3DScale(self.view.layer.transform, 0.95, 0.95, 1.0);
    CATransform3D endingScale = self.view.layer.transform;
    
    alertScaleAnimation.values = @[
                                   [NSValue valueWithCATransform3D:startingScale],
                                   [NSValue valueWithCATransform3D:overshootScale],
                                   [NSValue valueWithCATransform3D:undershootScale],
                                   [NSValue valueWithCATransform3D:endingScale]
                                   ];
    
    alertScaleAnimation.keyTimes = @[
                                     @(0.0f),
                                     @(0.5f),
                                     @(0.9f),
                                     @(1.0f)
                                     ];
    
    alertScaleAnimation.timingFunctions = @[
                                            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
                                            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
                                            ];
    alertScaleAnimation.fillMode = kCAFillModeForwards;
    alertScaleAnimation.removedOnCompletion = NO;
    
    CAAnimationGroup *alertAnimation = [CAAnimationGroup animation];
    alertAnimation.animations = @[
                                  alertScaleAnimation,
                                  opacityAnimation
                                  ];
    alertAnimation.duration = self.animationDuration;
    
    [self.view.layer addAnimation:alertAnimation forKey:@"alertAnimation"];
}

- (void)dismiss {
    CATransform3D transform = CATransform3DScale(self.view.layer.transform, 0, 0, 0);
    [UIView animateWithDuration:self.animationDuration
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.blurView.alpha = 0;
                         self.view.alpha = 0;
                         self.view.layer.transform = transform;
                     }
                     completion:^(BOOL finished){
                         [self.view.superview removeGestureRecognizer:self.superviewTapGesture];
                         [self.view removeFromSuperview];
                         [self.blurView removeFromSuperview];
                         displayedAlertView = nil;
                     }];
}

@end