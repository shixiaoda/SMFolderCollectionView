//
//  SMFolderCollectionView.h
//  XDBookShelf
//
//  Created by 施孝达 on 16/4/5.
//  Copyright © 2016年 施孝达. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SMFolderCollectionViewDataSource.h"
#import "SMFolderCell.h"

#define WS(weakSelf)  __block __typeof(&*self)weakSelf = self;

typedef NS_ENUM(NSUInteger, SMFolderCollectionViewOperarion) {
    XWDragCellCollectionViewOperarionNone = 0,
    XWDragCellCollectionViewOperarionAdd,       //叠加
    XWDragCellCollectionViewOperarionExchange,  //交换
    XWDragCellCollectionViewOperarionRemove,    //移除
};

@interface SMFolderCollectionView : UICollectionView
@property (nonatomic, weak) id <SMFolderCollectionViewDataSource> xd_dataSource;
/**是否开启拖动到边缘滚动CollectionView的功能，默认NO*/
@property (nonatomic, assign) BOOL edgeScrollEable;
/**是否文件夹，默认NO*/
@property (nonatomic, assign) BOOL isFolder;
// 是否正在 移除文件夹
@property (nonatomic, assign) BOOL removeFromFoldering;

@property (nonatomic, weak) UIView* dragView;

@property (nonatomic, weak, readonly) UIView *tempMoveCell;

@property (nonatomic, assign, readonly) SMFolderCollectionViewOperarion dragOperarion;//操作类型
// Support for reordering
- (BOOL)xd_beginInteractiveMovementForItemAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(6_0); // returns NO if reordering was prevented from beginning - otherwise YES
- (void)xd_updateInteractiveMovementTargetPosition:(CGPoint)targetPosition NS_AVAILABLE_IOS(6_0);

- (void)xd_endInteractiveMovement NS_AVAILABLE_IOS(6_0);

- (void)xd_cancelInteractiveMovement NS_AVAILABLE_IOS(6_0);

- (BOOL)xd_continueInteractiveMovementForItemAtIndexPath:(NSIndexPath *)indexPath tempMoveCell:(UIView *)tempMoveCell;

- (BOOL)xd_continueInteractiveMovementForItemAtIndexPath:(NSIndexPath *)indexPath needRemoveItem:(NSIndexPath *)needRemoveItem tempMoveCell:(UIView *)tempMoveCell;
@end

