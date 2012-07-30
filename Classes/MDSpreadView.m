//
//  MDSpreadView.m
//  MDSpreadViewDemo
//
//  Created by Dimitri Bouniol on 10/15/11.
//  Copyright (c) 2012 Mochi Development, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software, associated artwork, and documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  1. The above copyright notice and this permission notice shall be included in
//     all copies or substantial portions of the Software.
//  2. Neither the name of Mochi Development, Inc. nor the names of its
//     contributors or products may be used to endorse or promote products
//     derived from this software without specific prior written permission.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//  
//  Mochi Dev, and the Mochi Development logo are copyright Mochi Development, Inc.
//  
//  Also, it'd be super awesome if you credited this page in your about screen :)
//  

#import "MDSpreadView.h"
#import "MDSpreadViewCell.h"
#import "MDSpreadViewHeaderCell.h"

#define MAX_NUMBER_OF_PASSES 20
// so we don't delete cells too often when scrolling really fast

@interface MDSpreadViewCell ()

@property (nonatomic, readwrite, copy) NSString *reuseIdentifier;
@property (nonatomic, readwrite, assign) MDSpreadView *spreadView;
@property (nonatomic, retain) MDSortDescriptor *sortDescriptorPrototype;
@property (nonatomic) MDSpreadViewSortAxis defaultSortAxis;

@property (nonatomic, readonly) UILongPressGestureRecognizer *_tapGesture;
@property (nonatomic, retain) MDIndexPath *_rowPath;
@property (nonatomic, retain) MDIndexPath *_columnPath;

@end

@interface MDSpreadViewSection : NSObject {
    NSInteger numberOfCells;
    CGFloat offset;
    CGFloat size;
}

@property (nonatomic) NSInteger numberOfCells;
@property (nonatomic) CGFloat offset;
@property (nonatomic) CGFloat size;

@end

@implementation MDSpreadViewSection

@synthesize numberOfCells, offset, size;

@end

@interface MDSpreadViewSelection ()

@property (nonatomic, retain, readwrite) MDIndexPath *rowPath;
@property (nonatomic, retain, readwrite) MDIndexPath *columnPath;
@property (nonatomic, readwrite) MDSpreadViewSelectionMode selectionMode;

@end

@implementation MDSpreadViewSelection

@synthesize rowPath, columnPath, selectionMode;

+ (id)selectionWithRow:(MDIndexPath *)row column:(MDIndexPath *)column mode:(MDSpreadViewSelectionMode)mode
{
    MDSpreadViewSelection *pair = [[self alloc] init];
    
    pair.rowPath = row;
    pair.columnPath = column;
    pair.selectionMode = mode;
    
    return [pair autorelease];
}

- (BOOL)isEqual:(MDSpreadViewSelection *)object
{
    if ([object isKindOfClass:[MDSpreadViewSelection class]]) {
        if (self == object) return YES;
        return (self.rowPath.row == object.rowPath.row &&
                self.rowPath.section == object.rowPath.section &&
                self.columnPath.column == object.columnPath.column &&
                self.columnPath.section == object.columnPath.section);
    }
    return NO;
}

- (void)dealloc
{
    [rowPath release];
    [columnPath release];
    [super dealloc];
}

@end

@implementation MDIndexPath

@synthesize section, row;

+ (MDIndexPath *)indexPathForColumn:(NSInteger)b inSection:(NSInteger)a
{
    MDIndexPath *path = [[self alloc] init];
    
    path->section = a;
    path->row = b;
    
    return [path autorelease];
}

+ (MDIndexPath *)indexPathForRow:(NSInteger)b inSection:(NSInteger)a
{
    MDIndexPath *path = [[self alloc] init];
    
    path->section = a;
    path->row = b;
    
    return [path autorelease];
}

- (NSInteger)column
{
    return row;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%d, %d]", section, row];
}

- (BOOL)isEqualToIndexPath:(MDIndexPath *)object
{
    return (object->section == self->section && object->row == self->row);
}

@end

@interface MDSortDescriptor ()

@property (nonatomic, readwrite, retain) MDIndexPath *indexPath;
@property (nonatomic, readwrite) NSInteger section;
@property (nonatomic, readwrite) MDSpreadViewSortAxis sortAxis;

@end

@implementation MDSortDescriptor

@synthesize indexPath, section, sortAxis;

+ (id)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending selectsWholeSpreadView:(BOOL)wholeView
{
    return [[[self alloc] initWithKey:key ascending:ascending selectsWholeSpreadView:wholeView] autorelease];
}

+ (id)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending selector:(SEL)selector selectsWholeSpreadView:(BOOL)wholeView
{
    return [[[self alloc] initWithKey:key ascending:ascending selector:selector selectsWholeSpreadView:wholeView] autorelease];
}

+ (id)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending comparator:(NSComparator)cmptr selectsWholeSpreadView:(BOOL)wholeView
{
    return [[[self alloc] initWithKey:key ascending:ascending comparator:cmptr selectsWholeSpreadView:wholeView] autorelease];
}

- (id)initWithKey:(NSString *)key ascending:(BOOL)ascending selectsWholeSpreadView:(BOOL)wholeView
{
    if (self = [super initWithKey:key ascending:ascending]) {
        if (wholeView) section = MDSpreadViewSelectWholeSpreadView;
    }
    return self;
}

- (id)initWithKey:(NSString *)key ascending:(BOOL)ascending selector:(SEL)selector selectsWholeSpreadView:(BOOL)wholeView
{
    if (self = [super initWithKey:key ascending:ascending selector:selector]) {
        if (wholeView) section = MDSpreadViewSelectWholeSpreadView;
    }
    return self;
}

- (id)initWithKey:(NSString *)key ascending:(BOOL)ascending comparator:(NSComparator)cmptr selectsWholeSpreadView:(BOOL)wholeView
{
    if (self = [super initWithKey:key ascending:ascending comparator:cmptr]) {
        if (wholeView) section = MDSpreadViewSelectWholeSpreadView;
    }
    return self;
}

- (void)dealloc
{
    [indexPath release];
    [super dealloc];
}

@end

@interface MDSpreadView ()

- (void)_performInit;

- (CGFloat)_widthForColumnHeaderInSection:(NSInteger)columnSection;
- (CGFloat)_widthForColumnAtIndexPath:(MDIndexPath *)columnPath;
- (CGFloat)_widthForColumnFooterInSection:(NSInteger)columnSection;
- (CGFloat)_heightForRowHeaderInSection:(NSInteger)rowSection;
- (CGFloat)_heightForRowAtIndexPath:(MDIndexPath *)rowPath;
- (CGFloat)_heightForRowFooterInSection:(NSInteger)rowSection;

- (NSInteger)_numberOfColumnsInSection:(NSInteger)section;
- (NSInteger)_numberOfRowsInSection:(NSInteger)section;
- (NSInteger)_numberOfColumnSections;
- (NSInteger)_numberOfRowSections;

- (void)_willDisplayCell:(MDSpreadViewCell *)cell forRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath;

- (MDSpreadViewCell *)_cellForRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath;
- (MDSpreadViewCell *)_cellForHeaderInRowSection:(NSInteger)rowSection forColumnSection:(NSInteger)columnSection;
- (MDSpreadViewCell *)_cellForHeaderInRowSection:(NSInteger)section forColumnAtIndexPath:(MDIndexPath *)columnPath;
- (MDSpreadViewCell *)_cellForHeaderInColumnSection:(NSInteger)section forRowAtIndexPath:(MDIndexPath *)rowPath;

- (void)_clearCell:(MDSpreadViewCell *)cell;
- (void)_clearCellsForColumnAtIndexPath:(MDIndexPath *)columnPath;
- (void)_clearCellsForRowAtIndexPath:(MDIndexPath *)rowPath;
- (void)_clearCellForRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath;
- (void)_clearAllCells;

- (void)_layoutAddColumnCellsBeforeWithOffset:(CGPoint)offset size:(CGSize)size;
- (void)_layoutAddColumnCellsAfterWithOffset:(CGPoint)offset size:(CGSize)size;
- (void)_layoutRemoveColumnCellsBeforeWithOffset:(CGPoint)offset size:(CGSize)size;
- (void)_layoutRemoveColumnCellsAfterWithOffset:(CGPoint)offset size:(CGSize)size;

- (void)_layoutAddRowCellsBeforeWithOffset:(CGPoint)offset size:(CGSize)size;
- (void)_layoutAddRowCellsAfterWithOffset:(CGPoint)offset size:(CGSize)size;
- (void)_layoutRemoveRowCellsBeforeWithOffset:(CGPoint)offset size:(CGSize)size;
- (void)_layoutRemoveRowCellsAfterWithOffset:(CGPoint)offset size:(CGSize)size;

- (void)_layoutColumnAtIndexPath:(MDIndexPath *)columnPath withWidth:(CGFloat)width xOffset:(CGFloat)xOffset;
- (void)_layoutHeaderInColumnSection:(NSInteger)columnSection withWidth:(CGFloat)width xOffset:(CGFloat)xOffset;
- (void)_layoutFooterInColumnSection:(NSInteger)columnSection withWidth:(CGFloat)width xOffset:(CGFloat)xOffset;

- (void)_layoutRowAtIndexPath:(MDIndexPath *)rowPath withHeight:(CGFloat)height yOffset:(CGFloat)yOffset;
- (void)_layoutHeaderInRowSection:(NSInteger)rowSection withHeight:(CGFloat)height yOffset:(CGFloat)yOffset;
- (void)_layoutFooterInRowSection:(NSInteger)rowSection withHeight:(CGFloat)height yOffset:(CGFloat)yOffset;

- (NSInteger)_relativeIndexOfRowAtIndexPath:(MDIndexPath *)indexPath;
- (NSInteger)_relativeIndexOfColumnAtIndexPath:(MDIndexPath *)indexPath;

- (NSSet *)_allVisibleCells;

- (MDIndexPath *)_rowIndexPathFromRelativeIndex:(NSInteger)index;
- (MDIndexPath *)_columnIndexPathFromRelativeIndex:(NSInteger)index;

- (NSInteger)_relativeIndexOfHeaderRowInSection:(NSInteger)rowSection;
- (NSInteger)_relativeIndexOfHeaderColumnInSection:(NSInteger)columnSection;

- (void)_setNeedsReloadData;

@property (nonatomic, retain) MDIndexPath *_visibleRowIndexPath;
@property (nonatomic, retain) MDIndexPath *_visibleColumnIndexPath;

//@property (nonatomic, retain) MDIndexPath *_headerRowIndexPath;
//@property (nonatomic, retain) MDIndexPath *_headerColumnIndexPath;

@property (nonatomic, retain) MDSpreadViewCell *_headerCornerCell;

@property (nonatomic, retain) NSMutableArray *_rowSections;
@property (nonatomic, retain) NSMutableArray *_columnSections;

@property (nonatomic, retain) MDSpreadViewSelection *_currentSelection;

- (MDSpreadViewCell *)_visibleCellForRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath;
- (void)_setVisibleCell:(MDSpreadViewCell *)cell forRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath;

- (BOOL)_touchesBeganInCell:(MDSpreadViewCell *)cell;
- (void)_touchesEndedInCell:(MDSpreadViewCell *)cell;
- (void)_touchesCancelledInCell:(MDSpreadViewCell *)cell;

- (void)_addSelection:(MDSpreadViewSelection *)selection;
- (void)_removeSelection:(MDSpreadViewSelection *)selection;

- (MDSpreadViewSelection *)_willSelectCellForSelection:(MDSpreadViewSelection *)selection;
- (void)_didSelectCellForRowAtIndexPath:(MDIndexPath *)indexPath forColumnIndex:(MDIndexPath *)columnPath;

@end

@implementation MDSpreadView

+ (NSDictionary *)MDAboutControllerTextCreditDictionary
{
    if (self == [MDSpreadView class]) {
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Tables powered by MDSpreadView, available free on GitHub!", @"Text", @"https://github.com/mochidev/MDSpreadViewDemo", @"Link", nil];
    }
    return nil;
}

#pragma mark - Setup

