//
//  IMBImageCollectionView.m
//  iMedia
//
//  Created by Daniel Jalkut on 2/12/19.
//

#import "IMBImageCollectionView.h"
#import "IMBObjectViewController.h"

@implementation IMBImageCollectionView

#pragma mark
#pragma mark Quicklook

- (void) keyDown:(NSEvent*)inEvent
{
	IMBObjectViewController* controller = (IMBObjectViewController*) self.delegate;
	NSString* key = [inEvent charactersIgnoringModifiers];
	NSUInteger modifiers = [inEvent modifierFlags];

	if([key isEqual:@"y"] && (modifiers&NSCommandKeyMask)!=0)
	{
		[controller quicklook:self];
	}
	else
	{
		[super keyDown:inEvent];
	}
}


- (BOOL) acceptsPreviewPanelControl:(QLPreviewPanel*)inPanel
{
	return YES;
}


- (void) beginPreviewPanelControl:(QLPreviewPanel*)inPanel
{
	IMBObjectViewController* controller = (IMBObjectViewController*) self.delegate;
	inPanel.delegate = controller;
	inPanel.dataSource = controller;

	if ([controller respondsToSelector:@selector(beginPreviewPanelControl:)])
	{
		[controller performSelector:@selector(beginPreviewPanelControl:) withObject:inPanel];
	}
}


- (void) endPreviewPanelControl:(QLPreviewPanel*)inPanel
{
	IMBObjectViewController* controller = (IMBObjectViewController*) self.delegate;

	if ([controller respondsToSelector:@selector(endPreviewPanelControl:)])
	{
		[controller performSelector:@selector(endPreviewPanelControl:) withObject:inPanel];
	}

	inPanel.delegate = nil;
	inPanel.dataSource = nil;

}

//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Skimming

// Add tracking area of size of my own bounds (make this view skimmable)

- (void) updateTrackingArea
{
	NSTrackingAreaOptions trackingOptions = NSTrackingMouseEnteredAndExited |
	NSTrackingMouseMoved |
	NSTrackingActiveInActiveApp;

	NSTrackingArea* newTrackingArea = [[[NSTrackingArea alloc] initWithRect:[self bounds]
																 options: trackingOptions
																   owner:[self delegate]
																userInfo:nil] autorelease];
	if (newTrackingArea != nil)
	{
		if (self.skimmingTrackingArea != nil)
		{
			[self removeTrackingArea:self.skimmingTrackingArea];
		}
		self.skimmingTrackingArea = newTrackingArea;
		[self addTrackingArea:newTrackingArea];

		//NSLog(@"Created new tracking area for %@", self);
	}
}

// Skimming is enabled by simply creating a suitable tracking area for the view

- (void) enableSkimming
{
	[self updateTrackingArea];
}

// Keep mouse move tracking area in sync with view bounds.
// (Callback from Cocoa whenever view bounds change
// (will be called regardless whether this instance has any tracking areas or not))

- (void) updateTrackingAreas
{
	if (self.skimmingTrackingArea && !NSEqualRects([self.skimmingTrackingArea rect], [self bounds]))
	{
		[self updateTrackingArea];
	}
}

@end
