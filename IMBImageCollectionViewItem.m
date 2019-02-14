//
//  IMBImageCollectionViewItem.m
//  iMedia
//
//  Created by Daniel Jalkut on 2/11/19.
//

#import "IMBImageCollectionViewItem.h"
#import "IMBImageSelectionView.h"

@implementation IMBImageCollectionViewItem

- (void)setSelected:(BOOL)selected
{
	[super setSelected:selected];

	[self.imageSelectionView setSelected:selected];
}

- (void)setHighlightState:(NSCollectionViewItemHighlightState)highlightState
{
	[super setHighlightState:highlightState];

	[self.imageSelectionView setHighlightState:highlightState];
}

@end
