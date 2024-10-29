@import UIKit;
#include <roothide.h>

// stores entries for icons, where key is the uniqueidentifier for the icon and entry is GriddyIconLocationPreferences
extern NSMutableDictionary *locationPrefs;
// save for portrait icon locations
extern NSDictionary *portraitSavedDict;
// save for landscape icon locations
extern NSDictionary *landscapeSavedDict;
// set of the icons that are being dragged, entries are instances of SBIcon *
extern NSMutableOrderedSet *draggedIcons;
// determines if you are currently in edit mode or not
extern BOOL isEditingLayout;
// used with dragging and touches
extern CGPoint touchPoint;
// variable used to store the new index you are dragging an icon to
extern long long proposedIndex;
// variable used to determine if the icon list needs to be sorted
extern BOOL shouldRedrawList;
// variable used to determine if the curretn drag will create a new icon or not(example: app library to home screen)
extern BOOL creatingNewIcon;
// orientation of the screen, 0 for portrait and 1 for landscape
extern int screenOrientation;
// determines if the icon we are dragging should have a higher priority than other icons on the home screen(usually yes)
extern BOOL shouldGivePriority;
// determines if we need to sort by priority before laying out icons
extern BOOL needsRefresh;
// decides whether to patch folder icons or not
extern BOOL shouldPatchFolderIcon;
// determines whether we already checked if folder icons should be patched, only check once per reboot
extern BOOL patchFoldersChecked;

typedef struct SBHIconGridSize {
    unsigned short columns;
    unsigned short rows;
} SBHIconGridSize;

typedef struct SBHIconGridSizeClassSizes {
    SBHIconGridSize small;
    SBHIconGridSize medium;
    SBHIconGridSize large;
    SBHIconGridSize newsLargeTall;
    SBHIconGridSize extraLarge;
} SBHIconGridSizeClassSizes;

typedef struct SBIconCoordinate {
    long long column;
    long long row;
} SBIconCoordinate;

typedef struct SBIconImageInfo {
    struct CGSize size;
    double scale;
    double continuousCornerRadius;
} SBIconImageInfo;

@interface SBIconListModel : NSObject
@property (nonatomic, copy) NSArray *icons; 
@property (assign, nonatomic) SBHIconGridSize gridSize;  
@property (assign, nonatomic) id parent; 
@property (nonatomic,readonly) SBHIconGridSizeClassSizes iconGridSizeClassSizes;  
@property (assign, nonatomic) BOOL griddyShouldPatch; 
@property (assign, nonatomic) BOOL griddyNeedsRefreshFolderImage;
- (struct SBHIconGridSize )gridSizeForGridSizeClass:(NSUInteger)arg0;
@end

@interface SBIcon : NSObject
@property (assign, nonatomic) NSUInteger gridSizeClass;  
@property (readonly, copy, nonatomic) NSString *uniqueIdentifier;
@end

@interface SBIconListGridCellInfo : NSObject
@property (assign, nonatomic) SBHIconGridSize gridSize;  

- (void)setIconIndex:(NSUInteger)arg1 forGridCellIndex:(NSUInteger)arg2;
- (void)setGridCellIndex:(NSUInteger)arg1 forIconIndex:(NSUInteger)arg2;
- (void)clearAllIconAndGridCellIndexes;
- (NSUInteger)iconIndexForGridCellIndex:(NSUInteger)arg1;
- (SBIconCoordinate)coordinateForGridCellIndex:(NSUInteger)arg1;
- (NSUInteger)gridCellIndexForCoordinate:(SBIconCoordinate)arg1;
@end

@interface SBFolderIconImageCache : NSObject
@end

@interface SBIconView : UIView
@property (nonatomic, retain) SBIcon *icon; 
@property (nonatomic, strong, readwrite) SBFolderIconImageCache *folderIconImageCache;
@end

@interface SBIconListView : UIView
@property (nonatomic,readonly) CGRect iconLayoutRect; 
@property (nonatomic,readonly) SBHIconGridSize gridSizeForCurrentOrientation; 
@property (copy, nonatomic) NSString *iconLocation;
@property (retain, nonatomic) SBIconListModel *model;
@property (nonatomic) NSInteger orientation;
@end

@interface _UIDropSessionImpl : NSObject
- (CGPoint)locationInView:(id)arg1;
@end

@interface SBFolder : NSObject
@property (nonatomic,readonly,strong) SBIconListModel *firstList;
@property (readonly, copy, nonatomic) NSArray *lists;
@end

@interface SBFolderIcon : SBIcon
@property (nonatomic,readonly,strong) SBFolder *folder;
@end

@interface SBIconImageView : UIView
@property (readonly, nonatomic) SBIcon *icon;
@property (nonatomic, readwrite) SBIconView *iconView;
@end

@interface SBFolderIconImageView : SBIconImageView
@end

@interface SBHFolderIconVisualConfiguration : NSObject
@property (nonatomic, readwrite) CGSize gridCellSize;
@property (nonatomic, readwrite) CGSize gridCellSpacing;
@end

@interface SBIconListGridLayout : NSObject 
@property (readonly, copy, nonatomic) SBHFolderIconVisualConfiguration *folderIconVisualConfiguration;
@property (readonly, nonatomic) SBIconImageInfo iconImageInfo;
@end

@interface SBIconGridImage : UIImage
@property (retain, nonatomic) NSObject *listLayout;
@property (readonly, nonatomic) NSUInteger numberOfColumns;
@property (readonly, nonatomic) NSUInteger numberOfRows;
@end

@interface _SBFolderPageElement : NSObject
@property (retain, nonatomic) SBIconGridImage *gridImage;
@property (nonatomic) NSUInteger pageIndex;
@property (weak, nonatomic) SBFolderIcon *folderIcon;
@end

@interface _SBIconGridWrapperView : UIImageView
@property (retain, nonatomic) _SBFolderPageElement *element;
@property (nonatomic, readwrite) SBFolderIconImageView *folderIconImageView;
@end

@interface SBPlaceholderIcon : SBIcon
@property (readonly, nonatomic) SBIcon *referencedIcon;
@end
