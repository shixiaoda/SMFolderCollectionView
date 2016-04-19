//
//  ViewController.m
//  XDCollectViewReorder
//
//  Created by 施孝达 on 16/4/7.
//  Copyright © 2016年 shixiaoda. All rights reserved.
//

#import "ViewController.h"
#import "SMFolderCollectionView.h"
#import <objc/runtime.h>

@implementation UIView (test)
+ (void)load {
    SEL selectors[] = {
        @selector(setCenter:),
        @selector(setFrame:),
//        @selector(setHighlightedTextColor:),
        
    };
    
    for (NSUInteger index = 0; index < sizeof(selectors) / sizeof(SEL); ++index) {
        SEL originalSelector = selectors[index];
        SEL swizzledSelector = NSSelectorFromString([@"sm_hook_" stringByAppendingString:NSStringFromSelector(originalSelector)]);
        Method originalMethod = class_getInstanceMethod(self, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (void)sm_hook_setCenter:(CGPoint)center {
    if (center.y < 0 && self.tag == 88)
    {
        NSLog(@"出错了");
    }
    [self sm_hook_setCenter:center];
}

- (void)sm_hook_setFrame:(CGRect)frame{
    if (frame.origin.y < 0 && self.tag == 88)
    {
        NSLog(@"出错了2");
    }
    [self sm_hook_setFrame:frame];
}


@end


typedef void(^GestureStateChangeBlocks)(UILongPressGestureRecognizer *gestureRecognizer);

@interface ViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout,
SMFolderCollectionViewDataSource> {
    NSMutableArray *_collectionDataSource;
    GestureStateChangeBlocks _moveGestureStateChangeBlocks;
}
@property (nonatomic, strong) SMFolderCollectionView *collectionView;
@property (nonatomic,strong) UILongPressGestureRecognizer *moveGesture;

@property (nonatomic, weak) NSIndexPath *openedFolderIndexPath;//被打开的文件夹
@property (nonatomic, weak) NSIndexPath *moveToIndexPath;//交换的目标cell

@property (nonatomic, strong) NSNumber *removeFromFolderItem;//从文件夹中 移出的数据
@property (nonatomic, assign) CGRect selectCellRect;//打开文件夹前,cell原始位置

@property (nonatomic, assign) BOOL bNeedContinueEvent; //从文件夹中移除时,是否需要继续手势事件
@property (nonatomic, weak) NSIndexPath* needRemoverFolderIndexPath; //需要被移除的空文件夹
@property (nonatomic, assign) BOOL removeFromFoldering; //是否正在执行 从文件夹中移出

@property (nonatomic, assign) BOOL isHasSection; //是否有两个section
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initBaseLayout];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initBaseLayout
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
//    layout.minimumLineSpacing = 0;
//    layout.minimumInteritemSpacing = 0;
//    layout.itemSize = CGSizeMake(self.view.frame.size.width/3, 100);
    [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
    self.isHasSection = YES;
    _collectionDataSource = [[NSMutableArray alloc] init];
    for (int i=0; i<20; i++) {
        if (
//            i == 1
//            || i == 2 || i == 4 ||
            i == 1)
        {
            NSMutableArray * array = [[NSMutableArray alloc] init];
            [array addObject:@(i)];
                 [array addObject:@27];
            [array addObject:@28];
            [array addObject:@29];
            [array addObject:@30];
            [array addObject:@31];
            [array addObject:@32];
            [array addObject:@33];
            [array addObject:@34];
            [array addObject:@35];
            [array addObject:@36];
            
            [_collectionDataSource addObject:array];
        }
        else
        {
            [_collectionDataSource addObject:[NSNumber numberWithInt:i]];
        }
    }
    self.view.backgroundColor = [UIColor whiteColor];
//    CGRect frame = CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.height - 100);
    _collectionView = [[SMFolderCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    _collectionView.contentInset = UIEdgeInsetsMake(100, 0, 0, 0);
    _collectionView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_collectionView];
    
    [_collectionView registerClass:[SMBookCell class] forCellWithReuseIdentifier:NSStringFromClass([SMBookCell class])];
    [_collectionView registerClass:[SMFolderCell class] forCellWithReuseIdentifier:NSStringFromClass([SMFolderCell class])];
//    [_collectionView registerClass:[SMNoticeCell class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:NSStringFromClass([SMNoticeCell class])];
    
    [_collectionView registerClass:[SMNoticeCell class] forCellWithReuseIdentifier:NSStringFromClass([SMNoticeCell class])];
    
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.xd_dataSource = self;
    _collectionView.edgeScrollEable = YES;
    _collectionView.dragView = self.view;
    
    _moveGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(moveGestureAction:)];
    [self.view addGestureRecognizer:_moveGesture];
    
    WS(weakSelf);
    _moveGestureStateChangeBlocks = ^(UILongPressGestureRecognizer *gestureRecognizer) {
        switch (gestureRecognizer.state) {
            case UIGestureRecognizerStateBegan:{
                NSLog(@"UIGestureRecognizerStateBegan");
                if (weakSelf.openedFolderIndexPath)
                {
                    SMFolderCell *cell = (SMFolderCell *)[weakSelf.collectionView cellForItemAtIndexPath:weakSelf.openedFolderIndexPath];
                    CGPoint point = [gestureRecognizer locationInView:cell.collectionView];
                    [cell.collectionView xd_beginInteractiveMovementForItemAtIndexPath:[cell.collectionView indexPathForItemAtPoint:point]];
                    CGPoint tapLocation = [gestureRecognizer locationInView:cell.collectionView];
                    [cell.collectionView xd_updateInteractiveMovementTargetPosition:CGPointMake(tapLocation.x+5, tapLocation.y+5)];
                }
                else
                {
                    CGPoint point = [gestureRecognizer locationInView:weakSelf.collectionView];
                    NSIndexPath *indexPath = [weakSelf.collectionView indexPathForItemAtPoint:point];
                    if (weakSelf.isHasSection)
                    {
                        if ([indexPath section] == 0)
                        {
                            break;
                        }
                    }
                    
                    [weakSelf.collectionView xd_beginInteractiveMovementForItemAtIndexPath:indexPath];
                    CGPoint tapLocation = [gestureRecognizer locationInView:weakSelf.collectionView];
                    [weakSelf.collectionView xd_updateInteractiveMovementTargetPosition:CGPointMake(tapLocation.x+5, tapLocation.y+5)];
                }
            }
                break;
            case UIGestureRecognizerStateChanged:{
                NSLog(@"StateChanged ================begin");
                if (weakSelf.openedFolderIndexPath)
                {
                    SMFolderCell *cell = (SMFolderCell *)[weakSelf.collectionView cellForItemAtIndexPath:weakSelf.openedFolderIndexPath];
                    if (weakSelf.bNeedContinueEvent)
                    {
                        CGPoint point = [gestureRecognizer locationInView:weakSelf.collectionView];
                        
                        NSIndexPath *indexPath = [weakSelf.collectionView indexPathForItemAtPoint:point];
                        weakSelf.bNeedContinueEvent = NO;
                        if (indexPath != nil)
                        {
                            NSLog(@"StateChanged 移除 处理 有 indexPath");
                            [cell.collectionView xd_endInteractiveMovement];
                            [weakSelf removeFromFolder:cell removeIndexPath:indexPath tempCellPoint:point];
                        }
                        else
                        {
                            NSLog(@"StateChanged 移除 处理 无 indexPath");
                            [cell.collectionView xd_endInteractiveMovement];
                            CGPoint point2 = [gestureRecognizer locationInView:weakSelf.view];
                            [weakSelf removeFromFolder:cell removeIndexPath:nil tempCellPoint:point2];
                        }
                    }
                    else
                    {
                        if (!weakSelf.removeFromFoldering)
                        {
                            NSLog(@"StateChanged 21");
                            [cell.collectionView xd_updateInteractiveMovementTargetPosition:[gestureRecognizer locationInView:cell.collectionView]];
                        }
                        else
                        {
                            NSLog(@"StateChanged 22");
                        }
                    }
                }
                else
                {
                    if (!weakSelf.removeFromFoldering)
                    {
                        NSLog(@"StateChanged 31");
                        [weakSelf.collectionView xd_updateInteractiveMovementTargetPosition:[gestureRecognizer locationInView:weakSelf.collectionView]];
                    }
                    else
                    {
                        NSLog(@"StateChanged 32");
                        CGPoint point = [gestureRecognizer locationInView:weakSelf.view];
                        weakSelf.collectionView.removeFromFoldering = YES;
                        [weakSelf.collectionView xd_updateInteractiveMovementTargetPosition:point];
                    }
                }
                NSLog(@"StateChanged ================end");
            }
                break;
            case UIGestureRecognizerStateEnded:{
                NSLog(@"StateEnded");
                if (weakSelf.openedFolderIndexPath)
                {
                    SMFolderCell *cell = (SMFolderCell *)[weakSelf.collectionView cellForItemAtIndexPath:weakSelf.openedFolderIndexPath];
                    
                    if (weakSelf.bNeedContinueEvent)
                    {
                        weakSelf.bNeedContinueEvent = NO;
                        
//                        if (!weakSelf.removeFromFoldering)
//                        {
//                            NSLog(@"StateEnded 移除 处理 无 indexPath 1");
//                            CGPoint point = [gestureRecognizer locationInView:weakSelf.collectionView];
//                            [weakSelf removeFromFolder:cell removeIndexPath:nil tempCellPoint:point];
//                            [weakSelf.collectionView xd_endInteractiveMovement];
//                        }
//                        else
                        {
                            NSLog(@"StateEnded 移除 处理 无 indexPath 2");
                            CGPoint point = [gestureRecognizer locationInView:weakSelf.view];
                            [cell.collectionView xd_endInteractiveMovement];
                            [weakSelf removeFromFolder:cell removeIndexPath:nil tempCellPoint:point];
                            [weakSelf.collectionView xd_endInteractiveMovement];
                        }
                    }
                    else
                    {
                         NSLog(@"StateEnded2");
                        [cell.collectionView xd_endInteractiveMovement];
                    }
                }
                else
                {
                     NSLog(@"StateEnded3");
                    [weakSelf.collectionView xd_endInteractiveMovement];
                }
                NSLog(@"weakSelf.removeFromFoldering = NO");
                weakSelf.removeFromFoldering = NO;
            }
                break;
            default:{
                NSLog(@"default");
                if (weakSelf.openedFolderIndexPath)
                {
                    
                    SMFolderCell *cell = (SMFolderCell *)[weakSelf.collectionView cellForItemAtIndexPath:weakSelf.openedFolderIndexPath];
                    
                    if (weakSelf.bNeedContinueEvent)
                    {
                        NSLog(@"StateCancel 移除 处理 无 indexPath");
                        weakSelf.bNeedContinueEvent = NO;
                        CGPoint point = [gestureRecognizer locationInView:weakSelf.collectionView];
                        [cell.collectionView xd_endInteractiveMovement];
                        [weakSelf removeFromFolder:cell removeIndexPath:nil tempCellPoint:point];
                        [weakSelf.collectionView xd_endInteractiveMovement];
                    }
                    else
                    {
                        NSLog(@"default 2");
                        [cell.collectionView xd_endInteractiveMovement];
                    }
                }
                else
                {
                    NSLog(@"default 3");
                    [weakSelf.collectionView xd_endInteractiveMovement];
                }
            }
                break;
        }
    };

}

- (void)moveGestureAction:(id)sender {
    if (_moveGestureStateChangeBlocks) {
        _moveGestureStateChangeBlocks(sender);
    }
}

#pragma mark - UICollectionViewDelegate

//- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
//{
//    UICollectionReusableView *reusableview = nil;
//    
//    if (kind == UICollectionElementKindSectionHeader){
//        
//        SMNoticeCell *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:NSStringFromClass([SMNoticeCell class])forIndexPath:indexPath];
//        
//        NSString *title = [[NSString alloc] initWithFormat:@"this is header %i",indexPath.section +1];
//        headerView.textLabel.text = title;
//        reusableview = (UICollectionReusableView *)headerView;
//    }
//    
//    return reusableview;
//}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.isHasSection)
    {
        if ([indexPath section] == 0)
        {
            SMNoticeCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([SMNoticeCell class]) forIndexPath:indexPath];
//            [cell.textLabel setText:[NSString stringWithFormat:@"%d",[[_collectionDataSource objectAtIndex:indexPath.item] intValue]]];
            cell.tag = 1212;//[[_collectionDataSource objectAtIndex:indexPath.row] intValue];
            cell.hidden = NO;
            return cell;
        }
    }
    NSObject *item = [_collectionDataSource objectAtIndex:indexPath.row];
    if ([item isKindOfClass:[NSNumber class]])
    {
        SMBookCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([SMBookCell class]) forIndexPath:indexPath];
        [cell.textLabel setText:[NSString stringWithFormat:@"%d",[[_collectionDataSource objectAtIndex:indexPath.item] intValue]]];
        cell.tag = [[_collectionDataSource objectAtIndex:indexPath.row] intValue];
        if ([self.moveToIndexPath isEqual:indexPath])
        {
//            NSLog(@"cell test1 %d %@",cell.tag,cell);
            self.moveToIndexPath = nil;
            if (((SMFolderCollectionView *)collectionView).dragOperarion != XWDragCellCollectionViewOperarionNone)
            {
                cell.hidden = YES;
            }
        }
        else
        {
//            NSLog(@"cell test2 %d %@",cell.tag,cell);
            cell.hidden = NO;
        }
        return cell;
    }
    else
    {
        SMFolderCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([SMFolderCell class]) forIndexPath:indexPath];
        BOOL bNeedReloadData = NO;
        if (cell.collectionDataSource)
        {
            bNeedReloadData = YES;
        }
        cell.collectionDataSource = (NSMutableArray *)item;
        if (bNeedReloadData)
        {
            [cell.collectionView reloadData];
        }
        cell.collectionView.dragView = self.view;
        cell.superViewCtrl = self;
        cell.tag = 999;
        if ([self.moveToIndexPath isEqual:indexPath])
        {
//            NSLog(@"cell section1 %d state=%d",cell.tag, ((SMFolderCollectionView *)collectionView).dragOperarion);
            self.moveToIndexPath = nil;
            if (((SMFolderCollectionView *)collectionView).dragOperarion != XWDragCellCollectionViewOperarionNone)
            {
//                NSLog(@"hidden yes");
                cell.hidden = YES;
            }
            else
            {
//                NSLog(@"hidden NO");
                cell.hidden = NO;
            }
        }
        else
        {
//            NSLog(@"cell section2 %d",cell.tag);
            cell.hidden = NO;
        }
        return cell;
    }
}

