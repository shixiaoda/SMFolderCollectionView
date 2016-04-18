//
//  SMFolderCollectionView.m
//  XDBookShelf
//
//  Created by 施孝达 on 16/4/5.
//  Copyright © 2016年 施孝达. All rights reserved.
//

#import "SMFolderCollectionView.h"
#import <objc/runtime.h>

typedef NS_ENUM(NSUInteger, SMFolderCollectionViewScrollDirection) {
    XWDragCellCollectionViewScrollDirectionNone = 0,
    XWDragCellCollectionViewScrollDirectionLeft,
    XWDragCellCollectionViewScrollDirectionRight,
    XWDragCellCollectionViewScrollDirectionUp,
    XWDragCellCollectionViewScrollDirectionDown
};


@interface SMFolderCollectionView ()
@property (nonatomic, strong) NSIndexPath *originalIndexPath;//起始Cell
@property (nonatomic, strong) NSIndexPath *moveIndexPath;    //目标Cell
@property (nonatomic, weak) UIView *tempMoveCell;
@property (nonatomic, assign) SMFolderCollectionViewOperarion dragOperarion;//操作类型
@property (nonatomic, assign) BOOL isSelectFolderCell;      //选中的是否是文件夹Cell

@property (nonatomic, strong) NSTimer *moveCellTimer;

@property (nonatomic, strong) CADisplayLink *edgeTimer;
@property (nonatomic, assign) SMFolderCollectionViewScrollDirection scrollDirection;
@end

@implementation SMFolderCollectionView

- (BOOL)checkCanMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.xd_dataSource respondsToSelector:@selector(xd_collectionView:canMoveItemAtIndexPath:)])
    {
        if (![self.xd_dataSource performSelector:@selector(xd_collectionView:canMoveItemAtIndexPath:) withObject:self withObject:indexPath])
        {
            return NO;
        }
        else
        {
            return YES;
        }
    }
    return NO;
}

- (BOOL)xd_continueInteractiveMovementForItemAtIndexPath:(NSIndexPath *)indexPath tempMoveCell:(UIView *)tempMoveCell
{
    return [self xd_continueInteractiveMovementForItemAtIndexPath:indexPath needRemoveItem:nil tempMoveCell:tempMoveCell];
}

- (BOOL)xd_continueInteractiveMovementForItemAtIndexPath:(NSIndexPath *)indexPath needRemoveItem:(NSIndexPath *)needRemoveItem tempMoveCell:(UIView *)tempMoveCell
{
    if (![self checkCanMoveItemAtIndexPath:indexPath])
    {
        return NO;
    }
    NSLog(@"手势 continue %d 第%d个 需要移除%d",self.isFolder,[indexPath item],[needRemoveItem item]);
    NSAssert(indexPath != nil, @"continue indexPath不能为空");
    
    UICollectionViewCell *cell = nil;
    
    if (needRemoveItem)
    {
        [self performBatchUpdates:^{
            [self deleteItemsAtIndexPaths:@[needRemoveItem]];
            [self insertItemsAtIndexPaths:@[indexPath]];
        } completion:^(BOOL finished) {
            
        }];
    }
    else
    {
        [self insertItemsAtIndexPaths:@[indexPath]];
    }
    
    cell = [self cellForItemAtIndexPath:indexPath];
    self.originalIndexPath = [self indexPathForCell:cell];
    if (cell)
    {
        cell.hidden = YES;
        self.tempMoveCell = tempMoveCell;
//        self.tempMoveCell.frame = CGRectMake(tempMoveCell.frame.origin.x, tempMoveCell.frame.origin.y, cell.frame.size.width, cell.frame.size.height);
        
        //开启边缘滚动定时器
        [self xd_setEdgeTimer];
        
        return YES;
    }
    return NO;
}

