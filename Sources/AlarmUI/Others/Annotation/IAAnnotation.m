//
//  IAAnnotation.m
//  iArrived
//
//  Created by li shiyong on 10-10-28.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "IARegion.h"
#import "IARegionsCenter.h"
#import "YCLib.h"
#import "YCSystemStatus.h"
#import "IANotifications.h"
#import "LocalizedString.h"
#import "IAPerson.h"
#import "IAAlarm.h"
#import "IAAnnotation.h"

@interface IAAnnotation (Private) 

- (void)handleStandardLocationDidFinish: (NSNotification*) notification;
- (void)registerNotifications;
- (void)unRegisterNotifications;
- (void)setAnnotationStatus:(IAAnnotationStatus)annotationStatus location:(CLLocation*)location;

@end

@implementation IAAnnotation
@synthesize identifier = _identifier, annotationStatus = _annotationStatus, alarm = _alarm;


- (void)handleStandardLocationDidFinish: (NSNotification*) notification{
    CLLocation *curLocation = [[notification userInfo] objectForKey:IAStandardLocationKey];
    //设置与当前位置的subtitle的字符串
    if (_subTitleIsDistanceString) {
        [self setAnnotationStatus:_annotationStatus location:curLocation];
    }
}

- (void)handleApplicationDidBecomeActive: (NSNotification*) notification{
    [self setAnnotationStatus:_annotationStatus];
}

- (void)handleRegionsDidChange:(NSNotification*)notification {
    [self setAnnotationStatus:_annotationStatus];
}

- (void)handleRegionTypeDidChange:(NSNotification*)notification{	
    [self setAnnotationStatus:_annotationStatus];
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
    
    //区域列表发生了改变
    [notificationCenter addObserver: self
						   selector: @selector (handleRegionsDidChange:)
							   name: IARegionsDidChangeNotification
							 object: nil];
    //区域的类型发生了改变
    [notificationCenter addObserver: self
						   selector: @selector (handleRegionTypeDidChange:)
							   name: IARegionTypeDidChangeNotification
							 object: nil];
	
}

- (void)unRegisterNotifications{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self	name: IAStandardLocationDidFinishNotification object: nil];
    [notificationCenter removeObserver:self	name: UIApplicationDidBecomeActiveNotification object: nil];
    [notificationCenter removeObserver:self	name: IARegionsDidChangeNotification object: nil];
    [notificationCenter removeObserver:self	name: IARegionTypeDidChangeNotification object: nil];
}


- (id)initWithAlarm:(IAAlarm*)anAlarm{
    self = [super initWithCoordinate:anAlarm.visualCoordinate title:nil
                            subTitle:nil addressDictionary:nil];
    
    if (self) {
        _alarm = [anAlarm retain];
        _realCoordinate = _alarm.realCoordinate;
        
        self.annotationStatus = _alarm.enabled ? IAAnnotationStatusNormal:IAAnnotationStatusDisabledNormal;
        [self registerNotifications];
    }
    return self;
}

- (NSString *)identifier{
    return _alarm.alarmId;
}

