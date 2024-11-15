/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2015 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
 Redistributions of source code must retain the original terms stated here,
 including this list of conditions, the disclaimer noted below, and the
 following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
 Redistributions in binary form must include, in an end-user-visible manner,
 e.g., About window, Acknowledgments window, or similar, either a) the original
 terms stated here, including this list of conditions, the disclaimer noted
 below, and the aforementioned copyright notice, or b) the aforementioned
 copyright notice and a link to karelia.com/imedia.
 
 Neither the name of Karelia Software, nor Sandvox, nor the names of
 contributors to iMedia Browser may be used to endorse or promote products
 derived from the Software without prior and express written permission from
 Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
 */


//----------------------------------------------------------------------------------------------------------------------


// Author: Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBLightroomModernParser.h"
#import "FMDatabase.h"
#import "IMBNode.h"
#import "IMBFolderObject.h"
#import "IMBObject.h"
#import "NSData+SKExtensions.h"
#import "NSObject+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSURL+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "SBUtilities.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBLightroomModernParser ()

- (NSNumber*) databaseVersion;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBLightroomModernParser


//----------------------------------------------------------------------------------------------------------------------


// Unique identifier for this parser...

+ (NSString*) identifier
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];

	return nil;
}


// Key in Ligthroom app user defaults: which library to load

+ (NSString*) preferencesLibraryToLoadKey
{
    return @"libraryToLoad20";
}

// Key in Ligthroom app user defaults: which libraries have been loaded recently

+ (NSString*) preferencesRecentLibrariesKey
{
    return @"recentLibraries20";
}

//----------------------------------------------------------------------------------------------------------------------


+ (NSArray*) concreteParserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];
	
	if ([self lightroomPath] != nil) {
		NSArray* libraryPaths = [self libraryPaths];
		
        for (NSString* libraryPath in libraryPaths) {
            NSURL *libraryPathURL = [NSURL fileURLWithPath:libraryPath];
            IMBResourceAccessibility libraryAccessibility = [libraryPathURL imb_accessibility];
            
            if (libraryAccessibility != kIMBResourceDoesNotExist) {
                IMBLightroomModernParser* parser = [[[[self class] alloc] init] autorelease];
                parser.identifier = [NSString stringWithFormat:@"%@:/%@",[[self class] identifier],libraryPath];
                parser.mediaSource = libraryPathURL;
                parser.mediaType = inMediaType;
                parser.shouldDisplayLibraryName = libraryPaths.count > 1;
                
                [parserInstances addObject:parser];
            }
        }
    }
    
	return parserInstances;
}

- (BOOL) checkDatabaseVersion
{	
	return NO;
}

- (NSNumber*) databaseVersion
{
	__block NSNumber *databaseVersion = nil;

	[self inLibraryDatabase:^(FMDatabase *libraryDatabase) {
		if (libraryDatabase == nil) {
			return;
		}

		NSString* query =	@" SELECT value"
		@" FROM Adobe_variablesTable avt"
		@" WHERE avt.name = ?"
		@" LIMIT 1";

		FMResultSet* results = [libraryDatabase executeQuery:query, @"Adobe_DBVersion"];

        if ([libraryDatabase hadError]) {
            NSLog(@"DB Error %d: %@", [libraryDatabase lastErrorCode], [libraryDatabase lastErrorMessage]);
        }
        if ([results next]) {
			databaseVersion = [NSNumber numberWithLong:[results longForColumn:@"value"]];
		}

		[results close];
	}];

	return databaseVersion;
}

// This method creates the immediate subnodes of the "Lightroom" root node. The two subnodes are "Folders"  
// and "Collections"...

