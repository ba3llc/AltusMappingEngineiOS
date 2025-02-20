//
//  MECreateAndAddMarkerMapTest.m
//  Mapp
//
//  Created by Bruce Shankle III on 8/17/12.
//  Copyright (c) 2012 BA3, LLC. All rights reserved.
//
#import <QuartzCore/QuartzCore.h>
#import "MEMarkerTests.h"
#import "MarkerTestData.h"
#import "Country.h"
#import <ME/ME.h>
#import "../../Database/AviationDatabase.h"
#include <vector>
#import "../METestManager.h"
#import "../METestCategory.h"

@implementation MEMarkerTest
- (id) init
{
    if(self = [super init])
    {
		self.bestFontSize = 17.0f;
    }
    return self;
}
@end


///////////////////////////////////////////////////////////////////////////
//Bus stops around Bay Area
@implementation MESFOBusAddInMemoryClusteredMarkerTest
- (id) init
{
    if(self = [super init])
    {
        self.name=@"Bus Stops: In Memory";
    }
    return self;
}

- (BOOL) isEnabled
{
	
	if([self isOtherTestRunning:
		@"Bus Stops: To Disk Cache"])
		return NO;
	
	if([self isOtherTestRunning:
		@"Bus Stops: From Disk Cache"])
		return NO;
	
	return YES;
}

- (void) start
{
	
	if(!self.isEnabled)
	   return;
	   
    //Load marker test data
    MarkerTestData* markerTestData = [[MarkerTestData alloc]init];
    
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeMemoryMarker;
	mapInfo.zOrder = 20;
	mapInfo.meMarkerMapDelegate = self;
	mapInfo.markers = markerTestData.sanFranciscoBusStops;
	mapInfo.clusterDistance = 50;
	mapInfo.maxLevel = 18;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
    
    //Release test data
    [markerTestData release];
    
    //Zoom in on the San francisco area
    [self lookAtSanFrancisco];
    
    self.isRunning = YES;
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
                                   clearCache:YES];
    self.isRunning = NO;
}

// Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView *)mapView
updateMarkerInfo:(MEMarkerInfo *)markerInfo
		 mapName:(NSString *)mapName
{
	markerInfo.uiImage = [UIImage imageNamed:@"pinRed"];
	markerInfo.anchorPoint = CGPointMake(7,35);
}

- (void) tapOnMarker:(NSString*)metaData
           onMapView:(MEMapView*)mapView
       atScreenPoint:(CGPoint)point{
    NSLog(@"Marker %@ was tapped on", metaData);
}

- (void) tapOnMarker:(MEMarkerInfo *)markerInfo
		   onMapView:(MEMapView *)mapView
			 mapName:(NSString *)mapName
	   atScreenPoint:(CGPoint)screenPoint
	   atMarkerPoint:(CGPoint)markerPoint{
	
	//Query which markers are visible
	NSArray* visibleMarkers = [self.meMapViewController getVisibleMarkers:mapName];
	for(MEMarker* marker in visibleMarkers){
		NSLog(@"Marker with metadata=%@ uid=%d is visible.",
			  marker.metaData,
			  marker.uid);
	}
	NSLog(@"%d markers are visible", visibleMarkers.count);
	
}

@end

///////////////////////////////////////////////////////////////////////////
@implementation BusStopsNonClusteredInMemorySync
- (id) init
{
    if(self = [super init])
    {
        self.name=@"Bus Stops: In Memory Sync";
    }
    return self;
}

- (void) start
{
	
	if(!self.isEnabled)
		return;
	
    //Load marker test data
    MarkerTestData* markerTestData = [[MarkerTestData alloc]init];
    
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeDynamicMarker;
	mapInfo.markerImageLoadingStrategy = kMarkerImageLoadingSynchronous;
	mapInfo.zOrder = 20;
	mapInfo.meMarkerMapDelegate = self;
	mapInfo.markers = markerTestData.sanFranciscoBusStops;
	NSMutableArray* subset = [[[NSMutableArray alloc]init]autorelease];
	for(int i=0; i<100; i++)
	{
		[subset addObject:[markerTestData.sanFranciscoBusStops objectAtIndex:i]];
	}
	mapInfo.markers = subset;
	mapInfo.clusterDistance = 50;
	mapInfo.maxLevel = 18;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
    
    //Release test data
    [markerTestData release];
    
    //Zoom in on the San francisco area
    [self lookAtSanFrancisco];
    
    self.isRunning = YES;
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
							 clearCache:YES];
    self.isRunning = NO;
}

// Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView *)mapView
updateMarkerInfo:(MEMarkerInfo *)markerInfo
		 mapName:(NSString *)mapName
{
	markerInfo.uiImage = [UIImage imageNamed:@"pinRed"];
	markerInfo.anchorPoint = CGPointMake(7,35);
}


@end

///////////////////////////////////////////////////////////////////////////
//This test shows how to add an in-memory clustered marker map
//using the fast marker system. In this approach, you first
//pre-cache any necessary marker images, then when you add the map
//you provide an array of MEFastMarkerInfo object as opposed to MEMarkerAnnotion
//objects used in other methods. With this approach, the mapping engine
//does not have to call back to your delegate to request images and
//will not create any worker threads, thereby loading markers very quickly.
//NOTE: Clustering will still take a non-zero amount of time. If you don't want to
//cluster the markers by their weight, set all the weights to zero.
@implementation BusStopsClusteredInMemoryFast
- (id) init
{
    if(self = [super init])
    {
        self.name=@"Bus Stops: In Memory Fast";
		self.firstRun = YES;
    }
    return self;
}

- (BOOL) isEnabled
{
	return YES;
}

- (void) start
{
	if(self.isRunning)
		return;
	
	[self.meTestCategory stopAllTests];
	
    //Load marker test data
    MarkerTestData* markerTestData = [[MarkerTestData alloc]init];
    
	//Precache the necessary marker image in the mapping engine
	[self.meMapViewController addCachedMarkerImage:[UIImage imageNamed:@"pinGreen"]
										  withName:@"pinGreen"
								   compressTexture:NO
					nearestNeighborTextureSampling:NO];
	
	//Configure the marker map info object
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeMemoryMarkerFast;
	mapInfo.markerImageLoadingStrategy = kMarkerImageLoadingPrecached;
	mapInfo.zOrder = 20;
	mapInfo.meMarkerMapDelegate = self;
	mapInfo.markers = markerTestData.sanFranciscoBusStopsFast; //An array of MEFastMarkerInfo objects
	mapInfo.clusterDistance = 50;
	mapInfo.maxLevel = 18;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
    //Release test data
    [markerTestData release];
    
    //Zoom in on the San francisco area
	if(self.firstRun)
		[self lookAtSanFrancisco];
    
	self.firstRun = NO;
    self.isRunning = YES;
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
							 clearCache:YES];
    self.isRunning = NO;
}

- (void) tapOnMarker:(NSString*)metaData
           onMapView:(MEMapView*)mapView
       atScreenPoint:(CGPoint)point
{
    NSLog(@"Marker %@ was tapped on", metaData);
}

@end


///////////////////////////////////////////////////////////////////////////
//This test shows how to add an in-memory clustered marker map
//using the fast marker system. In this approach, you first
//pre-cache any necessary marker images, then when you add the map
//you provide an array of MEFastMarkerInfo object as opposed to MEMarkerAnnotion
//objects used in other methods. With this approach, the mapping engine
//does not have to call back to your delegate to request images and
//will not create any worker threads, thereby loading markers very quickly.
//NOTE: Clustering will still take a non-zero amount of time. If you don't want to
//cluster the markers by their weight, set all the weights to zero.
@implementation BusStopsNonClusteredInMemoryFast
- (id) init
{
    if(self = [super init])
    {
        self.name=@"Bus Stops: Non Clustered Fast";
		self.firstRun = YES;
    }
    return self;
}

- (BOOL) isEnabled
{
	return YES;
}

- (void) start
{
	if(self.isRunning)
		return;
	
	[self.meTestCategory stopAllTests];
	
    //Load marker test data
    MarkerTestData* markerTestData = [[MarkerTestData alloc]init];
    
	//Precache the necessary marker image in the mapping engine
	[self.meMapViewController addCachedMarkerImage:[UIImage imageNamed:@"pinGreen"]
										  withName:@"pinGreen"
								   compressTexture:NO
					nearestNeighborTextureSampling:NO];
	
	//Configure the marker map info object
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeDynamicMarkerFast;
	mapInfo.markerImageLoadingStrategy = kMarkerImageLoadingPrecached;
	mapInfo.zOrder = 20;
	mapInfo.meMarkerMapDelegate = self;
	//mapInfo.markers = markerTestData.sanFranciscoBusStopsFast; //An array of MEFastMarkerInfo objects
	
	NSMutableArray* subset = [[[NSMutableArray alloc]init]autorelease];
	for(int i=0; i<100; i++)
	{
		[subset addObject:[markerTestData.sanFranciscoBusStopsFast objectAtIndex:i]];
	}
	mapInfo.markers = subset;
	
	mapInfo.clusterDistance = 50;
	mapInfo.maxLevel = 18;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
    //Release test data
    [markerTestData release];
    
    //Zoom in on the San francisco area
	if(self.firstRun)
		[self lookAtSanFrancisco];
    
	self.firstRun = NO;
    self.isRunning = YES;
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
							 clearCache:YES];
    self.isRunning = NO;
}

