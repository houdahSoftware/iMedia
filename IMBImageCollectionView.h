//
//  IMBImageCollectionView.h
//  iMedia
//
//  Created by Daniel Jalkut on 2/12/19.
//

#import <Cocoa/Cocoa.h>

@class IMBImageCollectionView;
@class IMBObject;

NS_ASSUME_NONNULL_BEGIN
@protocol IMBImageCollectionViewDelegate

- (NSMenu*) collectionView:(IMBImageCollectionView*)collectionView wantsContextMenuForItem:(IMBObject*)itemIndex;

@end

@interface IMBImageCollectionView : NSCollectionView

// If we are a skimmable view then we use this to track mouse movements
@property (nonatomic, strong) NSTrackingArea* skimmingTrackingArea;

- (void) enableSkimming;

@end

NS_ASSUME_NONNULL_END