- (BOOL) populateSubnodesForRootNode:(IMBNode*)inRootNode error:(NSError**)outError
{
    if (! [self checkDatabaseVersion]) {
        if (outError != NULL) {
            NSString *lightroomVersion = [[self class] lightroomAppVersion];
            NSString *localizedErrorDescriptionFormat = NSLocalizedStringWithDefaultValue(
                                                                                          @"IMBLightroomParser.IncompatibleCatalogVersion",
                                                                                          nil, IMBBundle(),
                                                                                          @"Catalog %@ is associated with Lightroom version %@ but has an incompatible version.\n\nYou may want to try to open it with Lightroom %@ first to update it. If successful please re-start the application.",
                                                                                          @"Warning when Lightroom database version check fails");
            NSString *localizedErrorDescription = [NSString stringWithFormat:localizedErrorDescriptionFormat, [self.mediaSource path], lightroomVersion, lightroomVersion];
            
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      localizedErrorDescription, NSLocalizedDescriptionKey, nil];
            
            *outError = [NSError errorWithDomain:kIMBErrorDomain code:1 userInfo:userInfo];
        }
        
        // Use empty array for subnodes and objects. This prevents further attempts at populating the node
        [inRootNode mutableArrayForPopulatingSubnodes];
        inRootNode.objects = [NSArray array];

        //inRootNode.accessibility = kIMBResourceDoesNotExist;
        
        return NO;
    }
    
	NSMutableArray* subnodes = [inRootNode mutableArrayForPopulatingSubnodes];
	NSMutableArray* objects = [NSMutableArray array];
	inRootNode.displayedObjectCount = 0;
	
	// Add the Folders node...
	
	NSNumber* id_local = [NSNumber numberWithInt:-1];
	
	NSString* foldersName = NSLocalizedStringWithDefaultValue(
															  @"IMBLightroomParser.foldersName",
															  nil,IMBBundle(),
															  @"Folders",
															  @"Name of Folders node in IMBLightroomParser");
	
	IMBNode* foldersNode = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
	foldersNode.identifier = [self identifierWithFolderId:id_local];
	foldersNode.name = foldersName;
	foldersNode.icon = [[self class] folderIcon];
	foldersNode.attributes = [self attributesWithRootFolder:id_local
                                                    idLocal:id_local
                                                   rootPath:nil
                                               pathFromRoot:nil
                                                   nodeType:IMBLightroomNodeTypeFolder];
	foldersNode.isLeafNode = NO;
	
	[subnodes addObject:foldersNode];
	
	IMBFolderObject* foldersObject = [[[IMBFolderObject alloc] init] autorelease];
	foldersObject.representedNodeIdentifier = foldersNode.identifier;
	foldersObject.name = foldersNode.name;
	foldersObject.metadata = nil;
	foldersObject.parserIdentifier = self.identifier;
	foldersObject.index = 0;
	foldersObject.imageLocation = (id)self.mediaSource;
	foldersObject.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
	foldersObject.imageRepresentation = [[self class] largeFolderIcon];
	
	[objects addObject:foldersObject];
	
	
	// Add the Collections node...
	
	NSString* collectionsName = NSLocalizedStringWithDefaultValue(
																  @"IMBLightroomParser.collectionsName",
																  nil,IMBBundle(),
																  @"Collections",
																  @"Name of Collections node in IMBLightroomParser");
	NSMutableDictionary *collectionsAttributes = [NSMutableDictionary dictionaryWithCapacity:5];
	
	[collectionsAttributes setValue:[NSNumber numberWithInt:IMBLightroomNodeTypeRootCollection] forKey:@"nodeType"];

	IMBNode* collectionsNode = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
	collectionsNode.identifier = [self identifierWithCollectionId:[NSNumber numberWithLong:0]];
	collectionsNode.name = collectionsName;
	collectionsNode.icon = [[self class] groupIcon];
	collectionsNode.isLeafNode = NO;
	collectionsNode.attributes = collectionsAttributes;

	[subnodes addObject:collectionsNode];
	
	IMBFolderObject* collectionsObject = [[[IMBFolderObject alloc] init] autorelease];
	collectionsObject.representedNodeIdentifier = collectionsNode.identifier;
	collectionsObject.name = collectionsNode.name;
	collectionsObject.metadata = nil;
	collectionsObject.parserIdentifier = self.identifier;
	collectionsObject.index = 1;
	collectionsObject.imageLocation = (id)self.mediaSource;
	collectionsObject.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
	collectionsObject.imageRepresentation = [[self class] largeFolderIcon];
	
	[objects addObject:collectionsObject];
	
	inRootNode.objects = objects;

	return YES;
}