- (void) tapOnMarker:(NSString*)metaData
           onMapView:(MEMapView*)mapView
       atScreenPoint:(CGPoint)point
{
    NSLog(@"Marker %@ was tapped on", metaData);
}

@end


///////////////////////////////////////////////////////////////////////////
@implementation MESFOBusCreateAndAddClusteredMarkerTest
- (id) init
{
    if(self = [super init])
    {
        self.name=@"Bus Stops: To Disk Cache";
    }
    return self;
}

- (BOOL) isEnabled
{
	if([self isOtherTestRunning:
		@"Bus Stops: From Disk Cache"])
		return NO;
	
	if([self isOtherTestRunning:
		@"Bus Stops: In Memory"])
		return NO;
		
	return YES;
}

- (void) dealloc
{
    [super dealloc];
}

- (void) start
{
	if(!self.isEnabled)
		return;
	
    //Load some marker test data
    MarkerTestData* markerTestData = [[MarkerTestData alloc]init];
    
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarkerCreate;
	mapInfo.sqliteFileName = [MarkerTestData sfoBusStopsMarkerCachePath];
	mapInfo.zOrder = 20;
	mapInfo.meMarkerMapDelegate = self;
	mapInfo.markers = markerTestData.sanFranciscoBusStops;
	mapInfo.clusterDistance = 50;
	mapInfo.maxLevel = 18;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
    //Release test data
    [markerTestData release];
    
    self.isRunning = YES;
    [self wasUpdated];
    
    //Zoom in on the San francisco area
    [self lookAtSanFrancisco];
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
                                   clearCache:YES];
    self.isRunning = NO;
}

@end


@implementation MESFOBusAddExistingClusteredMarkerTest

- (id) init
{
    if(self = [super init])
    {
        self.name=@"Bus Stops: From Disk Cache";
    }
    return self;
}

- (BOOL) isEnabled
{
	if([self isOtherTestRunning:
		@"Bus Stops: To Disk Cache"])
		return NO;
	
	if([self isOtherTestRunning:
		@"Bus Stops: In Memory"])
		return NO;
	
    NSString* dbFileName = [MarkerTestData sfoBusStopsMarkerCachePath];
	return [[NSFileManager defaultManager]fileExistsAtPath:dbFileName];
}


- (void) start
{
	if(!self.isEnabled)
		return;
	
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarker;
	mapInfo.sqliteFileName = [MarkerTestData sfoBusStopsMarkerCachePath];
	mapInfo.zOrder = 20;
	mapInfo.meMarkerMapDelegate = self;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	    
    self.isRunning = YES;
    
    //Zoom in on the San francisco area
    [self lookAtSanFrancisco];
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
                                   clearCache:YES];
    self.isRunning = NO;
}

@end


//////////////////////////////////////////////////////////////////
@implementation MEBusDynamicMarker

@synthesize markerTestData;
@synthesize routeIndex;

- (id) init
{
    if(self = [super init])
    {
        self.name=@"Moving Bus: Dynamic In Memory";
        self.markerTestData = [[MarkerTestData alloc]init];
        self.routeIndex = 0;
    }
    return self;
}

- (void) dealloc
{
    self.markerTestData = nil;
    [super dealloc];
}

- (CLLocationCoordinate2D) getRoutePointCoordinate:(int) index
{
    NSValue* v = [self.markerTestData.sanFranciscoBusRoute objectAtIndex:index];
    CGPoint point = [v CGPointValue];
    return CLLocationCoordinate2DMake(point.y, point.x);
}

- (void) start
{
	
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeDynamicMarker;
	mapInfo.zOrder = 200;
	mapInfo.meMarkerMapDelegate = self;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	    
    //Zoom in on the San francisco area
    [self lookAtSanFrancisco];
    
    //Reset route index.
    self.routeIndex = 0;
    
    //Add marker to map
    MEMarkerAnnotation* markerAnnotation = [[[MEMarkerAnnotation alloc]init]autorelease];
    markerAnnotation.metaData = @"Bus 1";
    markerAnnotation.coordinate = [self getRoutePointCoordinate:0];
    [self.meMapViewController addMarkerToMap:self.name
							markerAnnotation:markerAnnotation];
    
    self.interval = 1.0;
    
    //Start timer
    [super start];
    
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
                                   clearCache:YES];
    self.isRunning = NO;
}

