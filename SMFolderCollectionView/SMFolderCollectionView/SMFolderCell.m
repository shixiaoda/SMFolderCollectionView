//
//  SMFolderCell.m
//  XDCollectViewReorder
//
//  Created by 施孝达 on 16/4/14.
//  Copyright © 2016年 shixiaoda. All rights reserved.
//

#import "SMFolderCell.h"
#import "SMFolderCollectionView.h"

@implementation SMBookCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor:[UIColor greenColor]];
        
        _textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(frame), CGRectGetHeight(frame))];
        [_textLabel setTextAlignment:NSTextAlignmentCenter];
        [_textLabel setTextColor:[UIColor blackColor]];
        [self addSubview:_textLabel];
    }
    return self;
}

@end

@interface SMFolderCell () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout,
SMFolderCollectionViewDataSource>
{

}
@end

@implementation SMFolderCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor:[UIColor clearColor]];
        
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.itemSize = CGSizeMake(45, 45);
        [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
        
        _collectionView = [[SMFolderCollectionView alloc] initWithFrame:self.bounds collectionViewLayout:layout];
        [self addSubview:_collectionView];
        
        [_collectionView registerClass:[SMBookCell class] forCellWithReuseIdentifier:NSStringFromClass([SMBookCell class])];
        
        _collectionView.backgroundColor = [UIColor yellowColor];
        
        
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.xd_dataSource = self;
        _collectionView.edgeScrollEable = YES;
        
        _collectionView.isFolder = YES;
        
        _collectionView.scrollEnabled = NO;
        _collectionView.userInteractionEnabled = NO;
    }
    return self;
}

#pragma mark - UICollectionViewDelegate
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSObject *item = [_collectionDataSource objectAtIndex:indexPath.row];
    
    if ([item isKindOfClass:[NSNumber class]])
    {
        SMBookCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([SMBookCell class]) forIndexPath:indexPath];
        [cell.textLabel setText:[NSString stringWithFormat:@"%d",[[_collectionDataSource objectAtIndex:indexPath.row] intValue]]];
        cell.backgroundColor = [UIColor greenColor];
        cell.tag = [[_collectionDataSource objectAtIndex:indexPath.row] intValue];
        cell.hidden = NO;
        return cell;
    }
    return nil;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath item] == 0)
    {
        //        [self.collectionView reloadData];
    }
}

//- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
//    return CGSizeMake(45, 45);
//}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return _collectionDataSource.count;
}

#pragma mark - SMFolderCollectionViewDataSource
- (BOOL)xd_collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)xd_collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
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
}

- (void)xd_collectionView:(UICollectionView *)collectionView removeFromFolderAtIndexPath:(NSIndexPath *)indexPath
{
    NSObject *item = [_collectionDataSource objectAtIndex:indexPath.item];
    if ([item isKindOfClass:[NSNumber class]])
    {
        if ([self.superViewCtrl respondsToSelector:@selector(removeFromFolder:)])
        {
            NSDictionary *dic = @{@"cell":self,@"item":item,@"indexPath":indexPath};
            [self.superViewCtrl performSelector:@selector(removeFromFolder:) withObject:dic];
        }
    }
}
@end

//@implementation SMNoticeCell
//
//- (instancetype)initWithFrame:(CGRect)frame {
//    self = [super initWithFrame:frame];
//    if (self) {
//        [self setBackgroundColor:[UIColor whiteColor]];
//        
//        _textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(frame), CGRectGetHeight(frame))];
//        [_textLabel setTextAlignment:NSTextAlignmentCenter];
//        [_textLabel setTextColor:[UIColor blackColor]];
//        [self addSubview:_textLabel];
//    }
//    return self;
//}
//
//@end

@implementation SMNoticeCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor:[UIColor orangeColor]];
        
        //        _textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(frame), CGRectGetHeight(frame))];
        //        [_textLabel setTextAlignment:NSTextAlignmentCenter];
        //        [_textLabel setTextColor:[UIColor blackColor]];
        //        [self addSubview:_textLabel];
    }
    return self;
}
@end