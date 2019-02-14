//
//  IMBObjectCollectionView.h
//  iMedia
//
//  Created by Daniel Jalkut on 2/12/19.
//

#import <Cocoa/Cocoa.h>
#import "IMBItemizableView.h"

@class IMBObjectCollectionView;
@class IMBObject;

NS_ASSUME_NONNULL_BEGIN
@protocol IMBObjectCollectionViewDelegate <NSCollectionViewDelegate>

- (NSMenu*) collectionView:(IMBObjectCollectionView*)collectionView wantsContextMenuForItem:(IMBObject*)itemIndex;

@end

@interface IMBObjectCollectionView : NSCollectionView

// If we are a skimmable view then we use this to track mouse movements
@property (nonatomic, strong) NSTrackingArea* skimmingTrackingArea;

- (void) enableSkimming;

@end

NS_ASSUME_NONNULL_END