- (void) timerTick
{
    //Increment / reset route index
    self.routeIndex = self.routeIndex + 1;
    if(self.routeIndex >= self.markerTestData.sanFranciscoBusRoute.count)
        self.routeIndex = 0;
    
    //Update marker location
    [self.meMapViewController updateMarkerLocationInMap:self.name
                                              metaData:@"Bus 1"
                                            newLocation:[self getRoutePointCoordinate:self.routeIndex]
									  animationDuration:1.0];
}

// Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView *)mapView
updateMarkerInfo:(MEMarkerInfo *)markerInfo
		 mapName:(NSString *)mapName
{
	markerInfo.uiImage = [UIImage imageNamed:@"bus"];
	markerInfo.anchorPoint = CGPointMake(71,4);
}

@end

///////////////////////////////////////////////////////////////////////////
@implementation MERotatingBusDynamicMarker
@synthesize rotation;

- (id) init
{
    if(self = [super init])
    {
        self.name=@"Moving & Rotating Bus: Dynamic In Memory";
		self.rotation = 0;
    }
    return self;
}

- (void) timerTick
{
	//[super timerTick];
	self.rotation += 5;
	
    //Increment / reset route index
	[self.meMapViewController updateMarkerRotationInMap:self.name
											   metaData:@"Bus 1"
											newRotation:self.rotation
									  animationDuration:1.0];
}

@end

///////////////////////////////////////////////////////////////////////////
@implementation MECountryMarkersInMemory
@synthesize countries;
- (id) init
{
    if(self = [super init])
    {
        self.name=@"Countries: In Memory";
    }
    return self;
}

- (void) dealloc
{
    self.countries = nil;
    [super dealloc];
}

- (void) start
{
    if(countries==nil)
    {
        countries = [MarkerTestData loadCountries];
    }
    
    //Create an marker annotation for each country
    NSMutableArray* countryAnnotations = [[NSMutableArray alloc]init];
    
    for(int i=0; i<countries.count; i++)

    {
        //Get a country
        Country* country = (Country*)[countries objectAtIndex:i];
        
        MEMarkerAnnotation * marker = [[MEMarkerAnnotation alloc] init];
        marker.coordinate = CLLocationCoordinate2DMake(country.latitude,
                                                       country.longitude);
        
        //Use the array index as the id
        marker.metaData = [NSString stringWithFormat:@"%d",i];
        
        //Use the countries population as the weight
        marker.weight = country.population;
        [countryAnnotations addObject:marker];
        [marker release];
    }
	
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeMemoryMarker;
	mapInfo.zOrder = 20;
	mapInfo.meMarkerMapDelegate = self;
	mapInfo.markers = countryAnnotations;
	mapInfo.clusterDistance = 90;
	mapInfo.maxLevel = 8;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
    
    [countryAnnotations release];
    [self lookAtAtlantic];
    self.isRunning = YES;
}

// Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView *)mapView
updateMarkerInfo:(MEMarkerInfo *)markerInfo
		 mapName:(NSString *)mapName
{
    //Look up the given country
    int index=[markerInfo.metaData integerValue];
    Country* country = (Country*)[self.countries objectAtIndex:index];
    
    //Scale marker font size based on population
    float fontSize = 12.5f;    
    if(country.population > 500000)
        fontSize = 15.0f;
    
    if(country.population > 1000000)
        fontSize = 17.5f;
    
    if(country.population > 10000000)
        fontSize = 20.0f;
    
    if(country.population > 100000000)
        fontSize = 22.5f;
    
    if(country.population > 200000000)
        fontSize = 25.0f;

    UIColor* fillColor = [UIColor whiteColor];
    UIColor* strokeColor = [UIColor blackColor];
    if(country.population > 300000000)
    {
        fillColor = [UIColor yellowColor];
        strokeColor = [UIColor blackColor];
        fontSize = 27.5f;
    }

    if(country.population > 500000000)
        fontSize = 30.0f;

    //Have the mapping engine create a label for us
    UIImage* textImage=[MEFontUtil newImageWithFontOutlined:@"Helvetica-Bold"
                                        fontSize:fontSize
                                       fillColor:fillColor
                                     strokeColor:strokeColor
                                     strokeWidth:0
                                            text:country.name];
    
    //Craete an anhor point based on the image size
    CGPoint anchorPoint = CGPointMake(textImage.size.width / 2.0,
                                      textImage.size.height / 2.0);
    //Update the marker info
	markerInfo.uiImage = textImage;
	markerInfo.anchorPoint = anchorPoint;
	[textImage release];

}

