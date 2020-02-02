//
//  IMBObjectCollectionViewFlowLayout.m
//  iMedia
//
//  Created by Pierre Bernard on 02.02.20.
//

#import "IMBObjectCollectionViewFlowLayout.h"


@interface IMBObjectCollectionViewFlowLayout ()

@end


@implementation IMBObjectCollectionViewFlowLayout

// NOTE: Apple private API
- (BOOL)_isSingleColumnOrRow
{
	// Enables shift-click range selections
	return YES;
}

@end