- (BOOL)xd_beginInteractiveMovementForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (![self checkCanMoveItemAtIndexPath:indexPath])
    {
        return NO;
    }
    
    if (indexPath == nil)
    {
        return NO;
    }
    NSLog(@"手势 begin %d %d",self.isFolder,[indexPath item]);
    
    UICollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath];
    
    if ([cell isKindOfClass:[SMFolderCell class]])
    {
        self.isSelectFolderCell = YES;
    }
    else
    {
        self.isSelectFolderCell = NO;
    }
    
    self.originalIndexPath = indexPath;
    if (cell)
    {
        UIView *tempMoveCell =  [cell snapshotViewAfterScreenUpdates:NO];
        tempMoveCell.tag = 88;
        cell.hidden = YES;
        self.tempMoveCell = tempMoveCell;
        
        if (self.isFolder)
        {
            [self.dragView addSubview:self.tempMoveCell];
            self.tempMoveCell.frame = [self convertRect:cell.frame toView:self.dragView];
        }
        else
        {
            [self addSubview:self.tempMoveCell];
            self.tempMoveCell.frame = cell.frame;
        }
        
        //开启边缘滚动定时器
        [self xd_setEdgeTimer];
        
        return YES;
    }
    return NO;
}

- (void)xd_updateInteractiveMovementTargetPosition:(CGPoint)targetPosition
{
    if (self.isFolder)
    {
        self.tempMoveCell.center = [self convertPoint:targetPosition toView:self.dragView];
    }
    else
    {
        self.tempMoveCell.center = targetPosition;
    }
    //开启坐标检测定时器
    [self xd_setMoveCellTimer];
}

- (void)xd_endInteractiveMovement
{
    NSLog(@"xd_endInteractiveMovement %d opera = %d self.originalIndexPath = %d isRemoving %d",self.isFolder,self.dragOperarion,[self.originalIndexPath item],self.removeFromFoldering);
    UICollectionViewCell *cell = [self cellForItemAtIndexPath:self.originalIndexPath];
    if (!self.isFolder)
    {
        self.userInteractionEnabled = NO;
    }
    
    [self xd_stopEdgeTimer];
    [self xd_stopMoveCellTimer];
    
    [UIView animateWithDuration:0.25 animations:^{
        if (self.dragOperarion == XWDragCellCollectionViewOperarionAdd)
        {
            UICollectionViewCell *moveCell = [self cellForItemAtIndexPath:self.moveIndexPath];
            CGRect frame = CGRectMake(moveCell.frame.origin.x, moveCell.frame.origin.y, 45, 45);
            if (self.removeFromFoldering)
            {
                frame = [self convertRect:frame toView:self.dragView];
            }
            self.tempMoveCell.frame = frame;
            if ([moveCell isKindOfClass:[SMBookCell class]])
            {
                moveCell.frame = CGRectMake(moveCell.frame.origin.x + moveCell.frame.size.width - 45, moveCell.frame.origin.y, 45, 45);
            }
            else
            {
                self.tempMoveCell.alpha = 0.5;
            }
            
            if (![self.moveIndexPath isEqual:self.originalIndexPath])
            {
                if (self.xd_dataSource && [self.xd_dataSource respondsToSelector:@selector(xd_collectionView:addItemAtIndexPath:toIndexPath:)])
                {
                    [self.xd_dataSource xd_collectionView:self addItemAtIndexPath:self.originalIndexPath toIndexPath:self.moveIndexPath];
                }
            }
        }
        else if (self.dragOperarion == XWDragCellCollectionViewOperarionRemove)
        {
//            NSLog(@"xd_endInteractiveMovement OperarionRemove");
        }
        else
        {
            if (self.isFolder || self.removeFromFoldering)
            {
                CGPoint center = [self convertPoint:cell.center toView:self.dragView];
//                NSLog(@"end center %f %f %d",center.x,center.y,self.isFolder);
                self.tempMoveCell.center = center;
            }
            else
            {
                self.tempMoveCell.center = cell.center;
            }
        }
    } completion:^(BOOL finished) {
        if (self.dragOperarion == XWDragCellCollectionViewOperarionAdd)
        {
            NSLog(@"叠加 结束 %d",self.isFolder);
            [self.tempMoveCell removeFromSuperview];
            self.tempMoveCell = nil;
            if (self.xd_dataSource && [self.xd_dataSource respondsToSelector:@selector(xd_collectionView:removeItemAtIndexPath:toIndexPath:)])
            {
                [self.xd_dataSource xd_collectionView:self removeItemAtIndexPath:self.originalIndexPath toIndexPath:self.moveIndexPath];
            }

        }
        else if (self.dragOperarion == XWDragCellCollectionViewOperarionRemove)
        {
            NSLog(@"移除 结束 %d",self.isFolder);
        }
        else if (self.dragOperarion == XWDragCellCollectionViewOperarionExchange)
        {
            NSLog(@"交换 结束 %d",self.isFolder);
            [self.tempMoveCell removeFromSuperview];
            self.tempMoveCell = nil;
            NSLog(@"cell %@ ",cell);
//            cell.hidden = NO;
            UICollectionViewCell *cell2 = [self cellForItemAtIndexPath:self.originalIndexPath];
            cell2.hidden = NO;
            NSLog(@"cell2 %@ ",cell2);
//            [self reloadItemsAtIndexPaths:@[self.originalIndexPath]];
        }
        else
        {
            NSLog(@"其他操作 结束 %d",self.isFolder);
            [self.tempMoveCell removeFromSuperview];
            self.tempMoveCell = nil;
            cell.hidden = NO;
        }
        
        if (!self.isFolder)
        {
            self.userInteractionEnabled = YES;
        }
        self.dragOperarion = XWDragCellCollectionViewOperarionNone;
    }];
    
    self.removeFromFoldering = NO;
    self.isSelectFolderCell = NO;
}