- (void) stop
{
    [self.meMapViewController removeMap:self.name clearCache:YES];
    self.isRunning = NO;
}

@end

/////////////////////////////////////////////////////////////////////////
@implementation MECountryMarkersSaveToDisk

- (id) init
{
    if(self = [super init])
    {
        self.name=@"Countries: To Disk Cache";
    }
    return self;
}

- (void) start
{
    if(self.countries==nil)
    {
        self.countries = [MarkerTestData loadCountries];
    }
    
    //Create an marker annotation for each country
    NSMutableArray* countryAnnotations = [[NSMutableArray alloc]init];
    
    for(int i=0; i<self.countries.count; i++)
		
    {
        //Get a country
        Country* country = (Country*)[self.countries objectAtIndex:i];
        
        MEMarkerAnnotation * marker = [[MEMarkerAnnotation alloc] init];
        marker.coordinate = CLLocationCoordinate2DMake(country.latitude,
                                                       country.longitude);
        
        //Use the array index as the id
        marker.metaData = [NSString stringWithFormat:@"%d",i];
        
        //Use the countries population as the weight
        marker.weight = country.population;
        [countryAnnotations addObject:marker];
        [marker release];
    }
	
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarkerCreate;
	mapInfo.sqliteFileName = [MarkerTestData countryMarkerCachePath];
	mapInfo.zOrder = 20;
	mapInfo.meMarkerMapDelegate = self;
	mapInfo.markers = countryAnnotations;
	mapInfo.clusterDistance = 90;
	mapInfo.maxLevel = 8;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
    
    
    [countryAnnotations release];
    [self lookAtAtlantic];
    self.isRunning = YES;
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name clearCache:YES];
    self.isRunning = NO;
}

@end

/////////////////////////////////////////////////////////////////////////
@implementation MECountryMarkersFromDisk

- (id) init
{
    if(self = [super init])
    {
        self.name=@"Countries: From Disk Cache";
    }
    return self;
}

- (BOOL) isEnabled
{
    NSString* dbFileName = [MarkerTestData countryMarkerCachePath];
    return [[NSFileManager defaultManager]fileExistsAtPath:dbFileName];
}


- (void) start
{
    if(self.countries==nil)
    {
        self.countries = [MarkerTestData loadCountries];
    }
    
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarker;
	mapInfo.sqliteFileName = [MarkerTestData countryMarkerCachePath];
	mapInfo.zOrder = 20;
	mapInfo.meMarkerMapDelegate = self;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
    [self lookAtAtlantic];
    self.isRunning = YES;
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
								   clearCache:YES];
    self.isRunning = NO;
}

@end


//////////////////////////////////////////////////////////////////////
//Markers generated by metool
@implementation MEMTCountryMarkersFromDisk
- (id) init
{
    if(self = [super init])
    {
        self.name=@"Countries: From Bundle";
    }
    return self;
}

- (void) start
{
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarker;
	mapInfo.sqliteFileName = [MarkerTestData metoolMarkerBundlePath];
	mapInfo.zOrder = 22;
	mapInfo.meMarkerMapDelegate = self;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
	[self lookAtUnitedStates];
    self.isRunning = YES;
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
                                   clearCache:YES];
    self.isRunning = NO;
}

// Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView *)mapView
updateMarkerInfo:(MEMarkerInfo *)markerInfo
		 mapName:(NSString *)mapName
{
	//Scale marker font size based on population
	//The weight of the marker represents population
	double population = markerInfo.weight;
    float fontSize = 12.5f;
    if(population > 500000)
        fontSize = 15.0f;
    
    if(population > 1000000)
        fontSize = 17.5f;
    
    if(population > 10000000)
        fontSize = 20.0f;
    
    if(population > 100000000)
        fontSize = 22.5f;
    
    if(population > 200000000)
        fontSize = 25.0f;
	
    UIColor* fillColor = [UIColor whiteColor];
    UIColor* strokeColor = [UIColor blackColor];
    if(population > 300000000)
    {
        fillColor = [UIColor yellowColor];
        strokeColor = [UIColor blackColor];
        fontSize = 27.5f;
    }
	
    if(population > 500000000)
        fontSize = 30.0f;
	
    //Have the mapping engine create a label for us
    UIImage* textImage=[MEFontUtil newImageWithFontOutlined:@"Helvetica-Bold"
												fontSize:fontSize
											   fillColor:fillColor
											 strokeColor:strokeColor
											 strokeWidth:0
													text:markerInfo.metaData];
	
   
    //Create an anhor point based on the image size
    CGPoint anchorPoint = CGPointMake(textImage.size.width / 2.0,
                                      textImage.size.height / 2.0);
    //Update marker info
	markerInfo.uiImage = textImage;
	[textImage release];
	
	markerInfo.anchorPoint = anchorPoint;
}

