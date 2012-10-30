//	  QuickCHM a CHM Quicklook plgin for Mac OS X 10.5
//
//    Copyright (C) 2007  Qian Qian (qiqian82@gmail.com)
//
//    QuickCHM is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    QuickCHM is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "CHMURLProtocol.h"
#import "CHMContainer.h"
#import "QuickChmPageAdaptor.h"


static NSMutableDictionary *containerReg = nil;

@implementation CHMURLProtocol

#pragma mark Lifecycle

-(id)initWithRequest:(NSURLRequest *)request
      cachedResponse:(NSCachedURLResponse *)cachedResponse
	      client:(id <NSURLProtocolClient>)client
{
    return [super initWithRequest:request cachedResponse:cachedResponse client:client];
}

#pragma mark CHM URL utils

+ (NSURL *)URLWithPath:(NSString *)path inContainer:(CHMContainer *)container
{
    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"quickchm://%@/", [container uniqueId]]];
    NSURL *url = [NSURL URLWithString:path relativeToURL:baseURL];
    
    if( baseURL && url == nil ) {
	// Something is wrong, perhaps path is not well-formed. Try percent-
	// escaping characters. It's not clear what encoding should be used,
	// but for now let's just use Latin1.
	CFStringRef str = CFURLCreateStringByAddingPercentEscapes(
            nil,                                // allocator
            (CFStringRef)path,                  // <#CFStringRef originalString#>
	    (CFStringRef)@"%#",                 // <#CFStringRef charactersToLeaveUnescaped#>
	    nil,                                // <#CFStringRef legalURLCharactersToBeEscaped#>,
	    kCFStringEncodingWindowsLatin1      //<#CFStringEncoding encoding#>
        );
        
        url = [NSURL URLWithString:(NSString*)str relativeToURL:baseURL];
        [(id)str release];
    }
    
    return url;
}


#pragma mark NSURLProtocol overriding
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	DEBUG_OUTPUT(@"Load URL query");
	NSURL *url = [request URL];
	NSString *scheme = [url scheme];
	NSString *host = [url host];
	return [scheme isEqualToString:@"quickchm"] ||
			([host isEqualToString:@"quickchm.href"] && [scheme isEqualToString:@"file"]) ||
			([host isEqualToString:@"quickchm.img"] && [scheme isEqualToString:@"file"]);	
}


+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}


-(void)startLoading
{
	NSURL *url = [[self request] URL];
	BOOL processingHtml = NO;
	NSString *host = [url host];
	if ([host isEqualToString:@"quickchm.href"]) {
		url = [NSURL URLWithString:[[url absoluteString] stringByReplacingOccurrencesOfString:@"file://quickchm.href/" withString:@"quickchm://"]];
		processingHtml = YES;
	} else if ([host isEqualToString:@"quickchm.img"]) {
		url = [NSURL URLWithString:[[url absoluteString] stringByReplacingOccurrencesOfString:@"file://quickchm.img/" withString:@"quickchm://"]];
	} 
	
	NSString *key = [url host];
    CHMContainer *container = [containerReg objectForKey:key];
	NSData *data = [container urlData:url];
    
    if( !data ) {
		[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:nil]];
		return;
    }
    
	if (processingHtml)
		data = (NSData *)adaptPage(data, container, url, NULL);
		
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL: [[self request] URL]
														MIMEType:@"application/octet-stream"
														expectedContentLength:[data length]
														textEncodingName:nil];
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];    
    [[self client] URLProtocol:self didLoadData:data];
    [[self client] URLProtocolDidFinishLoading:self];
	
    [response release];
}


-(void)stopLoading
{
//    DEBUG_OUTPUT( @"CHMURLProtocol:stopLoading" );
}

+ (void)registerContainer:(CHMContainer *)container
{
	if (!containerReg)
		containerReg = [[NSMutableDictionary alloc] initWithCapacity:1];
	NSString *key = [container uniqueId];
	[containerReg setObject:container forKey:key];
	DEBUG_OUTPUT([NSString stringWithFormat:@"Container %@ registered", key]); 
}

+ (void)unregisterContainer:(CHMContainer *)container
{
	if (!containerReg)
		containerReg = [[NSMutableDictionary alloc] init];
	NSString *key = [container uniqueId];
	[containerReg removeObjectForKey:key];
	DEBUG_OUTPUT([NSString stringWithFormat:@"Container %@ deregistered", key]);
}	

@end