- (void)xd_cancelInteractiveMovement
{
    NSLog(@"xd_cancelInteractiveMovement");
    UICollectionViewCell *cell = [self cellForItemAtIndexPath:self.originalIndexPath];
    self.userInteractionEnabled = NO;
    
    [self xd_stopEdgeTimer];
    [self xd_stopMoveCellTimer];
    
    [UIView animateWithDuration:0.25 animations:^{
        if (self.isFolder)
        {
            self.tempMoveCell.center = [self convertPoint:cell.center toView:self.dragView];
        }
        else
        {
            self.tempMoveCell.center = cell.center;
        }

    } completion:^(BOOL finished) {
        
        [self.tempMoveCell removeFromSuperview];
        self.tempMoveCell = nil;
        cell.hidden = NO;
        self.userInteractionEnabled = YES;
        
        
        self.dragOperarion = XWDragCellCollectionViewOperarionNone;
    }];
    
    self.isSelectFolderCell = NO;
}

#pragma mark - moveCellTimer methods

- (void)xd_setMoveCellTimer
{
    if (!self.moveCellTimer && self.tempMoveCell)
    {
        self.moveCellTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(xd_moveCell) userInfo:nil repeats:YES];
    }
}

- (void)xd_stopMoveCellTimer
{
    if (self.moveCellTimer)
    {
        [self.moveCellTimer invalidate];
        self.moveCellTimer = nil;
    }
}

