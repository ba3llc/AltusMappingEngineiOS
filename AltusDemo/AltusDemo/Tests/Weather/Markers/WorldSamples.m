//  Copyright (c) 2014 BA3, LLC. All rights reserved.
#import "WorldSamples.h"

@implementation WindGrid

-(void) readFromXYZ:(NSString*)filepath {
    NSMutableArray *values = [[NSMutableArray alloc]init];
    
    NSString *fileString = [NSString stringWithContentsOfFile:filepath
													 encoding:NSUTF8StringEncoding
														error:nil ];
    
	NSScanner *scanner = [NSScanner scannerWithString:fileString];
	
	[scanner setCharactersToBeSkipped: [NSCharacterSet characterSetWithCharactersInString:@"\n, "]];
	
    CLLocationCoordinate2D minCoord = CLLocationCoordinate2DMake(90, 180);
    CLLocationCoordinate2D maxCoord = CLLocationCoordinate2DMake(-90, -180);
    
    CLLocationCoordinate2D coord;
    double value;
    
    // for print stats
    double minValue = 1000;
    double maxValue = -1000;
    
    int coordCount = 0;
    while ([scanner scanDouble:&coord.longitude] &&
           [scanner scanDouble:&coord.latitude] &&
           [scanner scanDouble:&value]) {
        
        // find min
        if (coord.latitude < minCoord.latitude)
            minCoord.latitude = coord.latitude;
        if (coord.longitude < minCoord.longitude)
            minCoord.longitude = coord.longitude;
        
        // find max
        if (coord.latitude > maxCoord.latitude)
            maxCoord.latitude = coord.latitude;
        if (coord.longitude > maxCoord.longitude)
            maxCoord.longitude = coord.longitude;
        
        // store value
        [values addObject:[NSNumber numberWithDouble:value]];
        
        if (value < minValue) minValue = value;
        if (value > maxValue) maxValue = value;
        coordCount++;
    }
    
    minCoord = CLLocationCoordinate2DMake(-85, -180);
    maxCoord = CLLocationCoordinate2DMake(85, 180);
    
    numLongitudeValues = 400;
    numLatitudeValues = 200;
    
    self.deltaLongitude = (maxCoord.longitude - minCoord.longitude) / (numLongitudeValues + 1);
    self.deltaLatitude = (maxCoord.latitude - minCoord.latitude) / (numLatitudeValues + 1);
    self.minCoord = minCoord;
    self.maxCoord = maxCoord;
    
    valueArray = [values copy];
    
    /*
    NSLog(@"count: %d, min/max value: (%f, %f), min: (%f, %f), max: (%f, %f), dx: %f, dy: %f", coordCount, minValue, maxValue, minCoord.longitude, minCoord.latitude, maxCoord.longitude, maxCoord.latitude, self.deltaLongitude, self.deltaLatitude);*/
}

-(double) getValueAtCoordinate:(CLLocationCoordinate2D)coordinate {
    
    // compute normalized index;
    CGPoint floatIndex = CGPointMake((coordinate.longitude - self.minCoord.longitude) / (self.maxCoord.longitude - self.minCoord.longitude),
                                     (coordinate.latitude - self.minCoord.latitude) / (self.maxCoord.latitude - self.minCoord.latitude));
    // scale to array size
    floatIndex.x *= (numLongitudeValues - 1);
    floatIndex.y *= (numLatitudeValues - 1);
    
    // get nearest discrete index
    int x = roundf(floatIndex.x);
    int y = roundf(floatIndex.y);
    
    // clamp
    if (x < 0) x = 0;
    if (x >= numLongitudeValues) x = numLongitudeValues - 1;
    if (y < 0) y = 0;
    if (y >= numLatitudeValues) y = numLatitudeValues - 1;
    
    // flatten to 1d index
    int index = x + y * numLongitudeValues;
    return [[valueArray objectAtIndex:index] doubleValue];
}

