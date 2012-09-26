//
//  IAAlarmFindViewController.m
//  iAlarm
//
//  Created by li shiyong on 12-2-27.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "IAParam.h"
#import "IAFlagAnnotationView.h"
#import "YCLib.h"
#import "YCMapPointAnnotation+AlarmUI.h"
#import "YCShareContent.h"
#import "YCShareAppEngine.h"
#import "IAAlarmNotificationCenter.h"
#import "IANotifications.h"
#import "YCSystemStatus.h"
#import "LocalizedString.h"
#import "IAAlarm.h"
#import "YCSound.h"
#import "YCPositionType.h"
#import "IAAlarmNotification.h"
#import <QuartzCore/QuartzCore.h>
#import "IAAlarmFindViewController.h"

NSString* YCTimeIntervalStringSinceNow(NSDate *date);

NSString* YCTimeIntervalStringSinceNow(NSDate *date){ 
    
    NSDate *now = [NSDate date];
    NSCalendar *currentCalendar = [NSCalendar currentCalendar];
    NSUInteger units = NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit;
    NSDateComponents *comps = [currentCalendar components: units fromDate:date toDate:now options:0];
    
    NSString *returnString = nil;
    if (comps.day > 0) {
       returnString = [NSString stringWithFormat:KTITitleXDAgo, comps.day];
    }else if (comps.hour > 0) {
        returnString = [NSString stringWithFormat:KTITitleXHAgo, comps.hour];
    }else if (comps.minute > 0) {
        returnString = [NSString stringWithFormat:KTITitleXMAgo, comps.minute];
    }else  {
        returnString = KTITitleNow;
    }
    
    return returnString;
}


@interface IAAlarmFindViewController(private)

- (void)setDistanceLabelWithCurrentLocation:(CLLocation*)curLocation;
- (UIImage*)takePhotoFromTheMapView;
- (void)loadViewDataWithIndexOfNotifications:(NSInteger)index;
- (void)reloadTimeIntervalLabel;
- (void)makeMoveAlarmAnimationWithStatus:(NSInteger)theStatus;
- (void)registerNotifications;
- (void)unRegisterNotifications;

- (void)setSkinWithType:(IASkinType)type;

@end


@implementation IAAlarmFindViewController

- (void)setSkinWithType:(IASkinType)type{
    
    YCBarButtonItemStyle buttonItemStyle = YCBarButtonItemStyleDefault;
    YCBarStyle barStyle = YCBarStyleDefault;
    UIStatusBarStyle statusBarStyle = UIStatusBarStyleDefault;
    if (IASkinTypeDefault == type) {
        buttonItemStyle = YCBarButtonItemStyleDefault;
        barStyle = YCBarStyleDefault;
        statusBarStyle = UIStatusBarStyleDefault;
    }else {
        buttonItemStyle = YCBarButtonItemStyleSilver;
        barStyle = YCBarStyleSilver;
        statusBarStyle = UIStatusBarStyleBlackOpaque;
    }
    [self.navigationController.navigationBar setYCBarStyle:barStyle];
    //[self.tableView setYCBackgroundStyle:tableViewBgStyle];
    [self.doneButtonItem setYCStyle:buttonItemStyle];
    [self.upDownBarItem setUpDownYCStyle:buttonItemStyle];
    
    //iPad总是黑色不透明的状态bar
    if ([IAParam sharedParam].deviceType == YCDeviceTypeiPad) {
        [YCAlarmStatusBar shareStatusBarWithStyle:UIStatusBarStyleBlackOpaque];
    }else{
        [YCAlarmStatusBar shareStatusBarWithStyle:statusBarStyle];
    }
    
}

#pragma mark - property

@synthesize tableView;
@synthesize mapViewCell, takeImageContainerView, containerView, mapView, maskImageView, timeIntervalLabel, watchImageView;
@synthesize buttonCell, button1, button2;
@synthesize notesCell, notesLabel, titleLabel;
@synthesize backgroundTableView, backgroundTableViewCell;

- (id)doneButtonItem{
	
	if (!self->doneButtonItem) {
        /*
		doneButtonItem = [[UIBarButtonItem alloc]
								initWithBarButtonSystemItem:UIBarButtonSystemItemDone
								target:self
								action:@selector(doneButtonItemPressed:)];
        doneButtonItem.style = UIBarButtonItemStyleBordered;

         */
        doneButtonItem = [[UIBarButtonItem alloc] initWithTitle:KTitleDone 
                                                          style:UIBarButtonItemStyleBordered 
                                                         target:self 
                                                         action:@selector(doneButtonItemPressed:)];
        
        
	}
	
	return self->doneButtonItem;
}

