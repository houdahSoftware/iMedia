//
//  IMBObjectCollectionView.m
//  iMedia
//
//  Created by Daniel Jalkut on 2/12/19.
//

#import "IMBObjectCollectionView.h"
#import "IMBObjectViewController.h"


@implementation IMBObjectCollectionView

- (void) dealloc
{
	IMBRelease(_typeSelectTableView);
	IMBRelease(_skimmingTrackingArea);

	[super dealloc];
}

#pragma mark
#pragma mark Event Handling

- (void) keyDown:(NSEvent *)inEvent
{
	IMBObjectViewController* controller = (IMBObjectViewController*) self.delegate;
	NSString* key = [inEvent charactersIgnoringModifiers];
	NSUInteger modifiers = [inEvent modifierFlags];

	if (([key isEqual:@"y"] && (modifiers&NSCommandKeyMask)!=0) || [key isEqualToString:@" "])
	{
		[controller quicklook:self];
	}
	else if (([[inEvent characters] length] > 0) && (([inEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == 0)) {
		return [self typeSelectKeyDown:inEvent];
	}
	else
	{
		[super keyDown:inEvent];
	}
}

- (void)keyUp:(NSEvent *)event
{
	NSString *eventCharacters = [event characters];

	if ([eventCharacters length] > 0)
	{
		unichar firstChar = [eventCharacters characterAtIndex:0];

		if (firstChar == NSEnterCharacter)
		{
			return [self.typeSelectTableView keyUp:event];
		}
		else if (([event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == 0)
		{
			return [self.typeSelectTableView keyUp:event];
		}
	}

	[super keyUp:event];
}

- (void)typeSelectKeyDown:(NSEvent *)event
{
	NSSet<NSIndexPath *> *oldSlectionIndexPaths = self.selectionIndexPaths;

	[self.typeSelectTableView keyDown:event];

	NSSet<NSIndexPath *> *selectionIndexPaths = self.selectionIndexPaths;

	if (! [oldSlectionIndexPaths isEqual:selectionIndexPaths])
	{
		[self scrollToItemsAtIndexPaths:selectionIndexPaths scrollPosition:NSCollectionViewScrollPositionNearestHorizontalEdge|NSCollectionViewScrollPositionNearestVerticalEdge];
	}
}

- (void)doCommandBySelector:(SEL)selector
{
	if (selector == @selector(scrollPageDown:))
	{
		[[self enclosingScrollView] pageDown:self];
	}
	else if (selector == @selector(scrollPageUp:))
	{
		[[self enclosingScrollView] pageUp:self];
	}
	else if (selector == @selector(scrollToEndOfDocument:))
	{
		[self scrollToEndOfDocument:self];

	}
	else if (selector == @selector(scrollToBeginningOfDocument:))
	{
		[self scrollToBeginningOfDocument:self];
	}
	else {
		[super doCommandBySelector:selector];
	}
}

- (void)scrollToBeginningOfDocument:(id)sender
{
	NSPoint newScrollOrigin;
	NSScrollView *scrollview = self.enclosingScrollView;

	if ([[scrollview documentView] isFlipped]) {
		newScrollOrigin = NSMakePoint(0.0, 0.0);
	}
	else {
		newScrollOrigin = NSMakePoint(0.0, NSMaxY([[scrollview documentView] frame]) - NSHeight([[scrollview contentView] bounds]));
	}

	[[scrollview documentView] scrollPoint:newScrollOrigin];

}

- (void)scrollToEndOfDocument:(id)sender
{
	NSPoint newScrollOrigin;
	NSScrollView *scrollview = self.enclosingScrollView;

	if ([[scrollview documentView] isFlipped]) {
		newScrollOrigin = NSMakePoint(0.0, NSMaxY([[scrollview documentView] frame]) - NSHeight([[scrollview contentView] bounds]));
	} else {
		newScrollOrigin = NSMakePoint(0.0, 0.0);
	}

	[[scrollview documentView] scrollPoint:newScrollOrigin];
}

- (IMBObject*) itemForMouseEvent:(NSEvent*)mouseEvent
{
	IMBObject* itemUnderMouse = nil;
	NSPoint viewPoint = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
	NSIndexPath* selectedItemIndexPath = [self indexPathForItemAtPoint:viewPoint];
	if (selectedItemIndexPath != nil)
	{
		itemUnderMouse = (IMBObject*)[[self itemAtIndex:[selectedItemIndexPath indexAtPosition:1]] representedObject];
	}
	return itemUnderMouse;
}

// Detect double-clicks ... we accept them from clicks on ourself and from
// clicks on items, which defer to us.
- (void) sendDelegateDoubleClickEvent:(NSEvent*)mouseEvent
{
	if ([[self delegate] respondsToSelector:@selector(collectionView:wasDoubleClickedOnItem:)])
	{
		IMBObject* clickedItem = [self itemForMouseEvent:mouseEvent];

		[(id<IMBObjectCollectionViewDelegate>)[self delegate] collectionView:self wasDoubleClickedOnItem:clickedItem];
	}
}

// Thanks to Charles Parnot for sharing that rightMouseDown doesn't seem to get generated
// as expected for control clicks.
- (void) mouseDown:(NSEvent *)inEvent
{
	if ((inEvent.type == NSRightMouseDown) || (inEvent.modifierFlags & NSControlKeyMask))
	{
		[super rightMouseDown:inEvent];
	}
	else
	{
		[super mouseDown:inEvent];

		if ([inEvent clickCount] == 2)
		{
			[self sendDelegateDoubleClickEvent:inEvent];
		}
	}
}

// Handle right-click by delegating to our object view controller
- (NSMenu*) menuForEvent:(NSEvent *)inEvent
{
	NSMenu* returnedMenu = nil;

	if ([[self delegate] respondsToSelector:@selector(collectionView:wantsContextMenuForItem:)])
	{
		// If we don't find an object, the delegate knows to return a more generic contextual menu item
		IMBObject* selectedItem = [self itemForMouseEvent:inEvent];
		returnedMenu = [(id<IMBObjectCollectionViewDelegate>)[self delegate] collectionView:self wantsContextMenuForItem:selectedItem];
	}

	return returnedMenu;
}

- (void)magnifyWithEvent:(NSEvent *)event
{
	IMBObjectViewController* controller = (IMBObjectViewController*) self.delegate;

	if ([controller isKindOfClass:[IMBObjectViewController class]])
	{
		CGFloat iconSize = [controller iconSize];

		iconSize	+= [event magnification];
		iconSize	= MAX(0.0, iconSize);
		iconSize	= MIN(1.0, iconSize);

		[controller setIconSize:iconSize];
	}
}

#pragma mark
#pragma mark Quicklook

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