@synthesize dataSource=_dataSource;
@synthesize rowHeight, columnWidth, sectionColumnHeaderWidth, sectionRowHeaderHeight, _visibleRowIndexPath, _visibleColumnIndexPath, /*_headerRowIndexPath, _headerColumnIndexPath,*/ _headerCornerCell, sortDescriptors, selectionMode, _rowSections, _columnSections, _currentSelection, allowsMultipleSelection, allowsSelection;
@synthesize defaultCellClass=_defaultCellClass;
@synthesize defaultHeaderColumnCellClass=_defaultHeaderColumnCellClass;
@synthesize defaultHeaderRowCellClass=_defaultHeaderRowCellClass;
@synthesize defaultHeaderCornerCellClass=_defaultHeaderCornerCellClass;

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self _performInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self _performInit];
    }
    return self;
}

- (void)_performInit
{
    self.opaque = YES;
    self.backgroundColor = [UIColor whiteColor];
    self.directionalLockEnabled = YES;
    
    _dequeuedCells = [[NSMutableSet alloc] init];
    visibleCells = [[NSMutableArray alloc] init];
    
    _headerColumnCells = [[NSMutableArray alloc] init];
    _headerRowCells = [[NSMutableArray alloc] init];
    
    rowHeight = 44; // 25
    sectionRowHeaderHeight = 22;
    columnWidth = 220;
    sectionColumnHeaderWidth = 110;
    
    _selectedCells = [[NSMutableArray alloc] init];
    selectionMode = MDSpreadViewSelectionModeCell;
    allowsSelection = YES;
    
    _defaultCellClass = [MDSpreadViewCell class];
    _defaultHeaderColumnCellClass = [MDSpreadViewHeaderCell class];
    _defaultHeaderCornerCellClass = [MDSpreadViewHeaderCell class];
    _defaultHeaderRowCellClass = [MDSpreadViewHeaderCell class];
    
    anchorCell = [[UIView alloc] init];
//    anchorCell.hidden = YES;
    [self addSubview:anchorCell];
    [anchorCell release];
    
    anchorColumnHeaderCell = [[UIView alloc] init];
//    anchorColumnHeaderCell.hidden = YES;
    [self addSubview:anchorColumnHeaderCell];
    [anchorColumnHeaderCell release];
    
    anchorRowHeaderCell = [[UIView alloc] init];
//    anchorRowHeaderCell.hidden = YES;
    [self addSubview:anchorRowHeaderCell];
    [anchorRowHeaderCell release];
    
    anchorCornerHeaderCell = [[UIView alloc] init];
//    anchorCornerHeaderCell.hidden = YES;
    [self addSubview:anchorCornerHeaderCell];
    [anchorCornerHeaderCell release];
}

- (id<MDSpreadViewDelegate>)delegate
{
    return (id<MDSpreadViewDelegate>)super.delegate;
}

- (void)setDelegate:(id<MDSpreadViewDelegate>)delegate
{
    super.delegate = delegate;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_rowSections release];
    [_columnSections release];
    [sortDescriptors release];
    [_headerColumnCells release];
    [_headerRowCells release];
    [_selectedCells release];
    [_currentSelection release];
//    [_headerColumnIndexPath release];
//    [_headerRowIndexPath release];
    [_headerCornerCell release];
    [_visibleRowIndexPath release];
    [_visibleColumnIndexPath release];
    [visibleCells release];
    [_dequeuedCells release];
    [super dealloc];
}

#pragma mark - Data

- (void)setRowHeight:(CGFloat)newHeight
{
    rowHeight = newHeight;
    
    if (implementsRowHeight) return;
    
    [self _setNeedsReloadData];
}

- (void)setSectionRowHeaderHeight:(CGFloat)newHeight
{
    sectionRowHeaderHeight = newHeight;
    
    if (implementsRowHeaderHeight) return;
    
    [self _setNeedsReloadData];
}

- (void)setColumnWidth:(CGFloat)newWidth
{
    columnWidth = newWidth;
    
    if (implementsColumnWidth) return;
    
    [self _setNeedsReloadData];
}

- (void)setSectionColumnHeaderWidth:(CGFloat)newWidth
{
    sectionColumnHeaderWidth = newWidth;
    
    if (implementsColumnHeaderWidth) return;
    
    [self _setNeedsReloadData];
}

- (void)setDefaultHeaderCornerCellClass:(Class)aClass
{
    if (![aClass isSubclassOfClass:[MDSpreadViewCell class]]) [NSException raise:NSInvalidArgumentException format:@"%@ is not a subclass of MDSpreadViewCell.", NSStringFromClass(aClass)];
                          
    _defaultHeaderCornerCellClass = aClass;
    
    [self _setNeedsReloadData];
}

- (void)setDefaultHeaderColumnCellClass:(Class)aClass
{
    if (![aClass isSubclassOfClass:[MDSpreadViewCell class]]) [NSException raise:NSInvalidArgumentException format:@"%@ is not a subclass of MDSpreadViewCell.", NSStringFromClass(aClass)];
    
    _defaultHeaderColumnCellClass = aClass;
    
    [self _setNeedsReloadData];
}

- (void)setDefaultHeaderRowCellClass:(Class)aClass
{
    if (![aClass isSubclassOfClass:[MDSpreadViewCell class]]) [NSException raise:NSInvalidArgumentException format:@"%@ is not a subclass of MDSpreadViewCell.", NSStringFromClass(aClass)];
    
    _defaultHeaderRowCellClass = aClass;
    
    [self _setNeedsReloadData];
}

- (void)setDefaultCellClass:(Class)aClass
{
    if (![aClass isSubclassOfClass:[MDSpreadViewCell class]]) [NSException raise:NSInvalidArgumentException format:@"%@ is not a subclass of MDSpreadViewCell.", NSStringFromClass(aClass)];
    
    _defaultCellClass = aClass;
    
    [self _setNeedsReloadData];
}

- (void)_setNeedsReloadData
{
    if (!_didSetReloadData) {
        [self performSelector:@selector(reloadData) withObject:nil afterDelay:0];
        _didSetReloadData = YES;
    }
}

- (void)reloadData
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadData) object:nil];
    _didSetReloadData = NO;
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    implementsRowHeight = YES;
    implementsRowHeaderHeight = YES;
    implementsColumnWidth = YES;
    implementsColumnHeaderWidth = YES;
    
    NSUInteger numberOfColumnSections = [self _numberOfColumnSections];
    NSUInteger numberOfRowSections = [self _numberOfRowSections];
    
    CGFloat totalWidth = 0;
    CGFloat totalHeight = 0;
    
    [self _clearAllCells];
    [visibleCells removeAllObjects];
    
    visibleBounds.size = CGSizeZero;
    
    self._visibleColumnIndexPath = nil;
    self._visibleRowIndexPath = nil;
    
    NSMutableArray *newColumnSections = [[NSMutableArray alloc] init];
    
    for (NSUInteger i = 0; i < numberOfColumnSections; i++) {
        MDSpreadViewSection *sectionDescriptor = [[MDSpreadViewSection alloc] init];
        [newColumnSections addObject:sectionDescriptor];
        [sectionDescriptor release];
        
        NSUInteger numberOfColumns = [self _numberOfColumnsInSection:i];
        sectionDescriptor.numberOfCells = numberOfColumns;
        sectionDescriptor.offset = totalWidth;
        
        totalWidth += [self _widthForColumnHeaderInSection:i];
        
        if (!_visibleColumnIndexPath && totalWidth > visibleBounds.origin.x) {
            self._visibleColumnIndexPath = [MDIndexPath indexPathForColumn:-1 inSection:i];
        }
        
        for (NSUInteger j = 0; j < numberOfColumns; j++) {
            totalWidth += [self _widthForColumnAtIndexPath:[MDIndexPath indexPathForColumn:j inSection:i]];
            
            if (!_visibleColumnIndexPath && totalWidth > visibleBounds.origin.x) {
                self._visibleColumnIndexPath = [MDIndexPath indexPathForColumn:j inSection:i];
            }
        }
        
        sectionDescriptor.size = totalWidth - sectionDescriptor.offset;
    }
    
    // actually compare it at some point or something
    self._columnSections = newColumnSections;
    [newColumnSections release];
    
    NSMutableArray *newRowSections = [[NSMutableArray alloc] init];
    
    for (NSUInteger i = 0; i < numberOfRowSections; i++) {
        MDSpreadViewSection *sectionDescriptor = [[MDSpreadViewSection alloc] init];
        [newRowSections addObject:sectionDescriptor];
        [sectionDescriptor release];
        
        NSUInteger numberOfRows = [self _numberOfRowsInSection:i];
        sectionDescriptor.numberOfCells = numberOfRows;
        sectionDescriptor.offset = totalHeight;
        
        totalHeight += [self _heightForRowHeaderInSection:i];
        
        if (!_visibleRowIndexPath && totalHeight > visibleBounds.origin.y) {
            self._visibleRowIndexPath = [MDIndexPath indexPathForRow:-1 inSection:i];
        }
        
        for (NSUInteger j = 0; j < numberOfRows; j++) {
            totalHeight += [self _heightForRowAtIndexPath:[MDIndexPath indexPathForRow:j inSection:i]];
            
            if (!_visibleRowIndexPath && totalHeight > visibleBounds.origin.y) {
                self._visibleRowIndexPath = [MDIndexPath indexPathForRow:j inSection:i];
            }
        }
        
        sectionDescriptor.size = totalHeight - sectionDescriptor.offset;
    }
    
    self._rowSections = newRowSections;
    [newRowSections release];
    
    if (!self._visibleColumnIndexPath) {
        visibleBounds.origin.x = 0;
        self._visibleColumnIndexPath = [MDIndexPath indexPathForColumn:-1 inSection:0];
    }
    
    if (!self._visibleRowIndexPath) {
        visibleBounds.origin.y = 0;
        self._visibleRowIndexPath = [MDIndexPath indexPathForRow:-1 inSection:0];
    }
    
    self.contentOffset = visibleBounds.origin;
    self.contentSize = CGSizeMake(totalWidth-1, totalHeight-1);
    
//    self._headerRowIndexPath = nil;
//    self._headerColumnIndexPath = nil;
    
//    anchorCell.frame = CGRectMake(0, 0, calculatedSize.width, calculatedSize.height);
//    anchorColumnHeaderCell.frame = CGRectMake(0, 0, calculatedSize.width, calculatedSize.height);
//    anchorCornerHeaderCell.frame = CGRectMake(0, 0, calculatedSize.width, calculatedSize.height);
//    anchorRowHeaderCell.frame = CGRectMake(0, 0, calculatedSize.width, calculatedSize.height);
    
//    if (selectedSection != NSNotFound || selectedRow!= NSNotFound) {
//        if (selectedSection > numberOfSections || selectedRow > [self tableView:self numberOfRowsInSection:selectedSection]) {
//            [self deselectRow:selectedRow inSection:selectedSection];
//            [self tableView:self didSelectRow:selectedRow inSection:selectedSection];
//        }
//    }
    
    [pool drain];
    
    [self layoutSubviews];
    
    [CATransaction commit];
}

//- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
//{
//    UIView *returnValue = [anchorCornerHeaderCell hitTest:[anchorCornerHeaderCell convertPoint:point fromView:self] withEvent:event];
//    if (returnValue != anchorCornerHeaderCell) return returnValue;
//    
//    returnValue = [anchorRowHeaderCell hitTest:[anchorRowHeaderCell convertPoint:point fromView:self] withEvent:event];
//    if (returnValue != anchorRowHeaderCell) return returnValue;
//    
//    returnValue = [anchorColumnHeaderCell hitTest:[anchorColumnHeaderCell convertPoint:point fromView:self] withEvent:event];
//    if (returnValue != anchorColumnHeaderCell) return returnValue;
//    
//    returnValue = [anchorCell hitTest:[anchorCell convertPoint:point fromView:self] withEvent:event];
//    if (returnValue != anchorCell) return returnValue;
//    
//    return [super hitTest:point withEvent:event];
//}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [CATransaction begin];
    [CATransaction setAnimationDuration:0];
    [CATransaction setDisableActions:YES];
    
    CGPoint offset = self.contentOffset;
    CGSize boundsSize = self.bounds.size;
    
    if (boundsSize.width == 0 || boundsSize.height == 0) return;
    
