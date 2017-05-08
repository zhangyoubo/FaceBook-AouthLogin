//
//  ViewController.m
//  fabdemo
//
//  Created by CY on 16/4/19.
//  Copyright © 2016年 chenyuan. All rights reserved.
//

#import "ViewController.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import "SUCache.h"
#import <UIKit/UIKit.h>
#import "UIImageView+CreateByUrl.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIButton *loginButton;
@property (weak, nonatomic) IBOutlet UIButton *loginOut;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;
@property (weak, nonatomic) IBOutlet UIImageView *pictureView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_updateContent:)
                                                 name:FBSDKProfileDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_accessTokenChanged:)
                                                 name:FBSDKAccessTokenDidChangeNotification
                                               object:nil];
    
    SUCacheItem *item = [SUCache itemForSlot:0];
    [self labelDisplayWithProfile:item.profile];
    
}

#pragma mark - login / out
//自定义login button的点击事件
- (IBAction)loginBtnClicked:(id)sender {
    NSInteger slot = 0;
    FBSDKAccessToken *token = [SUCache itemForSlot:slot].token;
    
//    FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];
//    [login logOut];//这个一定要写，不然会出现换一个帐号就无法获取信息的错误
   
    if (token) {
        [self autoLoginWithToken:token];
    }
    else {
        [self newLogin];
    }

}
//自定义loginOut button的点击事件
- (IBAction)loginOutBtnClicked:(id)sender {
    FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];
    [login logOut];//这个一定要写，不然会出现换一个帐号就无法获取信息的错误
    
    NSInteger slot = 0;
    [SUCache deleteItemInSlot:slot];
    
    self.infoLabel.text = nil;
    self.pictureView.image = nil;
}

#pragma mark - function
- (void)autoLoginWithToken:(FBSDKAccessToken *)token {
    [FBSDKAccessToken setCurrentAccessToken:token];
    FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:token.userID parameters:@{@"fields": @"id,name,email"}];
    [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
        //token过期，删除存储的token和profile
        if (error) {
            NSLog(@"The user token is no longer valid.");
            NSInteger slot = 0;
            [SUCache deleteItemInSlot:slot];
            [FBSDKAccessToken setCurrentAccessToken:nil];
            [FBSDKProfile setCurrentProfile:nil];
        }
        //做登录完成的操作
        else {
            // Handle the result
            NSLog(@"id = %@,name = %@,email = %@",result[@"id"],result[@"name"],result[@"email"]);
        }
    }];
}
/**
 *  logInWithPublishPermissions : 发布(帖子)权限 logInWithReadPermissions : 读取信息权限
 */
- (void)newLogin {
    FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];
    [login logOut];//这个一定要写，不然会出现换一个帐号就无法获取信息的错误
    [login logInWithReadPermissions: @[@"public_profile",@"email",@"user_about_me",@"user_likes",@"user_birthday"] fromViewController:self
     handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
         NSLog(@"facebook login result.grantedPermissions = %@,error = %@",result.grantedPermissions,error);
         if (error) {
             NSLog(@"Process error");
         } else if (result.isCancelled) {
             NSLog(@"Cancelled");
         } else {
             NSLog(@"Logged in");
             
             FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc]
                                           initWithGraphPath:result.token.userID
                                           parameters:@{@"fields": @"id,name,email,likes,birthday"}
                                           HTTPMethod:@"GET"];
             [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result,NSError *error) {
                 
                 // Handle the result
                 NSLog(@"result = %@",result);
                 NSLog(@"id = %@,name = %@,birthday = %@,likes = %@,email = %@",result[@"id"],result[@"name"],result[@"birthday"],result[@"likes"],result[@"email"]);

             }];
         }
     }];
}

#pragma mark - Notification

- (void)_updateContent:(NSNotification *)notification {
    FBSDKProfile *profile = notification.userInfo[FBSDKProfileChangeNewKey];
    [self labelDisplayWithProfile:profile];
}

- (void)_accessTokenChanged:(NSNotification *)notification
{
    FBSDKAccessToken *token = notification.userInfo[FBSDKAccessTokenChangeNewKey];
    if (!token) {
        [FBSDKAccessToken setCurrentAccessToken:nil];
        [FBSDKProfile setCurrentProfile:nil];
    } else {
        NSInteger slot = 0;
         /** zyb  */
//        SUCacheItem *cacheItem = [SUCache itemForSlot:slot];
//        if (token&&![cacheItem.token isEqualToAccessToken:token]) {
//            cacheItem.token = token;
//            [SUCache saveItem:cacheItem slot:slot];
//        }
        
        SUCacheItem *item = [SUCache itemForSlot:slot] ?: [[SUCacheItem alloc] init];
        if (![item.token isEqualToAccessToken:token]) {
            item.token = token;
            [SUCache saveItem:item slot:slot];
        }
    }
}

#pragma mark - other

//这是facebook sdk中自带的button样式
- (void)addFacebookButton {
    FBSDKLoginButton *loginButton = [[FBSDKLoginButton alloc] init];
    loginButton.center = self.view.center;
    [self.view addSubview:loginButton];
}

- (void)labelDisplayWithProfile:(FBSDKProfile *)profile{
    NSInteger slot = 0;
    if (profile) {
        SUCacheItem *cacheItem = [SUCache itemForSlot:slot];
        cacheItem.profile = profile;
        [SUCache saveItem:cacheItem slot:slot];
        
        self.infoLabel.text = [NSString stringWithFormat:@"name = %@,userID = %@",profile.name,profile.userID];
        NSURL *imgURL = [profile imageURLForPictureMode:FBSDKProfilePictureModeNormal size:self.pictureView.frame.size];
        [self.pictureView setImageByUrl:[NSString stringWithFormat:@"%@",imgURL]];
        
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
