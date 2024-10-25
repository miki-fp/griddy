#import "Headers.h"
#import "Utils.h"
#import "GriddyIconLocationPreferences.h"

NSMutableDictionary<NSString *, GriddyIconLocationPreferences *> *locationPrefs;
NSDictionary<NSString *, NSNumber *> *portraitSavedDict;
NSDictionary<NSString *, NSNumber *> *landscapeSavedDict;
NSMutableOrderedSet<SBIcon *> *draggedIcons;
NSArray<NSString *> *patchLocations;
BOOL isEditingLayout = NO;
CGPoint touchPoint;
long long proposedIndex = -1;
BOOL shouldRedrawList = NO;
BOOL creatingNewIcon = NO;
int screenOrientation = -1;
BOOL shouldGivePriority = YES;
NSUserDefaults *userDefaults;
//three variables used to fix support for certain folder tweaks
CGRect gridWrapperSize;
BOOL shouldPatchFolderIcon = YES;
BOOL patchFoldersChecked = NO;
BOOL helloFolderEnable = NO;

%hook SBIconListModel
%property (assign, nonatomic) BOOL griddyShouldPatch; 

//SBIconListGridCellInfo is essentially the template for laying out icons
//it matches up icon indexes(indexes of icons in the model's icon array)
//with grid cell indexes(indexes on the grid, starting with 0 at the top left)
- (SBIconListGridCellInfo *)gridCellInfoForGridSize:(SBHIconGridSize)arg1 options:(NSUInteger)arg2 {
    SBIconListGridCellInfo *info = %orig;

    //we don't want to modify every SBIconListModel, because they are used for things like
    //the today view, library view, or even the edit screen for widget stacks
    if (self.griddyShouldPatch) {
        self.icons = patchGridCellInfoForIconList(self.icons, info, self);
    }
    return info;
}

//addIcon can run on respring, but also later on when dragging icons between pages
- (BOOL)addIcon:(SBIcon *)icon options:(NSUInteger)arg1  {
    if ([self.parent isKindOfClass:NSClassFromString(@"SBHLibraryCategoryFolder")] || self.gridSize.rows > 32767) return %orig;

    //if an entry doesnt exist for the icon we are adding, import from save or create a new one
    //note: screenOrientation will be 0 if portrait, 1 if landscape, or -1 on respring
    //-1 on respring is caused by the fact that by default, orientation is set to 0-unknown directly after a respring
    //later, it becomes 1,2,3, or 4, where 1,2 are portrait and 3,4 are landscape
    if (!locationPrefs[icon.uniqueIdentifier]) {
        creatingNewIcon = YES;
        if (screenOrientation == 0 && portraitSavedDict) {
            if (portraitSavedDict[icon.uniqueIdentifier]) {
                createNewLocationPrefs(self, icon, portraitSavedDict[icon.uniqueIdentifier].unsignedIntegerValue);
            } else {
                createNewLocationPrefs(self, icon, ([draggedIcons containsObject:icon]) ? proposedIndex : 0);
            }
        } else if(screenOrientation == 1 && landscapeSavedDict) {
            if (landscapeSavedDict[icon.uniqueIdentifier]) {
                createNewLocationPrefs(self, icon, landscapeSavedDict[icon.uniqueIdentifier].unsignedIntegerValue);
            } else {
                createNewLocationPrefs(self, icon, ([draggedIcons containsObject:icon]) ? proposedIndex : 0);
            }
        } else {
            createNewLocationPrefs(self, icon, ([draggedIcons containsObject:icon]) ? proposedIndex : 0);
        }
    }
    
    //adding a placeholder can occur when dragging between pages
    if ([icon isKindOfClass:%c(SBPlaceholderIcon)]) {
        [draggedIcons addObject:icon];
        locationPrefs[icon.uniqueIdentifier].index = proposedIndex;
    }
    return %orig;
}

