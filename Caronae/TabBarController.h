@import UIKit;
#import "AllRidesViewController.h"
#import "MenuViewController.h"

@class ActiveRidesViewController, MyRidesViewController;

@interface TabBarController : UITabBarController

@property (nonatomic, strong) AllRidesViewController *allRidesViewController;
@property (nonatomic, strong) UINavigationController *allRidesNavigationController;

@property (nonatomic, strong) ActiveRidesViewController *activeRidesViewController;
@property (nonatomic, strong) UINavigationController *activeRidesNavigationController;

@property (nonatomic, strong) MyRidesViewController *myRidesViewController;
@property (nonatomic, strong) UINavigationController *myRidesNavigationController;

@property (nonatomic, strong) MenuViewController *menuViewController;
@property (nonatomic, strong) UINavigationController *menuNavigationController;

@end