- (id)upDownBarItem{
    if (!upDownBarItem) {
        /*
        UISegmentedControl *segmentedControl = [[[UISegmentedControl alloc] initWithItems:
                                                [NSArray arrayWithObjects:
                                                 [UIImage imageNamed:@"UIButtonBarArrowUpSmall.png"],
                                                 [UIImage imageNamed:@"UIButtonBarArrowDownSmall.png"],
                                                 nil]] autorelease];
        
        [segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
        segmentedControl.frame = CGRectMake(0, 0, 90, 30);
        segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
        segmentedControl.momentary = YES;
        
        upDownBarItem = [[UIBarButtonItem alloc] initWithCustomView:segmentedControl];
         */
        
        upDownBarItem = [[UIBarButtonItem alloc] initUpDownWithYCStyle:YCBarButtonItemStyleDefault target:self action:@selector(segmentAction:)];
    }
    return upDownBarItem;
}
 
#pragma mark - Controll Event
- (IBAction)tellFriendsButtonPressed:(id)sender{
    NSString *title = viewedAlarmNotification.alarm.title;
    NSString *message = viewedAlarmNotification.alarm.title;
    UIImage *image = [self takePhotoFromTheMapView];
    
    YCShareContent *shareContent = [YCShareContent shareContentWithTitle:title message:message image:image];
    shareContent.message1 = viewedAlarmNotification.alarm.title;
    [engine shareAppWithContent:shareContent];
}

- (IBAction)delayAlarm1ButtonPressed:(id)sender{
    if (!actionSheet1) {
        NSString *bTitle5 = [NSString stringWithFormat:kTitleAlarmAfterXMinutes,5];
        NSString *bTitle30 = [NSString stringWithFormat:kTitleAlarmAfterXMinutes,30];
        actionSheet1 = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:kAlertBtnCancel destructiveButtonTitle:bTitle5 otherButtonTitles:bTitle30,nil];
    }
    [actionSheet1 showInView:self.view];
}

- (void)doneButtonItemPressed:(id)sender{
    [self dismissModalViewControllerAnimated:YES];
}


- (IBAction)segmentAction:(id)sender
{
    NSInteger index = 0;
    if (!viewedAlarmNotification) {
        [self loadViewDataWithIndexOfNotifications:index];
        return;
    }
    
    NSString *animationSubtype = nil;
	UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    switch (segmentedControl.selectedSegmentIndex) {
        case 0:
            index = [alarmNotifitions indexOfObject:viewedAlarmNotification] - 1; //up
            animationSubtype = kCATransitionFromBottom;
            break;
        case 1:
            index = [alarmNotifitions indexOfObject:viewedAlarmNotification] + 1; //down
            animationSubtype = kCATransitionFromTop;
            break;
        default:
            break;
    }
    
    [self loadViewDataWithIndexOfNotifications:index];
    
    //动画
    CATransition *animation = [CATransition animation];
    animation.delegate = self;
    animation.type = kCATransitionPush;
    animation.subtype = animationSubtype;
    animation.duration = 0.75;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.tableView.layer addAnimation:animation forKey:@"upDown AlarmNotification"];
}

- (void)timerFireMethod:(NSTimer*)theTimer{
    [self reloadTimeIntervalLabel];
}

