//
//  FTLocationSimulator.m
//
//  Created by Ortwin Gentz on 23.09.2010.
//  Copyright 2010 FutureTap http://www.futuretap.com
//  All rights reserved.
//
//  Permission is given to use this source code file without charge in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.

#import "FTLocationSimulator.h"
#import "FTSynthesizeSingleton.h"
#import "RegexKitLite.h"
#import "GeoUtilities.h"

@implementation FTLocationSimulator

SYNTHESIZE_SINGLETON_FOR_CLASS(FTLocationSimulator)

@synthesize location;
@synthesize oldLocation;
@synthesize delegate;
@synthesize distanceFilter;
@synthesize purpose;
@synthesize mapView;

- (void)dealloc
{
	[mapView release];
	mapView = nil;

	[location release];
	location = nil;

	[purpose release];
	purpose = nil;
	
	[super dealloc];
}

- (void)fakeNewLocation {
	// read and parse the KML file
	if (!fakeLocations) {
		NSString *fakeLocationsPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"FakeLocationsRoute"];
		if(!fakeLocationsPath)
			fakeLocationsPath = [[NSBundle mainBundle] pathForResource:@"fakeLocations" ofType:@"kml"];
        
        NSStringEncoding    enc; 
        NSError             *error = nil;
        
		NSString *fakeLocationsFile = [[NSString alloc] initWithContentsOfFile:fakeLocationsPath
                                       usedEncoding:&enc error:&error];
        if ( error == nil ) {
            NSString *coordinatesString = [fakeLocationsFile stringByMatching:@"<coordinates>[^-0-9]*(.+?)[^-0-9]*</coordinates>"
                                                                      options:RKLMultiline|RKLDotAll 
                                                                      inRange:NSMakeRange(0, fakeLocationsFile.length) 
                                                                      capture:1
                                                                        error:NULL];
            NSScanner *scanner = [NSScanner scannerWithString:coordinatesString];
            while ([scanner isAtEnd] == NO) {
                NSString *coordinate = nil;
                [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&coordinate];
                if (fakeLocations == nil)
                    fakeLocations = [[NSMutableArray alloc] init];
                [(NSMutableArray*)fakeLocations addObject:coordinate];
            }
            
            if([[NSUserDefaults standardUserDefaults] objectForKey:@"FakeLocationsUpdateInterval"])
                updateInterval = [[NSUserDefaults standardUserDefaults] doubleForKey:@"FakeLocationsUpdateInterval"];
            else
                updateInterval = FAKE_CORE_LOCATION_UPDATE_INTERVAL;
        } else {
            NSLog(@"initWithContentsOfFile error, file : %@, error: %@", fakeLocationsPath, error);
            [error release];
        }
        [fakeLocationsFile release];
	}
	// select a new fake location
	NSArray *latLong = [[fakeLocations objectAtIndex:index] componentsSeparatedByString:@","];
	CLLocationDegrees   lat = [[latLong objectAtIndex:1] doubleValue];
	CLLocationDegrees   lon = [[latLong objectAtIndex:0] doubleValue];
    CLLocationDirection currCourse = 0;
    CLLocationSpeed     currSpeed = defaultSpeed+(rand()%10 < 5 ? -1.0 : 1.0)*(double)(defaultSpeed/5.0 * (float)rand()/(float)RAND_MAX);
    
    if ( index 		) {
        currCourse = [GeoUtilities courseFromWayPoint1:oldLocation.coordinate toWayPoint2:CLLocationCoordinate2DMake(lat, lon)];
 		CLLocationDistance	dist = [GeoUtilities distanceBetweenWayPoint1:oldLocation.coordinate andWayPoint2:CLLocationCoordinate2DMake(lat, lon)];
        NSDate              *timeStamp = [[NSDate dateWithTimeInterval:dist/currSpeed sinceDate:lastTimeStamp] retain];
        
        [lastTimeStamp release];
        lastTimeStamp = timeStamp;
    }

	self.location = [[[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
												   altitude:0
										 horizontalAccuracy:1
										   verticalAccuracy:0
                                                     course:currCourse
                                                      speed:currSpeed
												  timestamp:lastTimeStamp] autorelease];
	
	// update the userlocation view
	if (self.mapView) {
		MKAnnotationView *userLocationView = [self.mapView viewForAnnotation:self.mapView.userLocation];
		[userLocationView.superview sendSubviewToBack:userLocationView];
		
 		CGRect frame = userLocationView.frame;
		frame.origin = [self.mapView convertCoordinate:self.location.coordinate toPointToView:userLocationView.superview];
		frame.origin.x -= 10;
		frame.origin.y -= 10;
		[UIView beginAnimations:@"fakeUserLocation" context:nil];
		[UIView setAnimationDuration:updateInterval];
		[UIView setAnimationCurve:UIViewAnimationCurveLinear];
		userLocationView.frame = frame;
		[UIView commitAnimations];

		[self.mapView.userLocation setCoordinate:self.location.coordinate];
	}

	// inform the locationManager delegate
	if((!self.oldLocation || [self.location distanceFromLocation:oldLocation] > distanceFilter) &&
	   [self.delegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
		[self.delegate locationManager:nil
				   didUpdateToLocation:self.location
						  fromLocation:oldLocation];
		self.oldLocation = self.location;
	}
	
	// iterate to the next fake location
	if (updatingLocation) {
		index++;
		if (index == fakeLocations.count) {
			index = 0;
		}
	
		[self performSelector:@selector(fakeNewLocation) withObject:nil afterDelay:updateInterval];
	}
}

- (void)startUpdatingLocation {
	updatingLocation = YES;
    defaultSpeed = FAKE_CORE_LOCATION_DEFAULT_SPEED;
    lastTimeStamp = [[NSDate dateWithTimeIntervalSinceNow:0] retain];

	[self fakeNewLocation];
}

- (void)stopUpdatingLocation {
	updatingLocation = NO;
}

- (MKAnnotationView*)fakeUserLocationView {
	if (!self.mapView) {
		return nil;
	}

	[self.mapView.userLocation setCoordinate:self.location.coordinate];
	MKAnnotationView *userLocationView = [[MKAnnotationView alloc] initWithAnnotation:self.mapView.userLocation reuseIdentifier:nil];
	[userLocationView addSubview:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"TrackingDot.png"]]];
	userLocationView.centerOffset = CGPointMake(-10, -10);
	return userLocationView;
}