//- (void)test
//{
//    self.isHasSection = NO;
//    NSIndexSet *set = [NSIndexSet indexSetWithIndex:0];
//    [self.collectionView deleteSections:set];
//
//}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"根目录 点击 %d",[indexPath item]);
    if ([indexPath item] == 0 && [indexPath section] == 0)
    {
//        NSMutableIndexSet *set = [[NSMutableIndexSet alloc] init];
//        [set addIndex:indexPath];
        if (self.isHasSection)
        {
            self.isHasSection = NO;
            NSIndexSet *set = [NSIndexSet indexSetWithIndex:0];
            [self.collectionView deleteSections:set];
        }
//        [self performSelector:@selector(test) withObject:self afterDelay:0.05];
    }
    else if ([indexPath item] == 0)
    {
        [self.collectionView reloadData];
    }
    
    NSObject *item = [_collectionDataSource objectAtIndex:[indexPath item]];
    if ([item isKindOfClass:[NSMutableArray class]])
    {
        if (self.openedFolderIndexPath && [self.openedFolderIndexPath isEqual:indexPath])
        {
            [self closeFolder:indexPath removeFromFolder:NO];
            self.openedFolderIndexPath = nil;
        }
        else
        {
            [self openFolder:indexPath];
        }
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if (!self.isHasSection)
    {
        return CGSizeMake(100, 100);
    }
    else
    {
        if ([indexPath section] == 0)
        {
            return CGSizeMake(self.view.frame.size.width, 30);
        }
        else
        {
            return CGSizeMake(100, 100);
        }
    }

}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    return CGSizeZero;
//    return CGSizeMake(self.view.frame.size.width, 30);
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return self.isHasSection? 2 : 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
//    NSLog(@"根目录 count = %d",_collectionDataSource.count);
//    return _collectionDataSource.count;
    if (!self.isHasSection)
    {
        return _collectionDataSource.count;
    }
    else
    {
        if (section == 0)
        {
            return 1;
        }
        else
        {
            return _collectionDataSource.count;
        }

    }
}

