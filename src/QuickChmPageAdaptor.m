//
//  QuichChmPageAdaptor.m
//  quickchm
//
//  Created by Qian Qian on 6/29/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <libxml/HTMLparser.h>
#import <libxml/HTMLtree.h>
#import <libxml/tree.h>

#import "QuickChmPageAdaptor.h"

typedef struct {
	const char *hrefHostPath;
	const char *hrefRelativePath;
	const char *imgHostPath;
	const char *imgRelativePath;
	NSURL *baseUrl;
	NSString *pageDir;
	CHMContainer *container;
	NSMutableDictionary **attachment;
} ProcessContext;


xmlChar * HREF = (xmlChar *)"href";
xmlChar * ONCLICK = (xmlChar *)"onclick";
xmlChar * SRC = (xmlChar *)"src";


static NSString *findMIME(NSString *img) {
	const char *ext = [[img pathExtension] UTF8String];
	
	if (!strcasecmp(ext, "bmp"))
		return @"image/bmp";
	else if (!strcasecmp(ext, "cod"))
		return @"image/cis-cod";
	else if (!strcasecmp(ext, "gif"))
		return @"image/gif";
	else if (!strcasecmp(ext, "ief"))
		return @"image/ief";
	else if (!strcasecmp(ext, "jpe"))
		return @"image/jpeg";
	else if (!strcasecmp(ext, "jpeg") || !strcasecmp(ext, "jpg"))
		return @"image/jpeg";
	else if (!strcasecmp(ext, "jfif"))
		return @"image/pipeg";
	else if (!strcasecmp(ext, "svg"))
		return @"image/svg+xml";
	else if (!strcasecmp(ext, "tif") || !strcasecmp(ext, "tiff"))
		return @"image/tiff";
	else if (!strcasecmp(ext, "ras"))
		return @"image/x-cmu-raster";
	else if (!strcasecmp(ext, "cmx"))
		return @"image/x-cmx";
	else if (!strcasecmp(ext, "ico"))
		return @"image/x-icon";
	else if (!strcasecmp(ext, "pnm"))
		return @"image/x-portable-anymap";
	else if (!strcasecmp(ext, "pbm"))
		return @"image/x-portable-bitmap";
	else if (!strcasecmp(ext, "pgm"))
		return @"image/x-portable-graymap";
	else if (!strcasecmp(ext, "ppm"))
		return @"image/x-portable-pixmap";
	else if (!strcasecmp(ext, "rgb"))
		return @"image/x-rgb";
	else if (!strcasecmp(ext, "xbm"))
		return @"image/x-xbitmap";
	else if (!strcasecmp(ext, "xpm"))
		return @"image/x-xpixmap";
	else if (!strcasecmp(ext, "xwd"))
		return @"image/x-xwindowdump";
	else
		return nil;
}


static void processHrefNode(xmlNode * cur_node, const char *hrefHostPath, const char *hrefRelativePath) 
{
	char *url = (char *)xmlGetProp(cur_node, HREF);
	if (url != NULL && xmlGetProp(cur_node, ONCLICK) == NULL) {
		// delete href 
		xmlSetProp(cur_node, HREF, (xmlChar *)"#");
		
		// compute new url
		char *newUrl = (*url == '/') ? 
			concateString(hrefHostPath, url) : concateString(hrefRelativePath, url);
				
		// create onclick
		char *prefix = "document.location.href='";
		uint32_t len = strlen(prefix) + strlen(newUrl) + 2;
        char *script = calloc(len, sizeof(char));

        strncpy(script, prefix, len);
		strncat(script, newUrl, len);
		strncat(script, "'", len);
		script[len-1] = 0;
		DEBUG_OUTPUT([NSString stringWithFormat:@"%@%@%@%@", @"QuickChm Adaptor : Change ", [NSString stringWithCString:url], @" to ", [NSString stringWithCString:script]]);
		
		// create javascript attribute
		xmlNewProp(cur_node, ONCLICK, (xmlChar *)script);
		
		free(script);
		free(newUrl);
	}
}


/**
 ** Set imge src to url scheme file://
 **/
static void processImgNodeToUrl(xmlNode * cur_node, const char *imgHostPath, const char *imgRelativePath) 
{
	char *src = (char *)xmlGetProp(cur_node, SRC);
	
	if (src == NULL)
		return;

	// process src
	char *newSrc = (*src == '/') ? 
		concateString(imgHostPath, src) : concateString(imgRelativePath, src);
	
	DEBUG_OUTPUT([NSString stringWithFormat:@"%@%@%@%@", @"QuickChm Adaptor : Change ", [NSString stringWithCString:src], @" to ", [NSString stringWithCString:newSrc]]);
	
	xmlSetProp(cur_node, SRC, (xmlChar *)newSrc);
	
	free(newSrc);
}

/*
 * Set image data into the provided dictionary
 */
