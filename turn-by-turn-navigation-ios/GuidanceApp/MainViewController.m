/*
 * Copyright (c) 2011-2017 HERE Europe B.V.
 * All rights reserved.
 */

#import "MainViewController.h"

@interface MainViewController ()
@property (weak, nonatomic) IBOutlet NMAMapView* mapView;
@property (weak, nonatomic) IBOutlet UIButton* navigationControlButton;
@property (nonatomic) NMACoreRouter* router;
@property (nonatomic) NMARoute* route;
@property (nonatomic) NMANavigationManager* navigationManager;
@property (nonatomic) NMAGeoBoundingBox* geoBoundingBox;
@end

@implementation MainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // create geo coordinate
    NMAGeoCoordinates* geoCoordCenter =
        [[NMAGeoCoordinates alloc] initWithLatitude:1.281269 longitude:103.848359];
    // set map view with geo center
    [self.mapView setGeoCenter:geoCoordCenter withAnimation:NMAMapAnimationNone];
    // set zoom level
    self.mapView.zoomLevel = 13.2;
    [self.navigationControlButton setTitle:@"Start Navigation" forState:UIControlStateNormal];
    self.navigationControlButton.titleLabel.adjustsFontSizeToFitWidth = YES;

    // Get the NavigationManager instance.It is responsible for providing voice and visual
    // instructions while driving and walking.
    self.navigationManager = NMANavigationManager.sharedNavigationManager;

    // Set this controller to be the delegate of NavigationManager, so that it can listening to the
    // navigation events through the different protocols.In this example, we will
    // implement 2 protocol methods for demo purpose, please refer to HERE iOS SDK API documentation
    // for details
    self.navigationManager.delegate = self;
}

- (IBAction)navigationControlButton:(id)sender
{
    // To start a turn-by-turn navigation, a concrete route object is required.We use same steps
    // from Routing sample app to create a route from 4350 Still Creek Dr to Langley BC without
    // going on HWY
    // The route calculation requires local map data.Unless there is pre-downloaded map
    // data on device by utilizing MapLoader APIs,it's not recommended to trigger the
    // route calculation immediately after the MapEngine is initialized.The
    // NMARoutingErrorInsufficientMapData error code may be returned by CoreRouter in this case.
    if ( !self.route )
    {
        [self createRoute];
    }
    else
    {
        [self.navigationManager stop];
        // Restore the map orientation to show entire route on screen
        [self.mapView setBoundingBox:self.geoBoundingBox withAnimation:NMAMapAnimationLinear];
        [self.mapView setOrientation:0];
        [self.navigationControlButton setTitle:@"Start Navigation" forState:UIControlStateNormal];
        self.route = nil;
    }
}

- (void)createRoute
{
    // Create an NSMutableArray to add two stops
    NSMutableArray* stops = [[NSMutableArray alloc] initWithCapacity:4];

    // START: Cecil court
    NMAGeoCoordinates* hereBurnaby =
        [[NMAGeoCoordinates alloc] initWithLatitude:1.281269 longitude:103.848359];
    // END: 111 Middle Rd, Singapore 188969
    NMAGeoCoordinates* langley =
        [[NMAGeoCoordinates alloc] initWithLatitude:1.298776 longitude:103.853564];
    [stops addObject:hereBurnaby];
    [stops addObject:langley];

    // Create an NMARoutingMode, then set it to find the fastest car route without going
    // on Highway.
    NMARoutingMode* routingMode =
        [[NMARoutingMode alloc] initWithRoutingType:NMARoutingTypeFastest
                                      transportMode:NMATransportModeCar
                                     routingOptions:NMARoutingOptionAvoidHighway];

    // Initialize the NMACoreRouter
    if ( !self.router )
    {
        self.router = [[NMACoreRouter alloc] init];
    }

    // Trigger the route calculation
    [self.router
        calculateRouteWithStops:stops
                    routingMode:routingMode
                completionBlock:^( NMARouteResult* routeResult, NMARoutingError error ) {
                  if ( !error )
                  {
                      if ( routeResult && routeResult.routes.count >= 1 )
                      {
                          // Let's add the 1st result onto the map
                          self.route = routeResult.routes[0];
                          NMAMapRoute* mapRoute = [NMAMapRoute mapRouteWithRoute:self.route];
                          [self.mapView addMapObject:mapRoute];

                          // In order to see the entire route, we orientate the
                          // map view
                          // accordingly
                          self.geoBoundingBox = self.route.boundingBox;
                          [self.mapView setBoundingBox:self.route.boundingBox
                                         withAnimation:NMAMapAnimationLinear];
                          [self startNavigation];
                      }
                      else
                      {
                          [self showMessage:@"Error:route result returned is not valid"];
                      }
                  }
                  else
                  {
                      [self showMessage:[NSString
                                            stringWithFormat:
                                                @"Error:route calculation returned error code %d",
                                                (int)error]];
                  }
                }];
}

- (void)startNavigation
{
    [self.navigationControlButton setTitle:@"Stop Navigation" forState:UIControlStateNormal];
    // Display the position indicator on map
    self.mapView.positionIndicator.visible = YES;
    // Configure NavigationManager to launch navigation on current map
    [self.navigationManager setMap:self.mapView];

    // Start the turn-by-turn navigation.Please note if the transport mode of the passed-in
    // route is pedestrian, the NavigationManager automatically triggers the guidance which is
    // suitable for walking. Simulation and tracking modes can also be launched at this moment
    // by calling either simulate() or startTracking()
    [self.navigationManager startTurnByTurnNavigationWithRoute:self.route];
    //[self.navigationManager startTrackingWithTransportMode:NMATransportModeCar];

    // Set the map tracking properties
    [NMANavigationManager sharedNavigationManager].mapTrackingEnabled = YES;
    [NMANavigationManager sharedNavigationManager].mapTrackingAutoZoomEnabled = YES;
    [NMANavigationManager sharedNavigationManager].mapTrackingOrientation
        = NMAMapTrackingOrientationDynamic;
    [NMANavigationManager sharedNavigationManager].speedWarningEnabled = YES;
}

// Signifies that there is new instruction information available
- (void)navigationManager:(NMANavigationManager*)navigationManager
       hasCurrentManeuver:(NMAManeuver*)maneuver
             nextManeuver:(NMAManeuver*)nextManeuver
{
    [self showMessage:@"New maneuver is available"];
}

// Signifies that the system has found a GPS signal
- (void)navigationManagerDidFindPosition:(NMANavigationManager*)navigationManager
{
    [self showMessage:@"New position has been found"];
}

- (void)showMessage:(NSString*)message
{
    CGRect frame = CGRectMake( 110, 200, 220, 120 );

    UILabel* label = [[UILabel alloc] initWithFrame:frame];
    label.backgroundColor = [UIColor groupTableViewBackgroundColor];
    label.textColor = [UIColor blueColor];
    label.text = message;
    label.numberOfLines = 0;

    CGRect rect = [[label text]
        boundingRectWithSize:frame.size
                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                  attributes:@{
                      NSFontAttributeName : label.font
                  }
                     context:nil];
    frame.size = rect.size;
    label.frame = frame;

    [self.view addSubview:label];

    [UIView animateWithDuration:2.0
        animations:^{
          label.alpha = 0;
        }
        completion:^( BOOL finished ) {
          [label removeFromSuperview];
        }];
}
@end