#pragma mark - XDCollectionViewDataSource
- (BOOL)xd_collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)xd_collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    NSLog(@"执行交换 数据 %d %d",sourceIndexPath.item,destinationIndexPath.item);
//    NSLog(@"交换前 collectionDataSource = %@",_collectionDataSource);
    NSObject *sourceItem = [_collectionDataSource objectAtIndex:sourceIndexPath.item];
    if ([sourceItem isKindOfClass:[NSMutableArray class]])
    {
        sourceItem = [sourceItem mutableCopy];
    }
    else
    {
        sourceItem = [sourceItem copy];
    }
    
    [_collectionDataSource removeObjectAtIndex:sourceIndexPath.item];
    [_collectionDataSource insertObject:sourceItem atIndex:destinationIndexPath.item];
    
    
    if ([destinationIndexPath item] == _collectionDataSource.count -1)
    {
        self.moveToIndexPath = destinationIndexPath;
        [collectionView reloadItemsAtIndexPaths:@[destinationIndexPath,[NSIndexPath indexPathForItem:[destinationIndexPath item]-1 inSection:self.isHasSection?1:0]]];
    }
    else
    {
        self.moveToIndexPath = destinationIndexPath;
        [collectionView reloadItemsAtIndexPaths:@[destinationIndexPath,[NSIndexPath indexPathForItem:[destinationIndexPath item]+1 inSection:self.isHasSection?1:0]]];
    }
    