#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    if ([actionSheet cancelButtonIndex] == buttonIndex) {
        return;
    }
    
    //闹钟弧形动画
    NSInteger status = (actionSheet == actionSheet1) ? 0 : 1;
    [self makeMoveAlarmAnimationWithStatus:status]; 
    
    if ( actionSheet == actionSheet1) {
        
        
        IAAlarm *alarmForNotif = viewedAlarmNotification.alarm;
        
        //保存到文件
        NSString *delayString = nil;
        NSTimeInterval secs = 0;
        if (0 == buttonIndex) {//延时1
            secs = 60*5;//5分钟
            delayString = @"5";
        }else if (1 == buttonIndex) {//延时2
            secs = 60*30;//30分钟
            delayString = @"30";
        }
        NSDate *fireDate = [NSDate dateWithTimeIntervalSinceNow:secs];

        IAAlarmNotification *alarmNotification = [[[IAAlarmNotification alloc] initWithSoureAlarmNotification:viewedAlarmNotification  fireTimeStamp:fireDate] autorelease];
        [[IAAlarmNotificationCenter defaultCenter] addNotification:alarmNotification];
        
        //发本地通知
        BOOL arrived = [alarmForNotif.positionType.positionTypeId isEqualToString:@"p002"];//是 “到达时候”提醒
        NSString *promptTemple = arrived?kAlertFrmStringArrived:kAlertFrmStringLeaved;
        
        NSString *alarmName = alarmForNotif.alarmName ? alarmForNotif.alarmName : alarmForNotif.positionTitle;
        NSString *alertTitle = [[[NSString alloc] initWithFormat:promptTemple,alarmName,0.0] autorelease];
        NSString *alarmMessage = [alarmForNotif.notes stringByTrim];
        
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:alarmNotification.notificationId forKey:@"knotificationId"];
        [userInfo setObject:alertTitle forKey:@"kTitleStringKey"];
        if (alarmMessage) 
            [userInfo setObject:alarmMessage forKey:@"kMessageStringKey"];
        
        //为了下面能取消它
        NSString *alarmIdDelayString = [NSString stringWithFormat:@"%@-%@",alarmForNotif.alarmId,delayString];
        NSString *alarmIdDelayStringKey = @"alarmIdDelayStringKey";
        [userInfo setObject:alarmIdDelayString forKey:alarmIdDelayStringKey];        
        
        NSString *iconString = [NSString stringEmojiClockFaceNine];//这是钟表🕘
        alertTitle =  [NSString stringWithFormat:@"%@%@",iconString,alertTitle]; 
        [userInfo setObject:iconString forKey:@"kIconStringKey"];
        
        
        NSString *notificationBody = alertTitle;
        if (alarmMessage && alarmMessage.length > 0) {
            notificationBody = [NSString stringWithFormat:@"%@: %@",alertTitle,alarmMessage];
        }
        
        NSString *notificationImage = nil;
        if (IASkinTypeDefault == [IAParam sharedParam].skinType) {
            notificationImage = @"IANotificationBackgroundDefault.png";
        }else {
            notificationImage = @"IANotificationBackgroundSilver.png";
        }
        
        UIApplication *app = [UIApplication sharedApplication];
        
        //如果有相同的先取消
        [app.scheduledLocalNotifications enumerateObjectsUsingBlock:^(UILocalNotification *obj, NSUInteger idx, BOOL *stop) {
            NSString *anAlarmIdDelayString = [obj.userInfo objectForKey:alarmIdDelayStringKey];
            if ([anAlarmIdDelayString isEqualToString:alarmIdDelayString]) {
                [app performSelector:@selector(cancelLocalNotification:) withObject:obj afterDelay:0.0];
            }
        }];
        
        
        NSInteger badgeNumber = app.applicationIconBadgeNumber + 1; //角标数
        UILocalNotification *notification = [[[UILocalNotification alloc] init] autorelease];
        notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:secs];
        notification.timeZone = [NSTimeZone defaultTimeZone];
        notification.repeatInterval = 0;
        notification.soundName = alarmForNotif.sound.soundFileName;
        notification.alertBody = notificationBody;
        notification.applicationIconBadgeNumber = badgeNumber;
        notification.userInfo = userInfo;
        notification.alertLaunchImage = notificationImage;
        [app scheduleLocalNotification:notification];
    }
    
}


#pragma mark - Animation delegate

- (void)animationDidStart:(CAAnimation *)theAnimation{
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    if ([theAnimation isKindOfClass:[CAKeyframeAnimation class]]) {
        //self.navigationController.wantsFullScreenLayout = YES;
        self.view.window.windowLevel = UIWindowLevelStatusBar+2; //自定义的状态栏：+1,所以这里+2。
        [[YCAlarmStatusBar shareStatusBar] setHidden:NO animated:YES];
    }
}

- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag{
    if ([theAnimation isKindOfClass:[CAKeyframeAnimation class]]) {
        
        //动画结束后，把主window设置成正常状态
        self.view.window.windowLevel = UIWindowLevelNormal;
        //在bar上立刻显示闹钟图标
        [[YCAlarmStatusBar shareStatusBar] setAlarmIconHidden:NO animated:NO];    
        
        //动画结束，图就没用了
        [clockAlarmImageView removeFromSuperview];
        [clockAlarmImageView release];clockAlarmImageView = nil;
        //bar的闹钟数量累加
        [[YCAlarmStatusBar shareStatusBar] increaseAlarmCount];
    }
    if ([UIApplication sharedApplication].isIgnoringInteractionEvents) 
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
}

#pragma mark - Utility

