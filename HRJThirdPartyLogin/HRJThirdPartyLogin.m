//
//  HRJThirdPartyLogin.m
//  text
//
//  Created by SZT-HRJ on 16/4/21.
//  Copyright © 2016年 侯仁杰. All rights reserved.
//

#import "HRJThirdPartyLogin.h"
#import "HRJThirdUserInfo.h"


@interface HRJThirdPartyLogin ()
{
    TencentOAuth *tencentOAuth;
    NSURL *weiboURL;
}

@property (nonatomic, strong) WBAuthorizeResponse *response;
@property (nonatomic, strong) WeixinUser *weixinUser;
@property (nonatomic, strong) QQUser *qqUser;
@property (nonatomic, strong) WeiboUser *weiBoUser;

@property (nonatomic, strong) NSString *openid;//三方唯一标识
@property (nonatomic, strong) NSString *access_token;//获取到的三方凭证
@property (nonatomic, strong, readwrite) NSString *refresh_token;//刷新access_token
@property (nonatomic, strong) NSString *thirdType;//第三方类型

@end

@implementation HRJThirdPartyLogin

+ (HRJThirdPartyLogin *)thirdPartyLogin {
    static HRJThirdPartyLogin *thirdPartyLogin = nil;
    if (thirdPartyLogin == nil) {
        thirdPartyLogin = [[HRJThirdPartyLogin alloc] init];
        [thirdPartyLogin registerAndAuthorizeMyApp];
    }
    return thirdPartyLogin;
}

//三方注册
- (void)registerAndAuthorizeMyApp {
    //    [WeiboSDK registerApp:SinaWeiBoAppID];
    [WXApi registerApp:WeiXinAppID];
    tencentOAuth = [[TencentOAuth alloc] initWithAppId:TencentAppID andDelegate:self];
    tencentOAuth.redirectURI = @"www.qq.com";
}

- (BOOL)handleOpenURL:(NSURL *)url {
    //根据不同的URL的前缀 交由各个SDK处理
    NSString *handle = [url absoluteString];
    if ([handle hasPrefix:@"wb3058"]) {
        weiboURL = url;
        return [WeiboSDK handleOpenURL:url delegate:self];
    }else if([handle hasPrefix:@"wx"]) {
        return [WXApi handleOpenURL:url delegate:self];
    }else if ([handle hasPrefix:@"tencent100"]){
        return [TencentOAuth HandleOpenURL:url];
    }else {
        return YES;
    }
}
#pragma mark-微博授权登陆
- (void)weiboAuthorizeLogin {
    WBAuthorizeRequest *request = [WBAuthorizeRequest request];
    request.redirectURI = @"http://client.3g.fang.com/";
    request.scope = @"all";
    request.userInfo = @{@"SSO_From": @"GQHotViewController",
                         @"Other_Info_1": [NSNumber numberWithInt:123],
                         @"Other_Info_2": @[@"obj1", @"obj2"],
                         @"Other_Info_3": @{@"key1": @"obj1", @"key2": @"obj2"}};
    [WeiboSDK sendRequest:request];
}
#pragma mark -- WeiboSDKDelegate
- (void)didReceiveWeiboResponse:(WBBaseResponse *)response {
    
    if ([response isKindOfClass:[WBAuthorizeResponse class]]) {
        self.response = (WBAuthorizeResponse *)response;
        [self requestUserInfo];
    }else {
        [UIToastView showToastViewWithContent:@"授权失败,请重新尝试" andRect:KTOASTRECT andTime:2.0 andObject:self.parentController];
    }
}
- (void)requestUserInfo {
    if (self.response != nil && self.response.userID.length > 0 && self.response.accessToken.length > 0) {
        NSString *userID = self.response.userID;
        NSString *accessToken = self.response.accessToken;
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:userID forKey:@"uid"];
        
        [WBHttpRequest requestWithAccessToken:accessToken url:@"https://api.weibo.com/2/users/show.json" httpMethod:@"GET" params:params delegate:self withTag:nil];
    }
}
- (void)didReceiveWeiboRequest:(WBBaseRequest *)request {
    
}
- (void)request:(WBHttpRequest *)request didFinishLoadingWithDataResult:(NSData *)data {
    NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    WeiboUser* userInfo = [[WeiboUser alloc] initWithDictionary:dict];
    self.weiBoUser = userInfo;
    self.openid = self.weiBoUser.userID;
    self.access_token = self.response.accessToken;
    [UIToastView showToastViewWithContent:@"登陆成功" andRect:KTOASTRECT andTime:5.0f andObject:self.parentController];
}
#pragma mark-微信授权登陆
- (void)weixinAuthorizeLogin {
    SendAuthReq *req = [[SendAuthReq alloc] init];
    req.scope = @"snsapi_userinfo,snsapi_base";
    req.state = @"0744";
    [WXApi sendAuthReq:req viewController:self.parentController delegate:self];
}
#pragma mark -- WXApiDelegate
- (void)onResp:(BaseResp *)resp {
    SendAuthResp *aresp = (SendAuthResp *)resp;
    if (aresp.errCode == 0) {
        [self getToken:aresp];
    }else {
        [UIToastView showToastViewWithContent:@"授权失败,请重新尝试" andRect:KTOASTRECT andTime:2.0 andObject:self.parentController];
    }
}