- (NSString*) pyramidPathForImage:(NSNumber*)idLocal
{
	__block NSString *uuid = nil;
	__block NSString *digest = nil;

	[self inThumbnailDatabase:^(FMDatabase *thumbnailDatabase) {
		if (thumbnailDatabase == nil) {
			return;
		}

		NSString* query =	@" SELECT ice.imageId AS image_id,  p.uuid, p.digest"
		@" FROM Pyramid p"
		@" JOIN ImageCacheEntry ice ON ice.uuid = p.uuid"
		@" WHERE image_id = ?";

		FMResultSet* results = [thumbnailDatabase executeQuery:query, idLocal];

		while ([results next] && ([digest length] == 0))
		{
			uuid = [results stringForColumn:@"uuid"];
			digest = [results stringForColumn:@"digest"];
		}

		[results close];
	}];

#if 0
	if (digest == nil) {
		[self inLibraryDatabase:^(FMDatabase *libraryDatabase) {
			if (libraryDatabase == nil) {
				return;
			}

			NSString* query =	@" SELECT alf.id_global uuid"
			@" FROM Adobe_images ai"
			@" INNER JOIN AgLibraryFile alf on alf.id_local = ai.rootFile"
			@" WHERE ai.id_local = ?";

			FMResultSet* results = [libraryDatabase executeQuery:query, idLocal];

			while ([results next] && ([uuid length] == 0))
			{
				uuid = [results stringForColumn:@"uuid"];
			}

			[results close];
		}];

		if (uuid != nil) {
			[self inThumbnailDatabase:^(FMDatabase *thumbnailDatabase) {
				if (thumbnailDatabase == nil) {
					return;
				}

				NSString* query =	@" SELECT p.digest"
				@" FROM Pyramid p"
				@" WHERE p.uuid = ?";

				FMResultSet* results = [thumbnailDatabase executeQuery:query, uuid];

				while ([results next] && ([digest length] == 0))
				{
					digest = [results stringForColumn:@"digest"];
				}

				[results close];
			}];
		}
	}
#endif

	if (digest == nil) {
		[self inLibraryDatabase:^(FMDatabase *libraryDatabase) {
			if (libraryDatabase == nil) {
				return;
			}

			NSString* query =	@" SELECT alf.id_global uuid, ids.digest"
			@" FROM Adobe_imageDevelopSettings ids"
			@" INNER JOIN Adobe_images ai ON ai.id_local = ids.image"
			@" INNER JOIN AgLibraryFile alf on alf.id_local = ai.rootFile"
			@" WHERE ids.image = ?"
			@" ORDER BY alf.id_global ASC";

			FMResultSet* results = [libraryDatabase executeQuery:query, idLocal];

			// JJ/2012-10-02: For some reason we may get multiple rows with some of them not properly filled. Try best we can.
			// Pierre/2024-11-15: Check Adobe_libraryImageDevelopHistoryStep for digests ordered by date
			
			while ([results next] && (uuid == nil || digest == nil || [uuid isEqualToString:@""] || [digest isEqualToString:@""]))
			{
				uuid = [results stringForColumn:@"uuid"];
				digest = [results stringForColumn:@"digest"];
			}

			[results close];
		}];
	}

	if ((uuid != nil) && (digest != nil)) {
		NSString* prefixOne = [uuid substringToIndex:1];
		NSString* prefixFour = [uuid substringToIndex:4];
		NSString* fileName = [[NSString stringWithFormat:@"%@-%@", uuid, digest] stringByAppendingPathExtension:@"lrprev"];

		return [[prefixOne stringByAppendingPathComponent:prefixFour] stringByAppendingPathComponent:fileName];
	}

	return nil;
}