- (void)setDistanceLabelWithCurrentLocation:(CLLocation*)curLocation{ 
    
    NSString *distanceString = [viewedAlarmNotification.alarm distanceLocalStringFromLocation:curLocation];
    if (distanceString) {
        if (![self.titleLabel.text isEqualToString:distanceString]){
            
            [UIView transitionWithView:self.titleLabel duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                self.titleLabel.text = distanceString;
            } completion:NULL];
        }
    }else{
        self.titleLabel.text = @" . . . ";
    }
    
}

- (UIImage*)takePhotoFromTheMapView{
    //UIGraphicsBeginImageContext(self.takeImageContainerView.frame.size);
    UIGraphicsBeginImageContextWithOptions(self.takeImageContainerView.frame.size,NO,0.0);
    [self.takeImageContainerView.layer renderInContext:UIGraphicsGetCurrentContext()]; 
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();     
    return viewImage;
}

- (void)loadViewDataWithIndexOfNotifications:(NSInteger)index{
    
    if (index >= alarmNotifitions.count || index <0)
        index = 0;
    [viewedAlarmNotification release];
    viewedAlarmNotification = (IAAlarmNotification*)[[alarmNotifitions objectAtIndex:index] retain];
    IAAlarm *alarm = viewedAlarmNotification.alarm;
    
    //title 查看 1/3
    self.title = [NSString stringWithFormat:@"%@ %d/%d",kAlertBtnView,(index+1),alarmNotifitions.count];
    
    //SegmentedControl
    UISegmentedControl *sc = (UISegmentedControl*)self.upDownBarItem.customView;
    [sc setEnabled:YES];
    if (alarmNotifitions.count <= 1) {
        [sc setEnabled:NO forSegmentAtIndex:0];
        [sc setEnabled:NO forSegmentAtIndex:1];
        [sc setEnabled:NO];
    }else if (0 == index){
        [sc setEnabled:NO forSegmentAtIndex:0];
        [sc setEnabled:YES forSegmentAtIndex:1];
    }else if ((alarmNotifitions.count -1) == index){
        [sc setEnabled:YES forSegmentAtIndex:0];
        [sc setEnabled:NO forSegmentAtIndex:1];
    }else{
        [sc setEnabled:YES forSegmentAtIndex:0];
        [sc setEnabled:YES forSegmentAtIndex:1];
    }
    
    
    /**地图相关**/
    
    if (circleOverlay) {
        [self.mapView removeOverlay:circleOverlay];
        [circleOverlay release];
    }
    if (pointAnnotation) {
        [self.mapView removeAnnotation:pointAnnotation];
        [pointAnnotation release];
    }
    
    CLLocationCoordinate2D visualCoordinate = alarm.visualCoordinate;
    CLLocationDistance radius = alarm.radius;
    
    //大头针
    NSString *alarmName = alarm.alarmName ? alarm.alarmName : alarm.positionTitle;
    pointAnnotation = [[YCMapPointAnnotation alloc] initWithCoordinate:visualCoordinate title:alarmName subTitle:nil];
    [self.mapView addAnnotation:pointAnnotation];
    
    
    //地图的显示region
    
    //先按老的坐标显示
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(visualCoordinate, radius*2.5, radius*2.5);
    MKCoordinateRegion regionFited =  [self.mapView regionThatFits:region];
    [self.mapView setRegion:regionFited animated:NO];
    
    CGPoint oldPoint = [self.mapView convertCoordinate:visualCoordinate toPointToView:self.mapView];
    CGPoint newPoint = CGPointMake(oldPoint.x, oldPoint.y - 15.0); //下移,避免pin的callout到屏幕外
    CLLocationCoordinate2D newCoord = [self.mapView convertPoint:newPoint toCoordinateFromView:self.mapView];
    MKCoordinateRegion newRegion = MKCoordinateRegionMakeWithDistance(newCoord, radius*2.5, radius*2.5);
    MKCoordinateRegion newRegionFited =  [self.mapView regionThatFits:newRegion];
    [self.mapView setRegion:newRegionFited animated:NO];
    
    
    //圈
    circleOverlay = [[MKCircle circleWithCenterCoordinate:visualCoordinate radius:radius] retain];
    [self.mapView addOverlay:circleOverlay];
    
    //选中大头针
    [self.mapView selectAnnotation:pointAnnotation animated:NO];
    
    /**地图相关**/
    
    //时间间隔
    [self reloadTimeIntervalLabel];
    [timer invalidate];
    [timer release];
    timer = [[NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(timerFireMethod:) userInfo:nil repeats:YES] retain];
    
    //备注
    [self setDistanceLabelWithCurrentLocation:[YCSystemStatus sharedSystemStatus].lastLocation];//距离
    
    CGFloat oldNotesLabelH = self.notesLabel.bounds.size.height;
    self.notesLabel.text = @"";
    self.notesLabel.text = viewedAlarmNotification.alarm.notes;
    [self.notesLabel sizeToFit];
    CGFloat newNotesLabelH = self.notesLabel.bounds.size.height;
    newNotesLabelH = newNotesLabelH < 35 ? 35 : newNotesLabelH;
    
    CGRect boundsOfnotesLabel = self.notesLabel.bounds;
    boundsOfnotesLabel.size.height = newNotesLabelH;
    self.notesLabel.bounds = boundsOfnotesLabel;
    
    CGFloat notesCellH = self.notesCell.bounds.size.height + (newNotesLabelH - oldNotesLabelH);
    //CGRect boundsOfnotesCell = self.notesCell.bounds;
    //boundsOfnotesCell.size.height = notesCellH;
    _notesCellHeight = notesCellH;//notesCell高度调整后，更新

    

    //状态栏
    [[YCAlarmStatusBar shareStatusBar] setHidden:YES animated:YES];
    //查寻文件得到延后通知的数量，免得重启后内存中就没了
    NSInteger nCount = [[IAAlarmNotificationCenter defaultCenter] notificationsForFired:NO alarmId:viewedAlarmNotification.alarm.alarmId].count;
    [[YCAlarmStatusBar shareStatusBar] setAlarmCount:nCount];
    
    //其他数据
    [self.tableView reloadData];
    [self.backgroundTableView reloadData];

}