- (void)getToken:(SendAuthResp *)aresp {
    NSString *url = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/oauth2/access_token?appid=%@&secret=%@&code=%@&grant_type=authorization_code",WeiXinAppID,kWXAPP_SECRET,aresp.code];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *zoneUrl = [NSURL URLWithString:url];
        NSString *zoneStr = [NSString stringWithContentsOfURL:zoneUrl encoding:NSUTF8StringEncoding error:nil];
        NSData *data = [zoneStr dataUsingEncoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (data) {
                NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                self.access_token = dic[@"access_token"];
                self.openid = dic[@"openid"];
                self.refresh_token = dic[@"refresh_token"];
                [self getUserInfo];
            }
        });
    });
}
- (void)getUserInfo {
    NSString *url = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/userinfo?access_token=%@&openid=%@",self.access_token,self.openid];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *zoneUrl = [NSURL URLWithString:url];
        NSString *zoneStr = [NSString stringWithContentsOfURL:zoneUrl encoding:NSUTF8StringEncoding error:nil];
        NSData *data = [zoneStr dataUsingEncoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (data) {
                NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                WeixinUser *weixinUser = [[WeixinUser alloc] init];
                weixinUser.city = dic[@"city"];
                weixinUser.country = dic[@"country"];
                weixinUser.headimgurl = dic[@"headimgurl"];
                weixinUser.language = dic[@"language"];
                weixinUser.name = dic[@"nickname"];
                weixinUser.openid = dic[@"openid"];
                weixinUser.privilege = dic[@"privilege"];
                weixinUser.province = dic[@"province"];
                weixinUser.sex = [[NSNumber numberWithInt:[dic[@"sex"] intValue]] intValue];;
                weixinUser.unionid = dic[@"unionid"];
                weixinUser.refresh_token = self.refresh_token;
                weixinUser.access_token = self.access_token;
                self.weixinUser = weixinUser;
                self.openid = weixinUser.openid;
                [UIToastView showToastViewWithContent:@"登陆成功" andRect:KTOASTRECT andTime:5.0f andObject:self.parentController];
            }
        });
    });
}
#pragma mark-QQ授权登陆
- (void)tencentAuthorizeLogin {
    NSArray*permissions =[[NSArray alloc]initWithObjects:@"get_user_info", @"get_simple_userinfo",@"add_t",nil];
    [tencentOAuth authorize:permissions inSafari:NO];
}
- (void)tencentDidLogin {
    if (tencentOAuth.accessToken && 0!= [tencentOAuth.accessToken length])
    {
        //  记录登录用户的OpenID、Token以及过期时间
        [tencentOAuth getUserInfo];
    }else {
        [UIToastView showToastViewWithContent:@"授权失败,请重新尝试" andRect:KTOASTRECT andTime:2.0f andObject:self.parentController];
    }
}
-(void)tencentDidNotLogin:(BOOL)cancelled
{
    if (cancelled)
    {
        NSLog(@"用户取消登录");
    }else
    {
        NSLog(@"登录失败");
    }
}
//网络错误导致登录失败：
-(void)tencentDidNotNetWork
{
    NSLog(@"无网络连接，请设置网络");
}

-(void)getUserInfoResponse:(APIResponse *)response
{
    NSLog(@"respons:%@",response.jsonResponse);
    QQUser*qqUser = [[QQUser alloc]init];
    qqUser.city = [response.jsonResponse objectForKey:@"city"];
    qqUser.gender = [response.jsonResponse objectForKey:@"gender"];
    qqUser.is_lost = [response.jsonResponse objectForKey:@"is_lost"];
    qqUser.figureurl = [response.jsonResponse objectForKey:@"figureurl_qq_2"];
    qqUser.is_yellow_vip = [response.jsonResponse objectForKey:@"is_yellow_vip"];
    qqUser.is_yellow_year_vip = [response.jsonResponse objectForKey:@"is_yellow_year_vip"];
    qqUser.level = [response.jsonResponse objectForKey:@"level"];
    qqUser.msg = [response.jsonResponse objectForKey:@"msg"];
    qqUser.name = [response.jsonResponse objectForKey:@"nickname"];
    qqUser.province = [response.jsonResponse objectForKey:@"province"];
    qqUser.ret = [response.jsonResponse objectForKey:@"ret"] ;
    qqUser.vip = [response.jsonResponse objectForKey:@"vip"];
    qqUser.yellow_vip_level = [response.jsonResponse objectForKey:@"yellow_vip_level"];
    self.qqUser = qqUser;
    self.openid = tencentOAuth.openId;
    self.access_token = tencentOAuth.accessToken;
    [UIToastView showToastViewWithContent:@"登陆成功" andRect:KTOASTRECT andTime:5.0f andObject:self.parentController];
}



@end