// dummy methods to keep the CLLocationManager interface
+ (BOOL)locationServicesEnabled {
	return [FTLocationSimulator sharedInstance].locationServicesEnabled;
}
+ (BOOL)headingAvailable {
	return NO;
}
+ (BOOL)significantLocationChangeMonitoringAvailable {
	return NO;
}
+ (BOOL)regionMonitoringAvailable {
	return NO;
}
+ (BOOL)regionMonitoringEnabled {
	return NO;
}
+ (CLAuthorizationStatus)authorizationStatus {
	return kCLAuthorizationStatusAuthorized;
}
- (BOOL)locationServicesEnabled {
	return updatingLocation;
}
- (CLLocationAccuracy) desiredAccuracy {
	return kCLLocationAccuracyBest;
}
- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy {
}
- (BOOL)headingAvailable {
	return NO;
}
- (CLLocationDegrees) headingFilter {
	return kCLHeadingFilterNone;
}
- (void)setHeadingFilter:(CLLocationDegrees)headingFilter {
}
- (CLDeviceOrientation) headingOrientation {
	return CLDeviceOrientationPortrait;
}
- (void)setHeadingOrientation:(CLDeviceOrientation)headingOrientation {
}
- (CLHeading*) heading {
	return nil;
}
- (CLLocationDistance) maximumRegionMonitoringDistance {
	return kCLErrorRegionMonitoringFailure;
}
- (NSSet*)monitoredRegions {
	return nil;
}
- (void)startUpdatingHeading {
}
- (void)stopUpdatingHeading {
}
- (void)dismissHeadingCalibrationDisplay {
}
- (void)startMonitoringSignificantLocationChanges {
}
- (void)stopMonitoringSignificantLocationChanges {
}
- (void)startMonitoringForRegion:(CLRegion*)region desiredAccuracy:(CLLocationAccuracy)accuracy {
}
- (void)stopMonitoringForRegion:(CLRegion*)region {
}
@end 