-(BOOL) containsCoordinate:(CLLocationCoordinate2D)coordinate {
    
    // support half a sample extra on both dimensions
    double dx = self.deltaLongitude * 0.4999;
    double dy = self.deltaLatitude * 0.4999;
    
    return  (coordinate.longitude > self.minCoord.longitude - dx) &&
    (coordinate.latitude > self.minCoord.latitude - dy) &&
    (coordinate.longitude < self.maxCoord.longitude + dx) &&
    (coordinate.latitude < self.maxCoord.latitude + dy);
}

-(BOOL) intersectsRect:(CGRect)rect {
    
    // build rect out of min/max bounds
    CGRect gridRect = CGRectMake(self.minCoord.longitude,
                                 self.minCoord.latitude,
                                 self.maxCoord.longitude - self.minCoord.longitude,
                                 self.maxCoord.latitude - self.minCoord.latitude);
    return CGRectIntersectsRect(gridRect, rect);
}

@end

@implementation WorldMarkerTileProvider

- (id) init{
	if(self = [super init]){
		self.isAsynchronous = YES;
	}
	return self;
}

- (MEMarker*) createMarkerWithName:(NSString*)name
                      andImageName:(NSString*)imageName
                       andLocation:(CLLocationCoordinate2D)location
                       andRotation:(double)rotation
{
	MEMarker* marker = [[MEMarker alloc]init];
	marker.uniqueName = name;
	marker.cachedImageName = imageName;
    
	marker.compressTexture = NO;
	marker.location = location;
    marker.rotation = rotation;
	marker.anchorPoint = CGPointMake(1, 33);
    
    return marker;
}

double GetMarkerSpacing(uint targetPixelSpacing, double tileStart, double tileEnd, double targetIncrement) {
    
    // width of the tile in geographic coords (todo: meters)
    double tileWidth = tileEnd - tileStart;
    
    // get the target number of markers along one side of the tile
    double targetPerTile = 256.0 / targetPixelSpacing;
    double spacing = tileWidth / targetPerTile;
    
    spacing /= targetIncrement;
    
    // compute a power of 2 subdivision
    double power = log2(spacing);
    double powerClamped = pow(2, floor(power));
    return powerClamped * targetIncrement;
}

double GetClosestGreaterIncrement(double value, double increment) {
    double result = value - fmodf(value, increment);
    if (value >= 0)
        result += increment;
    
    return result;
}

double GetIncrementNearValue(double value, double increment, double startValue) {
    
    // get smallest increment >= 0
    double startIncrement = fmodf(startValue, increment);
    if (startIncrement < 0)
        startIncrement += increment;
    
    // offset value so we get an increment that lies along the data
    double offsetValue = value - startIncrement;
    
    // get increment less than value
    value = value - fmodf(offsetValue, increment);
    
    // get next greatest value
    if (offsetValue > 0)
        value += increment;
    
    return value;
}

double GetPoleScaledPixelSpacing(double targetPixelSpacing, METileProviderRequest *tileRequest) {
    const int MaxLevelScale = 13;
    const int PolePixelSpacing = targetPixelSpacing * 10;
    
    // get tile level
    uint tileLevel = tileRequest.uid & 0x1F;
    double levelScale = (MaxLevelScale - (double)tileLevel) / MaxLevelScale;
    double latitudeScale = 1 - (90 - fabs(tileRequest.maxY + tileRequest.minY) * 0.5) / 90;
    
    latitudeScale = MIN(MAX(0, latitudeScale), 1.0);
    latitudeScale = pow(latitudeScale, 4);
    
    levelScale = MIN(MAX(0, levelScale), 1.0);
    return targetPixelSpacing + levelScale * latitudeScale * (PolePixelSpacing - targetPixelSpacing);
}

