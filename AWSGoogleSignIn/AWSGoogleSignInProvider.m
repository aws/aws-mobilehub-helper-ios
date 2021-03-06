//
//  AWSGoogleSignInProvider.m
//  AWSGoogleSignIn
//
// Copyright 2017 Amazon.com, Inc. or its affiliates (Amazon). All Rights Reserved.
//
// Code generated by AWS Mobile Hub. Amazon gives unlimited permission to
// copy, distribute and modify it.
//

#import "AWSGoogleSignInProvider.h"
#import <AWSMobileHubHelper/AWSSignInManager.h>

#import <GoogleSignIn/GoogleSignIn.h>

static NSString *const AWSGoogleSignInProviderClientScope = @"profile";
static NSString *const AWSGoogleSignInProviderOIDCScope = @"openid";
static NSTimeInterval const AWSGoogleSignInProviderTokenRefreshBuffer = 10 * 60;
static int64_t const AWSGoogleSignInProviderTokenRefreshTimeout = 60 * NSEC_PER_SEC;

typedef void (^AWSSignInManagerCompletionBlock)(id result, AWSIdentityManagerAuthState authState, NSError *error);

@interface AWSSignInManager()

- (void)completeLogin;

@end

@interface AWSGoogleSignInProvider() <GIDSignInDelegate, GIDSignInUIDelegate>

@property (atomic, strong) AWSTaskCompletionSource *taskCompletionSource;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, strong) AWSExecutor *executor;
@property (nonatomic, strong) UIViewController *signInViewController;
@property (atomic, copy) AWSSignInManagerCompletionBlock completionHandler;
@property (nonatomic, strong) GIDSignIn *signIn;

@end

@implementation AWSGoogleSignInProvider

static NSString *const AWSInfoIdentityManager = @"IdentityManager";
static NSString *const AWSInfoGoogleIdententifier = @"Google";
static NSString *const AWSInfoGoogleClientId = @"ClientId";

+ (instancetype)sharedInstance {
    AWSServiceInfo *serviceInfo = [[AWSInfo defaultAWSInfo] defaultServiceInfo:AWSInfoIdentityManager];
    NSString *googleClientID = [[serviceInfo.infoDictionary objectForKey:AWSInfoGoogleIdententifier] objectForKey:AWSInfoGoogleClientId];

    if (!googleClientID) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Google Client ID is not set correctly in `Info.plist`. You need to set it in `Info.plist` before using."
                                     userInfo:nil];
    }
    
    static AWSGoogleSignInProvider *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[AWSGoogleSignInProvider alloc] initWithGoogleClientID:googleClientID];
    });
    
    return _sharedInstance;
}

- (instancetype)initWithGoogleClientID:(NSString *)googleClientID {
    if (self = [super init]) {
        _semaphore = dispatch_semaphore_create(0);
        
        NSOperationQueue *operationQueue = [NSOperationQueue new];
        _executor = [AWSExecutor executorWithOperationQueue:operationQueue];
        
        _signInViewController = nil;
        
        _signIn = [GIDSignIn sharedInstance];
        _signIn.delegate = self;
        _signIn.uiDelegate = self;
        _signIn.clientID = googleClientID;
        _signIn.scopes = @[AWSGoogleSignInProviderClientScope, AWSGoogleSignInProviderOIDCScope];
    }
    
    return self;
}

#pragma mark - MobileHub user interface

- (void)setScopes:(NSArray *)scopes {
    _signIn.scopes = scopes;
}

- (void)setViewControllerForGoogleSignIn:(UIViewController *)signInViewController {
    self.signInViewController = signInViewController;
}

#pragma mark - AWSIdentityProvider

- (NSString *)identityProviderName {
    return AWSIdentityProviderGoogle;
}