static void processImgNodeToDict(xmlNode * cur_node, NSURL *baseUrl, NSString *pageDir, CHMContainer *container, NSMutableDictionary **attachment) 
{
	char *src = (char *)xmlGetProp(cur_node, SRC);
	
	if (src == NULL)
		return;
	
	NSString *imgSrc = [NSString stringWithCString:src];
	NSURL *imgURL = (*src == '/') ?	[NSURL URLWithString:imgSrc relativeToURL:baseUrl] : 
						[NSURL URLWithString:[pageDir stringByAppendingPathComponent:imgSrc] relativeToURL:baseUrl];
	NSData *data = [container urlData:imgURL];
	
	if (data == nil)
		return;
	
	// find image mime type
	NSString *imgName = [imgSrc lastPathComponent];
	NSString *mime = findMIME(imgName);
	
	// Set property
	NSMutableDictionary *imgProps=[[[NSMutableDictionary alloc] init] autorelease];	
	[imgProps setObject:mime forKey:(NSString *)kQLPreviewPropertyMIMETypeKey];
	[imgProps setObject:data forKey:(NSString *)kQLPreviewPropertyAttachmentDataKey];
	[*attachment setObject:imgProps forKey:imgSrc];
	
	// finally, update the src attr
	char *newSrc = concateString("cid:", [imgSrc UTF8String]);
	
	DEBUG_OUTPUT([NSString stringWithFormat:@"%@%@%@%@", @"QuickChm Adaptor : Change ", [NSString stringWithCString:src], @" to ", [NSString stringWithCString:newSrc]]);
	
	xmlSetProp(cur_node, SRC, (xmlChar *)newSrc);
	
	free(newSrc);
}

static void replaceHref(xmlNode * a_node, ProcessContext *context)
{
    xmlNode *cur_node = NULL;	
    for (cur_node = a_node; cur_node; cur_node = cur_node->next) {
        if (cur_node->type == XML_ELEMENT_NODE) {
            if (!strcasecmp((const char *)(cur_node->name), (const char *)"a"))
				processHrefNode(cur_node, context->hrefHostPath, context->hrefRelativePath);
			else if (!strcasecmp((const char *)(cur_node->name), (const char *)"img")) {
				if (context->attachment == NULL)
					processImgNodeToUrl(cur_node, context->imgHostPath, context->imgRelativePath);
				else
					processImgNodeToDict(cur_node, context->baseUrl, context->pageDir, context->container, context->attachment);
			}
		}		
        replaceHref(cur_node->children, context);
    }
}


CFDataRef adaptPage(NSData *page, CHMContainer *container, NSURL *pageUrl, NSMutableDictionary **dict)
{
#ifdef DEBUG_MODE
	[page writeToFile:@"/origin.htm" atomically:YES];	
#endif
	
	const char *hrefProtocol = "file://quickchm.href/";	
	const char *imgProtocol = "file://quickchm.img/";	
	
	NSString *containerId = [container uniqueId];
	const char *uid = [containerId UTF8String];;
	
	// create host path
	const char *hrefHostPath = concateString(hrefProtocol, uid);
	const char *imgHostPath = concateString(imgProtocol, uid);
	
	// create page relative path
	NSString *homePath = [pageUrl absoluteString];
	if (![homePath hasSuffix:@"/"])
		homePath = [[homePath stringByDeletingLastPathComponent] stringByAppendingString:@"/"];
	
	NSString *hrefHomePath = [homePath stringByReplacingOccurrencesOfString:@"quickchm:/" withString:@"file://quickchm.href/"];
	const char *hrefRelativePath = [hrefHomePath UTF8String];
	
	NSString *imgHomePath = [homePath stringByReplacingOccurrencesOfString:@"quickchm:/" withString:@"file://quickchm.img/"];
	const char *imgRelativePath = [imgHomePath UTF8String];
	
	// Parse and replace hyper link
	xmlChar *content = calloc([page length] + 1,sizeof(xmlChar));
    [page getBytes:content length:[page length]];
    DEBUG_OUTPUT(@"%s\n",content);
    htmlDocPtr doc = htmlParseDoc(content, NULL);
    free(content);
    
#ifdef DEBUG_MODE
	xmlChar *tempmem;
	int tempsize;
	htmlDocDumpMemory(doc, &tempmem, &tempsize);
	[[NSData dataWithBytes:tempmem length:tempsize] writeToFile:@"/origin2.htm" atomically:YES];
	free(tempmem);
#endif
	
	xmlNode *root_element = xmlDocGetRootElement(doc);
	
	// do adaption
	NSURL *baseURL = [pageUrl baseURL];	
	
	if (dict == NULL) {
		ProcessContext context = {hrefHostPath, hrefRelativePath, imgHostPath, imgRelativePath, 
									baseURL, [[pageUrl relativePath] stringByDeletingLastPathComponent], container, NULL};
		replaceHref(root_element, &context);
	} else {
		NSMutableDictionary *attachment = [[[NSMutableDictionary alloc] initWithCapacity:5] autorelease];	
		ProcessContext context = {hrefHostPath, hrefRelativePath, imgHostPath, imgRelativePath, 
									baseURL, [[pageUrl relativePath] stringByDeletingLastPathComponent], container, &attachment};
		replaceHref(root_element, &context);
		[*dict setObject:attachment forKey:(NSString *)kQLPreviewPropertyAttachmentsKey];
	}
	
	xmlChar *mem;
	int size;
	htmlDocDumpMemory(doc, &mem, &size);

	NSData * newData = [NSData dataWithBytes:mem length:size];
	
#ifdef DEBUG_MODE
	[newData writeToFile:@"/convert.htm" atomically:YES];
#endif

	xmlFreeDoc(doc);
	free((void *)hrefHostPath);
	free((void *)imgHostPath);
	free((void *)mem);
	
	return (CFDataRef)newData;
}