//    NSLog(@"执行交换后 数据 %d %d", selectItem   //obj:sourceIndexPath.item],[destinationIndexPath.item]);
}

- (void)xd_collectionView:(UICollectionView *)collectionView addItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath*)destinationIndexPath
{
    NSObject *selectItem = [_collectionDataSource objectAtIndex:sourceIndexPath.item];
    NSObject *destinationItem = [_collectionDataSource objectAtIndex:destinationIndexPath.item];
    
    if ([destinationItem isKindOfClass:[NSMutableArray class]] && [selectItem isKindOfClass:[NSNumber class]])
    {
        //处理数据
        NSLog(@"叠加到文件夹 处理 叠加数据");
        NSMutableArray * destinationArray = (NSMutableArray *)destinationItem;
        [destinationArray insertObject:selectItem atIndex:0];
        //处理UI
        SMFolderCell *cell = (SMFolderCell *)[collectionView cellForItemAtIndexPath:destinationIndexPath];
        NSIndexPath *newIndex = [NSIndexPath indexPathForItem:0 inSection:0];
        [cell.collectionView insertItemsAtIndexPaths:@[newIndex]];
        
    }
    else if ([destinationItem isKindOfClass:[NSNumber class]])
    {
        
    }
}

- (void)xd_collectionView:(UICollectionView *)collectionView removeItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath*)destinationIndexPath
{
    NSObject *selectItem = [_collectionDataSource objectAtIndex:sourceIndexPath.item];
    NSObject *destinationItem = [_collectionDataSource objectAtIndex:destinationIndexPath.item];
    
    if ([destinationItem isKindOfClass:[NSMutableArray class]] && [selectItem isKindOfClass:[NSNumber class]])
    {
        [_collectionDataSource removeObject:selectItem];
        [collectionView deleteItemsAtIndexPaths:@[sourceIndexPath]];
    }
    else if ([destinationItem isKindOfClass:[NSNumber class]])
    {
        NSLog(@"合并成文件夹 处理 叠加数据");
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:2];
        [array addObject:selectItem];
        [array addObject:destinationItem];
        [_collectionDataSource insertObject:array atIndex:destinationIndexPath.item];
        [_collectionDataSource removeObject:destinationItem];
        
        
        [collectionView performBatchUpdates:^{
//            [collectionView deleteItemsAtIndexPaths:@[destinationIndexPath]];
//            [collectionView insertItemsAtIndexPaths:@[destinationIndexPath]];
            [collectionView reloadItemsAtIndexPaths:@[destinationIndexPath]];
        } completion:^(BOOL finished) {
            [_collectionDataSource removeObject:selectItem];
            [collectionView deleteItemsAtIndexPaths:@[sourceIndexPath]];
        }];
    }
}