- (BOOL)usesLrprevPyramidFiles
{
	if (_usesLrprevPyramidFiles == nil) {
		NSNumber* databaseVersion = [self databaseVersion];
		long databaseVersionLong = [databaseVersion longValue];
		BOOL usesLrprevPyramidFiles = (databaseVersionLong < 1303000);

		_usesLrprevPyramidFiles = [NSNumber numberWithBool:usesLrprevPyramidFiles];
	}

	return [_usesLrprevPyramidFiles boolValue];
}

- (NSData*) previewDataForObject:(IMBObject*)inObject maximumSize:(NSNumber*)maximumSize
{
	if ([inObject isKindOfClass:[IMBLightroomObject class]]) {
		BOOL preferLrprev = [self usesLrprevPyramidFiles];
		NSString* absolutePyramidPath = [(IMBLightroomObject*)inObject absolutePyramidPath];

		return [[self class] previewDataWithPyramidPath:absolutePyramidPath maximumSize:maximumSize preferLrprev:preferLrprev acceptAlternateDigest:YES];
	}

	return nil;
}

+ (NSData*) previewDataWithPyramidPath:(NSString *)absolutePyramidPath
						   maximumSize:(NSNumber*)maximumSize
						  preferLrprev:(BOOL)preferLrprev
				 acceptAlternateDigest:(BOOL)acceptAlternateDigest
{
	// Starting with Lightroom 13.3, previews are no longer stored in a .lrprev file.
	// Instead Lightroom 13.3, creates individual JPEG files with no extension.
	// These files retain the same uuid-digest basename as the .lrprev file and add a suffix specifying the dimension

	// https://community.adobe.com/t5/lightroom-classic-discussions/upgrading-catalog-with-13-3-loses-previews/m-p/14659945
	// https://community.adobe.com/t5/lightroom-classic-discussions/preview-files-have-multiplied/m-p/14845368

	// Lightroom 13.3 probably maps to database version 1303000
	// Lightroom migrates lprev files as needed. An upgraded library has a mix of JPEG an .lrprev previews

	NSData* data = nil;

	if (preferLrprev) {
		data = [self previewDataFromLrprevWithPyramidPath:absolutePyramidPath maximumSize:maximumSize acceptAlternateDigest:NO];

		if (data == nil) {
			data = [self previewDataFromFilesWithPyramidPath:absolutePyramidPath maximumSize:maximumSize acceptAlternateDigest:NO];
		}
	}
	else {
		data = [self previewDataFromFilesWithPyramidPath:absolutePyramidPath maximumSize:maximumSize acceptAlternateDigest:NO];

		if (data == nil) {
			data = [self previewDataFromLrprevWithPyramidPath:absolutePyramidPath maximumSize:maximumSize acceptAlternateDigest:NO];
		}
	}

	if (data != nil) {
		return data;
	}

	if (acceptAlternateDigest) {
		if (preferLrprev) {
			data = [self previewDataFromLrprevWithPyramidPath:absolutePyramidPath maximumSize:maximumSize acceptAlternateDigest:YES];

			if (data == nil) {
				data = [self previewDataFromFilesWithPyramidPath:absolutePyramidPath maximumSize:maximumSize acceptAlternateDigest:YES];
			}
		}
		else {
			data = [self previewDataFromFilesWithPyramidPath:absolutePyramidPath maximumSize:maximumSize acceptAlternateDigest:YES];

			if (data == nil) {
				data = [self previewDataFromLrprevWithPyramidPath:absolutePyramidPath maximumSize:maximumSize acceptAlternateDigest:YES];
			}
		}
	}

	return data;
}