- (void) requestTileAsync:(METileProviderRequest *)meTileRequest{
    
    NSMutableArray *markers = [[NSMutableArray alloc] init];
    
    CGRect bounds = CGRectMake(meTileRequest.minX,
                               meTileRequest.minY,
                               meTileRequest.maxX - meTileRequest.minX,
                               meTileRequest.maxY - meTileRequest.minY);
    
    double pixelSpacing = GetPoleScaledPixelSpacing(50, meTileRequest);
    
    if ([self.windSpeedGrid intersectsRect:bounds]) {
        
        double spacingX = GetMarkerSpacing(pixelSpacing, meTileRequest.minX, meTileRequest.maxX, self.windSpeedGrid.deltaLongitude);
        double startX = GetIncrementNearValue(meTileRequest.minX, spacingX, self.windSpeedGrid.minCoord.longitude);
        double endX = GetIncrementNearValue(meTileRequest.maxX, spacingX, self.windSpeedGrid.minCoord.longitude);
        
        double spacingY = GetMarkerSpacing(pixelSpacing, meTileRequest.minY, meTileRequest.maxY, self.windSpeedGrid.deltaLatitude);
        double startY = GetIncrementNearValue(meTileRequest.minY, spacingY, self.windSpeedGrid.minCoord.latitude);
        double endY = GetIncrementNearValue(meTileRequest.maxY, spacingY, self.windSpeedGrid.minCoord.latitude);
        
        for (double x = startX; x < endX; x += spacingX) {
            for (double y = startY; y < endY; y += spacingY) {
                
                CLLocationCoordinate2D location = CLLocationCoordinate2DMake(y, x);
                
                // skip if location not in dataset
                if (![self.windSpeedGrid containsCoordinate:location]) {
                    continue;
                }
                
                //Get  unique name
                NSString *name = [NSString stringWithFormat:@"%d", self.count];
                self.count++;
                
                
                double windSpeed = [self.windSpeedGrid getValueAtCoordinate:location];
                double rotation = [self.windDirectionGrid getValueAtCoordinate:location];
                
                // scale up wind speed to look better! hackathon
                windSpeed *= 4;
                NSString *imageName = [WorldSamples getWindBarbNameForWindSpeed:windSpeed];
                MEMarker* rdu = [self createMarkerWithName:name
                                              andImageName:imageName
                                               andLocation:location
                                               andRotation:rotation];
                [markers addObject:rdu];
            }
        }
    }
    
    [self.meMapViewController markerTileLoadComplete:meTileRequest
                                         markerArray:[NSArray arrayWithArray:markers]];
}

@end

@implementation WorldSamples

- (id) init
{
    if(self = [super init])
    {
        self.name=@"World Samples";
    }
    return self;
}

- (void) beginTest
{
    WindGrid *windSpeedGrid = [[WindGrid alloc]init];
    [windSpeedGrid readFromXYZ:[[NSBundle mainBundle] pathForResource:@"ds.wspd" ofType:@"xyz"]];
    
    WindGrid *windDirectionGrid = [[WindGrid alloc]init];
    [windDirectionGrid readFromXYZ:[[NSBundle mainBundle] pathForResource:@"ds.wdir" ofType:@"xyz"]];
    
	//Create tile provider
	WorldMarkerTileProvider *tileProvider = [[WorldMarkerTileProvider alloc]init];
	tileProvider.meMapViewController = self.meMapViewController;
    tileProvider.windSpeedGrid = windSpeedGrid;
    tileProvider.windDirectionGrid = windDirectionGrid;
	
	//Create virtual map info
    MEVirtualMarkerMapInfo* mapInfo = [[MEVirtualMarkerMapInfo alloc]init];
    mapInfo.name = self.name;
    mapInfo.hitTestingEnabled = NO;
	mapInfo.meTileProvider = tileProvider;
	mapInfo.zOrder = 30;
	
	
    //Cache images
    for (int i = 0; i <= 40; i+= 5) {
        NSString *imageName = [WorldSamples getWindBarbNameForWindSpeed:i];
        UIImage *image = [UIImage imageNamed:imageName];
        [self.meMapViewController addCachedMarkerImage:image
                                              withName:imageName
                                       compressTexture:NO
                        nearestNeighborTextureSampling:NO];
    }
    
	//Add map
	[self.meMapViewController addMapUsingMapInfo:mapInfo];
}

+ (NSString*) getWindBarbNameForWindSpeed:(double)windSpeed {
    if (windSpeed > 40) windSpeed = 40;
    if (windSpeed < 0) windSpeed = 0;
    
    int windIndex = ((int)roundf(windSpeed/5)) * 5;
    
    return [NSString stringWithFormat:@"knots%d", windIndex];
}

- (void) endTest
{
    [self.meMapViewController removeMap:self.name
                             clearCache:YES];
}

@end