//replaceIcon is called on a couple different occasions, most notably when picking an icon up
//in this case, the icon to pick up will be replaced with an isntance of SBPlaceholderIcon
//however, if a placeholder already exists, it will just add it to the dragged placeholder
- (id)replaceIcon:(SBIcon *)oldIcon withIcon:(SBIcon *)newIcon options:(NSUInteger)arg2 {
    if (!self.griddyShouldPatch) return %orig;


    if (locationPrefs[oldIcon.uniqueIdentifier]) {
        GriddyIconLocationPreferences *newPrefs;

        //create a new entry in case it doesnt exist yet
        if (!locationPrefs[newIcon.uniqueIdentifier]) {
            newPrefs = [[GriddyIconLocationPreferences alloc] init];
        } else {
            newPrefs = locationPrefs[newIcon.uniqueIdentifier];
        }

        //this will run when dragging an icon from the app library out onto the home screen
        //in this case, we want to create a new entry, otherwise, swap all the info over to the new "real" icon
        if ([oldIcon isKindOfClass:NSClassFromString(@"SBPlaceholderIcon")] && ((SBPlaceholderIcon *)oldIcon).referencedIcon.uniqueIdentifier != newIcon.uniqueIdentifier) {
            createNewLocationPrefs(self, newIcon, proposedIndex);
        } else {
            GriddyIconLocationPreferences *oldPrefs = locationPrefs[oldIcon.uniqueIdentifier];
            newPrefs.index = oldPrefs.index;
            newPrefs.ogIndex = oldPrefs.ogIndex;
            newPrefs.gridSize = oldPrefs.gridSize;
            locationPrefs[newIcon.uniqueIdentifier] = newPrefs;
            if (![oldIcon isKindOfClass:NSClassFromString(@"SBWidgetIcon")]) [locationPrefs removeObjectForKey:oldIcon.uniqueIdentifier];
        }

        //get rid of the entry for the old placeholder icon
        if ([oldIcon isKindOfClass:NSClassFromString(@"SBPlaceholderIcon")]) {
            creatingNewIcon = NO;

            [locationPrefs removeObjectForKey:oldIcon.uniqueIdentifier];

            if ([draggedIcons containsObject:oldIcon]) [draggedIcons removeObject:oldIcon];
            if ([draggedIcons count] == 0) shouldRedrawList = YES;
        }

        //replace the real icon with the placeholder at the same index
        if ([newIcon isKindOfClass:NSClassFromString(@"SBPlaceholderIcon")]) newPrefs.index = proposedIndex;
    }

    //if replacing a placeholder with a placeholder (adding a new icon to the placeholder), swap them out
    if ([newIcon isKindOfClass:NSClassFromString(@"SBPlaceholderIcon")]) {
        if ([oldIcon isKindOfClass:NSClassFromString(@"SBPlaceholderIcon")] && [draggedIcons containsObject:oldIcon]) {
            [draggedIcons removeObject:oldIcon];
            [locationPrefs removeObjectForKey:oldIcon.uniqueIdentifier];
        }

        [draggedIcons addObject:newIcon];
    }
    return %orig;
}

//removing entry when removing icon
- (void)removeIcon:(SBIcon *)icon options:(NSUInteger)arg1 {
    %orig;
    //this if statement filters out removing icons in, for example, today view alterign the home screen
    //this is because widgets on the today view are the same object as the same widget on the home screen
    if (!self.griddyShouldPatch) return;
    if (isEditingLayout) [locationPrefs removeObjectForKey:icon.uniqueIdentifier];
}

%end


%hook SBIconView

//this runs when you pick up your first icon
- (void)dragInteraction:(id)arg1 sessionWillBegin:(id)arg2 {
    if (!self.icon) return %orig;
    //clear out dragged icons
    GriddyIconLocationPreferences *prefs = locationPrefs[self.icon.uniqueIdentifier];
    [draggedIcons removeAllObjects];

    %orig;
    //setup proposedIndex and add to draggedIcons
    proposedIndex = prefs.index;
    prefs.ogIndex = proposedIndex;
    if (![self isKindOfClass:NSClassFromString(@"SBHLibraryCategoryPodIconView")]) [draggedIcons addObject:self.icon];
}