//------------------------------------
+ (NSData*) previewDataFromLrprevWithPyramidPath:(NSString *)absolutePyramidPath
									 maximumSize:(NSNumber*)maximumSize
						   acceptAlternateDigest:(BOOL)acceptAlternateDigest
{
	if (absolutePyramidPath == nil) {
		return nil;
	}

	NSString* lrprevFilePath = absolutePyramidPath;
	NSFileManager* fileManager = [NSFileManager defaultManager];

	if (![fileManager fileExistsAtPath:lrprevFilePath]) {
		NSString* alternatePath = nil;

		if (acceptAlternateDigest) {
			NSString* absoluteFolderPath = [absolutePyramidPath stringByDeletingLastPathComponent];
			NSString* baseName = [[absolutePyramidPath lastPathComponent] stringByDeletingPathExtension];
			NSRange lastDashRange = [baseName rangeOfString:@"-" options:NSBackwardsSearch];

			if (lastDashRange.location != NSNotFound) {
				NSString* prefix = [baseName substringToIndex:(lastDashRange.location + 1)];
				NSError* fileManagerError = nil;
				NSArray* allFiles = [fileManager contentsOfDirectoryAtPath:absoluteFolderPath error:&fileManagerError];

				if (allFiles == nil) {
					NSLog(@"Lightroom parser. Directory listing error: %@", fileManagerError);

					return nil;
				}

				for (NSString* fileName in allFiles) {
					if ([fileName hasPrefix:prefix] && [[fileName pathExtension] isEqual:@"lrprev"]) {
						alternatePath = [absoluteFolderPath stringByAppendingPathComponent:fileName];

						break;
					}
				}
			}
		}

		if (alternatePath != nil) {
			lrprevFilePath = alternatePath;
		}
		else {
			NSLog(@"Lightroom parser. File not found: %@", absolutePyramidPath);
		}
	}

	NSURL* lrprevFileURL = [NSURL fileURLWithPath:lrprevFilePath isDirectory:NO];
	NSError* dataError = nil;
	NSData* data = [NSData dataWithContentsOfURL:lrprevFileURL options:NSDataReadingMappedIfSafe error:&dataError];

	if (data == nil) {
		NSLog(@"Lightroom parser. File read error: %@", dataError);

		return nil;
	}

	//		'AgHg'					-- a magic marker
	//		header length			-- 2 bytes, big endian includes marker and length
	//		version					-- 1 byte, zero for now
	//		kind					-- 1 bytes, 0 == string, 1 == blob
	//		data length				-- 8 bytes, big endian
	//		data padding length		-- 8 bytes, big endian
	//		name					-- zero terminated
	//		< padding for rest of header >
	//		< data >
	//		< data padding >

	const char pattern[4] = { 0x41, 0x67, 0x48, 0x67 };

	NSUInteger index = NSNotFound;

	if (maximumSize == nil) {
		index = [data lastIndexOfBytes:pattern length:4];
	}
	else {
		index = [data indexOfBytes:pattern length:4];
	}

	NSData* previousData = nil;
	CGFloat maximumSizeFloat = [maximumSize floatValue];

	while (index != NSNotFound) {
		unsigned short headerLengthValue; // size 2
		unsigned long long dataLengthValue; // size 8

		[data getBytes:&headerLengthValue range:NSMakeRange(index + 4, 2)];
		[data getBytes:&dataLengthValue range:NSMakeRange(index + 4 + 2 + 1 + 1, 8)];

		headerLengthValue = NSSwapBigShortToHost(headerLengthValue);
		dataLengthValue = NSSwapBigLongLongToHost(dataLengthValue);

		NSData* jpegData = nil;

		if ((index + headerLengthValue + dataLengthValue) <= [data length]) {
			jpegData = [data subdataWithRange:NSMakeRange(index + headerLengthValue, dataLengthValue)];
		}
		else {
			break;
		}

		if (maximumSize == nil) {
			return jpegData;
		}

		if (previousData == nil) {
			previousData = jpegData;
		}

		if (jpegData != nil) {
			CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)jpegData, nil);

			if (source != NULL) {
				CGImageRef imageRepresentation = CGImageSourceCreateImageAtIndex(source, 0, NULL);

				CFRelease(source);

				if (imageRepresentation != NULL) {
					CGFloat width = CGImageGetWidth(imageRepresentation);
					CGFloat height = CGImageGetHeight(imageRepresentation);

					CFRelease(imageRepresentation);

					if ((width > maximumSizeFloat) || (height > maximumSizeFloat)) {
						break;
					}
				}

				previousData = jpegData;
			}
		}

		index = [data indexOfBytes:pattern length:4 options:0 range:NSMakeRange(index + 4, [data length] - index - 4)];
	}

	return previousData;
}

