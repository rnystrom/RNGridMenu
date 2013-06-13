//
//  RNViewController.m
//  RNAlertView
//
//  Created by Ryan Nystrom on 6/11/13.
//  Copyright (c) 2013 Ryan Nystrom. All rights reserved.
//

#import "RNViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface RNViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@end

@implementation RNViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.imageView.layer.borderWidth = 2;
    self.imageView.layer.borderColor = [UIColor whiteColor].CGColor;
    self.imageView.layer.cornerRadius = CGRectGetHeight(self.imageView.bounds) / 2;
    self.imageView.clipsToBounds = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)alertView:(RNAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex option:(NSString *)option {
    NSLog(@"selected index %i with option %@",buttonIndex,option);
}

- (IBAction)onShowButton:(id)sender {
    [self showGrid];
}

- (void)showImagesOnly {
    NSInteger numberOfOptions = 5;
    NSArray *images = @[
                        [UIImage imageNamed:@"arrow"],
                        [UIImage imageNamed:@"attachment"],
                        [UIImage imageNamed:@"block"],
                        [UIImage imageNamed:@"bluetooth"],
                        [UIImage imageNamed:@"cube"],
                        [UIImage imageNamed:@"download"],
                        [UIImage imageNamed:@"enter"],
                        [UIImage imageNamed:@"file"],
                        [UIImage imageNamed:@"github"]
                        ];
    RNAlertView *av = [[RNAlertView alloc] initWithImages:[images subarrayWithRange:NSMakeRange(0, numberOfOptions)] delegate:self];
    [av show];
}

- (void)showList {
    NSInteger numberOfOptions = 5;
    NSArray *options = @[
                         @"Next",
                         @"Attach",
                         @"Cancel",
                         @"Bluetooth",
                         @"Deliver",
                         @"Download",
                         @"Enter",
                         @"Source Code",
                         @"Github"
                         ];
    RNAlertView *av = [[RNAlertView alloc] initWithOptions:[options subarrayWithRange:NSMakeRange(0, numberOfOptions)] delegate:self];
//    av.itemTextAlignment = NSTextAlignmentLeft;
    av.itemFont = [UIFont boldSystemFontOfSize:18];
    av.itemSize = CGSizeMake(150, 55);
    [av show];
}

- (void)showGrid {
    NSInteger numberOfOptions = 9;
    NSArray *images = @[
                        [UIImage imageNamed:@"arrow"],
                        [UIImage imageNamed:@"attachment"],
                        [UIImage imageNamed:@"block"],
                        [UIImage imageNamed:@"bluetooth"],
                        [UIImage imageNamed:@"cube"],
                        [UIImage imageNamed:@"download"],
                        [UIImage imageNamed:@"enter"],
                        [UIImage imageNamed:@"file"],
                        [UIImage imageNamed:@"github"]
                        ];
    NSArray *options = @[
                         @"Next",
                         @"Attach",
                         @"Cancel",
                         @"Bluetooth",
                         @"Deliver",
                         @"Download",
                         @"Enter",
                         @"Source Code",
                         @"Github"
                         ];
    RNAlertView *av = [[RNAlertView alloc] initWithOptions:[options subarrayWithRange:NSMakeRange(0, numberOfOptions)] images:[images subarrayWithRange:NSMakeRange(0, numberOfOptions)] delegate:self];
    [av show];
}

- (void)showGridWithHeader {
    NSInteger numberOfOptions = 9;
    NSArray *images = @[
                        [UIImage imageNamed:@"arrow"],
                        [UIImage imageNamed:@"attachment"],
                        [UIImage imageNamed:@"block"],
                        [UIImage imageNamed:@"bluetooth"],
                        [UIImage imageNamed:@"cube"],
                        [UIImage imageNamed:@"download"],
                        [UIImage imageNamed:@"enter"],
                        [UIImage imageNamed:@"file"],
                        [UIImage imageNamed:@"github"]
                        ];
    NSArray *options = @[
                         @"Next",
                         @"Attach",
                         @"Cancel",
                         @"Bluetooth",
                         @"Deliver",
                         @"Download",
                         @"Enter",
                         @"Source Code",
                         @"Github"
                         ];
    RNAlertView *av = [[RNAlertView alloc] initWithOptions:[options subarrayWithRange:NSMakeRange(0, numberOfOptions)] images:[images subarrayWithRange:NSMakeRange(0, numberOfOptions)] delegate:self];
    
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 44)];
    header.text = @"Example Header";
    header.font = [UIFont boldSystemFontOfSize:18];
    header.backgroundColor = [UIColor clearColor];
    header.textColor = [UIColor whiteColor];
    header.textAlignment = NSTextAlignmentCenter;
    av.headerView = header;
    
    [av show];
}

@end
