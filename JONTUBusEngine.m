//
//  JONTUBusEngine.m
//  NTUBusArrival
//
//  Created by Jeremy Foo on 3/26/10.
//  Copyright 2010 THIRDLY. All rights reserved.
//

#import "JONTUBusEngine.h"
#import "RegexKitLite.h"

@implementation JONTUBusEngine

@synthesize dirty, holdCache;

static NSString *getBusPosition = @"http://campusbus.ntu.edu.sg/ntubus/index.php/main/getCurrentPosition";
static NSString *getEta = @"http://campusbus.ntu.edu.sg/ntubus/index.php/xml/getEta";
static NSString *indexPage = @"http://campusbus.ntu.edu.sg/ntubus/";

static NSString *regexBusStop = @"ntu.busStop.push\\(\\{\\s*id:(\\d*),\\s*code:(\\d*),\\s*description:\"(.*)\",\\s*roadName:\"(.*)\",\\s*x:([\\d.]*),\\s*y:([\\d.]*),\\s*lon:([\\d.]*),\\s*lat:([\\d.]*),\\s*otherBus:\"(.*)\",\\s*marker:.*,\\s*markerShadow:.*\\s*\\}\\);";
static NSString *regexRoute = @"ntu.routes.push\\(\\{\\s*id:([\\d]*),\\s*name:\"(.*)\",\\s*centerMetric:.*,\\s*centerLonLat:new GeoPoint\\(([\\d.]*), ([\\d.]*)\\),\\s*color:.*,\\s*colorAlt:.*,\\s*zone:.*,\\s*busStop:.*\\s*\\}\\);";

SYNTHESIZE_SINGLETON_FOR_CLASS(JONTUBusEngine);

-(void)start {
	stops = [[NSMutableArray array] retain];
	routes = [[NSMutableArray array] retain];
	buses = [[NSMutableArray array] retain];
}

-(JONTUBusStop *)stopForId:(NSUInteger)stopid {
	for (JONTUBusStop *stop in [self stops]) {
		if ([stop busstopid] == stopid) {
			return stop;
		}
	}
	return nil;
}

-(NSArray *)stops {
	return [self stopsWithRefresh:NO];
}

-(NSArray *)stopsWithRefresh:(BOOL)refresh {
	if (refresh) {
		dirty = YES;
		NSString *matchString = [[NSString alloc] initWithData:[self getIndexPage] encoding:NSASCIIStringEncoding];
		NSArray *busstops = [matchString arrayOfCaptureComponentsMatchedByRegex:regexBusStop];
		JONTUBusStop *stop;
		
		[stops removeAllObjects];
		[matchString release];
			
		for (int i=0;i<[busstops count];i++) {
			
			stop = [[JONTUBusStop alloc] initWithID:[[[busstops objectAtIndex:i] objectAtIndex:1] intValue] code:[busstops objectAtIndex:2] 
										description:[[busstops objectAtIndex:i] objectAtIndex:3] 
										   roadName:[[busstops objectAtIndex:i] objectAtIndex:4]
										 longtitude:[[busstops objectAtIndex:i] objectAtIndex:7]
										   latitude:[[busstops objectAtIndex:i] objectAtIndex:8]
										 otherBuses:[[[busstops objectAtIndex:i] objectAtIndex:9] componentsSeparatedByString:@","]];
			[stops addObject:stop];
			[stop release];
		}
	}
	return stops;
}

-(JONTUBusRoute *)routeForId:(NSUInteger)routeid {
	for (JONTUBusRoute *route in [self routes]) {
		if ([route routeid] == routeid) {
			return route;
		}
	}
	return nil;
}

-(JONTUBusRoute *)routeForName:(NSString *)routename {
	for (JONTUBusRoute *route in [self routes]) {
		if ([[route name] isEqualToString:routename]) {
			return route;
		}
	}
	return nil;
	
}

-(NSArray *)routes {
	return [self routesWithRefresh:NO];
}