+ (NSData*) previewDataFromFilesWithPyramidPath:(NSString *)absolutePyramidPath
									maximumSize:(NSNumber*)maximumSize
						  acceptAlternateDigest:(BOOL)acceptAlternateDigest
{
	if (absolutePyramidPath == nil) {
		return nil;
	}

	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSString* absoluteFolderPath = [absolutePyramidPath stringByDeletingLastPathComponent];
	NSString* baseName = [[absolutePyramidPath lastPathComponent] stringByDeletingPathExtension];

	NSError* fileManagerError = nil;
	NSArray* allFiles = [fileManager contentsOfDirectoryAtPath:absoluteFolderPath error:&fileManagerError];

	if (allFiles == nil) {
		NSLog(@"Lightroom parser. Directory listing error: %@", fileManagerError);

		return nil;
	}

	NSString* regexPattern = [NSString stringWithFormat:@"%@_(\\d+)$", baseName];

	if (acceptAlternateDigest) {
		NSString* absoluteFolderPath = [absolutePyramidPath stringByDeletingLastPathComponent];
		NSString* baseName = [[absolutePyramidPath lastPathComponent] stringByDeletingPathExtension];
		NSRange lastDashRange = [baseName rangeOfString:@"-" options:NSBackwardsSearch];

		if (lastDashRange.location != NSNotFound) {
			NSString* uuid = [baseName substringToIndex:lastDashRange.location];

			regexPattern = [NSString stringWithFormat:@"%@-[a-z0-9]+_(\\d+)$", uuid];
		}
	}

	NSError* regexError = nil;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexPattern
																		   options:0
																			 error:&regexError];

	if (regex == nil) {
		NSLog(@"Lightroom parser. Regular expression error: %@", regexError);

		return nil;
	}

	NSString* bestMatchFileName = nil;
	NSInteger bestMatchSizeValue = NSNotFound;
	NSInteger maximumSizeValue = (maximumSize != nil) ? [maximumSize integerValue] : NSIntegerMax;

	for (NSString* fileName in allFiles) {
		NSRange range = NSMakeRange(0, fileName.length);
		NSTextCheckingResult* match = [regex firstMatchInString:fileName options:0 range:range];

		if (match) {
			NSRange sizeRange = [match rangeAtIndex:1];
			NSString* sizeString = [fileName substringWithRange:sizeRange];
			NSInteger sizeValue = [sizeString integerValue];

			if ((bestMatchFileName == nil) || ((sizeValue > bestMatchSizeValue) && (sizeValue <= maximumSizeValue))) {
				bestMatchFileName = fileName;
				bestMatchSizeValue = sizeValue;
			}
		}
	}

	if (bestMatchFileName == nil) {
		return nil;
	}

	NSString* bestMatchFilePath = [absoluteFolderPath stringByAppendingPathComponent:bestMatchFileName];
	NSURL* bestMatchFileURL = [NSURL fileURLWithPath:bestMatchFilePath isDirectory:NO];
	NSError* dataError = nil;
	NSData* data = [NSData dataWithContentsOfURL:bestMatchFileURL options:NSDataReadingMappedIfSafe error:&dataError];

	if (data == nil) {
		NSLog(@"Lightroom parser. File read error: %@", dataError);

		return nil;
	}

	return data;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSString*) rootFolderQuery
{
	NSString* query =
		@" SELECT id_local, absolutePath, name"
		@" FROM AgLibraryRootFolder"
		@" ORDER BY name ASC";
	
	return query;
}

