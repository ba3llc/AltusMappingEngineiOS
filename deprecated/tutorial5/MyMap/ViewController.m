//
//  ViewController.m
//  MyMap
//
//  Created by Bruce Shankle III on 11/24/12.
//  Copyright (c) 2012 BA3, LLC. All rights reserved.
//
// Tutorial 5:
//	* Initialize mapping engine and display an embedded low-res TileMill-generated map of planet Earth.
//	* Turn on GPS and update map to center on current GPS coordinate.
//	* Add and enable track-up mode so map rotates based on GPS course.
//	* Add buttons to toggle GPS and track-up mode.
//	* Handle device rotations and starting up in landscape mode.
//	* Add support for an own-ship marker that updates based on current location and course.

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void) initializeMappingEngine
{
	//Create view controller
	self.meMapViewController=[[[MEMapViewController alloc]init]autorelease];
	//Create view
	self.meMapView=[[[MEMapView alloc]init]autorelease];
	//Assign view to view controller
	self.meMapViewController.view = self.meMapView;
	
	//Add the map view as a sub view to our main view and size it.
	[self.view addSubview:self.meMapView];
	[self.view sendSubviewToBack:self.meMapView];
	self.meMapView.frame = self.view.bounds;

	//Initialize the map view controller
	[self.meMapViewController initialize];
}

- (void) turnOnBaseMap
{
	//Determine the physical path of the map file file.
	NSString* databaseFile = [[NSBundle mainBundle] pathForResource:@"world"
															 ofType:@"mbtiles"];
	
	MEMBTilesMapInfo* mapInfo = [[[MEMBTilesMapInfo alloc]init]autorelease];
	mapInfo.name = @"Earth";
	mapInfo.imageDataType = kImageDataTypeJPG;
	mapInfo.mapType = kMapTypeFileMBTiles;
	mapInfo.maxLevel = 6;
	mapInfo.sqliteFileName = databaseFile;
	mapInfo.zOrder = 1;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
}

////////////////////////////////////////////////
//Init GPS
- (void) initializeGPS:(BOOL) enabled
{
	if(enabled)
	{
		if(self.locationManager==nil)
		{
			self.locationManager = [[[CLLocationManager alloc] init] autorelease];
			self.locationManager.delegate = self;
		}
		[self.locationManager startUpdatingLocation];
		[self addOwnShipMarker];

	}
	else
	{
		[self.locationManager stopUpdatingLocation];
		[self removeOwnShipMarker];
	}
}

///////////////////////////////////////////////
//Respond to GPS
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    NSLog(@"Location: %@", [newLocation description]);
	
	[self.meMapView setCenterCoordinate:newLocation.coordinate
					  animationDuration:1.0];
	
	//Update own-ship marker position
	[self updateOwnShipMarkerLocation:newLocation.coordinate
							  heading:newLocation.course
					animationDuration:1.0];
	
	//If in track up mode, then the heading of the marker needs to be updated
	if(self.isTrackupMode)
	{
		[self.meMapViewController.meMapView setCameraOrientation:newLocation.course
															roll:0
														   pitch:0
											   animationDuration:1.0];
	}
	
}

///////////////////////////////////////////////
//Turn track-up mode on or off
- (void) enableTrackupMode:(BOOL) enabled
{
	if(enabled)
	{
		[self.meMapViewController setRenderMode:METrackUp];
		self.meMapView.panEnabled = NO;
	}
	else
	{
		[self.meMapViewController unsetRenderMode:METrackUp];
		self.meMapView.panEnabled = YES;
	}
	
	self.isTrackupMode = enabled;
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
	NSLog(@"Error: %@", [error description]);
}

////////////////////////////////////////////////////////////////////////////
//Add some extremely simple UI right on top of the map.
//Normally you would do this using the interface builder, but our goal here
//is to keep this very simple to illustrate mapping-engine concepts.
- (void) addButtons
{
	self.btnGPS = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[self.btnGPS setTitle:@"GPS - Off" forState:UIControlStateNormal];
	[self.btnGPS setTitle:@"GPS - On" forState:UIControlStateSelected];
	[self.view addSubview:self.btnGPS];
	[self.view bringSubviewToFront:self.btnGPS];
	self.btnGPS.frame=CGRectMake(0,0,90,30);
	[self.btnGPS addTarget:self
			   action:@selector(gpsButtonTapped)
	 forControlEvents:UIControlEventTouchDown];
	
	
	self.btnTrackUp = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[self.btnTrackUp setTitle:@"TU - Off" forState:UIControlStateNormal];
	[self.btnTrackUp setTitle:@"TU - On" forState:UIControlStateSelected];
	[self.view addSubview:self.btnTrackUp];
	[self.view bringSubviewToFront:self.btnTrackUp];
	self.btnTrackUp.frame=CGRectMake(self.btnGPS.frame.size.width, 0, 90, 30);
	[self.btnTrackUp addTarget:self
					action:@selector(trackUpButtonTapped)
		  forControlEvents:UIControlEventTouchDown];
		
}