- (void)reloadTimeIntervalLabel{
    //转换动画 timeIntervalLabel的宽度调整
    //[UIView animateWithDuration:0.25 animations:^{
        
        NSString *s = YCTimeIntervalStringSinceNow(viewedAlarmNotification.createTimeStamp);
        self.timeIntervalLabel.text = s;
        
        [self.timeIntervalLabel sizeToFit];//bounds调整到合适
        self.timeIntervalLabel.bounds = CGRectInset(self.timeIntervalLabel.bounds, -6, -2); //在字的周围留有空白
        //position在父view的左下角向上8像素
        CGSize superViewSize = self.timeIntervalLabel.superview.bounds.size;
        CGPoint thePosition = CGPointMake(superViewSize.width-8, superViewSize.height-8); //timeIntervalLabel调整后的Position
        self.timeIntervalLabel.layer.position = thePosition;
        
    //}];
    
    self.watchImageView.hidden =  (viewedAlarmNotification.soureAlarmNotification) ? NO : YES; //延时提醒，显示时钟
    if (!watchImageView.hidden) {
        CGPoint labelPosition = self.timeIntervalLabel.layer.position; //timeIntervalLabel的Position
        //watchImageView在label x像素
        CGFloat timeIntervalLabelH = self.timeIntervalLabel.bounds.size.height; 
        self.watchImageView.layer.position = CGPointMake(labelPosition.x, labelPosition.y - timeIntervalLabelH - 3); 
    }
}

- (void)makeMoveAlarmAnimationWithStatus:(NSInteger)theStatus{
    
    if (!clockAlarmImageView) {
        clockAlarmImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"YCClockAlarm.png"]];
        clockAlarmImageView.frame = CGRectMake(-100, -100, 32, 32); //放到不可视区域，动画完成后删除
        clockAlarmImageView.contentMode = UIViewContentModeCenter;  //下面的要转换的图片不长宽不一致
    }
    [self.view.window addSubview:clockAlarmImageView];
    
    CGPoint moveEndPoint = [YCAlarmStatusBar shareStatusBar].alarmIconCenter;
    moveEndPoint = [self.view.window convertPoint:moveEndPoint fromWindow:[YCAlarmStatusBar shareStatusBar]];
    CGMutablePathRef thePath = CGPathCreateMutable();
    //屏幕底端
    if (0 == theStatus){ //右边的按钮
        CGPathMoveToPoint(thePath,NULL,100,480); 
        CGPathAddCurveToPoint(thePath,NULL,50.0,320.0, 300,160, moveEndPoint.x,moveEndPoint.y);//优美的弧线
    }else{
        CGPathMoveToPoint(thePath,NULL,200,480);
        CGPathAddCurveToPoint(thePath,NULL,250.0,320.0, 300,160, moveEndPoint.x,moveEndPoint.y);//优美的弧线
    }
    
    [CATransaction begin];
    [CATransaction setAnimationDuration:1.5];
    
    CAKeyframeAnimation * moveAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    moveAnimation.delegate = self;
    moveAnimation.path=thePath;
    moveAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.1f :0.1f :0.1f :1.0f];//前快，后慢;
    [clockAlarmImageView.layer addAnimation:moveAnimation forKey:@"MoveWatch"];
    
    CABasicAnimation *scaleAnimation=[CABasicAnimation animationWithKeyPath: @"transform.scale"];
	scaleAnimation.timingFunction= [CAMediaTimingFunction functionWithControlPoints:0.7f :0.1f :0.8f :1.0f];//前极慢，后极快  
	scaleAnimation.fromValue= [NSNumber numberWithFloat:1.0];
	scaleAnimation.toValue= [NSNumber numberWithFloat:0.32];   
	[clockAlarmImageView.layer addAnimation :scaleAnimation forKey :@"ScaleWatch" ];    
    
    CABasicAnimation *contentsAnimation =[ CABasicAnimation animationWithKeyPath: @"contents" ];
	contentsAnimation.timingFunction= [CAMediaTimingFunction functionWithControlPoints:0.7f :0.2f :0.9f :0.2f];//前极慢，后极快
	contentsAnimation.fromValue = clockAlarmImageView.layer.contents;
    contentsAnimation.toValue=  (id)[UIImage imageNamed:@"YCSilver_Alarm.png"].CGImage;   
	[clockAlarmImageView.layer addAnimation :contentsAnimation forKey :@"contentsAnimation" ];
    [CATransaction commit];
    
    CFRelease(thePath);
    
}