//this runs any time an icon preview is generated for dragging
//ie, this runs for the first, second, third... icon you pick up 
- (id)dragInteraction:(id)arg1 previewForLiftingItem:(id)arg2 session:(_UIDropSessionImpl *)dropSession  {
    if (!self.icon) return %orig;

    id ret = %orig;
    GriddyIconLocationPreferences *prefs = locationPrefs[self.icon.uniqueIdentifier];
    
    proposedIndex = prefs.index;
    prefs.ogIndex = proposedIndex;

    //we will always use the information from the first icon you pick up
    //this works because you can only pick up 1x1 icons in groups, and widgets can only be dragged 1 at a time
    if ([draggedIcons count] == 0) {
        //touch offset will be the location where you started grabbing the icon
        //it is the cgpoint in the SBIconView itself
        CGPoint touchOffset = [dropSession locationInView:self];

        //constrain touch offset, just in case
        if (touchOffset.x < 0) touchOffset.x = 0;
        if (touchOffset.y < 0) touchOffset.y = 0;
        if (touchOffset.x >= self.frame.size.width) touchOffset.x = self.frame.size.width-1;
        if (touchOffset.y >= self.frame.size.height) touchOffset.y = self.frame.size.height-1;
        
        //set index offset based on where in the icon you dragged
        unsigned short cols = (int)((touchOffset.x / self.frame.size.width) * prefs.gridSize.columns);
        unsigned short rows = (int)((touchOffset.y / self.frame.size.height) * prefs.gridSize.rows);
        [prefs setIndexOffsetColumns:cols rows:rows];

        //constrain indexOffset, just in case
        if (prefs.indexOffset.columns >= prefs.gridSize.columns) {[prefs setIndexOffsetColumns:0 rows:rows];}
        if (prefs.indexOffset.rows >= prefs.gridSize.rows) {[prefs setIndexOffsetColumns:cols rows:0];}
    }

    //add to dragged if not in the app library
    if (![self isKindOfClass:NSClassFromString(@"SBHLibraryCategoryPodIconView")]) {
        [draggedIcons insertObject:self.icon atIndex:0];
    }

    return ret;
}

//clean up dragged, just in case
- (void)dragInteraction:(id)arg1 session:(id)arg2 willEndWithOperation:(NSUInteger)arg3 {
    [draggedIcons removeAllObjects];
    proposedIndex = -1;
    return %orig;
}

%end


%hook SBIconController

//this will run anytime you pause your drag
- (BOOL)iconManager:(id)arg1 canAcceptDropInSession:(_UIDropSessionImpl *)dropSession inIconListView:(id)arg3 {
    SBIconListView *listView = arg3;
    //if we are dragging something, we want to deal with the logic for getting the grid cell index at that point
    if ([draggedIcons count] > 0) {
        //use the first object for data abput hat e are dragging
        GriddyIconLocationPreferences *draggedPrefs = locationPrefs[[draggedIcons firstObject].uniqueIdentifier];
        if (draggedPrefs == nil) {
            createNewLocationPrefs(listView.model, [draggedIcons firstObject], proposedIndex);
            draggedPrefs = locationPrefs[[draggedIcons firstObject].uniqueIdentifier];
        }

        //get the grid cell index for wherever we are touching
        touchPoint = [dropSession locationInView:listView];
        proposedIndex = calculateGridCellIndexForPoint(touchPoint, listView.iconLayoutRect, listView.gridSizeForCurrentOrientation, draggedPrefs.indexOffset, draggedPrefs.gridSize);
        
        //this will run only if we are out of bounds of the SBIconListView
        //in this case, we want to make sure the icon does not move anyhting else when we let go
        if (proposedIndex == -1) {
            shouldGivePriority = NO;
            proposedIndex = draggedPrefs.ogIndex;
        } else {
            shouldGivePriority = YES;
        }
        //set the proposed index for each icon we are dragging
        for(int i = 0; i < [draggedIcons count]; i++) {
            locationPrefs[draggedIcons[i].uniqueIdentifier].index = proposedIndex;
        }
    } else {
        //this runs for icons dragged from the app library
        //we cannot add app library icons to dragged because they are 
        //the same instance as the corresponding icon on the home screen
        //adding this to dragged would mess up the icon already on the home screen, so we do it in a roundabout way
        touchPoint = [dropSession locationInView:listView];

        SBHIconGridSize offset = (SBHIconGridSize){0, 0};
        SBHIconGridSize size = (SBHIconGridSize){1, 1};

        proposedIndex = calculateGridCellIndexForPoint(touchPoint, listView.iconLayoutRect, listView.gridSizeForCurrentOrientation, offset, size);
    }

    return %orig;
}

