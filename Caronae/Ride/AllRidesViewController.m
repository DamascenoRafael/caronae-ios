@import SVProgressHUD;
#import "AllRidesViewController.h"
#import "SearchResultsViewController.h"
#import "SearchRideViewController.h"
#import "Caronae-Swift.h"

@interface AllRidesViewController () <SearchRideDelegate>
@property (nonatomic) NSDictionary *searchParams;
@property (nonatomic) UIView *tableFooter;
@end

@implementation AllRidesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"NavigationBarLogo"]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self loadAllRides];
}

- (UIView *)tableFooter {
    if (!_tableFooter) {
        UILabel *tableFooter = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 40)];
        tableFooter.text = @"Quer encontrar mais caronas? Use a pesquisa! 🔍";
        tableFooter.numberOfLines = 0;
        tableFooter.backgroundColor = [UIColor whiteColor];
        tableFooter.font = [UIFont systemFontOfSize:10];
        tableFooter.textColor = [UIColor lightGrayColor];
        tableFooter.textAlignment = NSTextAlignmentCenter;
        _tableFooter = tableFooter;
    }
    return _tableFooter;
}

- (void)refreshTable {
    [self loadAllRides];
}


#pragma mark - Rides methods

- (void)loadAllRides {
    if (self.tableView.backgroundView != nil) {
        self.tableView.backgroundView = self.loadingLabel;
    }
    
    [RideService.instance getAllRidesWithSuccess:^(NSArray<Ride *> * _Nonnull rides) {
        self.rides = rides;
        
        [self.tableView reloadData];
        
        if ([self.rides count] > 0) {
            self.tableView.tableFooterView = self.tableFooter;
        } else {
            self.tableView.tableFooterView = nil;
        }
        
        [self.refreshControl endRefreshing];
    } error:^(NSError * _Nonnull error) {
        [self.refreshControl endRefreshing];
        [self loadingFailedWithError:error];
    }];
    
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"SearchRide"]) {
        UINavigationController *searchNavController = segue.destinationViewController;
        SearchRideViewController *searchVC = searchNavController.viewControllers.firstObject;
        searchVC.previouslySelectedSegmentIndex = self.directionControl.selectedSegmentIndex;
        searchVC.delegate = self;
    }
    else if ([segue.identifier isEqualToString:@"ViewSearchResults"]) {
        SearchResultsViewController *searchViewController = segue.destinationViewController;
        [searchViewController searchedForRideWithCenter:self.searchParams[@"center"]
                                       andNeighborhoods:self.searchParams[@"neighborhoods"]
                                                 onDate:self.searchParams[@"date"]
                                                  going:[self.searchParams[@"going"] boolValue]];
    }
}


#pragma mark - Search methods

- (void)searchedForRideWithCenter:(NSString *)center andNeighborhoods:(NSArray *)neighborhoods onDate:(NSDate *)date going:(BOOL)going {
    self.searchParams = @{@"center": center,
                          @"neighborhoods": neighborhoods,
                          @"date": date,
                          @"going": @(going)
                          };
    
    [self performSegueWithIdentifier:@"ViewSearchResults" sender:self];
}


@end
