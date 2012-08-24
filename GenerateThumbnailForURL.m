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

#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFPlugInCOM.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>

#import <libxml/HTMLparser.h>

#import "CHMDocument.h"
#import "CHMContainer.h"
#import "CHMURLProtocol.h"

typedef struct CoverContext {
	NSData *cover;
	CHMDocument *doc;
	CHMContainer *container;
	NSString* homeDir;
} CoverContext;

void elementDidStart(CoverContext *context, const xmlChar *name, const xmlChar **atts);

static htmlSAXHandler saxHandler = {
NULL, /* internalSubset */
NULL, /* isStandalone */
NULL, /* hasInternalSubset */
NULL, /* hasExternalSubset */
NULL, /* resolveEntity */
NULL, /* getEntity */
NULL, /* entityDecl */
NULL, /* notationDecl */
NULL, /* attributeDecl */
NULL, /* elementDecl */
NULL, /* unparsedEntityDecl */
NULL, /* setDocumentLocator */
NULL, /* startDocument */
NULL, /* endDocument */
(startElementSAXFunc) elementDidStart, /* startElement */
NULL, /* endElement */
NULL, /* reference */
NULL, /* characters */
NULL, /* ignorableWhitespace */
NULL, /* processingInstruction */
NULL, /* comment */
NULL, /* xmlParserWarning */
NULL, /* xmlParserError */
NULL, /* xmlParserError */
NULL, /* getParameterEntity */
};


/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	xmlInitParser();
	LIBXML_TEST_VERSION;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    CHMDocument *doc = [[CHMDocument alloc] init];
	
	if ([doc readFromFile:[(NSURL *)url path] ofType:nil]) {
		// Read main page
		NSData *mainPageData = [doc urlData:[doc currentLocation]];
		
		NSString *home = [doc->_container homePath];
		CoverContext context = { nil, doc, doc->_container,  [home hasSuffix:@"/"] ? home : [home stringByDeletingLastPathComponent]};

		htmlDocPtr homePtr = htmlSAXParseDoc((xmlChar *)[mainPageData bytes], NULL, &saxHandler, &context);
		xmlFreeDoc(homePtr);	
		
		QLThumbnailRequestSetImageWithData(thumbnail, (CFDataRef)context.cover, NULL);
	}
	
	[doc release];	
	[pool release];
	
	xmlCleanupParser();
	
	return noErr;
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}

void elementDidStart(CoverContext *context, const xmlChar *name, const xmlChar **atts)
{
	if (!strcasecmp((char *)name, "img")
		&& atts != NULL && *atts != NULL) {
		// search for src
		while(*atts != NULL) {
			if (!strcasecmp((char *)*atts, "src")) { 
				// find src
				atts ++ ;
				NSURL *url;
				NSString *imgPath = [NSString stringWithCString:(char *)*atts];
				if (**atts == '/') {
					// absolute path
					url = [CHMURLProtocol URLWithPath:imgPath inContainer:context->container];
				} else {
					// relative path
					url = [CHMURLProtocol URLWithPath:[context->homeDir stringByAppendingPathComponent:imgPath] inContainer:context->container];
				}
				NSData *img = [context->doc urlData:url];
				if ([img length] > [context->cover length])
					context->cover = img;			
			} else
				atts += 2;
		}
	}
}