%end


%hook SBHIconManager

- (BOOL)isEditing {
    BOOL og = isEditingLayout;
    isEditingLayout = %orig;

    //if we are ending an edit, we want to save our layout
    if (og && !isEditingLayout) {
        NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] init];
        for (NSString *key in locationPrefs) {
            tempDict[key] = [NSNumber numberWithUnsignedLongLong:locationPrefs[key].index];
        }

        [userDefaults setObject:tempDict forKey:((screenOrientation == 0 ? @"GriddyPortraitSave" : @"GriddyLandscapeSave"))];
    }

    return isEditingLayout;
}

//this function is called when adding icons to a folder icon that exists on the homescreen
//note: this is only run when you let go over the folder preview, not if you actually open the folder up
- (void)addIcons:(NSArray <SBIcon *> *)arg1 intoFolderIcon:(SBFolderIcon *)folderIcon openFolderOnFinish:(BOOL)arg3 completion:(id)arg4 {
    
    SBFolder *folder = folderIcon.folder;
    SBIconListModel *model = folder.firstList;

    proposedIndex = 0;

    //find open spots for each icon
    for (int i = 0; i < [arg1 count]; i++) {
        SBIcon *icon = arg1[i];
        if ([draggedIcons containsObject:arg1[i]]) {
            NSUInteger idx = findFirstOpenIndexInListStartingAt(model.icons, model.gridSize, proposedIndex);
            GriddyIconLocationPreferences *prefs = locationPrefs[icon.uniqueIdentifier];
            prefs.index = idx;
            proposedIndex = idx + 1;
        } else {
            //if its not in dragged(app library drag) make a new entry
            if (!locationPrefs[icon.uniqueIdentifier]) {
                createNewLocationPrefs(model, icon, findFirstOpenIndexInListStartingAt(model.icons, model.gridSize, proposedIndex));
            }
        }
    }

    proposedIndex = -1;
    return %orig;
}

//this runs when creating a new folder
- (SBFolder *)createNewFolderFromRecipientIcon:(SBIcon *)recipientIcon grabbedIcon:(SBIcon *)grabbedIcon {
    GriddyIconLocationPreferences *prefs = locationPrefs[recipientIcon.uniqueIdentifier];
    
    if (prefs) prefs.index = 0;
    prefs = locationPrefs[grabbedIcon.uniqueIdentifier];
    if (prefs) prefs.index = 1;

    return %orig;
}

%end


%hook SBFolderIconImageView
//this patches the animation for opening and closing a folder(the zoom in and out)
- (CGRect)frameForMiniIconAtIndex:(NSUInteger)arg0  {
    if (helloFolderEnable) return %orig;

    SBFolder *folder = ((SBFolderIcon *)self.icon).folder;
    SBIconListModel *model = folder.firstList;

    if (!model.griddyShouldPatch) return %orig;
    if (!shouldPatchFolderIcon) return %orig;

    if ([model.icons count] > arg0) {
        SBIcon *icon = model.icons[arg0];
        GriddyIconLocationPreferences *prefs = locationPrefs[icon.uniqueIdentifier];
        return %orig(prefs.index);
    }

    return %orig;
}

%end

//_SBIconGridWrapperView is the image view for the mini icons on the folder icon
%hook _SBIconGridWrapperView