- (NSString*) folderNodesQuery
{
	// Note: Lightroom Classic CC v10 has introduced a parentId column
	NSString* query =
		@" SELECT id_local, pathFromRoot"
		@" FROM AgLibraryFolder"
		@" WHERE rootFolder = ?"
		@" AND (pathFromRoot LIKE ? AND NOT (pathFromRoot LIKE ?))"
		@" ORDER BY pathFromRoot ASC";
	
	return query;
}

- (NSString*) rootCollectionNodesQuery
{
	NSString* query =
		@" SELECT alc.id_local, alc.parent, alc.name, alc.creationId"
		@" FROM AgLibraryCollection alc"
		@" WHERE (creationId = 'com.adobe.ag.library.collection' OR creationId = 'com.adobe.ag.library.group') "
		@" AND alc.parent IS NULL";
		
	return query;
}

- (NSString*) collectionNodesQuery
{
	NSString* query =
		@" SELECT alc.id_local, alc.parent, alc.name, alc.creationId"
		@" FROM AgLibraryCollection alc"
		@" WHERE (alc.creationId = 'com.adobe.ag.library.collection' OR alc.creationId = 'com.adobe.ag.library.group') "
		@" AND alc.parent = ?";
	
	return query;
}

- (NSString*) folderObjectsQuery
{
	NSString* query = nil;

	if ([self.mediaType isEqualTo:kIMBMediaTypeMovie]) {
		query =
		@" SELECT	alf.idx_filename, ai.id_local, ai.captureTime, ai.fileHeight, ai.fileWidth, ai.orientation,"
		@"			iptc.caption"
		@" FROM Adobe_images ai"
		@" LEFT JOIN AgLibraryFile alf ON ai.rootFile = alf.id_local"
		@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
		@" WHERE alf.folder in ( "
		@"		SELECT id_local"
		@"		FROM AgLibraryFolder"
		@"		WHERE id_local = ? OR (rootFolder = ? AND (pathFromRoot IS NULL OR pathFromRoot = ''))"
		@" )"
		@" AND ai.fileFormat == 'VIDEO'"
		@" ORDER BY ai.captureTime ASC";
	}
	else
	{
		query =
		@" SELECT	alf.idx_filename, alf.baseName, alf.sidecarExtensions, ai.id_local, ai.captureTime, ai.fileHeight, ai.fileWidth, ai.orientation,"
		@"			iptc.caption"
		@" FROM Adobe_images ai"
		@" LEFT JOIN AgLibraryFile alf ON ai.rootFile = alf.id_local"
		@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
		@" WHERE alf.folder in ( "
		@"		SELECT id_local"
		@"		FROM AgLibraryFolder"
		@"		WHERE id_local = ? OR (rootFolder = ? AND (pathFromRoot IS NULL OR pathFromRoot = ''))"
		@" )"
		@" AND ai.fileFormat <> 'VIDEO'"
		@" ORDER BY ai.captureTime ASC";
	}

	return query;
}

- (NSString*) collectionObjectsQuery
{
	NSString* query = nil;

	if ([self.mediaType isEqualTo:kIMBMediaTypeMovie])
	{
		query =
		@" SELECT arf.absolutePath || '/' || alf.pathFromRoot absolutePath,"
		@"        aif.idx_filename, ai.id_local, ai.captureTime, ai.fileHeight, ai.fileWidth, ai.orientation, "
		@"        iptc.caption"
		@" FROM Adobe_images ai"
		@" LEFT JOIN AgLibraryFile aif ON aif.id_local = ai.rootFile"
		@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"
		@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"
		@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
		@" WHERE IFNULL(ai.masterImage, ai.id_local) in ( "
		@"		SELECT image"
		@"		FROM AgLibraryCollectionImage alci"
		@"		WHERE alci.collection = ?"
		@" )"
		@" AND ai.fileFormat == 'VIDEO'"
		@" ORDER BY ai.captureTime ASC";
	}
	else
	{
		query =
		@" SELECT arf.absolutePath || '/' || alf.pathFromRoot absolutePath,"
		@"        aif.idx_filename, aif.baseName, aif.sidecarExtensions, ai.id_local, ai.captureTime, ai.fileHeight, ai.fileWidth, ai.orientation, "
		@"        iptc.caption"
		@" FROM Adobe_images ai"
		@" LEFT JOIN AgLibraryFile aif ON aif.id_local = ai.rootFile"
		@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"
		@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"
		@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
		@" WHERE IFNULL(ai.masterImage, ai.id_local) in ( "
		@"		SELECT image"
		@"		FROM AgLibraryCollectionImage alci"
		@"		WHERE alci.collection = ?"
		@" )"
		@" AND ai.fileFormat <> 'VIDEO'"
		@" ORDER BY ai.captureTime ASC";
	}

	return query;
}