- (void) tapOnMarker:(NSString*)metaData
           onMapView:(MEMapView*)mapView
       atScreenPoint:(CGPoint)point
{
    NSLog(@"Marker %@ was tapped on", metaData);
}
@end


///////////////////////////////////////////////////////////////////////////
//States and Provinces
@implementation MEMTStateMarkersFromDisk
- (id) init
{
    if(self = [super init])
    {
        self.name=@"States & Provinces: From Bundle";
    }
    return self;
}

- (void) start
{
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarker;
	mapInfo.sqliteFileName = [MarkerTestData stateMarkerBundlePath];
	mapInfo.zOrder = 21;
	mapInfo.meMarkerMapDelegate = self;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	

	[self lookAtUnitedStates];
    
    
    self.isRunning = YES;
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
                                   clearCache:YES];
    self.isRunning = NO;
}

@end

///////////////////////////////////////////////////////////////////////////
//States and Provinces
@implementation MEMTCountriesAndStateMarkersFromDisk
- (id) init
{
    if(self = [super init])
    {
        self.name=@"Countries and States: From Bundle";
    }
    return self;
}

- (void) start
{
	
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarker;
	mapInfo.sqliteFileName = [MarkerTestData countryAndStateMarkerBundlePath];
	mapInfo.zOrder = 21;
	mapInfo.meMarkerMapDelegate = self;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
   
	[self lookAtUnitedStates];
    self.isRunning = YES;
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
                                   clearCache:YES];
    self.isRunning = NO;
}
@end

///////////////////////////////////////////////////////////////////////////
//Cities
@implementation MEMTCitiesFromDisk
- (id) init
{
    if(self = [super init])
    {
        self.name=@"Cities: From Bundle";
    }
    return self;
}

- (void) start
{
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarker;
	mapInfo.sqliteFileName = [MarkerTestData citiesMarkerBundlePath];
	mapInfo.zOrder = 21;
	mapInfo.meMarkerMapDelegate = self;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
	[self lookAtUnitedStates];
    self.isRunning = YES;
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
                                   clearCache:YES];
    self.isRunning = NO;
}
@end

/////////////////////////////////////////////////////////////////////
//Aviation markers
//Tower height markers
@implementation METowersHeightsMarkersTest

- (id) init{
    if(self = [super init]){
        self.name=@"Aviation Towers: From Bundle";
    }
    return self;
}

-(NSString*) dbFile{
	return [MarkerTestData towerMarkerBundlePath];
}

- (void) start{
    //Add existing marker layer
	
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarker;
	mapInfo.sqliteFileName = [self dbFile];
	mapInfo.zOrder = 15;
	mapInfo.meMarkerMapDelegate = self;
	mapInfo.maxLevel=20;
    
    //[self.meMapViewController addVirtualMarkerMap:mapInfo];
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
    self.isRunning = YES;
    
    //[self lookAtUnitedStates];
}

- (void) stop{
    [self.meMapViewController removeMap:self.name
                                   clearCache:YES];
    self.isRunning = NO;
}

- (BOOL) isEnabled
{
    NSString* dbFileName = [self dbFile];
    return [[NSFileManager defaultManager]fileExistsAtPath:dbFileName];
}

// Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView *)mapView
updateMarkerInfo:(MEMarkerInfo *)markerInfo
		 mapName:(NSString *)mapName
{
    //Scale marker font size based on population
    float fontSize = 8.6f;
    UIColor* fillColor = [UIColor whiteColor];
    UIColor* strokeColor = [UIColor blackColor];
    //markerInfo.offset = CGPointMake(500,500);
	NSString* label;
	if(markerInfo.metaData.length==0){
		label = @"N/A";
	}
	else{
		label = markerInfo.metaData;
	}
    //Have the mapping engine create a label for us
    UIImage* textImage=[MEFontUtil newImageWithFontOutlined:@"Helvetica-Bold"
												fontSize:fontSize
											   fillColor:fillColor
											 strokeColor:strokeColor
											 strokeWidth:0
													text:label];
    
    //Craete an anhor point based on the image size
    CGPoint anchorPoint = CGPointMake(textImage.size.width / 2.0,
                                      textImage.size.height / 2.0);
    //Update marker info
	markerInfo.uiImage = textImage;
	markerInfo.anchorPoint = anchorPoint;
	markerInfo.nearestNeighborTextureSampling = YES;
	[textImage release];
}
@end

