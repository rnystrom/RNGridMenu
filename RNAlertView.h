//
//  RNAlertView.h
//  RNAlertView
//
//  Created by Ryan Nystrom on 6/11/13.
//  Copyright (c) 2013 Ryan Nystrom. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RNAlertView;
@protocol RNAlertViewDelegate <NSObject>
@optional
- (void)alertView:(RNAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex option:(NSString *)option;
@end

@interface RNAlertView : UIViewController

@property (nonatomic, strong, readonly) NSArray *options;
@property (nonatomic, strong, readonly) NSArray *images;
@property (nonatomic, copy) UIColor *highlightColor;
@property (nonatomic, strong, readonly) UIColor *backgroundColor;
@property (nonatomic, assign) CGSize itemSize;
@property (nonatomic, weak) id <RNAlertViewDelegate> delegate;
@property (nonatomic, assign) CGFloat blurLevel;
@property (nonatomic, assign) BOOL addsToWindow;
@property (nonatomic, assign) BOOL viewHasLoaded;
@property (nonatomic, assign) CGFloat animationDuration;
@property (nonatomic, assign) BOOL shadeIcons;
@property (nonatomic, copy) UIColor *titleColor;
@property (nonatomic, copy) UIFont *titleFont;

- (id)initWithOptions:(NSArray *)options images:(NSArray *)images delegate:(id <RNAlertViewDelegate>)delegate;
- (void)show;
- (void)dismiss;


@end
