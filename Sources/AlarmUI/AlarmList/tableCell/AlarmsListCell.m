//
//  AlarmsListCell.m
//  iAlarm
//
//  Created by li shiyong on 11-1-9.
//  Copyright 2011 __MyCompanyName__. All rights reserved.

#import "IARegion.h"
#import "YCSystemStatus.h"
#import "YCLib.h"
#import "IAPerson.h"
#import "YCPlacemark.h"
#import "CLLocation+YC.h"
#import "UIColor+YC.h"
#import "IARegionsCenter.h"
#import "IANotifications.h"
#import "IAAlarm.h"
#import "LocalizedString.h"
#import "AlarmsListCell.h"

@interface AlarmsListCell (Private) 

- (void)handleStandardLocationDidFinish: (NSNotification*) notification;
- (void)registerNotifications;
- (void)unRegisterNotifications;
- (void)updateCellWithLocation:(CLLocation*)location;

@end

@implementation AlarmsListCell

@synthesize alarm = _alarm;
@synthesize alarmTitleLabel, alarmDetailLabel, isEnabledLabel, flagImageView, topShadowView, bottomShadowView, clockImageView;

- (void)setAlarm:(IAAlarm *)alarm{
    [alarm retain];
    [_alarm release];
    _alarm = alarm;
}

- (void)updateCell{
    //可用状态时候就更新距离
    _subTitleIsDistanceString = self.alarm.enabled;
    [self updateCellWithLocation:[YCSystemStatus sharedSystemStatus].lastLocation];
}

- (void)updateCellWithLocation:(CLLocation*)location{
    
    NSString *theTitle  = self.alarm.alarmName;
    theTitle = theTitle ? theTitle : self.alarm.person.personName;
    theTitle = theTitle ? theTitle : self.alarm.placemark.name;
    theTitle = [theTitle stringByTrim];
    theTitle = (theTitle.length > 0) ? theTitle : nil;
    theTitle = theTitle ? theTitle : self.alarm.person.organization;
    theTitle = theTitle ? theTitle : self.alarm.positionTitle; 
    theTitle = theTitle ? theTitle : KDefaultAlarmName;
    
    
    NSString *distanceString = [self.alarm distanceLocalStringFromLocation:location];
    NSString *theDetail = nil;
    if (self.alarm.enabled &&  distanceString) 
        theDetail = distanceString;
    else 
        theDetail = self.alarm.position;
    
    if (self.alarm.enabled){
        NSString *iconString = nil;
        if (self.alarm.shouldWorking ) {
            IARegion *region = [[IARegionsCenter sharedRegionCenter].regions objectForKey:self.alarm.alarmId];
            if (location != nil) {
                if (region.isMonitoring) 
                    iconString = [NSString stringEmojiBell]; //启动了。🔔
                else 
                    iconString = [NSString stringEmojiSleepingSymbol]; //启动了，但是下次进入才会提醒。💤！
            }else{
                iconString = [NSString stringEmojiWarningSign]; //无定位数据，警告图标！⚠
            }
        }else {
            if (self.alarm.usedAlarmSchedule) 
                iconString = [NSString stringEmojiClockFaceNine]; //等待定时通知🕘
        }
        if (iconString) 
            theDetail = [NSString stringWithFormat:@"%@ %@",iconString,theDetail];
    }
    
    
    alarmTitleLabel.text = theTitle;
    alarmDetailLabel.text = theDetail;
    NSString *imageName = self.alarm.enabled ? self.alarm.alarmRadiusType.alarmRadiusTypeImageName : @"IAFlagGray.png";
    
    self.flagImageView.image = [UIImage imageNamed:imageName];
    
    
    if (self.alarm.enabled) {
        self.isEnabledLabel.text = KDicOn; 
        self.isEnabledLabel.alpha = 1.0;
        self.alarmDetailLabel.alpha = 1.0;
        self.alarmTitleLabel.textColor = [UIColor colorWithWhite:0.03 alpha:0.9];
        self.alarmDetailLabel.textColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        self.isEnabledLabel.textColor = [UIColor colorWithWhite:0.03 alpha:0.85];
    }else{
        self.isEnabledLabel.text = KDicOff; //文字:关闭
        self.alarmTitleLabel.textColor = [UIColor darkGrayColor];
        self.alarmDetailLabel.textColor = [UIColor darkGrayColor];
        //self.isEnabledLabel.textColor = [UIColor grayColor];
        self.isEnabledLabel.textColor = [UIColor darkGrayColor];
    }

}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated{
    [super setEditing:editing animated:animated];
    [UIView animateWithDuration:0.25 animations:^{ self.isEnabledLabel.alpha = editing ? 0.0 : 1.0;}];
}