- (void)xd_moveCell
{
    NSLog(@"xd_moveCell");
    self.dragOperarion = XWDragCellCollectionViewOperarionNone;
    
    //计算是否超出 collectionView 边界
    CGPoint tempCellCent = self.tempMoveCell.center;
    CGRect frame = self.frame;
    
    if (self.isFolder || self.removeFromFoldering)
    {
        tempCellCent = [self.dragView convertPoint:tempCellCent toView:self];
        frame = [self.dragView convertRect:frame toView:self];
    }
    
    if (!CGRectContainsPoint(frame, tempCellCent) && self.isFolder)
    {
        self.dragOperarion = XWDragCellCollectionViewOperarionRemove;
        
        NSLog(@"命中 移除 第%d个 ",[self.originalIndexPath item]);
        
        if (self.xd_dataSource && [self.xd_dataSource respondsToSelector:@selector(xd_collectionView:removeFromFolderAtIndexPath:)])
        {
            [self.xd_dataSource xd_collectionView:self removeFromFolderAtIndexPath:self.originalIndexPath];
        }
        
        [self xd_stopMoveCellTimer];
        [self xd_stopEdgeTimer];
        
        return;
    }

//    NSLog(@"开始遍历 self.originalIndexPath ＝ %d",[self.originalIndexPath item]);
    for (UICollectionViewCell *cell in [self visibleCells])
    {
        NSIndexPath *indexPath = [self indexPathForCell:cell];
        if (indexPath == self.originalIndexPath || [indexPath section] != [self.originalIndexPath section] || cell.hidden == YES)
        {
            continue;
        }
        //计算中心距
        CGFloat spacingX = fabs(tempCellCent.x - cell.center.x);
        CGFloat spacingY = fabs(tempCellCent.y - cell.center.y);
        
//        NSLog(@"spacingX =%f",spacingX);
//        NSLog(@"spacingY =%f",spacingY);
        if (spacingX <= self.tempMoveCell.bounds.size.width / 8.0f * 3 &&
             spacingY <= self.tempMoveCell.bounds.size.height / 8.0f * 3 && !self.isFolder && !self.isSelectFolderCell)
        {
            NSLog(@"命中 叠加 tag %d",cell.tag);
            self.dragOperarion = XWDragCellCollectionViewOperarionAdd;
            
            [UIView animateWithDuration:0.25 animations:^{
                self.tempMoveCell.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.8, 0.8);
            } completion:^(BOOL finished) {
                
            }];
            self.moveIndexPath = [self indexPathForCell:cell];
            break;
        }
        else if ((spacingX <= self.tempMoveCell.bounds.size.width / 2.0f &&
                 spacingY <= self.tempMoveCell.bounds.size.height / 2.0f &&
                  !self.isFolder) ||
                 (spacingX <= self.tempMoveCell.bounds.size.width / 2.0f &&
                  spacingY <= self.tempMoveCell.bounds.size.height / 2.0f &&
                  self.isFolder))
        {
            NSLog(@"命中 交换 self.isFolder = %d self.isSelectFolderCell = %d",self.isFolder,self.isSelectFolderCell);
            self.dragOperarion = XWDragCellCollectionViewOperarionExchange;
            
            [UIView animateWithDuration:0.25 animations:^{
                self.tempMoveCell.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.0, 1.0);
            } completion:^(BOOL finished) {
                
            }];
            
            self.moveIndexPath = [self indexPathForCell:cell];
            
            if (![self.moveIndexPath isEqual:self.originalIndexPath])
            {
                if (self.xd_dataSource && [self.xd_dataSource respondsToSelector:@selector(xd_collectionView:moveItemAtIndexPath:toIndexPath:)])
                {
                    NSIndexPath *originalIndexPath = self.originalIndexPath;
                    [self performBatchUpdates:^{
                        [self moveItemAtIndexPath:self.originalIndexPath toIndexPath:self.moveIndexPath];
                    } completion:^(BOOL finished) {
                        if (self.xd_dataSource && [self.xd_dataSource respondsToSelector:@selector(xd_collectionView:moveItemAtIndexPath:toIndexPath:)])
                        {
                            [self.xd_dataSource xd_collectionView:self moveItemAtIndexPath:originalIndexPath toIndexPath:self.moveIndexPath];
                        }

                    }];
                }
                //设置移动后的起始indexPath
                self.originalIndexPath = self.moveIndexPath;
            }
            break;
        }
    }
    
    if (self.dragOperarion != XWDragCellCollectionViewOperarionAdd)
    {
        [UIView animateWithDuration:0.25 animations:^{
            self.tempMoveCell.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.0, 1.0);
        } completion:^(BOOL finished) {
            
        }];
    }

}