- (AWSTask<NSString *> *)token {
    AWSTask *task = [AWSTask taskWithResult:nil];
    return [task continueWithExecutor:self.executor withBlock:^id _Nullable(AWSTask * _Nonnull task) {
        
        NSString *idToken = _signIn.currentUser.authentication.idToken;
        NSDate *idTokenExpirationDate = _signIn.currentUser.authentication.idTokenExpirationDate;
        
        if (idToken
            // If the cached token expires within 10 min, tries refreshing a token.
            && [idTokenExpirationDate compare:[NSDate dateWithTimeIntervalSinceNow:AWSGoogleSignInProviderTokenRefreshBuffer]] == NSOrderedDescending) {
            return [AWSTask taskWithResult:idToken];
        }
        
        if (self.taskCompletionSource) {
            // Waits up to 60 seconds for the Google SDK to refresh a token.
            if (dispatch_semaphore_wait(self.semaphore, dispatch_time(DISPATCH_TIME_NOW, AWSGoogleSignInProviderTokenRefreshTimeout)) != 0) {
                NSError *error = [NSError errorWithDomain:AWSCognitoCredentialsProviderHelperErrorDomain
                                                     code:AWSCognitoCredentialsProviderHelperErrorTypeTokenRefreshTimeout
                                                 userInfo:nil];
                return [AWSTask taskWithError:error];
            }
        }
        
        idToken = _signIn.currentUser.authentication.idToken;
        idTokenExpirationDate = _signIn.currentUser.authentication.idTokenExpirationDate;
        
        if (idToken
            // If the cached token expires within 10 min, tries refreshing a token.
            && [idTokenExpirationDate compare:[NSDate dateWithTimeIntervalSinceNow:AWSGoogleSignInProviderTokenRefreshBuffer]] == NSOrderedDescending) {
            return [AWSTask taskWithResult:idToken];
        }
        
        // `self.taskCompletionSource` is used to convert the `GIDSignInDelegate` method to a block based method.
        // The `token` string or an error object is returned in a block when the delegate method is called later.
        // See the `GIDSignInDelegate` section of this file.
        self.taskCompletionSource = [AWSTaskCompletionSource taskCompletionSource];
        dispatch_async(dispatch_get_main_queue(), ^{
            [_signIn signInSilently];
        });
        return self.taskCompletionSource.task;
    }];
}

#pragma mark -

- (BOOL)isLoggedIn {
    return [_signIn hasAuthInKeychain];
}

- (void)reloadSession {
    if ([self isLoggedIn]) {
        [_signIn signInSilently];
    }
}

- (void)completeLoginWithToken {
    [[AWSSignInManager sharedInstance] completeLogin];
}

- (void)login:(AWSSignInManagerCompletionBlock)completionHandler {
    self.completionHandler = completionHandler;
    [_signIn signIn];
}


- (void)logout {
    [_signIn disconnect];
}

#pragma mark - GIDSignInDelegate

- (void)signIn:(GIDSignIn *)signIn didSignInForUser:(GIDGoogleUser *)user withError:(NSError *)error {
    
    // Determine Auth State
    AWSIdentityManagerAuthState authState = [AWSSignInManager sharedInstance].authState;
    // `self.taskCompletionSource` is used to return `user.authentication.idToken` or `error` to the `- token` method.
    // See the `AWSIdentityProvider` section of this file.
    if (error) {
        AWSLogError(@"Error: %@", error);
        if (self.taskCompletionSource) {
            self.taskCompletionSource.error = error;
            self.taskCompletionSource = nil;
        }
        if (self.completionHandler) {
            self.completionHandler(nil, authState, error);
        }
    } else {
        if (self.taskCompletionSource) {
            self.taskCompletionSource.result = user.authentication.idToken;
            self.taskCompletionSource = nil;
        }
        [self completeLoginWithToken];
    }
    
    dispatch_semaphore_signal(self.semaphore);
}

- (void)signIn:(GIDSignIn *)signIn didDisconnectWithUser:(GIDGoogleUser *)user withError:(NSError *)error {
    if (error) {
        AWSLogError(@"Error: %@", error);
    }
}

#pragma mark - GIDSignInUIDelegate

- (void)signInWillDispatch:(GIDSignIn *)signIn error:(NSError *)error {
    if (error) {
        AWSLogError(@"Error: %@", error);
    }
}

- (void)signIn:(GIDSignIn *)signIn
presentViewController:(UIViewController *)viewController {
    [self.signInViewController ?: [UIApplication sharedApplication].keyWindow.rootViewController presentViewController:viewController animated:YES completion:nil];
}

- (void)signIn:(GIDSignIn *)signIn
dismissViewController:(UIViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Application delegates

- (BOOL)interceptApplication:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return YES;
}

- (BOOL)interceptApplication:(UIApplication *)application
                     openURL:(NSURL *)url
           sourceApplication:(NSString *)sourceApplication
                  annotation:(id)annotation {
    return [_signIn handleURL:url
            sourceApplication:sourceApplication
                   annotation:annotation];
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary *)options {
    return [_signIn handleURL:url
            sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                   annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    return [_signIn handleURL:url
            sourceApplication:sourceApplication
                   annotation:annotation];
}

@end
