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
    NSInteger numberOfOptions = 4;
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

- (void)viewDidUnload {
    [self setImageView:nil];
    [super viewDidUnload];
}
@end
