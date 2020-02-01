//
//  IMBImageSelectionView.h
//  iMedia
//
//  Created by Daniel Jalkut on 2/11/19.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface IMBImageSelectionView : NSView

@property (nonatomic, assign, getter=isSelected) BOOL selected;

@property (nonatomic, assign) NSCollectionViewItemHighlightState highlightState;

@end

NS_ASSUME_NONNULL_END