- (void)setAnnotationStatus:(IAAnnotationStatus)annotationStatus{
    [self setAnnotationStatus:annotationStatus location:[YCSystemStatus sharedSystemStatus].lastLocation];
}
- (void)setAnnotationStatus:(IAAnnotationStatus)annotationStatus location:(CLLocation*)location{

    NSString *distanceString = [self.alarm distanceLocalStringFromLocation:location];
    
    NSString *iconString = nil;
    if (self.alarm.enabled){
        if (self.alarm.shouldWorking) {
            IARegion *region = [[IARegionsCenter sharedRegionCenter].regions objectForKey:self.alarm.alarmId];
            if (location != nil) {
                if (region.isMonitoring) 
                    iconString = [NSString stringEmojiBell]; //启动了。🔔
                else 
                    iconString = [NSString stringEmojiSleepingSymbol]; //启动了，但是下次进入才会提醒。💤！
            }else{
                 iconString = [NSString stringEmojiWarningSign]; //无定位数据，。警告图标！⚠
            }
            
        }else {
            if (self.alarm.usedAlarmSchedule) 
                iconString = [NSString stringEmojiClockFaceNine]; //等待定时通知🕘
        }
    }
    
    //NSLog(@"annotationStatus = %d",annotationStatus);
    _annotationStatus = annotationStatus;
    switch (_annotationStatus) {
        case IAAnnotationStatusNormal:
        {//正常状态 titel：名称，subtitle：距离
            self.title = self.alarm.title;
            
            NSString *subtitle = nil;
            if (distanceString) {
                subtitle = distanceString;
            }else{
                subtitle = self.alarm.position;
            }
            
            if (iconString != nil) {
                subtitle = (subtitle != nil) ? subtitle : @"";
                subtitle = [NSString stringWithFormat:@"%@%@",iconString,subtitle];
            }
            
            
            if (![self.subtitle isEqualToString:subtitle]){
                self.subtitle = nil;
                self.subtitle = subtitle;
            }
            _subTitleIsDistanceString = YES;
            
            break;
        }
        case IAAnnotationStatusNormal1:
        {//正常状态1 titel：名称，subtitle：长地址(如果名称是地址，那么subtitle显示距离)
            //如果不等待，calloutView有裂缝
            [self performSelector:@selector(setTitle:) withObject:self.alarm.title afterDelay:0.35];
            
            NSString *postion = self.alarm.position;
            if (iconString != nil) {
                postion = (postion != nil) ? postion : @"";
                postion = [NSString stringWithFormat:@"%@%@",iconString,postion];
            }
            if (postion) {
                if (![self.subtitle isEqualToString:postion]){
                    self.subtitle = nil;
                    self.subtitle = postion;
                }
            }else{
                self.subtitle = nil;
            }
            _subTitleIsDistanceString = NO;
            
            break;
        }
        case IAAnnotationStatusDisabledNormal:
        {//禁用状态 titel：名称，subtitle：nil
            self.title = self.alarm.title;
            self.subtitle = nil;            
            _subTitleIsDistanceString = NO;
            break;
        }
        case IAAnnotationStatusDisabledNormal1:
        {//禁用状态1 titel：名称，subtitle：长地址
            self.title = self.alarm.title;
            self.subtitle = self.alarm.position;
            _subTitleIsDistanceString = NO;
            break;
        }
        case IAAnnotationStatusEditingBegin:
        {//编辑开始状态 titel："拖动改变目的地"，subtitle：名称
            self.title = KLabelMapNewAnnotationTitle;
            self.subtitle = self.alarm.title;
            
            _subTitleIsDistanceString = NO;
            break;
        }
        case IAAnnotationStatusReversing:
        {//反转地址中 titel："..."(或名称)，subtitle：名称(或"...")
            if (self.alarm.name) {//有名字，在拖拽过程中不显示地点的更换
                self.title = self.alarm.name;
                self.subtitle = @" . . .        ";
            }else{
                self.title = @" . . .          ";
                self.subtitle = nil;
            }
            
            _subTitleIsDistanceString = NO;
            break;
        }
        case IAAnnotationStatusReversFinished:
        {//反转完成 titel：名称，subtitle：长地址(如果名称是地址，那么subtitle显示距离)
            //如果不等待，calloutView有裂缝
            //[self performSelector:@selector(setTitle:) withObject:self.alarm.title afterDelay:0.35];            
            NSString *title = self.alarm.title;
            NSString *subtitle = nil;
            
            if (self.alarm.name) {
                subtitle = self.alarm.position;
                _subTitleIsDistanceString = NO;
            }else{
                
                subtitle = distanceString;
                _subTitleIsDistanceString = YES;
                
            }
            
            if (![self.title isEqualToString:title]) 
                self.title = title;
            if (![self.subtitle isEqualToString:subtitle]) 
                self.subtitle = subtitle;
             
            break;
        }
        default:
            break;
    }
}

- (void)dealloc {
    //NSLog(@"IAAnnotation dealloc");
    [self unRegisterNotifications];
    [_identifier release];
    [_alarm release];
	[super dealloc];
}

@end
