//
//  AWSZendeskAuthorizationManager.h
//
// Copyright 2016 Amazon.com, Inc. or its affiliates (Amazon). All Rights Reserved.
//
// Code generated by AWS Mobile Hub. Amazon gives unlimited permission to
// copy, distribute and modify it.
//

#import "AWSAuthorizationManager.h"

@interface AWSZendeskAuthorizationManager : AWSAuthorizationManager

/**
 * Singleton used to authorize user during OAuth2.0
 * @return the singleton
 */
+ (instancetype _Nonnull)sharedInstance;

/**
 * Customize the flow. This relies on the redirectURI being an Universal link.
 *
 * @param clientID The client ID that you signed up for in Zendesk
 * @param redirectURI The redirect URI you provided Zendesk
 *          i.e. https://mysampleapp.amazonaws.com/zendesk/success
 * @param subdomain The subdomain that you signed up for in Zendesk
 */
- (void)configureWithClientID:(NSString * _Nonnull)clientID
                  redirectURI:(NSString * _Nonnull)redirectURI
                    subdomain:(NSString * _Nonnull)subdomain;

/**
 * Zendesk requires that your redirectURI use HTTPS.
 * If you are unable to setup Universal links, then you may consider use a HTTPS endpoint
 * that you control to redirect to a custom app scheme url.
 *
 * Example:
 *   Endpoint HTML content at https://awsmobilehub.s3-us-west-2.amazonaws.com/zendesk
 *      <html>
 *          <script>window.location.href = "com.amazon.mysampleapp://zendesk/oauth2" + window.location.href;</script>
 *      </html>
 *
 *   customSchemeRedirectURI = @"com.amazon.mysampleapp://zendesk/oauth2";
 *   httpsEndpoint = @"ttps://awsmobilehub.s3-us-west-2.amazonaws.com/zendesk";
 *
 * @param customSchemeRedirectURI The redirectURI that has the custom app scheme
 * @param httpsEndpoint The HTTPS endpoint that needs to be registered with Zendesk.
 *                      This endpoint must redirect the page to the customSchemeRedirectURI
 *                      provided here.
 */
- (void)setCustomSchemeRedirectURI:(NSString * _Nonnull)customSchemeRedirectURI
                  httpsEndpoint:(NSString * _Nonnull)httpsEndpoint;

/**
 *
 * Available scopes:
 *  tickets
 *  users
 *  auditlogs (read only)
 *  organizations
 *  hc
 *  apps
 *  triggers
 *  automations
 *  targets
 *
 * @param scope Specify the amount of access the user would like.
 *          i.e. @"read"
 *               @"read tickets:write"
 *               @"tickets:read tickets:write"
 */
- (void)setScope:(NSString * _Nonnull)scope;

/**
 * @return The token type. Available after user authorizes app.
 *         i.e. Bearer
 */
- (NSString * _Nullable)getTokenType;

/**
 * @return The subdomain that you signed up for in Zendesk.
 *         i.e. aws
 */
- (NSString * _Nullable)getSubdomain;

@end