/////////////////////////////////////////////////////////////////////
//Aviation markers
//Tower height markers
@implementation METowersHeightsMarkersVirtualTest

- (id) init{
    if(self = [super init]){
        self.name=@"Aviation Towers: From Bundle Virtual";
    }
    return self;
}

- (void) start{
    //Add existing marker layer
	
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarker;
	mapInfo.sqliteFileName = [self dbFile];
	mapInfo.zOrder = 15;
	mapInfo.meMarkerMapDelegate = self;
	mapInfo.maxLevel=20;
    
    [self.meMapViewController addVirtualMarkerMap:mapInfo];
    self.isRunning = YES;
}

@end


@implementation METowersHeightsMarkersTestRandomFontSize

- (id) init
{
    if(self = [super init])
    {
        self.name=@"Aviation Towers: Random Font Size";
		self.fontSize = 5;
    }
    return self;
}


// Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView *)mapView
updateMarkerInfo:(MEMarkerInfo *)markerInfo
		 mapName:(NSString *)mapName
{
    //Scale marker font size based on population
    UIColor* fillColor = [UIColor whiteColor];
    UIColor* strokeColor = [UIColor blackColor];
    
    //Have the mapping engine create a label for us
    UIImage* textImage=[MEFontUtil newImageWithFontOutlined:@"Helvetica-Bold"
													  fontSize:self.fontSize
													 fillColor:fillColor
												   strokeColor:strokeColor
												   strokeWidth:0
														  text:markerInfo.metaData];
    
    //Craete an anhor point based on the image size
    CGPoint anchorPoint = CGPointMake(textImage.size.width / 2.0,
                                      textImage.size.height / 2.0);
    //Update marker info
	markerInfo.uiImage = textImage;
	markerInfo.anchorPoint = anchorPoint;
	markerInfo.nearestNeighborTextureSampling = YES;
	[textImage release];
	self.fontSize+=0.1;
	if(self.fontSize>15)
		self.fontSize = 4;
}


@end


@implementation METowersHeightsMarkersTestHalfHidden

- (id) init
{
    if(self = [super init])
    {
        self.name=@"Aviation Towers: Half Hidden";
    }
    return self;
}


// Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView *)mapView
updateMarkerInfo:(MEMarkerInfo *)markerInfo
		 mapName:(NSString *)mapName
{
	@synchronized(self)
	{
		self.isVisible = !self.isVisible;
	}
	if(self.isVisible)
	{
		return [super mapView:mapView updateMarkerInfo:markerInfo mapName:mapName];
	}
	else
	{
		markerInfo.isVisible = self.isVisible;
	}
}


@end

///////////////////////////////////////////////////////////
@implementation METAWSTowersCached

- (id) init
{
    if(self = [super init])
    {
        self.name=@"TAWS Towers Cached";
    }
    return self;
}

- (void) start
{
    //Add existing marker layer
	
	MEMarkerMapInfo* mapInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	mapInfo.name = self.name;
	mapInfo.mapType = kMapTypeFileMarker;
	mapInfo.sqliteFileName = [MarkerTestData towerMarkerBundlePath];
	mapInfo.zOrder = 14;
	mapInfo.meMarkerMapDelegate = self;
	mapInfo.fadeEnabled = NO;
	mapInfo.hitTestingEnabled = YES;
	mapInfo.markerImageLoadingStrategy=kMarkerImageLoadingSynchronous;
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
	
	
	//Create a color bar for ther marker map
	MEHeightColorBar* colorBar = [[[MEHeightColorBar alloc]init]autorelease];
	[colorBar addColor:[UIColor clearColor] atHeight:-1000.00001];
	[colorBar addColor:[UIColor yellowColor] atHeight:-1000];
	[colorBar addColor:[UIColor yellowColor] atHeight:-100.000001];
	[colorBar addColor:[UIColor redColor] atHeight:-100];
	
	//Add the color bar to the marker map
	[self.meMapViewController setMarkerMapColorBar:self.name
										  colorBar:colorBar];
	
	//Enable the color bar
	[self.meMapViewController setMarkerMapColorBarEnabled:self.name
												  enabled:YES];
	
	//Add a cached marker image
	UIImage* markerImage = [UIImage imageNamed:@"ShortTower"];
	self.markerAnchorPoint = CGPointMake(markerImage.size.width/2.0, 24.0);
	[self.meMapViewController addCachedMarkerImage:markerImage
										  withName:@"ShortTower"
								   compressTexture:YES
					nearestNeighborTextureSampling:YES];
	
    
    self.isRunning = YES;
    
    [self lookAtUnitedStates];
}