- (void) gpsButtonTapped
{
	//Toggle GPS
	self.isGPSMode = !self.isGPSMode;
	[self initializeGPS:self.isGPSMode];
	self.btnGPS.selected = self.isGPSMode;
}

- (void) trackUpButtonTapped
{
	//Toggle trackup mode
	self.isTrackupMode = !self.isTrackupMode;
	[self enableTrackupMode:self.isTrackupMode];
	self.btnTrackUp.selected = self.isTrackupMode;
}


////////////////////////////////////////////////////////////////////////////
//Size map view when device rotates
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	self.meMapView.frame = self.view.bounds;
}

////////////////////////////////////////////////////////////////////////////
//Size map view when view appears (handles landscape startup)
- (void) viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	self.meMapView.frame = self.view.bounds;
}

////////////////////////////////////////////////////////////////////////////
//Initialize things
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	//Add some UI
	[self addButtons];
	
	//Initialize the mapping engine
	[self initializeMappingEngine];
	
	//Turn on the embedded raster map
	[self turnOnBaseMap];
	
}



////////////////////////////////////////////////////////////////////////////
//Create a marker layer which will contain our 'own-ship' marker
- (void) addOwnShipMarker
{
	//Create an array to hold markers (even though we're only adding 1)
	NSMutableArray* markers= [[[NSMutableArray alloc]init]autorelease];
	
	//Create a single marker annotation which describes the marker
	MEMarkerAnnotation* ownShipMarker = [[[MEMarkerAnnotation alloc]init]autorelease];
	ownShipMarker.metaData = @"ownship";
	ownShipMarker.weight=0;
	[markers addObject:ownShipMarker];
	
	//Create a marker map info object which will describe the marker layer
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = @"ownship marker layer";
	mapInfo.mapType = kMapTypeDynamicMarker;
	mapInfo.markerImageLoadingStrategy = kMarkerImageLoadingSynchronous;
	mapInfo.zOrder = 999;
	mapInfo.meMarkerMapDelegate = self;
	mapInfo.markers = markers;
	
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
}

////////////////////////////////////////////////////////////////////////////
//Update the location and heading of the dynamic marker
-(void) updateOwnShipMarkerLocation:(CLLocationCoordinate2D) location
							heading:(double) heading
				  animationDuration:(CGFloat) animationDuration

{
	
	[self.meMapViewController updateMarkerInMap:@"ownship marker layer"
									   metaData:@"ownship"
									newLocation:location
									newRotation:heading
							  animationDuration:animationDuration];
	
	
}

////////////////////////////////////////////////////////////////////////////
//Remove the own-ship marker layer
- (void) removeOwnShipMarker
{
	[self.meMapViewController removeMap:@"ownship marker layer" clearCache:NO];
}

////////////////////////////////////////////////////////////////////////////
//Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView*)mapView
updateMarkerInfo:(MEMarkerInfo*) markerInfo
		 mapName:(NSString*) mapName
{
	//Return an image for the ownship marker
	if([markerInfo.metaData isEqualToString:@"ownship"])
	{
		markerInfo.rotationType = kMarkerRotationTrueNorthAligned;
		markerInfo.uiImage = [UIImage imageNamed:@"blueplane"];
		markerInfo.anchorPoint = CGPointMake(markerInfo.uiImage.size.width/2,
											 markerInfo.uiImage.size.height/2);
	}
}

- (void) dealloc {
	
	//Turn off the GPS
	[self.locationManager stopUpdatingLocation];
	self.locationManager = nil;
	
	//Shut down mapping engine
	[self.meMapViewController shutdown];
	self.meMapViewController = nil;
	self.meMapView = nil;
	
	[super dealloc];
}


@end
