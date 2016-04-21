//
//  HRJThirdPartyLogin.h
//  text
//
//  Created by SZT-HRJ on 16/4/21.
//  Copyright © 2016年 侯仁杰. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WeiboSDK.h"
#import "WeiboUser.h"
#import "WXApi.h"
#import "WXApiObject.h"
#import <TencentOpenAPI/TencentOAuth.h>

#import "UIToastView.h"

#define SinaWeiBoAppID  @"3058269702" //d9052a0186059007fc5fc83577511e3a
#define WeiXinAppID  @"wxc207cd5f14a013e8"
#define kWXAPP_SECRET @"fcdb8b3c3fd9665ecbcc6b8f7c1f24e7"//微信秘钥
#define TencentAppID @"100869910"

@interface HRJThirdPartyLogin : NSObject<WXApiDelegate, WBHttpRequestDelegate,WeiboSDKDelegate,TencentSessionDelegate,TencentLoginDelegate>

@property (nonatomic, strong) UIViewController *parentController;

+ (GQThirdAuthorizeLoginService *)thirdAuthorizeLoginService;

- (BOOL)handleOpenURL:(NSURL *)url;
- (void)weiboAuthorizeLogin;//微博授权登录
- (void)weixinAuthorizeLogin;//微信授权登录
- (void)tencentAuthorizeLogin;//QQ授权登录


@end