//----------------------------------------------------------------------------------------------------------------------

+ (NSImage*) folderIcon
{
	static NSImage* folderIcon = nil;
	
	if (folderIcon == nil) {
		folderIcon = [[self customLightroomIconWithName:@"icon_folder.png" croppedToRect:NSMakeRect(2,1,19,16)] copy];
	}

	return folderIcon;
}

+ (NSImage*) groupIcon;
{
	static NSImage* groupIcon = nil;
	
	if (groupIcon == nil) {
		groupIcon = [[self customLightroomIconWithName:@"groupCreation.png" croppedToRect:NSMakeRect(2,2,19,16)] copy];
	}

	return groupIcon;
}

+ (NSImage*) collectionIcon;
{
	static NSImage* collectionIcon = nil;
	
	if (collectionIcon == nil) {
		collectionIcon = [[self customLightroomIconWithName:@"collectionCreation.png" croppedToRect:NSMakeRect(1,1,19,16)] copy];
	}
	
	return collectionIcon;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL)hasDatabaseAccessWithError:(NSError **)pError
{
    __block BOOL hasAccess = NO;
    
    [self inLibraryDatabase:^(FMDatabase *libraryDatabase) {
        if (libraryDatabase == nil) {
            return;
        }
        
        // Check for catalog access by simply trying to query the database version
        
        NSString* query =    @" SELECT value"
        @" FROM Adobe_variablesTable avt"
        @" WHERE avt.name = ?"
        @" LIMIT 1";
        
        FMResultSet* results = [libraryDatabase executeQuery:query, @"Adobe_DBVersion"];
        
        if (![libraryDatabase hadError]) {
            hasAccess = YES;
        } else {
            hasAccess = NO;
            
            if (pError) {
                NSInteger sqliteErrorCode = [libraryDatabase lastErrorCode];
                switch (sqliteErrorCode) {
                    case 14: {
                        NSString *localizedErrorDescriptionFormat =
                        NSLocalizedStringWithDefaultValue(@"IMBLightroomParser.MustRunLightroom",
                                                          nil, IMBBundle(),
                                                          @"Please run Lightroom %@ to gain access to its catalog. Then hit \"Reload\" from the context menu.",
                                                          @"Warning when catalog can't be opened");
                        NSString *localizedErrorDescription = [NSString stringWithFormat:localizedErrorDescriptionFormat,
                                                               [self.class lightroomAppVersion]];
                        
                        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  localizedErrorDescription, NSLocalizedDescriptionKey, nil];
                        
                        *pError = [NSError errorWithDomain:kIMBErrorDomain code:sqliteErrorCode userInfo:userInfo];
                        break;
                    }
                        
                        
                    default:
                        break;
                }
            }
            
            NSLog(@"DB Error %d: %@", [libraryDatabase lastErrorCode], [libraryDatabase lastErrorMessage]);
        }
        
        [results close];
    }];
    
    return hasAccess;
}

- (FMDatabasePool*) createLibraryDatabasePool;
{
	[[self class] imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	
	return nil;
}

- (FMDatabasePool*) createThumbnailDatabasePool;
{
	[[self class] imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


@end
