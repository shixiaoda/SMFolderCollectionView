//
//  SMFolderCell.h
//  XDCollectViewReorder
//
//  Created by 施孝达 on 16/4/14.
//  Copyright © 2016年 shixiaoda. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SMFolderCollectionView;
@interface SMBookCell : UICollectionViewCell

@property (nonatomic, strong) UILabel *textLabel;

@end

@interface SMFolderCell : UICollectionViewCell

@property (nonatomic, strong) SMFolderCollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray *collectionDataSource;
@property (nonatomic, weak) UIViewController* superViewCtrl;
@end

//@interface SMNoticeCell : UICollectionReusableView
//
//@property (nonatomic, strong) UILabel *textLabel;
//
//@end

@interface SMNoticeCell : UICollectionViewCell

@end