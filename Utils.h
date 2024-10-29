#import "Headers.h"
#import "GriddyIconLocationPreferences.h"

/**
 * Finds the first open grid index in the provided list starting from the given start index.
 *
 * @param list NSArray containing SBIcon objects.
 * @param gridSize SBHIconGridSize representing the grid dimensions (columns, rows).
 * @param start The starting index to search for an open space in the grid.
 * @return The first open grid index in the grid starting from the provided start index.
 */
NSUInteger findFirstOpenIndexInListStartingAt(NSArray *list, SBHIconGridSize gridSize, int start);

/**
 * Checks if a given index is valid for placing an icon of a specified size.
 *
 * @param info SBIconListGridCellInfo object containing information about the icon grid.
 * @param writeSize SBHIconGridSize representing the size of the icon being placed.
 * @param writeIndex The index to check if valid for placing the icon.
 * @return YES if the index is valid, NO otherwise.
 */
BOOL checkValidIndexForIconSize(SBIconListGridCellInfo *info, SBHIconGridSize writeSize, long long writeIndex);

/**
 * Creates a new set of location preferences for an icon and associates it with the provided index.
 *
 * @param model SBIconListModel object representing the icon list model icon will be placed in.
 * @param icon SBIcon object representing the icon for which to create preferences.
 * @param idx The index where the icon should be placed in the grid.
 */
void createNewLocationPrefs(SBIconListModel *model, SBIcon *icon, long long idx);

/**
 * Reorders the icon list based on a custom index stored in location preferences, as well as assigning priority levels.
 *
 * @param iconList NSArray of SBIcon objects to be reordered.
 * @param size The total size of the grid where icons are displayed.
 * @return A new NSArray with the icons reordered based on their custom indices.
 */
NSArray *reorderIconListBasedOnCustomIndex(NSArray *iconList, int size);

/**
 * Patches the grid cell information for the icon list, ensuring icons are placed according to custom preferences.
 *
 * @param staticIconList NSArray of SBIcon objects representing the original list.
 * @param info SBIconListGridCellInfo object that contains information about the grid.
 * @param model SBIconListModel object representing the icon list model.
 * @return NSArray containing all the SBIcon objects associated with the model.
 */
NSArray *patchGridCellInfoForIconList(NSArray *staticIconList, SBIconListGridCellInfo *info, SBIconListModel *model);

/**
 * Calculates the grid cell index for a point within a working size.
 *
 * @param point CGPoint representing the point in the grid.
 * @param workingSize CGRect representing the size of the working area.
 * @param workingGridSize SBHIconGridSize representing the grid dimensions.
 * @param indexOffset SBHIconGridSize representing the offset to apply to the calculated index.
 * @param iconSize SBHIconGridSize representing the size of the icon being placed.
 * @return The calculated grid cell index for the point, or a fallback index if invalid.
 */
long long calculateGridCellIndexForPoint(CGPoint point, CGRect workingSize, SBHIconGridSize workingGridSize, SBHIconGridSize indexOffset, SBHIconGridSize iconSize);

/**
 * Tests different tweaks thay may or may not be installed to see if Griddy should patch folder previews
 */
BOOL determineFolderPatching();

/**
 * Transfer Griddy portrait and landscape saves to new location
 */
void transferGriddySave();

/**
 * Generate new image for a given folder model
 * 
 * @param model SBIconListModel for the folder we want to create an icon for
 * @param gridImageRef SBIconGridImage instance of the original folder icon image
 * @param imageCache SBFolderIconImageCache of all icon images
 * @param miniIconLayout SBIconListGridLayout describing the layout fo mini icons
 */
SBIconGridImage *generateNewFolderImageForModel(SBIconListModel *model, SBIconGridImage *gridImageRef, SBFolderIconImageCache *imageCache, SBIconListGridLayout *miniIconLayout);
