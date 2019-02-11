//
//  IMBImageBrowserViewItem.m
//  iMedia
//
//  Created by Daniel Jalkut on 2/11/19.
//

#import "IMBImageBrowserViewItem.h"
#import "IMBImageSelectionView.h"

@implementation IMBImageBrowserViewItem

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