#pragma mark - privite methods
- (void)removeFromFolder:(NSDictionary *)dic
{
    self.removeFromFoldering = YES;
    self.collectionView.removeFromFoldering = YES;

    SMFolderCell *cell = dic[@"cell"];
    
    [UIView animateWithDuration:0.25 animations:^{
        CGRect frame = cell.collectionView.tempMoveCell.frame;
        cell.collectionView.tempMoveCell.frame = CGRectMake(frame.origin.x, frame.origin.y, 100, 100);
    } completion:^(BOOL finished) {
    }];
    
    self.removeFromFolderItem = dic[@"item"];
    [cell.collectionDataSource removeObject:self.removeFromFolderItem];
    
    if (cell.collectionDataSource.count == 0)
    {
        self.needRemoverFolderIndexPath = [_collectionView indexPathForCell:cell];
        cell.hidden = YES;
    }
    else
    {
        self.needRemoverFolderIndexPath = nil;
    }
    
    NSIndexPath *indexPath = dic[@"indexPath"];
    [cell.collectionView deleteItemsAtIndexPaths:@[indexPath]];
    
    NSIndexPath *subCellIndexPath = [self.collectionView indexPathForCell:cell];
    [self closeFolder:subCellIndexPath removeFromFolder:YES];
//    NSLog(@"dragcloseFolder 移除第%d个 内容是 %d",[dic[@"indexPath"] row], [dic[@"item"] integerValue]);
}

