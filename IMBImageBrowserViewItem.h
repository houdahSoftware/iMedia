//
//  IMBImageBrowserViewItem.h
//  iMedia
//
//  Created by Daniel Jalkut on 2/11/19.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class IMBImageSelectionView;

@interface IMBImageBrowserViewItem : NSCollectionViewItem

@property (assign) IBOutlet IMBImageSelectionView* imageSelectionView;

@end

NS_ASSUME_NONNULL_END