//    NSLog(@"--");
//    NSLog(@"Current Visible Bounds: %@ in actual bounds: %@ offset: %@", NSStringFromCGRect(visibleBounds), NSStringFromCGSize(boundsSize), NSStringFromCGPoint(offset));
    
    [self _layoutRemoveColumnCellsAfterWithOffset:offset size:boundsSize];
    [self _layoutAddColumnCellsBeforeWithOffset:offset size:boundsSize];
    [self _layoutRemoveColumnCellsBeforeWithOffset:offset size:boundsSize];
    [self _layoutAddColumnCellsAfterWithOffset:offset size:boundsSize];
    [self _layoutRemoveColumnCellsAfterWithOffset:offset size:boundsSize];
    
    [self _layoutRemoveRowCellsAfterWithOffset:offset size:boundsSize];
    [self _layoutAddRowCellsBeforeWithOffset:offset size:boundsSize];
    [self _layoutRemoveRowCellsBeforeWithOffset:offset size:boundsSize];
    [self _layoutAddRowCellsAfterWithOffset:offset size:boundsSize];
    [self _layoutRemoveRowCellsAfterWithOffset:offset size:boundsSize];
    
    NSSet *allCells = [self _allVisibleCells];
    
    for (MDSpreadViewCell *cell in allCells) {
        cell.hidden = !(cell.bounds.size.width && cell.bounds.size.height);
    }

    if (_visibleColumnIndexPath.column == -1 && [visibleCells count] > 0) {
        NSMutableArray *headerColumn = [visibleCells objectAtIndex:0];
        for (MDSpreadViewCell *cell in headerColumn) {
            if ((NSNull *)cell != [NSNull null]) {
                cell.hidden = YES;
            }
        }
    }
    
    if (_visibleRowIndexPath.row == -1) {
        for (NSMutableArray *column in visibleCells) {
            if ([column count] > 0) {
                MDSpreadViewCell *cell = [column objectAtIndex:0];
                if ((NSNull *)cell != [NSNull null]) {
                    cell.hidden = YES;
                }
            }
        }
    }
    
    for (MDSpreadViewCell *cell in _headerRowCells) {
        cell.hidden = YES;
        [_dequeuedCells addObject:cell];
    }
    
    for (MDSpreadViewCell *cell in _headerColumnCells) {
        cell.hidden = YES;
        [_dequeuedCells addObject:cell];
    }
    
    if (self._headerCornerCell) {
        self._headerCornerCell.hidden = YES;
        [_dequeuedCells addObject:self._headerCornerCell];
        self._headerCornerCell = nil;
    }
    
    [_headerRowCells removeAllObjects];
    [_headerColumnCells removeAllObjects];
    
    NSInteger columnSection = self._visibleColumnIndexPath.section;
    NSInteger column = self._visibleColumnIndexPath.column;
    NSInteger totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
    
    CGFloat constructedWidth = 0;
    UIView *anchor;
    
    NSInteger rowSection = self._visibleRowIndexPath.section;
    NSInteger row = self._visibleRowIndexPath.row;
    NSInteger totalInRowSection = [self _numberOfRowsInSection:rowSection];
    
    CGFloat nextHeaderOffset = visibleBounds.origin.y;
    while (row != -1 || (row == self._visibleRowIndexPath.row && rowSection == self._visibleRowIndexPath.section)) {
        nextHeaderOffset += [self _heightForRowAtIndexPath:[MDIndexPath indexPathForRow:row inSection:rowSection]];
        row++;
        if (row >= totalInRowSection+1) { // +1 for eventual footer
            rowSection++;
            totalInRowSection = [self _numberOfRowsInSection:rowSection];
            row = -1; // -1 for header
        }
    }
    
    CGFloat yOffset = offset.y;
    rowSection = _visibleRowIndexPath.section;
    CGFloat height = [self _heightForRowAtIndexPath:[MDIndexPath indexPathForRow:-1 inSection:rowSection]];
    if (yOffset+height > nextHeaderOffset) {
        yOffset = nextHeaderOffset-height;
    }
    if (yOffset < 0) yOffset = 0;
    
    while (height > 0 && constructedWidth < visibleBounds.size.width) {
        MDIndexPath *columnPath = [MDIndexPath indexPathForColumn:column inSection:columnSection];
        MDSpreadViewCell *cell = nil;
        
        if (column == -1 && columnSection == self._visibleColumnIndexPath.section) {
            cell = nil;
            anchor = nil;
        } else if (column == -1) { // header
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else if (column == totalInColumnSection) { // footer
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else {
            cell = [self _cellForHeaderInRowSection:rowSection forColumnAtIndexPath:columnPath];
            anchor = anchorColumnHeaderCell;
        }
        
        CGFloat width = [self _widthForColumnAtIndexPath:columnPath];
        
        if (cell) {
            [cell setFrame:CGRectMake(visibleBounds.origin.x+constructedWidth, yOffset, width, height)];
            cell.hidden = !(width && height);
            
            [self _willDisplayCell:cell forRowAtIndexPath:[MDIndexPath indexPathForRow:-1 inSection:rowSection] forColumnAtIndexPath:columnPath];
            
            
            [self insertSubview:cell belowSubview:anchor];
            [_headerRowCells addObject:cell];
        }
        constructedWidth += width;
        
        column++;
        if (column >= totalInColumnSection+1) { // +1 for eventual footer
            columnSection++;
            if (columnSection >= [self numberOfColumnSections]) break;
            totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
            column = -1; // -1 for header
        }
    }
    
    rowSection = self._visibleRowIndexPath.section;
    row = self._visibleRowIndexPath.row;
    totalInRowSection = [self _numberOfRowsInSection:rowSection];
    
    CGFloat constructedHeight = 0;
    anchor = nil;
    
    columnSection = self._visibleColumnIndexPath.section;
    column = self._visibleColumnIndexPath.column;
    totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
    
    nextHeaderOffset = visibleBounds.origin.x;
    while (column != -1 || (column == self._visibleColumnIndexPath.row && columnSection == self._visibleColumnIndexPath.section)) {
        nextHeaderOffset += [self _widthForColumnAtIndexPath:[MDIndexPath indexPathForColumn:column inSection:columnSection]];
        column++;
        if (column >= totalInColumnSection+1) { // +1 for eventual footer
            columnSection++;
            totalInColumnSection = [self _numberOfRowsInSection:columnSection];
            column = -1; // -1 for header
        }
    }
    
    CGFloat xOffset = offset.x;
    columnSection = _visibleColumnIndexPath.section;
    CGFloat width = [self _widthForColumnAtIndexPath:[MDIndexPath indexPathForColumn:-1 inSection:columnSection]];
    if (xOffset+width > nextHeaderOffset) {
        xOffset = nextHeaderOffset-width;
    }
    if (xOffset < 0) xOffset = 0;
    
    while (width > 0 && constructedHeight < visibleBounds.size.height) {
        MDIndexPath *rowPath = [MDIndexPath indexPathForRow:row inSection:rowSection];
        MDSpreadViewCell *cell = nil;
        
        if (row == -1 && rowSection == self._visibleRowIndexPath.section) {
            cell = nil;
            anchor = nil;
        } else if (row == -1) { // header
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else if (row == totalInRowSection) { // footer
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else {
            cell = [self _cellForHeaderInColumnSection:columnSection forRowAtIndexPath:rowPath];
            anchor = anchorColumnHeaderCell;
        }
        
        CGFloat height = [self _heightForRowAtIndexPath:rowPath];
        
        if (cell) {
            [cell setFrame:CGRectMake(xOffset, visibleBounds.origin.y+constructedHeight, width, height)];
            cell.hidden = !(width && height);
            
            [self _willDisplayCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:[MDIndexPath indexPathForColumn:-1 inSection:columnSection]];
            
            [self insertSubview:cell belowSubview:anchor];
            [_headerColumnCells addObject:cell];
        }
        
        constructedHeight += height;
        
        row++;
        if (row >= totalInRowSection+1) { // +1 for eventual footer
            rowSection++;
            if (rowSection >= [self numberOfRowSections]) break;
            totalInRowSection = [self _numberOfRowsInSection:rowSection];
            row = -1; // -1 for header
        }
    }
    
    self._headerCornerCell = [self _cellForHeaderInRowSection:_visibleRowIndexPath.section forColumnSection:_visibleColumnIndexPath.section];
    
    width = [self _widthForColumnHeaderInSection:_visibleColumnIndexPath.section];
    height = [self _heightForRowHeaderInSection:_visibleRowIndexPath.section];
    
    if (self._headerCornerCell) {
        [self._headerCornerCell setFrame:CGRectMake(xOffset, yOffset, width, height)];
        self._headerCornerCell.hidden = !(width && height);
        
        [self _willDisplayCell:self._headerCornerCell forRowAtIndexPath:_visibleRowIndexPath forColumnAtIndexPath:_visibleColumnIndexPath];
        
        [self insertSubview:self._headerCornerCell belowSubview:anchorCornerHeaderCell];
    }
    
    NSMutableSet *allVisibleCells = [NSMutableSet setWithSet:[self _allVisibleCells]];
    [allVisibleCells addObjectsFromArray:_headerColumnCells];
    [allVisibleCells addObjectsFromArray:_headerRowCells];
    if (self._headerCornerCell) [allVisibleCells addObject:self._headerCornerCell];
    
    for (MDSpreadViewCell *cell in allVisibleCells) {
        cell.highlighted = NO;
        for (MDSpreadViewSelection *selection in _selectedCells) {
            if (selection.selectionMode == MDSpreadViewSelectionModeNone) continue;
            
            if ([cell._rowPath isEqualToIndexPath:selection.rowPath]) {
                if (selection.selectionMode == MDSpreadViewSelectionModeRow ||
                    selection.selectionMode == MDSpreadViewSelectionModeRowAndColumn) {
                    cell.highlighted = YES;
                }
            }
            
            if ([cell._columnPath isEqualToIndexPath:selection.columnPath]) {
                if (selection.selectionMode == MDSpreadViewSelectionModeColumn ||
                    selection.selectionMode == MDSpreadViewSelectionModeRowAndColumn) {
                    cell.highlighted = YES;
                }
                
                if ([cell._rowPath isEqualToIndexPath:selection.rowPath] && selection.selectionMode == MDSpreadViewSelectionModeCell) {
                    cell.highlighted = YES;
                }
            }
        }
    }
    
//    if (_headerColumnSection != _visibleColumnIndexPath.section) {
//        if (_visibleColumnIndexPath.column == -1 && [visibleCells count] > 0) {
//            for (MDSpreadViewCell *cell in _headerColumnCells) {
//                cell.hidden = YES;
//                [dequeuedCells addObject:cell];
//            }
//            [_headerColumnCells removeAllObjects];
//            NSMutableArray *headerColumn = [visibleCells objectAtIndex:0];
//            for (MDSpreadViewCell *cell in headerColumn) {
//                if ((NSNull *)cell != [NSNull null]) {
//                    [_headerColumnCells addObject:cell];
//                }
//            }
//        } else {
//            
//        }
//        _headerColumnSection = _visibleColumnIndexPath.section;
//    }
//    
//    for (MDSpreadViewCell *cell in _headerColumnCells) {
//        CGRect frame = cell.frame;
//        if (offset.x >= 0) frame.origin.x = offset.x;
//        else frame.origin.x = 0;
//        
//        cell.frame = frame;
//        cell.hidden = !(width && height);
//    }
    
//    if (_headerColumnSection != _visibleColumnIndexPath.section || _headerRowSection != _visibleRowIndexPath.section) {
//    
//        _headerColumnSection = _visibleColumnIndexPath.section;
//        _headerRowSection = _visibleRowIndexPath.section;
//        
////        if (_visibleColumnIndexPath.column == 0) {
////    //        _headerColumnSection--;
////        }
////        
////        if (_visibleRowIndexPath.row == 0) {
////    //        _headerRowSection--;
////        }
//        
//        MDSpreadViewCell *cell = [self _cellForHeaderInRowSection:_headerRowSection forColumnSection:_headerColumnSection];
//        
////        if ([cell superview] != self) {
//            [self insertSubview:cell belowSubview:anchorCornerHeaderCell];
////        }
//    
//        cell.hidden = !(width && height);
//        cell.frame = CGRectMake(0, 0, [self _widthForColumnHeaderInSection:_headerColumnSection], [self _heightForRowHeaderInSection:_headerRowSection]);
//        [self _clearCell:_headerCornerCell];
//        self._headerCornerCell = cell;
//    }
//    
//    _headerCornerCell.frame = CGRectMake(offset.x, offset.y, _headerCornerCell.frame.size.width, _headerCornerCell.frame.size.height);
    
    [CATransaction commit];
}

- (void)_layoutAddColumnCellsBeforeWithOffset:(CGPoint)offset size:(CGSize)size
{
    CGFloat width = 0;
    
    while (visibleBounds.origin.x > offset.x) { // add columns before
        @autoreleasepool {
            NSInteger columnSection = self._visibleColumnIndexPath.section;
            NSInteger column = self._visibleColumnIndexPath.column - 1;
            NSInteger totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
            
            if (column < -1) { // -1 for header
                columnSection--;
                totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
                column = totalInColumnSection; // size of count for eventual footer
            }
            
            if (columnSection < 0) break;
            
            MDIndexPath *columnPath = [MDIndexPath indexPathForColumn:column inSection:columnSection];
            
            width = [self _widthForColumnAtIndexPath:columnPath];
            if (visibleBounds.size.height <= 0) visibleBounds.size.height = [self _heightForRowAtIndexPath:self._visibleRowIndexPath];
            
            visibleBounds.size.width += width;
            visibleBounds.origin.x -= width;
            
            if (column == -1) {
                visibleBounds.origin.x = [[_columnSections objectAtIndex:columnSection] offset];
            }
            
            if (column == -1) { // header
                [self _layoutHeaderInColumnSection:columnSection withWidth:width xOffset:visibleBounds.origin.x];
            } else if (column == totalInColumnSection) { // footer
                [self _layoutFooterInColumnSection:columnSection withWidth:width xOffset:visibleBounds.origin.x];
            } else { // cells
                [self _layoutColumnAtIndexPath:columnPath withWidth:width xOffset:visibleBounds.origin.x];
            }
        }
    }
}

- (void)_layoutAddColumnCellsAfterWithOffset:(CGPoint)offset size:(CGSize)size
{
    @autoreleasepool {
        NSUInteger numberOfColumnSections = [self _numberOfColumnSections];
    
        MDIndexPath *lastIndexPath = [[[self _columnIndexPathFromRelativeIndex:visibleCells.count-1] retain] autorelease];
//        int numberOfPasses = 0;
        
//        NSLog(@"Count: %d, %@", visibleCells.count, _visibleColumnIndexPath);
//        
//        NSLog(@"Adding From %@", lastIndexPath);
        
        while (visibleBounds.origin.x+visibleBounds.size.width < offset.x+size.width) { // add columns after
            NSInteger columnSection = lastIndexPath.section;
            NSInteger column = lastIndexPath.column + 1; // get the next index
            NSInteger totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
            
            if (column >= totalInColumnSection+1) { // +1 for eventual footer
                columnSection++;
                column = -1; // -1 for header
            }
            lastIndexPath = [MDIndexPath indexPathForColumn:column inSection:columnSection]; // set indexpath for next runthrough
            
            if (columnSection >= numberOfColumnSections) break;
            
            MDIndexPath *columnPath = lastIndexPath;
            
            CGFloat width = [self _widthForColumnAtIndexPath:columnPath];
            
            visibleBounds.size.width += width;
            if (visibleBounds.size.height <= 0) visibleBounds.size.height = [self _heightForRowAtIndexPath:self._visibleRowIndexPath];
            
            if (column == -1) { // header
                [self _layoutHeaderInColumnSection:columnSection withWidth:width xOffset:visibleBounds.origin.x+visibleBounds.size.width-width];
            } else if (column == totalInColumnSection) { // footer
                [self _layoutFooterInColumnSection:columnSection withWidth:width xOffset:visibleBounds.origin.x+visibleBounds.size.width-width];
            } else {
                [self _layoutColumnAtIndexPath:columnPath withWidth:width xOffset:visibleBounds.origin.x+visibleBounds.size.width-width];
            }
        }
        
//        NSLog(@"         To %@", [self _columnIndexPathFromRelativeIndex:visibleCells.count-1]);
    }
}

- (void)_layoutRemoveColumnCellsBeforeWithOffset:(CGPoint)offset size:(CGSize)size
{
    @autoreleasepool {
        CGFloat width = 0;
        MDIndexPath *indexPathToRemove = [[self._visibleColumnIndexPath retain] autorelease];
        MDIndexPath *nextIndexPathToRemove = nil;
    
        NSUInteger numberOfColumnSections = [self _numberOfColumnSections];
        width = [self _widthForColumnAtIndexPath:indexPathToRemove];
        
//        NSLog(@"Removing From %@", indexPathToRemove);
//        NSLog(@"    Current Visible Bounds: %@ in {%@, %@}", NSStringFromCGRect(visibleBounds), NSStringFromCGPoint(offset), NSStringFromCGSize(size));
        
        while (visibleBounds.origin.x+width < offset.x) { // delete left most column
            visibleBounds.size.width -= width;
            if (visibleBounds.size.width < 0) visibleBounds.size.width = 0;
            visibleBounds.origin.x += width;
            
            if (indexPathToRemove.column == -1) {
                visibleBounds.origin.x = [[_columnSections objectAtIndex:indexPathToRemove.section] offset] + width;
            }
            
            if (visibleCells.count > 0)
                [self _clearCellsForColumnAtIndexPath:indexPathToRemove];
            
            NSInteger columnSection = indexPathToRemove.section;
            NSInteger column = indexPathToRemove.column+1;
            NSInteger totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
            
            if (column >= totalInColumnSection+1) {
                columnSection++;
                column = -1; // -1 for header
                
                if (columnSection >= numberOfColumnSections) {
                    columnSection = numberOfColumnSections-1;
                    column = totalInColumnSection;
                }
            }
            
            nextIndexPathToRemove = [MDIndexPath indexPathForColumn:column inSection:columnSection];
            if ([indexPathToRemove isEqualToIndexPath:nextIndexPathToRemove]) break;
            
            indexPathToRemove = nextIndexPathToRemove;
            width = [self _widthForColumnAtIndexPath:indexPathToRemove];
        }
        
        if (visibleCells.count == 0)
            self._visibleColumnIndexPath = indexPathToRemove;
    
//        NSLog(@"           To %@ (%@)", indexPathToRemove, self._visibleColumnIndexPath);
//        NSLog(@"    Current Visible Bounds: %@ in {%@, %@}", NSStringFromCGRect(visibleBounds), NSStringFromCGPoint(offset), NSStringFromCGSize(size));
    }
}

- (void)_layoutRemoveColumnCellsAfterWithOffset:(CGPoint)offset size:(CGSize)size
{
//    if (!self._visibleColumnIndexPath) return;
    
    CGFloat width = 0;
    MDIndexPath *lastIndexPath = nil;
    MDIndexPath *last2IndexPath = nil;
    MDIndexPath *nextIndexPath = nil;
    
    @autoreleasepool {
        lastIndexPath = [self _columnIndexPathFromRelativeIndex:visibleCells.count-1];
        last2IndexPath = self._visibleColumnIndexPath;
        width = [self _widthForColumnAtIndexPath:lastIndexPath];
        
//        NSLog(@"Removing From %@ (%@) %@", lastIndexPath, self._visibleColumnIndexPath, NSStringFromCGRect(visibleBounds));
        
        while (visibleBounds.origin.x+visibleBounds.size.width-width > offset.x+size.width) { // delete right most column
            if (lastIndexPath.section == 0 && lastIndexPath.column < -1) break;
            
            visibleBounds.size.width -= width;
            if (visibleBounds.size.width < 0) {
                visibleBounds.origin.x += visibleBounds.size.width;
                visibleBounds.size.width = 0;
                
                if (lastIndexPath.column == -1) {
                    visibleBounds.origin.x = [[_columnSections objectAtIndex:lastIndexPath.section] offset];
                }
            }
            
            if (visibleCells.count > 0)
                [self _clearCellsForColumnAtIndexPath:lastIndexPath];
            
            //            NSLog(@"Removing cell %d,%d from the right (%d columns)", lastIndexPath.section, lastIndexPath.column, visibleCells.count);
            //            NSLog(@"    Current Visible Bounds: %@ in {%@, %@}", NSStringFromCGRect(visibleBounds), NSStringFromCGPoint(offset), NSStringFromCGSize(boundsSize));
            
            NSInteger columnSection = lastIndexPath.section;
            NSInteger column = lastIndexPath.column-1;
            
            if (column < -1) {
                columnSection--;
                column = [self _numberOfColumnsInSection:columnSection];
                
                if (columnSection < 0) {
                    columnSection = 0;
                    column = -1;
                }
            }
            
            nextIndexPath = [MDIndexPath indexPathForColumn:column inSection:columnSection];
            last2IndexPath = lastIndexPath;
            if ([lastIndexPath isEqualToIndexPath:nextIndexPath]) break;
            lastIndexPath = nextIndexPath;
            width = [self _widthForColumnAtIndexPath:lastIndexPath];
        }
        if ([visibleCells count] == 0)
            self._visibleColumnIndexPath = last2IndexPath;
        
//        NSLog(@"           To %@ (%@)", lastIndexPath, self._visibleColumnIndexPath);
//        NSLog(@"    Current Visible Bounds: %@ in {%@, %@}", NSStringFromCGRect(visibleBounds), NSStringFromCGPoint(offset), NSStringFromCGSize(size));
    }
}

- (void)_layoutAddRowCellsBeforeWithOffset:(CGPoint)offset size:(CGSize)size
{
    CGFloat height = 0;
    
    while (visibleBounds.origin.y > offset.y) { // add rows before
        @autoreleasepool {
            NSInteger rowSection = self._visibleRowIndexPath.section;
            NSInteger row = self._visibleRowIndexPath.row - 1;
            NSInteger totalInRowSection = [self _numberOfRowsInSection:rowSection];
            
            if (row < -1) { // -1 for header
                rowSection--;
                totalInRowSection = [self _numberOfRowsInSection:rowSection];
                row = totalInRowSection; // count for eventual footer
            }
            
            if (rowSection < 0) break;
            
            MDIndexPath *rowPath = [MDIndexPath indexPathForRow:row inSection:rowSection];
            
            height = 0;
            
            if (visibleBounds.size.width) {
                height = [self _heightForRowAtIndexPath:rowPath];
            }
            
            visibleBounds.size.height += height;
            visibleBounds.origin.y -= height;
            
            if (row == -1) {
                visibleBounds.origin.y = [[_rowSections objectAtIndex:rowSection] offset];
            }
            
            if (row == -1) { // header
                [self _layoutHeaderInRowSection:rowSection withHeight:height yOffset:visibleBounds.origin.y];
            } else if (row == totalInRowSection) { // footer
                [self _layoutFooterInRowSection:rowSection withHeight:height yOffset:visibleBounds.origin.y];
            } else { // cells
                [self _layoutRowAtIndexPath:rowPath withHeight:height yOffset:visibleBounds.origin.y];
            }
        }
    }
}

- (void)_layoutAddRowCellsAfterWithOffset:(CGPoint)offset size:(CGSize)size
{
    NSUInteger numberOfRowSections = [self _numberOfRowSections];
    
    CGFloat height = 0;
    MDIndexPath *lastIndexPath = nil;
    
    if (visibleCells.count) {
        @autoreleasepool {
            lastIndexPath = [self _rowIndexPathFromRelativeIndex:[[visibleCells objectAtIndex:0] count]-1];
            
            while (visibleBounds.origin.y+visibleBounds.size.height < offset.y+size.height) { // add rows after
                NSInteger rowSection = lastIndexPath.section;
                NSInteger row = lastIndexPath.row + 1;
                NSInteger totalInRowSection = [self _numberOfRowsInSection:rowSection];
                
                if (row >= totalInRowSection+1) { // +1 for eventual footer
                    rowSection++;
                    row = -1; // -1 for header
                }
                
                lastIndexPath = [MDIndexPath indexPathForRow:row inSection:rowSection];
                
                if (rowSection >= numberOfRowSections) break;
                
                MDIndexPath *rowPath = lastIndexPath;
                
                height = 0;
                
                if (visibleBounds.size.width) {
                    height = [self _heightForRowAtIndexPath:rowPath];
                }
                
                visibleBounds.size.height += height;
                
                if (row == -1) { // header
                    [self _layoutHeaderInRowSection:rowSection withHeight:height yOffset:visibleBounds.origin.y+visibleBounds.size.height-height];
                } else if (row == totalInRowSection) { // footer
                    [self _layoutFooterInRowSection:rowSection withHeight:height yOffset:visibleBounds.origin.y+visibleBounds.size.height-height];
                } else {
                    [self _layoutRowAtIndexPath:rowPath withHeight:height yOffset:visibleBounds.origin.y+visibleBounds.size.height-height];
                }
            }
        }
    }
}

- (void)_layoutRemoveRowCellsBeforeWithOffset:(CGPoint)offset size:(CGSize)size
{
    CGFloat height = 0;
    MDIndexPath *lastIndexPath = nil;
    
    @autoreleasepool {
        lastIndexPath = self._visibleRowIndexPath;
        height = [self _heightForRowAtIndexPath:lastIndexPath];
        
        while (visibleBounds.origin.y+height < offset.y) { // delete top most row
            visibleBounds.size.height -= height;
            if (visibleBounds.size.height < 0) visibleBounds.size.height = 0;
            visibleBounds.origin.y += height;
            
            if (lastIndexPath.row == -1) {
                visibleBounds.origin.y = [[_rowSections objectAtIndex:lastIndexPath.section] offset] + height;
            }
            
            //            MDIndexPath *firstIndexPath = [[self._visibleRowIndexPath retain] autorelease];
            [self _clearCellsForRowAtIndexPath:lastIndexPath];
            
            //            NSLog(@"Removing cell %d,%d from the top (%d rows)", firstIndexPath.section, firstIndexPath.column, [[visibleCells objectAtIndex:0] count]);
            //            NSLog(@"    Current Visible Bounds: %@ in {%@, %@}", NSStringFromCGRect(visibleBounds), NSStringFromCGPoint(offset), NSStringFromCGSize(boundsSize));
            
            if (lastIndexPath == self._visibleRowIndexPath) break;
            lastIndexPath = self._visibleRowIndexPath;
            height = [self _heightForRowAtIndexPath:lastIndexPath];
        }
    }
}

- (void)_layoutRemoveRowCellsAfterWithOffset:(CGPoint)offset size:(CGSize)size
{
    CGFloat height = 0;
    MDIndexPath *lastIndexPath = nil;
    MDIndexPath *last2IndexPath = nil;
    MDIndexPath *nextIndexPath = nil;
    
    if (visibleCells.count) @autoreleasepool {
        lastIndexPath = [self _rowIndexPathFromRelativeIndex:[[visibleCells objectAtIndex:0] count]-1];
        height = [self _heightForRowAtIndexPath:lastIndexPath];
        
//        NSLog(@"Removing From %@", lastIndexPath);
        
        while (visibleBounds.origin.y+visibleBounds.size.height-height > offset.y+size.height) { // delete bottom most row
            if (lastIndexPath.section == 0 && lastIndexPath.row < -1) break;
            
            visibleBounds.size.height -= height;
            if (visibleBounds.size.height < 0) {
                visibleBounds.origin.y += visibleBounds.size.height;
                visibleBounds.size.height = 0;
                
                if (lastIndexPath.row == -1) {
                    visibleBounds.origin.y = [[_rowSections objectAtIndex:lastIndexPath.section] offset];
                }
            }
            
            if ([[visibleCells objectAtIndex:0] count] > 0)
                [self _clearCellsForRowAtIndexPath:lastIndexPath];
            
//                NSLog(@"Removing cell %d,%d from the bottom (%d rows)", lastIndexPath.section, lastIndexPath.column, [[visibleCells objectAtIndex:0] count]);
//                NSLog(@"    Current Visible Bounds: %@ in {%@, %@}", NSStringFromCGRect(visibleBounds), NSStringFromCGPoint(offset), NSStringFromCGSize(size));
            
            NSInteger rowSection = lastIndexPath.section;
            NSInteger row = lastIndexPath.row-1;
            
            if (row < -1) {
                rowSection--;
                row = [self _numberOfRowsInSection:rowSection];
                
                if (rowSection < 0) {
                    rowSection = 0;
                    row = -1;
                }
            }
            
            nextIndexPath = [MDIndexPath indexPathForRow:row inSection:rowSection];
            last2IndexPath = lastIndexPath;
            if ([lastIndexPath isEqualToIndexPath:nextIndexPath]) break;
            lastIndexPath = nextIndexPath;
            height = [self _heightForRowAtIndexPath:lastIndexPath];
        }
        if ([[visibleCells objectAtIndex:0] count] == 0)
            self._visibleRowIndexPath = last2IndexPath;
        
//        NSLog(@"           To %@", lastIndexPath);
//        NSLog(@"    Current Visible Bounds: %@ in {%@, %@}", NSStringFromCGRect(visibleBounds), NSStringFromCGPoint(offset), NSStringFromCGSize(size));
    }
}

- (void)_layoutColumnAtIndexPath:(MDIndexPath *)columnPath withWidth:(CGFloat)width xOffset:(CGFloat)xOffset
{
    NSInteger rowSection = self._visibleRowIndexPath.section;
    NSInteger row = self._visibleRowIndexPath.row;
    NSInteger totalInRowSection = [self _numberOfRowsInSection:rowSection];
    
    CGFloat constructedHeight = 0;
    UIView *anchor;
    
    while (constructedHeight < visibleBounds.size.height) {
        MDIndexPath *rowPath = [MDIndexPath indexPathForRow:row inSection:rowSection];
        MDSpreadViewCell *cell = nil;
        
        if (row == -1) { // header
            cell = [self _cellForHeaderInRowSection:rowSection forColumnAtIndexPath:columnPath];
            anchor = anchorRowHeaderCell;
        } else if (row == totalInRowSection) { // footer
            cell = [self _cellForHeaderInRowSection:rowSection forColumnAtIndexPath:columnPath];
            anchor = anchorRowHeaderCell;
        } else {
            cell = [self _cellForRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
            anchor = anchorCell;
        }
        
        [self _setVisibleCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
        CGFloat height = [self _heightForRowAtIndexPath:rowPath];
        
        [cell setFrame:CGRectMake(xOffset, visibleBounds.origin.y+constructedHeight, width, height)];
        constructedHeight += height;
        
        cell.hidden = !(width && height);
        
        [self _willDisplayCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
//        if ([cell superview] != self) {
            [self insertSubview:cell belowSubview:anchor];
//        }
        
        row++;
        if (row >= totalInRowSection+1) { // +1 for eventual footer
            rowSection++;
            totalInRowSection = [self _numberOfRowsInSection:rowSection];
            row = -1; // -1 for header
        }
    }
}

- (void)_layoutHeaderInColumnSection:(NSInteger)columnSection withWidth:(CGFloat)width xOffset:(CGFloat)xOffset
{
    NSInteger rowSection = self._visibleRowIndexPath.section;
    NSInteger row = self._visibleRowIndexPath.row;
    NSInteger totalInRowSection = [self _numberOfRowsInSection:rowSection];
    
    CGFloat constructedHeight = 0;
    UIView *anchor;
    MDIndexPath *columnPath = [MDIndexPath indexPathForColumn:-1 inSection:columnSection];
    
    while (constructedHeight < visibleBounds.size.height) {
        MDIndexPath *rowPath = [MDIndexPath indexPathForRow:row inSection:rowSection];
        MDSpreadViewCell *cell = nil;
        
        if (row == -1) { // header
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else if (row == totalInRowSection) { // footer
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else {
            cell = [self _cellForHeaderInColumnSection:columnSection forRowAtIndexPath:rowPath];
            anchor = anchorColumnHeaderCell;
        }
        
        [self _setVisibleCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
        CGFloat height = [self _heightForRowAtIndexPath:rowPath];
        
        [cell setFrame:CGRectMake(xOffset, visibleBounds.origin.y+constructedHeight, width, height)];
        constructedHeight += height;
        
        cell.hidden = !(width && height);
        
        [self _willDisplayCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
//        if ([cell superview] != self) {
            [self insertSubview:cell belowSubview:anchor];
//        }
        
        row++;
        if (row >= totalInRowSection+1) { // +1 for eventual footer
            rowSection++;
            totalInRowSection = [self _numberOfRowsInSection:rowSection];
            row = -1; // -1 for header
        }
    }
}

- (void)_layoutFooterInColumnSection:(NSInteger)columnSection withWidth:(CGFloat)width xOffset:(CGFloat)xOffset
{
    NSInteger rowSection = self._visibleRowIndexPath.section;
    NSInteger row = self._visibleRowIndexPath.row;
    NSInteger totalInRowSection = [self _numberOfRowsInSection:rowSection];
    
    CGFloat constructedHeight = 0;
    UIView *anchor;
    MDIndexPath *columnPath = [MDIndexPath indexPathForColumn:[self _numberOfColumnsInSection:columnSection] inSection:columnSection];
    
    while (constructedHeight < visibleBounds.size.height) {
        MDIndexPath *rowPath = [MDIndexPath indexPathForRow:row inSection:rowSection];
        MDSpreadViewCell *cell = nil;
        
        if (row == -1) { // header
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else if (row == totalInRowSection) { // footer
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else {
            cell = [self _cellForHeaderInColumnSection:columnSection forRowAtIndexPath:rowPath];
            anchor = anchorColumnHeaderCell;
        }
        
        [self _setVisibleCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
        CGFloat height = [self _heightForRowAtIndexPath:rowPath];
        
        [cell setFrame:CGRectMake(xOffset, visibleBounds.origin.y+constructedHeight, width, height)];
        constructedHeight += height;
        
        cell.hidden = !(width && height);
        
        [self _willDisplayCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
//        if ([cell superview] != self) {
            [self insertSubview:cell belowSubview:anchor];
//        }
        
        row++;
        if (row >= totalInRowSection+1) { // +1 for eventual footer
            rowSection++;
            totalInRowSection = [self _numberOfRowsInSection:rowSection];
            row = -1; // -1 for header
        }
    }
}

- (void)_layoutRowAtIndexPath:(MDIndexPath *)rowPath withHeight:(CGFloat)height yOffset:(CGFloat)yOffset
{
    NSInteger columnSection = self._visibleColumnIndexPath.section;
    NSInteger column = self._visibleColumnIndexPath.column;
    NSInteger totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
    
    CGFloat constructedWidth = 0;
    UIView *anchor;
    
    while (constructedWidth < visibleBounds.size.width) {
        MDIndexPath *columnPath = [MDIndexPath indexPathForColumn:column inSection:columnSection];
        MDSpreadViewCell *cell = nil;
        
        if (column == -1) { // header
            cell = [self _cellForHeaderInColumnSection:columnSection forRowAtIndexPath:rowPath];
            anchor = anchorColumnHeaderCell;
        } else if (column == totalInColumnSection) { // footer
            cell = [self _cellForHeaderInColumnSection:columnSection forRowAtIndexPath:rowPath];
            anchor = anchorColumnHeaderCell;
        } else {
            cell = [self _cellForRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
            anchor = anchorCell;
        }
        
        [self _setVisibleCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
        CGFloat width = [self _widthForColumnAtIndexPath:columnPath];
        
        [cell setFrame:CGRectMake(visibleBounds.origin.x+constructedWidth, yOffset, width, height)];
        constructedWidth += width;
        
        cell.hidden = !(width && height);
        
        [self _willDisplayCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
//        if ([cell superview] != self) {
            [self insertSubview:cell belowSubview:anchor];
//        }
        
        column++;
        if (column >= totalInColumnSection+1) { // +1 for eventual footer
            columnSection++;
            totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
            column = -1; // -1 for header
        }
    }
}

- (void)_layoutHeaderInRowSection:(NSInteger)rowSection withHeight:(CGFloat)height yOffset:(CGFloat)yOffset
{
    NSInteger columnSection = self._visibleColumnIndexPath.section;
    NSInteger column = self._visibleColumnIndexPath.column;
    NSInteger totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
    
    CGFloat constructedWidth = 0;
    UIView *anchor;
    MDIndexPath *rowPath = [MDIndexPath indexPathForRow:-1 inSection:rowSection];
    
    while (constructedWidth < visibleBounds.size.width) {
        MDIndexPath *columnPath = [MDIndexPath indexPathForColumn:column inSection:columnSection];
        MDSpreadViewCell *cell = nil;
        
        if (column == -1) { // header
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else if (column == totalInColumnSection) { // footer
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else {
            cell = [self _cellForHeaderInRowSection:rowSection forColumnAtIndexPath:columnPath];
            anchor = anchorColumnHeaderCell;
        }
        
        [self _setVisibleCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
        CGFloat width = [self _widthForColumnAtIndexPath:columnPath];
        
        [cell setFrame:CGRectMake(visibleBounds.origin.x+constructedWidth, yOffset, width, height)];
        constructedWidth += width;
        
        cell.hidden = !(width && height);
        
        [self _willDisplayCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
//        if ([cell superview] != self) {
            [self insertSubview:cell belowSubview:anchor];
//        }
        
        column++;
        if (column >= totalInColumnSection+1) { // +1 for eventual footer
            columnSection++;
            totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
            column = -1; // -1 for header
        }
    }
}
- (void)_layoutFooterInRowSection:(NSInteger)rowSection withHeight:(CGFloat)height yOffset:(CGFloat)yOffset
{
    NSInteger columnSection = self._visibleColumnIndexPath.section;
    NSInteger column = self._visibleColumnIndexPath.column;
    NSInteger totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
    
    CGFloat constructedWidth = 0;
    UIView *anchor;
    MDIndexPath *rowPath = [MDIndexPath indexPathForRow:[self _numberOfRowsInSection:rowSection] inSection:rowSection];
    
    while (constructedWidth < visibleBounds.size.width) {
        MDIndexPath *columnPath = [MDIndexPath indexPathForColumn:column inSection:columnSection];
        MDSpreadViewCell *cell = nil;
        
        if (column == -1) { // header
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else if (column == totalInColumnSection) { // footer
            cell = [self _cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
            anchor = anchorCornerHeaderCell;
        } else {
            cell = [self _cellForHeaderInRowSection:rowSection forColumnAtIndexPath:columnPath];
            anchor = anchorColumnHeaderCell;
        }
        
        [self _setVisibleCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
        CGFloat width = [self _widthForColumnAtIndexPath:columnPath];
        
        [cell setFrame:CGRectMake(visibleBounds.origin.x+constructedWidth, yOffset, width, height)];
        constructedWidth += width;
        
        cell.hidden = !(width && height);
        
        [self _willDisplayCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
//        if ([cell superview] != self) {
            [self insertSubview:cell belowSubview:anchor];
//        }
        
        column++;
        if (column >= totalInColumnSection+1) { // +1 for eventual footer
            columnSection++;
            totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
            column = -1; // -1 for header
        }
    }
}

- (CGRect)rectForRowSection:(NSInteger)rowSection columnSection:(NSInteger)columnSection
{
    if (!_rowSections || !_columnSections ||
        rowSection < 0 || rowSection >= [self numberOfRowSections] ||
        columnSection < 0 || columnSection >= [self numberOfColumnSections]) return CGRectNull;
    
    MDSpreadViewSection *column = [_columnSections objectAtIndex:columnSection];
    MDSpreadViewSection *row = [_rowSections objectAtIndex:rowSection];
    
    return CGRectMake(column.offset, row.offset, column.size, row.size);
}

- (CGRect)cellRectForRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath
{
    if (!_rowSections || !_columnSections ||
        rowPath.section < 0 || rowPath.section >= [self numberOfRowSections] ||
        columnPath.section < 0 || columnPath.section >= [self numberOfColumnSections]) return CGRectNull;
    
    MDSpreadViewSection *columnSection = [_columnSections objectAtIndex:columnPath.section];
    MDSpreadViewSection *rowSection = [_rowSections objectAtIndex:rowPath.section];
    
    if (rowPath.row < -1 || rowPath.row > rowSection.numberOfCells ||
        columnPath.column < -1 || columnPath.column > columnSection.numberOfCells) return CGRectNull;
    
    CGRect rect = CGRectMake(columnSection.offset, rowSection.offset, [self _widthForColumnAtIndexPath:columnPath], [self _heightForRowAtIndexPath:rowPath]);
    
    if (columnPath.column >= 0)
        rect.origin.x += [self _widthForColumnHeaderInSection:columnPath.section];
    
    for (int i = 0; i < columnPath.column; i++) {
        rect.origin.x += [self _widthForColumnAtIndexPath:[MDIndexPath indexPathForColumn:i inSection:columnPath.section]];
    }
    
    if (rowPath.row >= 0)
        rect.origin.y += [self _heightForRowHeaderInSection:rowPath.section];
    
    for (int i = 0; i < rowPath.row; i++) {
        rect.origin.y += [self _heightForRowAtIndexPath:[MDIndexPath indexPathForRow:i inSection:rowPath.section]];
    }
    
    return rect;
}

#pragma mark - Cell Management

- (MDSpreadViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier
{
    MDSpreadViewCell *dequeuedCell = nil;
//    NSUInteger _reuseHash = [identifier hash];
//    for (MDSpreadViewCell *aCell in _dequeuedCells) {
//        if (aCell->_reuseHash == _reuseHash) {
//            dequeuedCell = aCell;
//            break;
//        }
//    }
    
    for (MDSpreadViewCell *aCell in _dequeuedCells) {
        if ([aCell.reuseIdentifier isEqualToString:identifier]) {
            dequeuedCell = aCell;
            break;
        }
    }
    if (dequeuedCell) {
        [dequeuedCell retain];
        [_dequeuedCells removeObject:dequeuedCell];
        [dequeuedCell prepareForReuse];
    }
    return [dequeuedCell autorelease];
}

- (NSInteger)_relativeIndexOfRowAtIndexPath:(MDIndexPath *)indexPath
{
    NSInteger numberOfSections = indexPath.section - _visibleRowIndexPath.section;
    
    NSInteger returnIndex = 0;
    
    if (numberOfSections == 0) {
        returnIndex += indexPath.row-_visibleRowIndexPath.row;
    } else if (numberOfSections > 0) {
        for (int i = _visibleRowIndexPath.section; i <= indexPath.section; i++) {
            if (i == _visibleRowIndexPath.section) {
                returnIndex += [self _numberOfRowsInSection:i]-_visibleRowIndexPath.row+1;
            } else if (i == indexPath.section) {
                returnIndex += indexPath.row + 1;
            } else {
                returnIndex += [self _numberOfRowsInSection:i] + 2;
            }
        }
    } else {
        for (int i = _visibleRowIndexPath.section; i >= indexPath.section; i--) {
            if (i == _visibleRowIndexPath.section) {
                returnIndex -= _visibleRowIndexPath.row+1;
            } else if (i == indexPath.section) {
                returnIndex -= [self _numberOfRowsInSection:i] - indexPath.row + 1;
            } else {
                returnIndex -= [self _numberOfRowsInSection:i] + 2;
            }
        }
    }
    
    return returnIndex;
}

- (NSInteger)_relativeIndexOfColumnAtIndexPath:(MDIndexPath *)indexPath
{
    NSInteger numberOfSections = indexPath.section - _visibleColumnIndexPath.section;
    
    NSInteger returnIndex = 0;
    
    if (numberOfSections == 0) {
        returnIndex += indexPath.column-_visibleColumnIndexPath.column;
    } else if (numberOfSections > 0) {
        for (int i = _visibleColumnIndexPath.section; i <= indexPath.section; i++) {
            if (i == _visibleColumnIndexPath.section) {
                returnIndex += [self _numberOfColumnsInSection:i]-_visibleColumnIndexPath.column+1;
            } else if (i == indexPath.section) {
                returnIndex += indexPath.column + 1;
            } else {
                returnIndex += [self _numberOfColumnsInSection:i] + 2;
            }
        }
    } else {
        for (int i = _visibleColumnIndexPath.section; i >= indexPath.section; i--) {
            if (i == _visibleColumnIndexPath.section) {
                returnIndex -= _visibleColumnIndexPath.column+1;
            } else if (i == indexPath.section) {
                returnIndex -= [self _numberOfColumnsInSection:i] - indexPath.column + 1;
            } else {
                returnIndex -= [self _numberOfColumnsInSection:i] + 2;
            }
        }
    }
    
    return returnIndex;
}

- (MDIndexPath *)_rowIndexPathFromRelativeIndex:(NSInteger)index
{
    NSInteger rowSection = self._visibleRowIndexPath.section;
    NSInteger row = self._visibleRowIndexPath.row;
    NSInteger totalInRowSection = [self _numberOfRowsInSection:rowSection];
    
    if (index == -1) {
        return [MDIndexPath indexPathForRow:row-1 inSection:rowSection];
    }
    
    for (int i = 0; i < index; i++) {
        row++;
        if (row >= totalInRowSection+1) { // +1 for eventual footer
            rowSection++;
            totalInRowSection = [self _numberOfRowsInSection:rowSection];
            row = -1; // -1 for header
        }
    }
    
    return [MDIndexPath indexPathForRow:row inSection:rowSection];
}

- (MDIndexPath *)_columnIndexPathFromRelativeIndex:(NSInteger)index
{
    NSInteger columnSection = self._visibleColumnIndexPath.section;
    NSInteger column = self._visibleColumnIndexPath.column;
    NSInteger totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
    
    if (index == -1) {
        return [MDIndexPath indexPathForColumn:column-1 inSection:columnSection];
    }
    
    for (int i = 0; i < index; i++) {
        column++;
        if (column >= totalInColumnSection+1) { // +1 for eventual footer
            columnSection++;
            totalInColumnSection = [self _numberOfColumnsInSection:columnSection];
            column = -1; // -1 for header
        }
    }
    
    return [MDIndexPath indexPathForColumn:column inSection:columnSection];
}

- (NSInteger)_relativeIndexOfHeaderRowInSection:(NSInteger)rowSection
{
    return [self _relativeIndexOfRowAtIndexPath:[MDIndexPath indexPathForRow:-1 inSection:rowSection]];
}

- (NSInteger)_relativeIndexOfHeaderColumnInSection:(NSInteger)columnSection
{
    return [self _relativeIndexOfColumnAtIndexPath:[MDIndexPath indexPathForColumn:-1 inSection:columnSection]];
}

- (NSSet *)_allVisibleCells
{
    NSMutableSet *allCells = [[NSMutableSet alloc] init];
    
    for (NSArray *column in visibleCells) {
        for (id cell in column) {
            if (cell != [NSNull null]) {
                [allCells addObject:cell];
            }
        }
    }
    
    return [allCells autorelease];
}

- (MDSpreadViewCell *)_visibleCellForRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath
{
    NSInteger xIndex = [self _relativeIndexOfColumnAtIndexPath:columnPath];
    NSInteger yIndex = [self _relativeIndexOfRowAtIndexPath:rowPath];
    
    if (xIndex < 0 || yIndex < 0 || xIndex >= visibleCells.count) {
        return nil;
    }
    
    NSMutableArray *column = [visibleCells objectAtIndex:xIndex];
    
    if (yIndex >= column.count) {
        return nil;
    }
    
    id cell = [column objectAtIndex:yIndex];
    
    if ((NSNull *)cell != [NSNull null]) {
        return cell;
    }
    
    return nil;
}

- (void)_setVisibleCell:(MDSpreadViewCell *)cell forRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath
{
    NSInteger xIndex = [self _relativeIndexOfColumnAtIndexPath:columnPath];
    NSInteger yIndex = [self _relativeIndexOfRowAtIndexPath:rowPath];
    
    if (cell) {
        if (xIndex < 0) {
            NSUInteger count = -xIndex;
            for (int i = 0; i < count; i++) {
                NSMutableArray *array = [[NSMutableArray alloc] init];
                [visibleCells insertObject:array atIndex:0];
                [array release];
            }
            self._visibleColumnIndexPath = columnPath;
            xIndex = 0;
        } else if (xIndex >= [visibleCells count]) {
            NSUInteger count = xIndex+1-[visibleCells count];
            for (int i = 0; i < count; i++) {
                NSMutableArray *array = [[NSMutableArray alloc] init];
                [visibleCells addObject:array];
                [array release];
            }
        }
        
        NSMutableArray *column = [visibleCells objectAtIndex:xIndex];
        
        if (yIndex < 0) {
            NSUInteger count = -yIndex;
            for (NSMutableArray *column in visibleCells) {
                for (int i = 0; i < count; i++) {
                    [column insertObject:[NSNull null] atIndex:0];
                }
            }
            self._visibleRowIndexPath = rowPath;
            yIndex = 0;
        } else if (yIndex >= [column count]) {
            NSUInteger count = yIndex+1-[column count];
            for (int i = 0; i < count; i++) {
                NSNull *null = [NSNull null];
                [column addObject:null];
            }
        }
        
        [column replaceObjectAtIndex:yIndex withObject:cell];
    } else {
        if (xIndex < 0 || yIndex < 0 || xIndex >= visibleCells.count) {
            return;
        }
        
        NSMutableArray *column = [visibleCells objectAtIndex:xIndex];
        
        if (yIndex >= column.count) {
            return;
        } else if (yIndex == column.count-1) {
            [column removeLastObject];
        } else {
            NSNull *null = [NSNull null];
            [column replaceObjectAtIndex:yIndex withObject:null];
        }
        
        if (xIndex == 0 || xIndex == visibleCells.count-1) {
            BOOL foundCell = NO;
            
            while (!foundCell) {
                NSMutableArray *columnToCheck = [visibleCells objectAtIndex:xIndex];
                if (xIndex > 0) xIndex--; // prepare for next run through
                
                for (id cell in columnToCheck) {
                    if ((NSNull *)cell != [NSNull null]) {
                        foundCell = YES;
                        break;
                    }
                }
                
                if (!foundCell) {
                    [visibleCells removeObject:columnToCheck];
                    
                    if (xIndex == 0) {
                        NSInteger section = self._visibleColumnIndexPath.section;
                        NSInteger column = self._visibleColumnIndexPath.column + 1;
                        NSInteger totalInSection = [self _numberOfColumnsInSection:section];
                        
                        if (column >= totalInSection+1) { // +1 for eventual footer
                            section++;
                            column = -1; // -1 for header
                        }
                    
                        self._visibleColumnIndexPath = [MDIndexPath indexPathForColumn:column inSection:section];
                    }
                }
            }
        }
        
        if (yIndex == 0) {
            BOOL foundCell = NO;
            
            while (!foundCell) {
                for (NSMutableArray *columnToCheck in visibleCells) {
                    NSNull *cell = [columnToCheck objectAtIndex:0];
                    
                    if (cell != [NSNull null]) {
                        foundCell = YES;
                        break;
                    }
                }
                
                if (!foundCell) {
                    for (NSMutableArray *columnToCheck in visibleCells) {
                        [columnToCheck removeObjectAtIndex:0];
                    }
                    
                    NSInteger section = self._visibleRowIndexPath.section;
                    NSInteger row = self._visibleRowIndexPath.row + 1;
                    NSInteger totalInSection = [self _numberOfRowsInSection:section];
                    
                    if (row >= totalInSection+1) { // +1 for eventual footer
                        section++;
                        row = -1; // -1 for header
                    }
                    
                    self._visibleRowIndexPath = [MDIndexPath indexPathForColumn:row inSection:section];
                }
            }
        }
    }
}

- (void)_clearCell:(MDSpreadViewCell *)cell
{
    if (!cell) return;
//    [cell removeFromSuperview];
    cell.hidden = YES;
    [_dequeuedCells addObject:cell];
}

- (void)_clearCellsForColumnAtIndexPath:(MDIndexPath *)columnPath
{
    NSInteger xIndex = [self _relativeIndexOfColumnAtIndexPath:columnPath];
    
    if (xIndex < 0 || xIndex >= visibleCells.count) {
        return;
    }
    
    NSMutableArray *column = [visibleCells objectAtIndex:xIndex];
    
    for (MDSpreadViewCell *cell in column) {
        if ((NSNull *)cell != [NSNull null]) {
//            [cell removeFromSuperview];
            cell.hidden = YES;
            [_dequeuedCells addObject:cell];
        }
    }
    
    [column removeAllObjects];
    
    if (xIndex == visibleCells.count-1) {
        [visibleCells removeLastObject];
    } else if (xIndex == 0) {
        [visibleCells removeObjectAtIndex:0];
        
        NSInteger section = self._visibleColumnIndexPath.section;
        NSInteger column = self._visibleColumnIndexPath.column + 1;
        NSInteger totalInSection = [self _numberOfColumnsInSection:section];
        
        if (column >= totalInSection+1) { // +1 for eventual footer
            section++;
            column = -1; // -1 for header
        }
        
        self._visibleColumnIndexPath = [MDIndexPath indexPathForColumn:column inSection:section];
    }
}

- (void)_clearCellsForRowAtIndexPath:(MDIndexPath *)rowPath
{
    NSInteger yIndex = [self _relativeIndexOfRowAtIndexPath:rowPath];
    
    if (yIndex < 0 || visibleCells.count == 0) {
        return;
    }
    
    for (NSMutableArray *column in visibleCells) {
        if (yIndex >= column.count) {
            break;
        } else if (yIndex == column.count-1) {
            MDSpreadViewCell *cell = [column objectAtIndex:yIndex];
            
            if ((NSNull *)cell != [NSNull null]) {
//                [cell removeFromSuperview];
                cell.hidden = YES;
                [_dequeuedCells addObject:cell];
            }
            
            [column removeObjectAtIndex:yIndex];
        } else {
            MDSpreadViewCell *cell = [column objectAtIndex:yIndex];
            
            if ((NSNull *)cell != [NSNull null]) {
//                [cell removeFromSuperview];
                cell.hidden = YES;
                [_dequeuedCells addObject:cell];
            }
            
            [column replaceObjectAtIndex:yIndex withObject:[NSNull null]];
        }
    }
    
    if (yIndex == 0) {
        BOOL foundCell = NO;
        
        for (NSMutableArray *columnToCheck in visibleCells) {
            if (columnToCheck.count) {
                NSNull *cell = [columnToCheck objectAtIndex:0];
                
                if (cell != [NSNull null]) {
                    foundCell = YES;
                    break;
                }
            }
        }
        
        if (!foundCell) {
            for (NSMutableArray *columnToCheck in visibleCells) {
                if (columnToCheck.count)
                    [columnToCheck removeObjectAtIndex:0];
            }
            
            NSInteger section = self._visibleRowIndexPath.section;
            NSInteger row = self._visibleRowIndexPath.row + 1;
            NSInteger totalInSection = [self _numberOfRowsInSection:section];
            
            if (row >= totalInSection+1) { // +1 for eventual footer
                section++;
                row = -1; // -1 for header
            }
            
            self._visibleRowIndexPath = [MDIndexPath indexPathForRow:row inSection:section];
        }
    }
}

- (void)_clearCellForRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath
{
    MDSpreadViewCell *cell = [self _visibleCellForRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
    
//    [cell removeFromSuperview];
    cell.hidden = YES;
    [_dequeuedCells addObject:cell];
}

- (void)_clearAllCells
{
    for (NSMutableArray *array in visibleCells) {
        for (MDSpreadViewCell *cell in array) {
            if ((NSNull *)cell != [NSNull null]) {
//                [cell removeFromSuperview];
                cell.hidden = YES;
                [_dequeuedCells addObject:cell];
            }
        }
    }
}

#pragma mark - Fetchers

#pragma mark — Sizes
- (CGFloat)_widthForColumnHeaderInSection:(NSInteger)columnSection
{
    if (columnSection < 0 || columnSection >= [self _numberOfColumnSections]) return 0;
    
    if (implementsColumnHeaderWidth && [self.delegate respondsToSelector:@selector(spreadView:widthForColumnHeaderInSection:)]) {
        return [self.delegate spreadView:self widthForColumnHeaderInSection:columnSection];
    } else {
        implementsColumnHeaderWidth = NO;
    }
    
    return self.sectionColumnHeaderWidth;
}

- (CGFloat)_widthForColumnAtIndexPath:(MDIndexPath *)columnPath
{
    if (columnPath.column < 0) return [self _widthForColumnHeaderInSection:columnPath.section];
    else if (columnPath.column >= [self _numberOfColumnsInSection:columnPath.section]) return [self _widthForColumnFooterInSection:columnPath.section];
    
    if (implementsColumnWidth && [self.delegate respondsToSelector:@selector(spreadView:widthForColumnAtIndexPath:)]) {
        return [self.delegate spreadView:self widthForColumnAtIndexPath:columnPath];
    } else {
        implementsColumnWidth = NO;
    }
    
    return self.columnWidth;
}

- (CGFloat)_widthForColumnFooterInSection:(NSInteger)columnSection
{
    if (columnSection < 0 || columnSection >= [self _numberOfColumnSections]) return 0;
    
    return 0;
}

- (CGFloat)_heightForRowHeaderInSection:(NSInteger)rowSection
{
    if (rowSection < 0 || rowSection >= [self _numberOfRowSections]) return 0;
    
    if (implementsRowHeaderHeight && [self.delegate respondsToSelector:@selector(spreadView:heightForRowHeaderInSection:)]) {
        return [self.delegate spreadView:self heightForRowHeaderInSection:rowSection];
    } else {
        implementsRowHeaderHeight = NO;
    }
    
    return self.sectionRowHeaderHeight;
}

- (CGFloat)_heightForRowAtIndexPath:(MDIndexPath *)rowPath
{
    if (rowPath.row < 0) return [self _heightForRowHeaderInSection:rowPath.section];
    else if (rowPath.row >= [self _numberOfRowsInSection:rowPath.section]) return [self _heightForRowFooterInSection:rowPath.section];
    
    if (implementsRowHeight && [self.delegate respondsToSelector:@selector(spreadView:heightForRowAtIndexPath:)]) {
        return [self.delegate spreadView:self heightForRowAtIndexPath:rowPath];
    } else {
        implementsRowHeight = NO;
    }
    
    return self.rowHeight;
}

- (CGFloat)_heightForRowFooterInSection:(NSInteger)rowSection
{
    if (rowSection < 0 || rowSection >= [self _numberOfRowSections]) return 0;
    
    return 0;
}

#pragma mark — Counts
- (NSInteger)numberOfRowSections
{
    if (_rowSections) return [_rowSections count];
    else return [self _numberOfRowSections];
}

- (NSInteger)numberOfRowsInRowSection:(NSInteger)section
{
    if (_rowSections) return [[_rowSections objectAtIndex:section] numberOfCells];
    else return [self _numberOfRowsInSection:section];
}

- (NSInteger)numberOfColumnSections
{
    if (_columnSections) return [_columnSections count];
    else return [self _numberOfColumnSections];
}

- (NSInteger)numberOfColumnsInColumnSection:(NSInteger)section
{
    if (_columnSections) return [[_columnSections objectAtIndex:section] numberOfCells];
    else return [self _numberOfColumnsInSection:section];
}

- (NSInteger)_numberOfColumnsInSection:(NSInteger)section
{
    if (section < 0 || section >= [self _numberOfColumnSections]) return 0;
    
    NSInteger returnValue = 0;
    
    if ([_dataSource respondsToSelector:@selector(spreadView:numberOfColumnsInSection:)])
        returnValue = [_dataSource spreadView:self numberOfColumnsInSection:section];
    
    return returnValue;
}

- (NSInteger)_numberOfRowsInSection:(NSInteger)section
{
    if (section < 0 || section >= [self _numberOfRowSections]) return 0;
    
    NSInteger returnValue = 0;
    
    if ([_dataSource respondsToSelector:@selector(spreadView:numberOfRowsInSection:)])
        returnValue = [_dataSource spreadView:self numberOfRowsInSection:section];
    
    return returnValue;
}

- (NSInteger)_numberOfColumnSections
{
    NSInteger returnValue = 1;
    
    if ([_dataSource respondsToSelector:@selector(numberOfColumnSectionsInSpreadView:)])
        returnValue = [_dataSource numberOfColumnSectionsInSpreadView:self];
    
    return returnValue;
}

- (NSInteger)_numberOfRowSections
{
    NSInteger returnValue = 1;
    
    if ([_dataSource respondsToSelector:@selector(numberOfRowSectionsInSpreadView:)])
        returnValue = [_dataSource numberOfRowSectionsInSpreadView:self];
    
    return returnValue;
}

#pragma mark — Cells
- (void)_willDisplayCell:(MDSpreadViewCell *)cell forRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath
{
    if (rowPath.row <= 0 && columnPath.column <= 0) {
        if ([self.delegate respondsToSelector:@selector(spreadView:willDisplayCell:forHeaderInRowSection:forColumnSection:)])
            [self.delegate spreadView:self willDisplayCell:cell forHeaderInRowSection:rowPath.section forColumnSection:columnPath.section];
    } else if (rowPath.row <= 0) {
        if ([self.delegate respondsToSelector:@selector(spreadView:willDisplayCell:forHeaderInRowSection:forColumnAtIndexPath:)])
            [self.delegate spreadView:self willDisplayCell:cell forHeaderInRowSection:rowPath.section forColumnAtIndexPath:columnPath];
    } else if (columnPath.column <= 0) {
        if ([self.delegate respondsToSelector:@selector(spreadView:willDisplayCell:forHeaderInColumnSection:forRowAtIndexPath:)])
            [self.delegate spreadView:self willDisplayCell:cell forHeaderInColumnSection:columnPath.section forRowAtIndexPath:rowPath];
    } else {
        if ([self.delegate respondsToSelector:@selector(spreadView:willDisplayCell:forRowAtIndexPath:forColumnAtIndexPath:)])
            [self.delegate spreadView:self willDisplayCell:cell forRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
    }
}

- (MDSpreadViewCell *)_cellForHeaderInRowSection:(NSInteger)rowSection forColumnSection:(NSInteger)columnSection
{
    MDSpreadViewCell *returnValue = nil;
    
    if ([_dataSource respondsToSelector:@selector(spreadView:cellForHeaderInRowSection:forColumnSection:)])
        returnValue = [_dataSource spreadView:self cellForHeaderInRowSection:rowSection forColumnSection:columnSection];
    
    if (!returnValue) {
        static NSString *cellIdentifier = @"_kMDDefaultHeaderCornerCell";
        
        MDSpreadViewCell *cell = (MDSpreadViewCell *)[self dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil) {
            cell = [[[_defaultHeaderCornerCellClass alloc] initWithStyle:MDSpreadViewHeaderCellStyleCorner
                                                         reuseIdentifier:cellIdentifier] autorelease];
        }
        
        if ([_dataSource respondsToSelector:@selector(spreadView:titleForHeaderInRowSection:forColumnSection:)])
            cell.objectValue = [_dataSource spreadView:self titleForHeaderInRowSection:rowSection forColumnSection:columnSection];
        
        returnValue = cell;
    }
	
    returnValue.spreadView = self;
	returnValue._rowPath = [MDIndexPath indexPathForRow:-1 inSection:rowSection];
    returnValue._columnPath = [MDIndexPath indexPathForColumn:-1 inSection:columnSection];
//    [returnValue._tapGesture removeTarget:nil action:NULL];
//    [returnValue._tapGesture addTarget:self action:@selector(_selectCell:)];
    
    [returnValue setNeedsLayout];
    
    return returnValue;
}

- (MDSpreadViewCell *)_cellForHeaderInColumnSection:(NSInteger)section forRowAtIndexPath:(MDIndexPath *)rowPath
{
    MDSpreadViewCell *returnValue = nil;
    
    if ([_dataSource respondsToSelector:@selector(spreadView:cellForHeaderInColumnSection:forRowAtIndexPath:)])
        returnValue = [_dataSource spreadView:self cellForHeaderInColumnSection:section forRowAtIndexPath:rowPath];
    
    if (!returnValue) {
        static NSString *cellIdentifier = @"_kMDDefaultHeaderColumnCell";
        
        MDSpreadViewCell *cell = (MDSpreadViewCell *)[self dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil) {
            cell = [[[_defaultHeaderColumnCellClass alloc] initWithStyle:MDSpreadViewHeaderCellStyleColumn
                                                         reuseIdentifier:cellIdentifier] autorelease];
        }
        
        if ([_dataSource respondsToSelector:@selector(spreadView:titleForHeaderInColumnSection:forRowAtIndexPath:)])
            cell.objectValue = [_dataSource spreadView:self titleForHeaderInColumnSection:section forRowAtIndexPath:rowPath];
        
        returnValue = cell;
    }
	
    returnValue.spreadView = self;
	returnValue._rowPath = rowPath;
    returnValue._columnPath = [MDIndexPath indexPathForColumn:-1 inSection:section];
//    [returnValue._tapGesture removeTarget:nil action:NULL];
//    [returnValue._tapGesture addTarget:self action:@selector(_selectCell:)];
    
    [returnValue setNeedsLayout];
    
    return returnValue;
}

- (MDSpreadViewCell *)_cellForHeaderInRowSection:(NSInteger)section forColumnAtIndexPath:(MDIndexPath *)columnPath
{
    MDSpreadViewCell *returnValue = nil;
    
    if ([_dataSource respondsToSelector:@selector(spreadView:cellForHeaderInRowSection:forColumnAtIndexPath:)])
        returnValue = [_dataSource spreadView:self cellForHeaderInRowSection:section forColumnAtIndexPath:columnPath];
    
    if (!returnValue) {
        static NSString *cellIdentifier = @"_kMDDefaultHeaderRowCell";
        
        MDSpreadViewCell *cell = (MDSpreadViewCell *)[self dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil) {
            cell = [[[_defaultHeaderRowCellClass alloc] initWithStyle:MDSpreadViewHeaderCellStyleRow
                                                      reuseIdentifier:cellIdentifier] autorelease];
        }
        
        if ([_dataSource respondsToSelector:@selector(spreadView:titleForHeaderInRowSection:forColumnAtIndexPath:)])
            cell.objectValue = [_dataSource spreadView:self titleForHeaderInRowSection:section forColumnAtIndexPath:columnPath];
        
        returnValue = cell;
    }
	
    returnValue.spreadView = self;
	returnValue._rowPath = [MDIndexPath indexPathForRow:-1 inSection:section];
    returnValue._columnPath = columnPath;
//    [returnValue._tapGesture removeTarget:nil action:NULL];
//    [returnValue._tapGesture addTarget:self action:@selector(_selectCell:)];
    
    [returnValue setNeedsLayout];
    
    return returnValue;
}

- (MDSpreadViewCell *)_cellForRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath
{
    MDSpreadViewCell *returnValue = nil;
    
    if ([_dataSource respondsToSelector:@selector(spreadView:cellForRowAtIndexPath:forColumnAtIndexPath:)])
        returnValue = [_dataSource spreadView:self cellForRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
    
    if (!returnValue) {
        static NSString *cellIdentifier = @"_kMDDefaultCell";
        
        MDSpreadViewCell *cell = (MDSpreadViewCell *)[self dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil) {
            cell = [[[_defaultCellClass alloc] initWithStyle:MDSpreadViewCellStyleDefault
                                             reuseIdentifier:cellIdentifier] autorelease];
        }
        
        if ([_dataSource respondsToSelector:@selector(spreadView:objectValueForRowAtIndexPath:forColumnAtIndexPath:)])
            cell.objectValue = [_dataSource spreadView:self objectValueForRowAtIndexPath:rowPath forColumnAtIndexPath:columnPath];
        
        returnValue = cell;
    }
    
    returnValue.spreadView = self;
	returnValue._rowPath = rowPath;
    returnValue._columnPath = columnPath;
	
    [returnValue setNeedsLayout];
    
    return returnValue;
}

#pragma mark - Selection

- (BOOL)_touchesBeganInCell:(MDSpreadViewCell *)cell
{
    if (!allowsSelection) return NO;
    
    MDSpreadViewSelection *selection = [MDSpreadViewSelection selectionWithRow:cell._rowPath column:cell._columnPath mode:self.selectionMode];
    self._currentSelection = [self _willSelectCellForSelection:selection];
    
    if (self._currentSelection) {
        [self _addSelection:self._currentSelection];
        return YES;
    } else {
        return NO;
    }
}

- (void)_touchesEndedInCell:(MDSpreadViewCell *)cell
{
    [self _addSelection:[MDSpreadViewSelection selectionWithRow:self._currentSelection.rowPath
                                                         column:self._currentSelection.columnPath
                                                           mode:self._currentSelection.selectionMode]];
    [self _didSelectCellForRowAtIndexPath:self._currentSelection.rowPath forColumnIndex:self._currentSelection.columnPath];
    self._currentSelection = nil;
}

- (void)_touchesCancelledInCell:(MDSpreadViewCell *)cell
{
    [self _removeSelection:self._currentSelection];
    self._currentSelection = nil;
}

- (void)_addSelection:(MDSpreadViewSelection *)selection
{
    if (selection != _currentSelection) {
        NSUInteger index = [_selectedCells indexOfObject:selection];
        if (index != NSNotFound) {
            [_selectedCells replaceObjectAtIndex:index withObject:selection];
        } else {
            [_selectedCells addObject:selection];
        }
    }
    
    if (!allowsMultipleSelection) {
        NSMutableArray *bucket = [[NSMutableArray alloc] initWithCapacity:_selectedCells.count];
        
        for (MDSpreadViewSelection *oldSelection in _selectedCells) {
            if (oldSelection != selection) {
                [bucket addObject:oldSelection];
            }
        }
        
        for (MDSpreadViewSelection *oldSelection in bucket) {
            [self _removeSelection:oldSelection];
        }
        
        [bucket release];
    }
    
    
    NSArray *allSelections = [_selectedCells arrayByAddingObject:_currentSelection];
    NSMutableSet *allVisibleCells = [NSMutableSet setWithSet:[self _allVisibleCells]];
    [allVisibleCells addObjectsFromArray:_headerColumnCells];
    [allVisibleCells addObjectsFromArray:_headerRowCells];
    if (self._headerCornerCell) [allVisibleCells addObject:self._headerCornerCell];
    
    for (MDSpreadViewCell *cell in allVisibleCells) {
        cell.highlighted = NO;
        for (MDSpreadViewSelection *selection in allSelections) {
            if (selection.selectionMode == MDSpreadViewSelectionModeNone) continue;
            
            if ([cell._rowPath isEqualToIndexPath:selection.rowPath]) {
                if (selection.selectionMode == MDSpreadViewSelectionModeRow ||
                    selection.selectionMode == MDSpreadViewSelectionModeRowAndColumn) {
                    cell.highlighted = YES;
                }
            }
            
            if ([cell._columnPath isEqualToIndexPath:selection.columnPath]) {
                if (selection.selectionMode == MDSpreadViewSelectionModeColumn ||
                    selection.selectionMode == MDSpreadViewSelectionModeRowAndColumn) {
                    cell.highlighted = YES;
                }
                
                if ([cell._rowPath isEqualToIndexPath:selection.rowPath] && selection.selectionMode == MDSpreadViewSelectionModeCell) {
                    cell.highlighted = YES;
                }
            }
        }
    }
}

- (void)_removeSelection:(MDSpreadViewSection *)selection
{
    [_selectedCells removeObject:selection];
    
    NSMutableSet *allVisibleCells = [NSMutableSet setWithSet:[self _allVisibleCells]];
    [allVisibleCells addObjectsFromArray:_headerColumnCells];
    [allVisibleCells addObjectsFromArray:_headerRowCells];
    if (self._headerCornerCell) [allVisibleCells addObject:self._headerCornerCell];
    
    for (MDSpreadViewCell *cell in allVisibleCells) {
        cell.highlighted = NO;
        for (MDSpreadViewSelection *selection in _selectedCells) {
            if (selection.selectionMode == MDSpreadViewSelectionModeNone) continue;
            
            if ([cell._rowPath isEqualToIndexPath:selection.rowPath]) {
                if (selection.selectionMode == MDSpreadViewSelectionModeRow ||
                    selection.selectionMode == MDSpreadViewSelectionModeRowAndColumn) {
                    cell.highlighted = YES;
                }
            }
            
            if ([cell._columnPath isEqualToIndexPath:selection.columnPath]) {
                if (selection.selectionMode == MDSpreadViewSelectionModeColumn ||
                    selection.selectionMode == MDSpreadViewSelectionModeRowAndColumn) {
                    cell.highlighted = YES;
                }
                
                if ([cell._rowPath isEqualToIndexPath:selection.rowPath] && selection.selectionMode == MDSpreadViewSelectionModeCell) {
                    cell.highlighted = YES;
                }
            }
        }
    }
}

- (void)selectCellForRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath withSelectionMode:(MDSpreadViewSelectionMode)mode animated:(BOOL)animated scrollPosition:(MDSpreadViewScrollPosition)scrollPosition
{
    [self _addSelection:[MDSpreadViewSelection selectionWithRow:rowPath column:columnPath mode:mode]];
    
//    if (mode != MDSpreadViewScrollPositionNone) {
//        [self scrollToCell...];
//    }
}

- (void)deselectCellForRowAtIndexPath:(MDIndexPath *)rowPath forColumnAtIndexPath:(MDIndexPath *)columnPath animated:(BOOL)animated
{
    [self _removeSelection:[MDSpreadViewSelection selectionWithRow:rowPath column:columnPath mode:MDSpreadViewSelectionModeNone]];
}

- (MDSpreadViewSelection *)_willSelectCellForSelection:(MDSpreadViewSelection *)selection
{
    if ([self.delegate respondsToSelector:@selector(spreadView:willSelectCellForSelection:)])
        selection = [self.delegate spreadView:self willSelectCellForSelection:selection];
    
    return selection;
}

- (void)_didSelectCellForRowAtIndexPath:(MDIndexPath *)indexPath forColumnIndex:(MDIndexPath *)columnPath
{
	if ([self.delegate respondsToSelector:@selector(spreadView:didSelectCellForRowAtIndexPath:forColumnAtIndexPath:)])
		[self.delegate spreadView:self didSelectCellForRowAtIndexPath:indexPath forColumnAtIndexPath:columnPath];
}


@end
