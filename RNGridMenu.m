//
//  RNGridMenu.m
//  RNGridMenu
//
//  Created by Ryan Nystrom on 6/11/13.
//  Copyright (c) 2013 Ryan Nystrom. All rights reserved.
//

#import "RNGridMenu.h"
#import <QuartzCore/QuartzCore.h>
#import <Accelerate/Accelerate.h>


CGFloat const kRNGridMenuDefaultDuration = 0.25f;
CGFloat const kRNGridMenuDefaultBlur = 0.3f;
CGFloat const kRNGridMenuDefaultWidth = 280;


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
    free(pixelBuffer2);
    CFRelease(inBitmapData);
    CGImageRelease(imageRef);

    return returnImage;
}

@end


@interface RNMenuOptionView : UIView

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) NSInteger optionIndex;

@end


@implementation RNMenuOptionView

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


@interface RNGridMenu()

@property (nonatomic, strong, readwrite) NSArray *options;
@property (nonatomic, strong, readwrite) NSArray *images;
@property (nonatomic, assign) CGPoint menuCenter;
@property (nonatomic, strong) NSMutableArray *optionViews;
@property (nonatomic, strong) RNMenuOptionView *selectedOptionView;
@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, strong) UIView *menuView;

@end

static RNGridMenu *displayedGridMenu;

@implementation RNGridMenu

#pragma mark - Lifecycle

- (id)init {
    if (self = [super init]) {
        _itemSize = CGSizeMake(100, 100);
        _blurLevel = kRNGridMenuDefaultBlur;
        _animationDuration = kRNGridMenuDefaultDuration;
        _itemTextColor = [UIColor whiteColor];
        _itemFont = [UIFont boldSystemFontOfSize:14];
        _highlightColor = [UIColor colorWithRed:.02 green:.549 blue:.961 alpha:1];
        _menuStyle = RNGridMenuStyleDefault;
        _itemTextAlignment = NSTextAlignmentCenter;
        _menuView = [UIView new];
    }
    return self;
}

- (id)initWithOptions:(NSArray *)options delegate:(id <RNGridMenuDelegate>)delegate {
    if (self = [self init]) {
        self.menuStyle = RNGridMenuStyleList;
        self.options = options;
        self.delegate = delegate;
        [self initializeOptionsAndImages];
    }
    return self;
}

- (id)initWithImages:(NSArray *)images delegate:(id <RNGridMenuDelegate>)delegate {
    if (self = [self init]) {
        self.images = images;
        self.delegate = delegate;
        [self initializeOptionsAndImages];
    }
    return self;
}

- (id)initWithOptions:(NSArray *)options images:(NSArray *)images delegate:(id <RNGridMenuDelegate>)delegate {
    NSAssert([options count] == [images count], @"Grid menu must have the same number of option strings and images.");

    if (self = [self init]) {
        self.options = options;
        self.images = images;
        self.delegate = delegate;
        [self initializeOptionsAndImages];
    }
    return self;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UIResponder
////////////////////////////////////////////////////////////////////////

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    RNMenuOptionView *selectedOptionView = [self optionViewAtPoint:point];

    [self highlightOptionView:selectedOptionView];
    self.selectedOptionView = selectedOptionView;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    RNMenuOptionView *newSelectedOptionView = [self optionViewAtPoint:point];

    [self highlightOptionView:newSelectedOptionView];
    self.selectedOptionView = newSelectedOptionView;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.selectedOptionView != nil) {
        if ([self.delegate respondsToSelector:@selector(gridMenu:willDismissWithButtonIndex:option:)]) {
            [self.delegate gridMenu:self
         willDismissWithButtonIndex:self.selectedOptionView.optionIndex
                             option:self.options[self.selectedOptionView.optionIndex]];
        }
    }

    [self dismiss];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    // do nothing
}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.menuView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    self.menuView.opaque = NO;
    self.menuView.clipsToBounds = YES;
    self.menuView.layer.cornerRadius = 8;
    self.menuView.autoresizingMask = UIViewAutoresizingNone;

    CGFloat m34 = 1 / 300.f;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = m34;
    self.menuView.layer.transform = transform;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    CGRect bounds = self.view.bounds;
    self.blurView.frame = bounds;

    [self styleOptionViews];

    if (self.menuStyle == RNGridMenuStyleDefault) {
        [self layoutAsGrid];
    }
    else if (self.menuStyle == RNGridMenuStyleList) {
        [self layoutAsList];
    }

    CGRect headerFrame = self.headerView.frame;
    headerFrame.size.width = self.menuView.bounds.size.width;
    headerFrame.origin = CGPointZero;
    self.headerView.frame = headerFrame;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self becomeFirstResponder];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];

    if ([self isViewLoaded] && self.view.window != nil) {
        [self createScreenshotAndLayout];
    }
}

#pragma mark - Actions

- (void)initializeOptionsAndImages {
    self.optionViews = [NSMutableArray array];

    NSInteger itemCount = self.options ? [self.options count] : [self.images count];
    for (NSInteger i = 0; i < itemCount; i++) {
        UIImage *image = self.images[i];
        NSString *option = self.options[i];

        RNMenuOptionView *optionView = [[RNMenuOptionView alloc] init];
        optionView.imageView.image = image;
        optionView.titleLabel.text = option;
        optionView.optionIndex = i;

        [self.menuView addSubview:optionView];
        [self.optionViews addObject:optionView];
    }
}