#pragma mark - MapView delegate

- (MKAnnotationView *)mapView:(MKMapView *)mv viewForAnnotation:(id <MKAnnotation>)theAnnotation{
        
    if(![theAnnotation isKindOfClass:[YCMapPointAnnotation class]])
        return nil;


    NSString *annotationIdentifier = @"PinViewAnnotation";
    //MKPinAnnotationView *pinView = (MKPinAnnotationView *) [mapView dequeueReusableAnnotationViewWithIdentifier:annotationIdentifier];
    IAFlagAnnotationView *pinView = (IAFlagAnnotationView *) [mapView dequeueReusableAnnotationViewWithIdentifier:annotationIdentifier];
    
    if (!pinView){

        UIImageView *leftView = [[[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)] autorelease];
        UIImage *ringImage = [UIImage imageNamed:@"YCRing.png"];
        UIImage *ringImageClear = [UIImage imageNamed:@"YCRingClear.png"];
        
        leftView.image = ringImage;
        leftView.animationImages = [NSArray arrayWithObjects:ringImage,ringImageClear, nil];
        leftView.animationDuration = 1.75;
        
        /*
        pinView = [[[MKPinAnnotationView alloc]
                                      initWithAnnotation:theAnnotation
                                         reuseIdentifier:annotationIdentifier] autorelease];
         */
        pinView = [[[IAFlagAnnotationView alloc] initWithAnnotation:theAnnotation reuseIdentifier:annotationIdentifier] autorelease];
        pinView.flagColor = IAFlagAnnotationColorChecker;
        
        //[pinView setPinColor:MKPinAnnotationColorPurple];
        pinView.canShowCallout = YES;
         
        pinView.leftCalloutAccessoryView = leftView;
        
    }else{
        pinView.annotation = theAnnotation;
    }
    
    return pinView;
   
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay{    
	
    if ([overlay isKindOfClass:[MKCircle class]]) {
		MKCircleView *cirecleView = nil;
		cirecleView = [[[MKCircleView alloc] initWithCircle:overlay] autorelease];
		cirecleView.fillColor = [UIColor colorWithRed:160.0/255.0 green:127.0/255.0 blue:255.0/255.0 alpha:0.4]; //淡紫几乎透明
		cirecleView.strokeColor = [UIColor whiteColor];   //白
		cirecleView.lineWidth = 2.0;
		return cirecleView;
	}
	
	return nil;
}

- (void)mapView:(MKMapView *)theMapView didAddAnnotationViews:(NSArray *)views{
	for (id oneObj in views) {
		id anAnnotation = ((MKAnnotationView*)oneObj).annotation;
		if ([anAnnotation isKindOfClass:[YCMapPointAnnotation class]]) {
            [self.mapView selectAnnotation:anAnnotation animated:NO];//选中
            [(UIImageView*)((MKAnnotationView*)oneObj).leftCalloutAccessoryView performSelector:@selector(startAnimating) withObject:nil afterDelay:0.5]; //x秒后开始闪烁
            
		}
	}
}

- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO; 
}

- (void)mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

#pragma mark - Table view data source & delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)theTableView {
    if (theTableView == self.backgroundTableView) {
        return 1;
    }
    
    return 3;
}