#pragma mark - edgeTimer methods

- (void)xd_setEdgeTimer
{
    if (!self.edgeTimer && self.edgeScrollEable) {
        self.edgeTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(xd_edgeScroll)];
        [self.edgeTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)xd_stopEdgeTimer
{
    if (self.edgeTimer) {
        [self.edgeTimer invalidate];
        self.edgeTimer = nil;
    }
}

- (void)xd_setScrollDirection
{
    CGPoint tempCellCent = self.tempMoveCell.center;
    if (self.isFolder || self.removeFromFoldering)
    {
        tempCellCent = [self.dragView convertPoint:tempCellCent toView:self];
    }
    
    self.scrollDirection = XWDragCellCollectionViewScrollDirectionNone;
    
    if (self.bounds.size.height + self.contentOffset.y - tempCellCent.y < self.tempMoveCell.bounds.size.height / 2 && self.bounds.size.height + self.contentOffset.y < self.contentSize.height) {
        self.scrollDirection = XWDragCellCollectionViewScrollDirectionDown;
    }
    if (tempCellCent.y - self.contentOffset.y < self.tempMoveCell.bounds.size.height / 2 && self.contentOffset.y > 0) {
        self.scrollDirection = XWDragCellCollectionViewScrollDirectionUp;
    }
    if (self.bounds.size.width + self.contentOffset.x - tempCellCent.x < self.tempMoveCell.bounds.size.width / 2 && self.bounds.size.width + self.contentOffset.x < self.contentSize.width) {
        self.scrollDirection = XWDragCellCollectionViewScrollDirectionRight;
    }
    if (tempCellCent.x - self.contentOffset.x < self.tempMoveCell.bounds.size.width / 2 && self.contentOffset.x > 0) {
        self.scrollDirection = XWDragCellCollectionViewScrollDirectionLeft;
    }
}

- (void)xd_edgeScroll
{
    [self xd_setScrollDirection];
//    NSLog(@"xd_edgeScroll %d",self.scrollDirection);
    CGPoint tempCellCent = self.tempMoveCell.center;
    if (self.isFolder || self.removeFromFoldering)
    {
        tempCellCent = [self.dragView convertPoint:tempCellCent toView:self];
    }
    
    switch (self.scrollDirection) {
        case XWDragCellCollectionViewScrollDirectionLeft:{
            //这里的动画必须设为NO
            [self setContentOffset:CGPointMake(self.contentOffset.x - 4, self.contentOffset.y) animated:NO];
            if (!self.isFolder)
            {
                self.tempMoveCell.center = CGPointMake(self.tempMoveCell.center.x - 4, self.tempMoveCell.center.y);
            }
        }
            break;
        case XWDragCellCollectionViewScrollDirectionRight:{
            [self setContentOffset:CGPointMake(self.contentOffset.x + 4, self.contentOffset.y) animated:NO];
            if (!self.isFolder)
            {
                self.tempMoveCell.center = CGPointMake(self.tempMoveCell.center.x + 4, self.tempMoveCell.center.y);
            }
        }
            break;
        case XWDragCellCollectionViewScrollDirectionUp:{
            [self setContentOffset:CGPointMake(self.contentOffset.x, self.contentOffset.y - 4) animated:NO];
            if (!self.isFolder)
            {
                self.tempMoveCell.center = CGPointMake(self.tempMoveCell.center.x, self.tempMoveCell.center.y - 4);
            }
        }
            break;
        case XWDragCellCollectionViewScrollDirectionDown:{
            [self setContentOffset:CGPointMake(self.contentOffset.x, self.contentOffset.y + 4) animated:NO];
            if (!self.isFolder)
            {
                self.tempMoveCell.center = CGPointMake(self.tempMoveCell.center.x, self.tempMoveCell.center.y + 4);
            }
        }
            break;
        default:
            break;
    }
}

@end