#pragma mark - Layout

- (void)styleOptionViews {
    [self.optionViews enumerateObjectsUsingBlock:^(RNMenuOptionView *optionView, NSUInteger idx, BOOL *stop) {
        optionView.titleLabel.textColor = self.itemTextColor;
        optionView.titleLabel.textAlignment = self.itemTextAlignment;
        optionView.titleLabel.font = self.itemFont;
    }];
}

- (void)layoutAsList {
    NSInteger itemCount = self.options ? [self.options count] : [self.images count];
    CGFloat width = self.itemSize.width;
    CGFloat height = self.itemSize.height * itemCount;
    CGFloat headerOffset = CGRectGetHeight(self.headerView.bounds);

    self.menuView.frame = [self menuFrameWithWidth:width height:height center:self.menuCenter headerOffset:headerOffset];

    [self.optionViews enumerateObjectsUsingBlock:^(RNMenuOptionView *optionView, NSUInteger idx, BOOL *stop) {
        optionView.frame = CGRectMake(0, idx * self.itemSize.height + headerOffset, self.itemSize.width, self.itemSize.height);
    }];
}

- (void)layoutAsGrid {
    NSInteger itemCount = self.options ? [self.options count] : [self.images count];
    NSInteger rowCount = floorf(sqrtf(itemCount));

    CGFloat height = self.itemSize.height * rowCount;
    CGFloat width = self.itemSize.width * ceilf(itemCount / (CGFloat)rowCount);
    CGFloat itemHeight = floorf(height / (CGFloat)rowCount);
    CGFloat headerOffset = self.headerView.bounds.size.height;

    self.menuView.frame = [self menuFrameWithWidth:width height:height center:self.menuCenter headerOffset:headerOffset];

    for (NSInteger i = 0; i < rowCount; i++) {
        NSInteger rowLength = ceilf(itemCount / (CGFloat)rowCount);
        NSInteger offset = 0;
        if ((i + 1) * rowLength > itemCount) {
            rowLength = itemCount - i * rowLength;
            offset++;
        }
        NSArray *subOptions = [self.optionViews subarrayWithRange:NSMakeRange(i * rowLength + offset, rowLength)];
        CGFloat itemWidth = floorf(width / (CGFloat)rowLength);
        [subOptions enumerateObjectsUsingBlock:^(RNMenuOptionView *optionView, NSUInteger idx, BOOL *stop) {
            optionView.frame = CGRectMake(idx * itemWidth, i * itemHeight + headerOffset, itemWidth, itemHeight);
        }];
    }
}