#pragma mark - Init and Memery

- (id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self registerNotifications];
    }
    return self;
}

+ (id)viewWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle{
    nibName = nibName ? nibName : @"AlarmsListCell";
    nibBundle = nibBundle ? nibBundle : [NSBundle mainBundle];
    
    NSArray *nib = [nibBundle loadNibNamed:nibName owner:self options:nil];
	AlarmsListCell *cell =nil;
	for (id oneObject in nib){
		if ([oneObject isKindOfClass:[AlarmsListCell class]]){
			cell = (AlarmsListCell *)oneObject;
		}
	}
	
	NSString *backgroundImagePath = [nibBundle pathForResource:@"iAlarmList_row" ofType:@"png"];
    UIImage *backgroundImage = [[UIImage imageWithContentsOfFile:backgroundImagePath] stretchableImageWithLeftCapWidth:0.0 topCapHeight:1.0];
	cell.backgroundView = [[[UIImageView alloc] initWithImage:backgroundImage] autorelease];
	cell.backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	cell.backgroundView.frame = cell.bounds;
    
	return cell; 
}

- (void)dealloc {
    NSLog(@"AlarmsListCell dealloc");
    [self unRegisterNotifications];    
	[_alarm release];
    [alarmTitleLabel release];
    [alarmDetailLabel release];
    [isEnabledLabel release];
    [flagImageView release];
    [topShadowView release];
	[bottomShadowView release];
    [super dealloc];
}

- (void)handleStandardLocationDidFinish: (NSNotification*) notification{
    
    if (self.window == nil) { //cell 没有在显示
        self.alarm = nil;
        return;
    }
    
    CLLocation *curLocation = [[notification userInfo] objectForKey:IAStandardLocationKey];
    //设置与当前位置的subtitle的字符串
    if (_subTitleIsDistanceString) {
        [UIView transitionWithView:self.alarmDetailLabel duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^()
         {
             [self updateCellWithLocation:curLocation];
         } completion:NULL];         
    }
    
}

- (void)handleApplicationDidBecomeActive: (NSNotification*) notification{
    
    if (self.window == nil) { //cell 没有在显示
        self.alarm = nil;
        return;
    }
    
    //进入前台，模拟发送定位数据。防止真正的定位数据迟迟不发。
    NSDictionary *userInfo = nil;
    CLLocation *curLocation = [YCSystemStatus sharedSystemStatus].lastLocation;
    if (curLocation)
        userInfo = [NSDictionary dictionaryWithObject:curLocation forKey:IAStandardLocationKey];
    
    NSNotification *aNotification = [NSNotification notificationWithName:IAStandardLocationDidFinishNotification 
                                                                  object:self
                                                                userInfo:userInfo];
    [self handleStandardLocationDidFinish:aNotification];
    //[self performSelector:@selector(handleStandardLocationDidFinish:) withObject:aNotification afterDelay:0.0];
}

- (void)registerNotifications {
	
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver: self
						   selector: @selector (handleStandardLocationDidFinish:)
							   name: IAStandardLocationDidFinishNotification
							 object: nil];
    [notificationCenter addObserver: self
						   selector: @selector (handleApplicationDidBecomeActive:)
							   name: UIApplicationDidBecomeActiveNotification
							 object: nil];
	
}

- (void)unRegisterNotifications{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self	name: IAStandardLocationDidFinishNotification object: nil];
    [notificationCenter removeObserver:self	name: UIApplicationDidBecomeActiveNotification object: nil];
}



@end