-(NSArray *)routesWithRefresh:(BOOL)refresh {
	
	if (refresh) {
		dirty = YES;		
		NSString *matchString = [[NSString alloc] initWithData:[self getIndexPage] encoding:NSASCIIStringEncoding];
		NSArray *busroutes = [matchString arrayOfCaptureComponentsMatchedByRegex:regexRoute];
		JONTUBusRoute *route;
		
		[routes removeAllObjects];
		[matchString release];	
		
		for (int i=0;i<[busroutes count];i++) {
			route = [[JONTUBusRoute alloc] initWithID:[[[busroutes objectAtIndex:i] objectAtIndex:1] intValue] 
												 name:[[busroutes objectAtIndex:i] objectAtIndex:2] stops:nil];
			[routes addObject:route];
			[route release];
			
		}		
	}
	
	return routes;
}

-(NSArray *)buses {
	return [self busesWithRefresh:NO];
}

-(NSArray *)busesWithRefresh:(BOOL)refresh {
	[buses removeAllObjects];
	
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[self sendXHRToURL:getBusPosition PostValues:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%f", (float)arc4random()/10000000000] forKey:@"r"]]];
						   
	[parser setDelegate:self];
	[parser setShouldProcessNamespaces:NO];
	[parser setShouldReportNamespacePrefixes:NO];
	[parser setShouldResolveExternalEntities:NO];
	
	[parser parse];
	[parser release];
	
	return buses;
}

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	JONTUBus *bus;
	
	if ([elementName isEqualToString:@"device"]) {
		NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
		[f setNumberStyle:NSNumberFormatterNoStyle];

		
		bus = [[JONTUBus alloc] initWithID:[[attributeDict objectForKey:@"id"] intValue]
									 route:[self routeForName:[attributeDict objectForKey:@"routename"]] 
							   plateNumber:[attributeDict objectForKey:@"name"] 
								longtitude:[f numberFromString:[attributeDict objectForKey:@"lon"]]
								  latitude:[f numberFromString:[attributeDict objectForKey:@"lat"]]
									 speed:[[attributeDict objectForKey:@"speed"] intValue]
									  hide:([attributeDict objectForKey:@"stat"] == @"hide")?YES:NO 
							   iscDistance:[f numberFromString:[attributeDict objectForKey:@"iscdistance"]]];
		[buses addObject:bus];
		
		[f release];
		[bus release];
	}
}

-(NSData *) getIndexPage {
	if (holdCache < 0) {
		if (indexPageCache == nil) {
			indexPageCache = [[self sendXHRToURL:indexPage PostValues:nil] retain];
			lastGetIndexPage = [NSDate date];
		} else {
			return indexPageCache;
		}
	} else {
		if (indexPageCache == nil) {
			indexPageCache = [[self sendXHRToURL:indexPage PostValues:nil] retain];
			lastGetIndexPage = [NSDate date];
		}		
		if ([[NSDate date] timeIntervalSinceDate:lastGetIndexPage] > holdCache) {
			[indexPageCache release];
			indexPageCache = [[self sendXHRToURL:indexPage PostValues:nil] retain];
			[lastGetIndexPage release];
			lastGetIndexPage = [NSDate date];
		}		
	}
	return indexPageCache;
}

-(NSData *) sendXHRToURL:(NSString *)url PostValues:(NSDictionary *)postValues {

	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

	if (postValues != nil) {
	
		NSMutableString *post = [NSMutableString string];
		for (NSString *key in postValues) {
			if ([post length] > 0) {
				[post appendString:@"&"];
			}
			[post appendFormat:@"%@=%@",key,[postValues objectForKey:key]];
		}
		
		NSLog(@"Post String: %@", post);
		NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
		[request setHTTPMethod:@"POST"];
		[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
		[request setHTTPBody:postData];
		
	}
	
	[request setURL:[NSURL URLWithString:url]];
	
	NSData *recvData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
	
	[request release];
	
	return recvData;
}

-(void)dealloc {
	[buses release];
	[stops release];
	[routes release];
	[super dealloc];
}

@end