- (void)removeFromFolder:(SMFolderCell *)folderCell removeIndexPath:(NSIndexPath *)removeIndexPath tempCellPoint:(CGPoint)tempCellPoint
{
//    [folderCell.collectionView xd_endInteractiveMovement];
    if (removeIndexPath == nil)
    {
        NSIndexPath * folderIndexPath = [_collectionView indexPathForCell:folderCell];
        if (self.needRemoverFolderIndexPath)
        {
            [_collectionDataSource removeObjectAtIndex:[self.needRemoverFolderIndexPath item]];
            removeIndexPath = folderIndexPath;
        }
        else
        {
            removeIndexPath = [NSIndexPath indexPathForItem:[folderIndexPath item]+1 inSection:self.isHasSection?1:0];
        }
    }
    else
    {
        if (self.needRemoverFolderIndexPath)
        {
            [_collectionDataSource removeObjectAtIndex:[self.needRemoverFolderIndexPath item]];
        }
    }
    
    [_collectionDataSource insertObject:self.removeFromFolderItem atIndex:[removeIndexPath item]];
    [_collectionView xd_continueInteractiveMovementForItemAtIndexPath:removeIndexPath needRemoveItem:self.needRemoverFolderIndexPath tempMoveCell:folderCell.collectionView.tempMoveCell];
    if (self.needRemoverFolderIndexPath)
    {
        self.needRemoverFolderIndexPath = nil;
    }
    [_collectionView xd_updateInteractiveMovementTargetPosition:tempCellPoint];
    
    
    self.openedFolderIndexPath = nil;
//    self.removeFromFoldering = NO;
    NSLog(@"self.openedFolderIndexPath = nil");
//    self.moveGesture.enabled = NO;
//    self.moveGesture.enabled = YES;
}