- (void)createScreenshotAndLayout {
    self.menuView.alpha = 0;
    self.blurView.alpha = 0;
    UIImage *screenshot = [[UIApplication sharedApplication].keyWindow.rootViewController.view screenshot];
    self.menuView.alpha = 1;
    self.blurView.alpha = 1;
    UIImage *blur = [screenshot boxblurImageWithBlur:self.blurLevel];
    self.blurView.layer.contents = (id) blur.CGImage;

    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

#pragma mark - Animations

- (void)showInViewController:(UIViewController *)parentViewController center:(CGPoint)center {
    NSParameterAssert(parentViewController != nil);

    if (displayedGridMenu != nil) {
        [displayedGridMenu dismiss];
    }

    [self rn_addToParentViewController:parentViewController callingAppearanceMethods:YES];
    self.menuCenter = center;
    self.view.frame = parentViewController.view.bounds;

    [self showAfterScreenshotDelay];
}

- (void)showAfterScreenshotDelay {
    displayedGridMenu = self;

    UIImage *screenshot = [self.parentViewController.view screenshot];
    UIImage *blur = [screenshot boxblurImageWithBlur:self.blurLevel];

    self.blurView = [[UIView alloc] initWithFrame:self.parentViewController.view.bounds];
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.blurView.layer.contents = (id)blur.CGImage;
    [self.view addSubview:self.blurView];
    [self.blurView addSubview:self.menuView];

    if (self.headerView) {
        [self.menuView addSubview:self.headerView];
    }

    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];

    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @0.;
    opacityAnimation.toValue = @1.;
    opacityAnimation.duration = self.animationDuration * 0.5f;
    [self.blurView.layer addAnimation:opacityAnimation forKey:nil];

    CAKeyframeAnimation *scaleAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];

    CATransform3D startingScale = CATransform3DScale(self.menuView.layer.transform, 0, 0, 0);
    CATransform3D overshootScale = CATransform3DScale(self.menuView.layer.transform, 1.1, 1.1, 1.0);
    CATransform3D undershootScale = CATransform3DScale(self.menuView.layer.transform, 0.95, 0.95, 1.0);
    CATransform3D endingScale = self.menuView.layer.transform;

    scaleAnimation.values = @[
                              [NSValue valueWithCATransform3D:startingScale],
                              [NSValue valueWithCATransform3D:overshootScale],
                              [NSValue valueWithCATransform3D:undershootScale],
                              [NSValue valueWithCATransform3D:endingScale]
                              ];

    scaleAnimation.keyTimes = @[
                                @0.0f,
                                @0.5f,
                                @0.85f,
                                @1.0f
                                ];

    scaleAnimation.timingFunctions = @[
                                       [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
                                       [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                       [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
                                       ];
    scaleAnimation.fillMode = kCAFillModeForwards;
    scaleAnimation.removedOnCompletion = NO;

    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    animationGroup.animations = @[
                                  scaleAnimation,
                                  opacityAnimation
                                  ];
    animationGroup.duration = self.animationDuration;

    [self.menuView.layer addAnimation:animationGroup forKey:nil];
    [self becomeFirstResponder];
}

- (void)dismiss {
    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @1.;
    opacityAnimation.toValue = @0.;
    opacityAnimation.duration = self.animationDuration;
    [self.blurView.layer addAnimation:opacityAnimation forKey:nil];

    CATransform3D transform = CATransform3DScale(self.menuView.layer.transform, 0, 0, 0);

    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    scaleAnimation.fromValue = [NSValue valueWithCATransform3D:self.menuView.layer.transform];
    scaleAnimation.toValue = [NSValue valueWithCATransform3D:transform];
    scaleAnimation.duration = self.animationDuration;

    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    animationGroup.animations = @[
                                  opacityAnimation,
                                  scaleAnimation
                                  ];
    animationGroup.duration = self.animationDuration;
    animationGroup.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.menuView.layer addAnimation:animationGroup forKey:nil];

    self.blurView.layer.opacity = 0;
    self.menuView.layer.transform = transform;

    displayedGridMenu = nil;
    self.selectedOptionView = nil;
    [self performSelector:@selector(cleanupGridMenu) withObject:nil afterDelay:self.animationDuration];
}

- (void)cleanupGridMenu {
    [self rn_removeFromParentViewControllerCallingAppearanceMethods:YES];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Private
////////////////////////////////////////////////////////////////////////

- (void)rn_addToParentViewController:(UIViewController *)parentViewController callingAppearanceMethods:(BOOL)callAppearanceMethods {
    if (self.parentViewController != nil) {
        [self rn_removeFromParentViewControllerCallingAppearanceMethods:callAppearanceMethods];
    }

    if (callAppearanceMethods) [self beginAppearanceTransition:YES animated:NO];
    [parentViewController addChildViewController:self];
    [parentViewController.view addSubview:self.view];
    [self didMoveToParentViewController:self];
    if (callAppearanceMethods) [self endAppearanceTransition];
}

- (void)rn_removeFromParentViewControllerCallingAppearanceMethods:(BOOL)callAppearanceMethods {
    if (callAppearanceMethods) [self beginAppearanceTransition:NO animated:NO];
    [self willMoveToParentViewController:nil];
    [self.view removeFromSuperview];
    [self removeFromParentViewController];
    if (callAppearanceMethods) [self endAppearanceTransition];
}


- (RNMenuOptionView *)optionViewAtPoint:(CGPoint)point {
    RNMenuOptionView *selectedView = nil;

    if (CGRectContainsPoint(self.menuView.frame, point)) {
        point =  [self.view convertPoint:point toView:self.menuView];
        selectedView = [[self.optionViews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(RNMenuOptionView *optionView, NSDictionary *bindings) {
            return CGRectContainsPoint(optionView.frame, point);
        }]] lastObject];
    }

    return selectedView;
}

- (void)highlightOptionView:(UIView *)optionView {
    if (optionView != self.selectedOptionView) {
        self.selectedOptionView.backgroundColor = [UIColor clearColor];
        optionView.backgroundColor = self.highlightColor;
    }
}

- (CGRect)menuFrameWithWidth:(CGFloat)width height:(CGFloat)height center:(CGPoint)center headerOffset:(CGFloat)headerOffset {
    height += headerOffset;

    CGRect frame = CGRectMake(center.x - width/2.f, center.y - height/2.f, width, height);

    CGFloat offsetX = 0.f;
    CGFloat offsetY = 0.f;

    // make sure frame doesn't exceed views bounds
    {
        CGFloat tempOffset = CGRectGetMinX(frame) - CGRectGetMinX(self.view.bounds);
        if (tempOffset < 0.f) {
            offsetX = -tempOffset;
        } else {
            tempOffset = CGRectGetMaxX(frame) - CGRectGetMaxX(self.view.bounds);
            if (tempOffset > 0.f) {
                offsetX = -tempOffset;
            }
        }

        tempOffset = CGRectGetMinY(frame) - CGRectGetMinY(self.view.bounds);
        if (tempOffset < 0.f) {
            offsetY = -tempOffset;
        } else {
            tempOffset = CGRectGetMaxY(frame) - CGRectGetMaxY(self.view.bounds);
            if (tempOffset > 0.f) {
                offsetY = -tempOffset;
            }
        }
        
        frame = CGRectOffset(frame, offsetX, offsetY);
    }
    
    return CGRectIntegral(frame);
}

@end