- (NSInteger)tableView:(UITableView *)theTableView numberOfRowsInSection:(NSInteger)section {
	if (theTableView == self.backgroundTableView) {
        return 1;
    }
    
	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)theTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (theTableView == self.backgroundTableView) {
        return self.backgroundTableViewCell;
    }
    
	UITableViewCell *cell  = nil;
    switch (indexPath.section) {
        case 0:
            cell = self.mapViewCell;
            break;
        case 1:
            cell = self.notesCell;
            break;
        case 2:
            cell = self.buttonCell;
            break;
        default:
            break;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)theTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if (theTableView == self.backgroundTableView) {
        CGFloat contentViewHeight = self.tableView.contentSize.height;
        contentViewHeight = (contentViewHeight > 416.0) ? contentViewHeight : 416.0;
        return contentViewHeight;
    }
    
    switch (indexPath.section) {
        case 0:
            return _mapViewCellHeight;
            break;
        case 1:
            return _notesCellHeight ;
            break;
        case 2:
            return _buttonCellHeight;
            break;
        default:
            return 0.0;
            break;
    }
    
}

- (CGFloat)tableView:(UITableView *)theTableView heightForHeaderInSection:(NSInteger)section{
    if (theTableView == self.backgroundTableView) {
        return 0.0;
    }
    
    //长屏幕
    if ([IAParam sharedParam].deviceType == YCDeviceTypeIPhone4Inch) {
        
        switch (section) {
            case 0:
                return 10.0;
                break;
            case 1:
                return 18.0;
                break;
            case 2:
                return 18.0;
                break;
            default:
                return 10.0;
                break;
        }
        
    }else{
        
        switch (section) {
            case 0:
                return 10.0;
                break;
            case 1:
                return 13.0;
                break;
            case 2:
                return 13.0;
                break;
            default:
                return 10.0;
                break;
        }
        
    }
    
}

- (CGFloat)tableView:(UITableView *)theTableView heightForFooterInSection:(NSInteger)section{
    if (theTableView == self.backgroundTableView) {
        return 0.0;
    }
    
    switch (section) {
        case 0:
        case 1:
            return 0.0;
            break;
        case 2:
            return 10.0;
            break;
        default:
            return 10.0;
            break;
    }

}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    return @" "; //4.2前没这个不行
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
    return @" "; //4.2前没这个不行
}

#pragma mark - UIScrollViewDelegate
/*
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset{
    if (scrollView == self.backgroundTableView) {
        //NSLog(@"targetContentOffset = %@",NSStringFromCGPoint(*targetContentOffset));
        //NSLog(@"velocity = %@",NSStringFromCGPoint(velocity));
        //NSLog(@"self.backgroundTableViewCell.frame = %@",NSStringFromCGRect(self.backgroundTableViewCell.frame));
        UISegmentedControl *sc = (UISegmentedControl*)self.upDownBarItem.customView;
        sc.selectedSegmentIndex = 0;
        [self segmentAction:sc];
        
    }
}
 */

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = self.doneButtonItem;
    self.navigationItem.rightBarButtonItem = self.upDownBarItem;
    
    //设置cell拖拽后显示背景
    self.backgroundTableView.backgroundView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];//[UIColor tableViewBackgroundViewBackgroundColor];
    self.backgroundTableView.leftShadowView.hidden = YES;
    self.backgroundTableView.rightShadowView.hidden = YES;
    self.backgroundTableView.topShadowView.bounds = (CGRect){{0,0},{320,20}};
    self.backgroundTableView.bottomShadowView.bounds = (CGRect){{0,0},{320,20}};
    
    [self performBlock:^{
        self.backgroundTableViewCell.layer.shadowOpacity = 0.4;
        self.backgroundTableViewCell.layer.shadowOffset = CGSizeMake(0, -4.0);
        self.backgroundTableViewCell.layer.shadowColor = [UIColor blackColor].CGColor;
        self.backgroundTableViewCell.layer.shadowRadius = 7.0;
        
    } afterDelay:0.5];
    [self.backgroundTableViewCell addSubview:self.tableView];
    
    //5.0以下 cell背景设成透明后，显示背景后面竟然是黑的。没搞懂，到底是谁的颜色。所以只好给加个背景view了。
    UIImageView *backgroundView = [[[UIImageView alloc] initWithFrame:self.tableView.bounds] autorelease];
    backgroundView.image = [UIImage imageNamed:@"YCGroupTableViewBackground1.png"];
    self.tableView.backgroundView = backgroundView;
    
    
    //地图的圆角和边框，下白边框是containerView多1个像素
    self.maskImageView.layer.cornerRadius = 4;
    self.maskImageView.layer.masksToBounds = YES;
    
    self.mapView.layer.cornerRadius = 4;
    self.mapView.layer.borderColor = [UIColor colorWithIntRed:114 intGreen:121 intBlue:133 intAlpha:255].CGColor;//深色边框，同TextureButton的边框
    self.mapView.layer.borderWidth = 1.0;
    self.containerView.layer.cornerRadius = 4;
    
    
    //把position设置到左下角
    self.timeIntervalLabel.layer.anchorPoint = CGPointMake(1, 1);
    self.watchImageView.layer.anchorPoint = CGPointMake(1, 1);
    
    //备注
    self.notesLabel.textColor = [UIColor tableViewFooterTextColor];
    
    //按钮
    [self.button1 setTitle:kTitleTellFriends forState:UIControlStateNormal];
    [self.button2 setTitle:kTitleAlarmLater forState:UIControlStateNormal];
    
    
    //留着，tableView的委托要用
    _mapViewCellHeight = self.mapViewCell.bounds.size.height;
    _buttonCellHeight = self.buttonCell.bounds.size.height;
    _notesCellHeight = self.notesCell.bounds.size.height;//根据文本多少调整后才知道
     
    //skin Style
    [self setSkinWithType:[IAParam sharedParam].skinType];
    
    [self registerNotifications];
    
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    //加载数据
    [self loadViewDataWithIndexOfNotifications:indexForView]; 
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [timer invalidate]; [timer release]; timer = nil;
    [actionSheet1 dismissWithClickedButtonIndex:actionSheet1.cancelButtonIndex animated:NO];
    [[YCAlarmStatusBar shareStatusBar] setHidden:YES animated:YES];
}