- (void)closeFolder:(NSIndexPath *)indexPath removeFromFolder:(BOOL)removeFromFolder
{
    SMFolderCell *cell = (SMFolderCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
    if ([cell isKindOfClass:[SMFolderCell class]])
    {
        WS(weakSelf);
        [UIView animateWithDuration:0.25 animations:^{
            cell.frame = self.selectCellRect;
            cell.backgroundColor = [UIColor yellowColor];
            
            cell.collectionView.frame = CGRectMake(0, 0, cell.frame.size.width, cell.frame.size.height);
            cell.collectionView.backgroundColor = [UIColor yellowColor];
            
            UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
            layout.itemSize = CGSizeMake(45, 45);
            [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
            __block SMFolderCell* wkCell = cell;
            
            [cell.collectionView setCollectionViewLayout:layout animated:YES completion:^(BOOL finished) {
//                NSLog(@"finish closeFolder");
                wkCell.collectionView.scrollEnabled = NO;
                wkCell.collectionView.userInteractionEnabled = NO;
                
                weakSelf.collectionView.scrollEnabled = YES;
            }];
            
        } completion:^(BOOL finished) {
            if (removeFromFolder)
            {
                CGPoint point = [self.view convertPoint:cell.collectionView.tempMoveCell.center toView:_collectionView];
                NSIndexPath *indexPath = [_collectionView indexPathForItemAtPoint:point];
                if (indexPath != nil)
                {
                    //直接处理
                    NSLog(@"finish 移除 处理 有 indexPath");
                    self.bNeedContinueEvent = NO;
                    [cell.collectionView xd_endInteractiveMovement];
                    [self removeFromFolder:cell removeIndexPath:indexPath tempCellPoint:cell.collectionView.tempMoveCell.center];
                    
                    if (_moveGesture.state == UIGestureRecognizerStateChanged)
                    {
                        NSLog(@"手势还没结束1");
//                        [_collectionView xd_endInteractiveMovement];
                    }
                    else
                    {
                        NSLog(@"手势已经结束1");
                        [_collectionView xd_endInteractiveMovement];
                    }
                }
                else
                {
                    //放到 拖动位置更新时候处理
                    NSLog(@"finish 移除 处理 无 indexPath");
                    if (_moveGesture.state == UIGestureRecognizerStateChanged)
                    {
                        NSLog(@"手势还没结束");
                        self.bNeedContinueEvent = YES;
                    }
                    else
                    {
                        NSLog(@"手势已经结束");
                        self.bNeedContinueEvent = NO;
                        CGPoint point2 = cell.collectionView.tempMoveCell.center;
//                        NSLog(@"point = %f %f",point2.x,point2.y);
                        [self removeFromFolder:cell removeIndexPath:nil tempCellPoint:point2];
                        
                        [_collectionView xd_endInteractiveMovement];
                    }
                }
            }
            
        }];
    }
}

- (void)openFolder:(NSIndexPath *)indexPath
{
    self.openedFolderIndexPath = indexPath;
    
    SMFolderCell *cell = (SMFolderCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
    if ([cell isKindOfClass:[SMFolderCell class]])
    {
        self.selectCellRect = cell.frame;
        [UIView animateWithDuration:0.25 animations:^{
            [self.collectionView bringSubviewToFront:cell];
            CGRect frame = CGRectMake(0, self.collectionView.contentOffset.y, self.view.frame.size.width, self.view.frame.size.height);
            cell.frame = frame;//[self.collectionView convertRect:frame toView:self.view];
            cell.backgroundColor = [UIColor clearColor];
            
            cell.collectionView.frame = CGRectMake(10, 100, self.view.frame.size.width - 20, self.view.frame.size.height -200);
            cell.collectionView.backgroundColor = [UIColor yellowColor];
            
            UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
            layout.itemSize = CGSizeMake(80, 80);
            [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
            __block SMFolderCell* wkCell = cell;
            WS(weakSelf);
            [cell.collectionView setCollectionViewLayout:layout animated:YES completion:^(BOOL finished) {
                NSLog(@"finish openFolder");
                wkCell.collectionView.scrollEnabled = YES;
                wkCell.collectionView.userInteractionEnabled = YES;
                
                weakSelf.collectionView.scrollEnabled = NO;
                
            }];
            
        } completion:^(BOOL finished) {
            
            
        }];
    }
}

@end

