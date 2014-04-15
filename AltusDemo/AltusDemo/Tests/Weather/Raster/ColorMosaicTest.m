//  Copyright (c) 2014 BA3, LLC. All rights reserved.
#import "ColorMosaicTest.h"

@implementation ColorMosaicTileProvider

- (CGRect) getSubsetInRect:(CGRect)parent withChildRect:(CGRect)child {
    return CGRectMake((child.origin.x - parent.origin.x) / parent.size.width,
                      (child.origin.y - parent.origin.y) / parent.size.height,
                      child.size.width / parent.size.width,
                      child.size.height / parent.size.height);
}

- (UIImage*) imageFromBytes:(unsigned char *)bytes {
    const int WIDTH = 256;
    const int HEIGHT = 256;
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext=CGBitmapContextCreate(bytes, WIDTH, HEIGHT, 8, 4*WIDTH, colorSpace,  kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CFRelease(colorSpace);
    CGImageRef cgImage=CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease(bitmapContext);
    
    UIImage * newimage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return newimage;
}

- (double) mercatorLatitude:(double) coord
{
    coord = coord * M_PI / 180.0;
    double result = log(tan(coord) + 1/cos(coord));
    return result;
}

- (double) inverseMercatorLatitude:(double)coord
{
    coord = atan(sinh(coord));
    return coord * 180.0 / M_PI;
}

- (void) requestTileAsync:(METileProviderRequest *)meTileRequest{
 
    // get the geographic bounds of the tile (block to use in block below)
    __block CGRect tileBounds = CGRectMake(meTileRequest.minX,
                                   meTileRequest.minY,
                                   meTileRequest.maxX - meTileRequest.minX,
                                   meTileRequest.maxY - meTileRequest.minY);
    
    // filter out tiles outside of bounds
    if (!CGRectIntersectsRect(tileBounds, self.grid.bounds)) {
        meTileRequest.tileProviderResponse = kTileResponseTransparentWithChildren;
        [self.meMapViewController tileLoadComplete:meTileRequest];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        

        // size of the tile image
        const int WIDTH = 256;
        const int HEIGHT = 256;
        
        // allocate data for the tile image and clear it
        unsigned char *imageData = (unsigned char*)malloc(WIDTH * HEIGHT * 4);
        memset(imageData, 0, WIDTH * HEIGHT * 4);
        
        // get mercator latitude bounds
        double normalizedMinY = [self mercatorLatitude:meTileRequest.minY];
        double normalizedMaxY = [self mercatorLatitude:meTileRequest.maxY];
        
        for (int y = 0; y < HEIGHT; ++y) {
            
            // interpolate y coordinate in mercator space
            double t = (y + 0.5) / HEIGHT;
            double mercatorY = normalizedMinY + t * (normalizedMaxY - normalizedMinY);

            // convert mercator space y to latitude
            CLLocationCoordinate2D sampleLocation;
            sampleLocation.latitude = [self inverseMercatorLatitude:mercatorY];
            
            for (int x = 0; x < WIDTH; ++x) {
                
                // interpolate x coordinate
                double s = (x + 0.5) / WIDTH;
                sampleLocation.longitude = tileBounds.origin.x + s * tileBounds.size.width;
                
                // filter out pixels outside bounds
                if (!CGRectContainsPoint(self.grid.bounds, CGPointMake(sampleLocation.longitude, sampleLocation.latitude)))
                    continue;
                
                // get value from source data at location
                double value = [self.grid getValueForLocationBilinear:sampleLocation];
                
                // invert Y index because images start with y = 0 at the top
                int invY = HEIGHT - y - 1;
                
                // get uint color
                uint color = [self.grid getColorForValue:value];
                
                // swap bytes in uint color in order to assign them to a byte array
                unsigned char *pixel = &imageData[(x + invY * WIDTH)*4];
                pixel[0] = (color & 0xff000000) >> 24;
                pixel[1] = (color & 0xff0000) >> 16;
                pixel[2] = (color & 0xff00) >> 8;
                pixel[3] = (color & 0xff);
            }
        }

        
        //Load complete
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIImage *result = [self imageFromBytes:imageData];
            free(imageData);
            
            meTileRequest.uiImage = result;
            meTileRequest.isOpaque = NO;
            meTileRequest.tileProviderResponse = kTileResponseRenderUIImage;
            [self.meMapViewController tileLoadComplete:meTileRequest];
        });
    });

}

@end

@implementation ColorMosaicTest

- (id) init{
    if(self = [super init]){
        self.name=@"Color Mosaic Test";
    }
    return self;
}

- (void) start{
    
    if(self.isRunning){
        return;
    }
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"ds.temp.bin" ofType:@"txt"];
    DataGrid *grid = [[DataGrid alloc] initWithFile:path
                                            andWidth:860
                                           andHeight:430
                                           andBounds:CGRectMake(-130, 20, 67, 30)];

    
    ColorMosaicTileProvider *tileProvider = [[ColorMosaicTileProvider alloc]init];
    tileProvider.meMapViewController = self.meMapViewController;
    tileProvider.isAsynchronous = YES;
    tileProvider.grid = grid;
    
    MEVirtualMapInfo *mapInfo = [[MEVirtualMapInfo alloc]init];
    mapInfo.name = self.name;
    mapInfo.mapType = kMapTypeVirtualRaster;
    mapInfo.zOrder = 20;
    mapInfo.maxLevel = 20;
    mapInfo.meTileProvider = tileProvider;
    mapInfo.isSphericalMercator = NO;
    
    [self.meMapViewController addMapUsingMapInfo:mapInfo];
    self.isRunning = YES;
}

- (void) stop{
    
    if(!self.isRunning){
        return;
    }
    
    //Remove the map
    [self.meMapViewController removeMap:self.name
                             clearCache:YES];
    self.isRunning = NO;
}

@end

@implementation ColorMosaicNativeTest


- (id) init{
    if(self = [super init]){
        self.name=@"Color Mosaic Native Test";
    }
    return self;
}

- (void) start{
    
    if(self.isRunning){
        return;
    }
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"ds.temp.bin" ofType:@"txt"];
    
    int width = 860;
    int height = 430;
    double *data = [self loadData:path withWidth:width andHeight:height];
    
//    // convert data from kelvin to fahrenheit
//    int dataCount = width * height;
//    for (int i = 0; i < dataCount; ++i) {
//        data[i] = (data[i] - 273.15) * 1.8000 + 32.00;
//    }
    
    [self.meMapViewController addDataGridMap:self.name
                                   withArray:data
                                   withWidth:width
                                  withHeight:height
                                  withBounds:CGRectMake(-130, 20, 67, 30)];

    self.isRunning = YES;
}

- (void) stop{
    
    if(!self.isRunning){
        return;
    }
    
    //Remove the map
    [self.meMapViewController removeMap:self.name
                             clearCache:YES];
    self.isRunning = NO;
}

- (double*) loadData:(NSString*)filePath withWidth:(int)width andHeight:(int)height {
    // read file into a string
    NSString *fileString = [NSString stringWithContentsOfFile:filePath
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil ];

    // set up scanner to scan through string
    NSScanner *scanner = [NSScanner scannerWithString:fileString];
    [scanner setCharactersToBeSkipped: [NSCharacterSet characterSetWithCharactersInString:@"\n, "]];

    // allocate the array of data
    uint capacity = width * height;
    double *dataArray = (double *)malloc(capacity * sizeof(double));

    // scan through data
    double value;
    int count = 0;
    while ([scanner scanDouble:&value] ) {
        dataArray[count++] = value;
    }
    
    return dataArray;
}

@end