- (void)setImage:(UIImage *)image {
    if (!image) return %orig;
    
    //getting needed items
    _SBFolderPageElement *elem = self.element;
    SBIconGridImage *gridImageRef = (SBIconGridImage *)image;
    SBFolderIcon *folderIconRef = elem.folderIcon;

    if (elem == nil || gridImageRef == nil || folderIconRef == nil) return %orig;

    SBIconListModel *workingModel = folderIconRef.folder.lists[elem.pageIndex];

    if (!workingModel.griddyShouldPatch) return %orig;

    //checks for Primal Folders 2 settings, and decides based on this if it should patch the folder icon
    //allows for Primal folders behaviour or Griddy behaviour
    if (!patchFoldersChecked) {
        NSDictionary *primalFoldersDict = [NSDictionary dictionaryWithContentsOfFile:ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.ichitaso.primalfolder2.plist")];
        if (primalFoldersDict == nil) {
            shouldPatchFolderIcon = YES;
        } else {
            if ([primalFoldersDict[@"keepFolder"] boolValue]) {
               shouldPatchFolderIcon = YES;
            } else {
                shouldPatchFolderIcon = NO;
            }
        }
        if (![NSClassFromString(@"SBFloatyFolderScrollView") instancesRespondToSelector:@selector(foldrCloseFolder:)]) shouldPatchFolderIcon = YES;
        patchFoldersChecked = YES;
    }

    if (!shouldPatchFolderIcon) return %orig;

    //this solution is a bit scuffed, because the image has to be an instance of SBIconGridImage, 
    //which is very difficult to create. Thus, we instead will overwrite the existing image
    SBIconView *iconView = self.folderIconImageView.iconView;
    SBFolderIconImageCache *imageCache = iconView.folderIconImageCache;
    NSMapTable *miniGridImages = [imageCache valueForKey:@"_cachedMiniGridImages"];

    SBIconListGridLayout *miniIconLayout = (SBIconListGridLayout *)gridImageRef.listLayout;
    SBHFolderIconVisualConfiguration *miniIconConfiguration = miniIconLayout.folderIconVisualConfiguration;

    CGSize size = miniIconConfiguration.gridCellSize;
    CGSize spacing = miniIconConfiguration.gridCellSpacing;

    CGSize perIconSpace = CGSizeMake(size.width + spacing.width, size.height + spacing.height);
    CGSize newSize;

    //v1.0.3 changes this to base size off nuber of icons, not just a set value
    newSize = CGSizeMake((perIconSpace.width * (gridImageRef.numberOfRows-1)) + size.width, (perIconSpace.height *(gridImageRef.numberOfColumns-1)) + size.height);

    UIGraphicsBeginImageContextWithOptions(newSize, NO, gridImageRef.scale);

    if (UIGraphicsGetCurrentContext() == nil) return %orig;

    int wantFolderGriddy = 0;
    for(SBIcon *icon in workingModel.icons) {
        GriddyIconLocationPreferences *prefs = locationPrefs[icon.uniqueIdentifier];
        wantFolderGriddy += prefs.index;
    }
    if(wantFolderGriddy < 1) return %orig;

    //draw mini icons for the custom locations
    for(SBIcon *icon in workingModel.icons) {
        GriddyIconLocationPreferences *prefs = locationPrefs[icon.uniqueIdentifier];
        if (prefs == nil) continue;

        int row = prefs.index / gridImageRef.numberOfRows;
        int col = prefs.index % gridImageRef.numberOfColumns;

        UIImage *img = [miniGridImages objectForKey:icon];
        
        if (img == nil) img = [imageCache valueForKey:@"_genericMiniGridImage"];
        if (img == nil) continue;

        [img drawInRect:CGRectMake(col * perIconSpace.width, row * perIconSpace.height, size.width, size.height)];
    }

    UIImage *newImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //overwrite the old image by running an init
    //this is very scuffed, but it seems to work, and we manage get around making an new instance of SBIconGridImage
    //update as of v1.0.3: this seems to work only most of the time
    //occasionally, it will mess up and cause a crash intp safe mode
    //I am not sure why this is, and thus have not implemented a fix, but instead took this approach of 
    //retrying a couple times in an attempt to minimize crashes while still preserving functionality
    if (newImg != nil) {
        for (int i = 0; i < 10; i++) {
            BOOL success = YES;
            @try {
                gridImageRef = [gridImageRef initWithCGImage:newImg.CGImage scale:gridImageRef.scale orientation:UIImageOrientationUp];
            }
            @catch (NSException * e) {
                NSLog(@"Griddy exception with creating folder icon: %@", e);
                success = NO;
            }
            if (success) break;
        }
        elem.gridImage = gridImageRef;
        //some folder tweaks change the size of the _SBGridWrapperView and make them very tiny, 
        //here we are simply generating the correct size and will set it in layoutSubviews
        float neededWidth = (miniIconLayout.iconImageInfo).size.width * 0.75;
        float neededHeight = (miniIconLayout.iconImageInfo).size.height * 0.75;
        gridWrapperSize = CGRectMake( (0.166666 * neededWidth), (0.166666 * neededHeight), neededWidth, neededHeight);
    }

    
    return %orig(gridImageRef);
}

- (void)layoutSubviews {
    %orig;
    //this if statement is a bit sketchy, and I will try to clean it up in a future version
    if (![self.folderIconImageView isKindOfClass:NSClassFromString(@"SBHLibraryAdditionalItemsIndicatorIconImageView")] && gridWrapperSize.size.width != 0 && shouldPatchFolderIcon) self.frame = gridWrapperSize;
}


%end

%hook SBIconListView
- (void)layoutIconsIfNeeded {

    //determine if the model should be patched or not
    if ([patchLocations containsObject:self.iconLocation])
        self.model.griddyShouldPatch = YES;
    else
        self.model.griddyShouldPatch = NO;

    //we will only use the dock for deciding rotation
    //SBIconLocationFloatingDockSuggestions is for floating dock
    if (!([self.iconLocation isEqualToString:@"SBIconLocationDock"] || [self.iconLocation isEqualToString:@"SBIconLocationFloatingDockSuggestions"])) {
        return %orig;
    }

    //load corresponding saved state
    if ((self.orientation == 1 || self.orientation == 2) && screenOrientation != 0) {

        screenOrientation = 0;
        portraitSavedDict = [userDefaults dictionaryForKey:@"GriddyPortraitSave"];

        if (portraitSavedDict){
            for (NSString *key in locationPrefs) {
                ((GriddyIconLocationPreferences *)locationPrefs[key]).index = (portraitSavedDict[key] == nil) ? 999 : ((NSNumber *)portraitSavedDict[key]).unsignedIntegerValue;
            }
        }
    } else if ((self.orientation == 3 || self.orientation == 4) && screenOrientation != 1) {

        screenOrientation = 1;
        landscapeSavedDict = [userDefaults dictionaryForKey:@"GriddyLandscapeSave"];

        if (landscapeSavedDict) {
            for (NSString *key in locationPrefs) {
                ((GriddyIconLocationPreferences *)locationPrefs[key]).index = (landscapeSavedDict[key] == nil) ? 999 : ((NSNumber *)landscapeSavedDict[key]).unsignedIntegerValue;
            }
        }
    }

    return %orig;
}
%end

//setup variables and load saves
%ctor {
    locationPrefs = [[NSMutableDictionary alloc] init]; 
    draggedIcons = [[NSMutableOrderedSet alloc] init];  
    userDefaults = [NSUserDefaults standardUserDefaults]; 
    portraitSavedDict = [userDefaults dictionaryForKey:@"GriddyPortraitSave"];
    landscapeSavedDict = [userDefaults dictionaryForKey:@"GriddyLandscapeSave"];
    NSString *temp[] = {@"SBIconLocationRoot", @"SBIconLocationDock", @"SBIconLocationFolder", @"SBIconLocationRootWithWidgets", @"SBIconLocationFloatingDockSuggestions"};
    patchLocations = [NSArray arrayWithObjects:temp count:5];

    NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:ROOT_PATH_NS(@"/var/mobile/Library/Preferences/cn.zqbb.0rzFolder.plist")];
    if (plistDict){
        helloFolderEnable = (plistDict[@"wantsEnable"] == nil || [plistDict[@"wantsEnable"] boolValue] == YES) ? YES : NO;
    }
}
