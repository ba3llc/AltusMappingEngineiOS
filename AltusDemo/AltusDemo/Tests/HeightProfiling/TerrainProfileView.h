//  Copyright (c) 2013 BA3, LLC. All rights reserved.
#pragma  once
#import <AltusMappingEngine/AltusMappingEngine.h>
#import <UIKit/UIKit.h>

@interface TerrainProfileView : UIView
@property (retain) NSArray* heightSamples;
@property (retain) NSArray* weightSamples;
@property (assign) CGFloat zeroOffset;
@property (assign) bool drawTerrainProfile;
@property (assign) CGFloat maxHeight;
- (void) setMaxHeightInFeet:(CGFloat) feet;
@end