#pragma mark - Notification

- (void)handle_standardLocationDidFinish: (NSNotification*) notification{
    //还没加载
	if (![self isViewLoaded]) return;
    CLLocation *location = [[notification userInfo] objectForKey:IAStandardLocationKey];
    [self setDistanceLabelWithCurrentLocation:location];    
}

- (void)registerNotifications {
	
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	
	//有新的定位数据产生
	[notificationCenter addObserver: self
						   selector: @selector (handle_standardLocationDidFinish:)
							   name: IAStandardLocationDidFinishNotification
							 object: nil];
    
	
}

- (void)unRegisterNotifications{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter removeObserver:self	name: IAStandardLocationDidFinishNotification object: nil];
}

#pragma mark - memory manager

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil alarmNotifitions:(NSArray *)theAlarmNotifitions{
    return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil alarmNotifitions:theAlarmNotifitions indexForView:0];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil alarmNotifitions:(NSArray *)theAlarmNotifitions indexForView:(NSUInteger)theIndexForView{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        alarmNotifitions = [theAlarmNotifitions retain];
        indexForView = theIndexForView;
        engine = [[YCShareAppEngine alloc] initWithSuperViewController:self];
    }
    return self;
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [self unRegisterNotifications];
	self.tableView = nil;
    [doneButtonItem release];doneButtonItem = nil;
    [upDownBarItem release];upDownBarItem = nil;
    [pointAnnotation release];pointAnnotation = nil;
    [circleOverlay release];circleOverlay = nil; 
    
    self.mapViewCell = nil;
    self.containerView = nil;
    self.mapView = nil;
    self.maskImageView = nil;
    self.timeIntervalLabel = nil;
    self.watchImageView = nil;
    
    self.buttonCell = nil;
    self.button1 = nil;
    self.button2 = nil;
    
    self.notesCell = nil;
    
    self.backgroundTableView = nil;
    self.backgroundTableViewCell = nil;
    
    [actionSheet1 release];actionSheet1 = nil;
}

- (void)dealloc {
    [self unRegisterNotifications];
	[tableView release];
    [doneButtonItem release];
    [upDownBarItem release];
    
    [mapViewCell release];
    [takeImageContainerView release];
    [containerView release];
    [mapView release];
    [maskImageView release];
    [timeIntervalLabel release];
    [watchImageView release];
    
    [buttonCell release];
    [button1 release];
    [button2 release];
    
    [notesCell release];
    [notesLabel release];
    
    [backgroundTableView release];
    [backgroundTableViewCell release];
    
    [alarmNotifitions release];
    [viewedAlarmNotification release];
    [pointAnnotation release];
    [circleOverlay release];
    [engine release];
    [actionSheet1 release];
    [clockAlarmImageView release];
    [super dealloc];
}


@end