- (void) stop
{
    [self.meMapViewController removeMap:self.name
                                   clearCache:YES];
    self.isRunning = NO;
}

- (BOOL) isEnabled
{
    NSString* dbFileName =[MarkerTestData towerMarkerBundlePath];
    return [[NSFileManager defaultManager]fileExistsAtPath:dbFileName];
}

// Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView *)mapView
updateMarkerInfo:(MEMarkerInfo *)markerInfo
		 mapName:(NSString *)mapName
{
	markerInfo.cachedImageName = @"ShortTower";
	markerInfo.anchorPoint = self.markerAnchorPoint;
}

- (void) tapOnMarker:(NSString *)metaData onMapView:(MEMapView *)mapView atScreenPoint:(CGPoint)point
{
	NSLog(@"Tapped on %@", metaData);
}

@end


///////////////////////////////////////////////////////////
@implementation METAWSTowersNonCached

- (id) init
{
    if(self = [super init])
    {
        self.name=@"TAWS Towers Non-Cached";
    }
    return self;
}

- (void) stop
{
	[super stop];
	[self.meMapViewController removeMap:@"foo" clearCache:YES];
}

// Implement MEMarkerMapDelegate methods
- (void) mapView:(MEMapView *)mapView
updateMarkerInfo:(MEMarkerInfo *)markerInfo
		 mapName:(NSString *)mapName
{
	UIImage* markerImage;
	if([mapName isEqualToString:self.name])
	{
		markerImage = [UIImage imageNamed:@"ShortTower"];
		markerInfo.uiImage = markerImage;
		markerInfo.anchorPoint = CGPointMake(markerImage.size.width/2.0, 24.0);
	}
	else
	{
		markerImage = [UIImage imageNamed:@"quotebubble"];
		markerInfo.uiImage = markerImage;
		markerInfo.anchorPoint = CGPointMake(43,279);
	}
}

- (void) tapOnMarker:(NSString *)metaData onMapView:(MEMapView *)mapView atScreenPoint:(CGPoint)point
{
	[self.meMapViewController removeMap:@"foo" clearCache:YES];
	NSLog(@"Tapped on %@", metaData);
	MEMarkerMapInfo* markerInfo = [[[MEMarkerMapInfo alloc]init]autorelease];
	markerInfo.name = @"foo";
	markerInfo.mapType = kMapTypeDynamicMarker;
	markerInfo.markerImageLoadingStrategy = kMarkerImageLoadingSynchronous;
	markerInfo.zOrder = 200;
	markerInfo.meMarkerMapDelegate = self;
	
	[self.meMapViewController addMapUsingMapInfo:markerInfo];
	MEMarkerAnnotation* marker = [[[MEMarkerAnnotation alloc]init]autorelease];
	marker.coordinate = [self.meMapViewController.meMapView convertPoint:point];
	marker.metaData = @"Bruce";
	[self.meMapViewController addMarkerToMap:@"foo" markerAnnotation:marker];
}

@end


//////////////////////////////////////////////////////////////////////
@implementation MEMarkerPerfTest
- (id) init
{
    if(self = [super init])
    {
        self.name=@"Marker Perf Test";
    }
    return self;
}

- (void) start
{
	self.interval = 5.0;
	[self startTests];
	[super start];
}

- (void) startTests
{
	[self.meTestCategory stopAllTests];
	[self.meTestCategory startTestWithName:@"Bus Stops: In Memory"];
	[self.meTestCategory startTestWithName:@"Airports: From Bundle"];
	[self.meTestCategory startTestWithName:@"Countries and States: From Bundle"];
	[self.meTestCategory startTestWithName:@"Aviation Towers: From Bundle"];
	[self.meTestCategory startTestWithName:@"TAWS Aviation Towers: From Bundle"];
	self.isRunning = YES;
}

- (void) timerTick
{
	[self stop];
	[self start];
}

- (void) stop
{
	if(!self.isRunning)
		return;
	[super stop];
	self.isRunning = NO;
	[self.meTestCategory stopAllTests];
}

@end



