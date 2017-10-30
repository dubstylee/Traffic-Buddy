//
//  ParticleCloud.h
//  Particle iOS Cloud SDK
//
//  Created by Ido Kleinman
//  Copyright 2015 Particle
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import <Foundation/Foundation.h>
#import "ParticleDevice.h"
#import "ParticleEvent.h"


NS_ASSUME_NONNULL_BEGIN

extern NSString *const kParticleAPIBaseURL;

@interface ParticleCloud : NSObject

/**
 *  Currently logged in user name, nil if no valid session
 */
@property (nonatomic, strong, nullable, readonly) NSString* loggedInUsername;
/**
 *  Currently logged in via app - deprecated
 */
@property (nonatomic, readonly) BOOL isLoggedIn __deprecated_msg("Use isAuthenticated instead");
/**
 *  Currently authenticated (does a access token exist?)
 */
@property (nonatomic, readonly) BOOL isAuthenticated;

/**
 *  Current session access token string, nil if not logged in
 */
@property (nonatomic, strong, nullable, readonly) NSString *accessToken;

/**
 *  oAuthClientId unique for your app, use 'particle' for development or generate your OAuth creds for production apps (https://docs.particle.io/reference/api/#create-an-oauth-client)
 */
@property (nonatomic, nullable, strong) NSString *oAuthClientId;
/**
 *  oAuthClientSecret unique for your app, use 'particle' for development or generate your OAuth creds for production apps (https://docs.particle.io/reference/api/#create-an-oauth-client)
 */
@property (nonatomic, nullable, strong) NSString *oAuthClientSecret;

/**
 *  Singleton instance of ParticleCloud class
 *
 *  @return initialized ParticleCloud singleton
 */
+ (instancetype)sharedInstance;

#pragma mark User onboarding functions
// --------------------------------------------------------------------------------------------------------------------------------------------------------
// User onboarding functions
// --------------------------------------------------------------------------------------------------------------------------------------------------------

/**
 *  Login with existing account credentials to Particle cloud
 *
 *  @param user       User name, must be a valid email address
 *  @param password   Password
 *  @param completion Completion block will be called when login finished, NSError object will be passed in case of an error, nil if success
 */
-(NSURLSessionDataTask *)loginWithUser:(NSString *)user
                              password:(NSString *)password
                            completion:(nullable ParticleCompletionBlock)completion; 

/**
 *  Sign up with new account credentials to Particle cloud
 *
 *  @param user       Required user name, must be a valid email address
 *  @param password   Required password
 *  @param completion Completion block will be called when sign-up finished, NSError object will be passed in case of an error, nil if success
 */
-(NSURLSessionDataTask *)signupWithUser:(NSString *)user
                               password:(NSString *)password
                             completion:(nullable ParticleCompletionBlock)completion __deprecated_msg("use createUser:password:accountInfo:completion instead");;


// NEW
/**
 *  Sign up with new account credentials to Particle cloud
 *
 *  @param username   Required user name, must be a valid email address
 *  @param password   Required password
 *  @param accountInfo Optional dictionary with extended account info fields: firstName, lastName, isBusinessAccount [NSNumber @0=false, @1=true], companyName
 *  @param completion Completion block will be called when sign-up finished, NSError object will be passed in case of an error, nil if success
 */
-(NSURLSessionDataTask *)createUser:(NSString *)username
                           password:(NSString *)password
                        accountInfo:(nullable NSDictionary *)accountInfo
                         completion:(nullable ParticleCompletionBlock)completion;



/**
 *  Sign up with new account credentials to Particle cloud
 *
 *  @param username   Required user name, must be a valid email address
 *  @param password   Required password
 *  @param orgSlug    Organization string to include in cloud API endpoint URL
 *  @param completion Completion block will be called when sign-up finished, NSError object will be passed in case of an error, nil if success
 */
-(nullable NSURLSessionDataTask *)signupWithCustomer:(NSString *)username
                                            password:(NSString *)password
                                             orgSlug:(NSString *)orgSlug
                                          completion:(nullable ParticleCompletionBlock)completion __deprecated_msg("use createCustomer:password:productId:completion instead");

// NEW
/**
 *  Sign up with new account credentials to Particle cloud
 *
 *  @param username   Required user name, must be a valid email address
 *  @param password   Required password
 *  @param productId  Required ProductID number should be copied from console for your specific product
 *  @param accountInfo Optional account information metadata that contains fields: first_name, last_name, company_name, business_account [boolean] - currently has no effect for customers
 *  @param completion Completion block will be called when sign-up finished, NSError object will be passed in case of an error, nil if success
 */
-(nullable NSURLSessionDataTask *)createCustomer:(NSString *)username
                                        password:(NSString *)password
                                       productId:(NSUInteger)productId
                                     accountInfo:(nullable NSDictionary *)accountInfo
                                      completion:(nullable ParticleCompletionBlock)completion;


/**
 *  Logout user, remove session data
 */
-(void)logout;

/**
 *  Inject session access token received from a custom backend service in case Two-legged auth is being used. This session expected not to expire, or at least SDK won't know about its expiration date.
 *
 *  @param accessToken      Particle Access token string
 *  @return YES if session injected successfully
 */
-(BOOL)injectSessionAccessToken:(NSString * _Nonnull)accessToken;
/**
 *  Inject session access token received from a custom backend service in case Two-legged auth is being used. Session will expire at expiry date.
 *
 *  @param accessToken      Particle Access token string
 *  @param expiryDate       Date/time in which session expire and no longer be active - you'll have to inject a new session token at that point.
 *  @return YES if session injected successfully
 */
-(BOOL)injectSessionAccessToken:(NSString *)accessToken withExpiryDate:(NSDate *)expiryDate;
/**
 *  Inject session access token received from a custom backend service in case Two-legged auth is being used. Session will expire at expiry date, and SDK will try to renew it using supplied refreshToken.
 *
 *  @param accessToken      Particle Access token string
 *  @param expiryDate       Date/time in which session expire
 *  @param refreshToken     Refresh token will be used automatically to hit Particle cloud to create a new active session access token.
 *  @return YES if session injected successfully
 */
-(BOOL)injectSessionAccessToken:(NSString *)accessToken withExpiryDate:(NSDate *)expiryDate andRefreshToken:(NSString *)refreshToken;

/**
 *  Request password reset for customer (organization mode) DEPRECATED
 *  command generates confirmation token and sends email to customer using org SMTP settings
 *
 *  @param email      user email
 *  @param completion Completion block with NSError object if failure, nil if success
 */

-(NSURLSessionDataTask *)requestPasswordResetForCustomer:(NSString *)orgSlug
                                                   email:(NSString *)email
                                              completion:(nullable ParticleCompletionBlock)completion __deprecated_msg("use requestPasswordResetForCustomer:email:productId:completion instead");

/**
 *  Request password reset for customer (in product mode)
 *  command generates confirmation token and sends email to customer using org SMTP settings
 *
 *  @param email      user email
 *  @param productId  Product ID number
 *  @param completion Completion block with NSError object if failure, nil if success
 */
-(NSURLSessionDataTask *)requestPasswordResetForCustomer:(NSString *)email
                                               productId:(NSUInteger)productId
                                              completion:(nullable ParticleCompletionBlock)completion;

/**
*  Request password reset for user
*  command generates confirmation token and sends email to customer using org SMTP settings
*
*  @param email      user email
*  @param completion Completion block with NSError object if failure, nil if success
*/
-(NSURLSessionDataTask *)requestPasswordResetForUser:(NSString *)email
                                          completion:(nullable ParticleCompletionBlock)completion;

#pragma mark Device management functions
// --------------------------------------------------------------------------------------------------------------------------------------------------------
// Device management functions
// --------------------------------------------------------------------------------------------------------------------------------------------------------

/**
 *  Get an array of instances of all user's claimed devices
 *  offline devices will contain only partial data (no info about functions/variables)
 *
 *  @param completion Completion block with the device instances array in case of success or with NSError object if failure
 *  @return NSURLSessionDataTask task for requested network access
 */
-(NSURLSessionDataTask *)getDevices:(nullable void (^)(NSArray<ParticleDevice *> * _Nullable particleDevices, NSError * _Nullable error))completion;

/**
 *  Get a specific device instance by its deviceID. If the device is offline the instance will contain only partial information the cloud has cached, 
 *  notice that the the request might also take quite some time to complete for offline devices.
 *
 *  @param deviceID   required deviceID
 *  @param completion Completion block with first arguemnt as the device instance in case of success or with second argument NSError object if operation failed
 *  @return NSURLSessionDataTask task for requested network access
 */
-(NSURLSessionDataTask *)getDevice:(NSString *)deviceID
                        completion:(nullable void (^)(ParticleDevice * _Nullable device, NSError * _Nullable error))completion;

// Not available yet
//-(void)publishEvent:(NSString *)eventName data:(NSData *)data;

/**
 *  Claim the specified device to the currently logged in user (without claim code mechanism)
 *
 *  @param deviceID   required deviceID
 *  @param completion Completion block with NSError object if failure, nil if success
 *  @return NSURLSessionDataTask task for requested network access
 */
-(NSURLSessionDataTask *)claimDevice:(NSString *)deviceID
                          completion:(nullable ParticleCompletionBlock)completion;

/**
 *  Get a short-lived claiming token for transmitting to soon-to-be-claimed device in soft AP setup process
 *
 *  @param completion Completion block with claimCode string returned (48 random bytes base64 encoded to 64 ASCII characters), second argument is a list of the devices currently claimed by current session user and third is NSError object for failure, nil if success
 *  @return NSURLSessionDataTask task for requested network access
 */
-(NSURLSessionDataTask *)generateClaimCode:(nullable void(^)(NSString * _Nullable claimCode, NSArray * _Nullable userClaimedDeviceIDs, NSError * _Nullable error))completion;


/**
 *  Get a short-lived claiming token for transmitting to soon-to-be-claimed device in soft AP setup process for specific product and organization (different API endpoints)
 *  @param orgSlug - the organization slug string in URL
 *  @param productSlug - the product slug string in URL
 *  @param activationCode - optional (can be nil) activation code string for products in private-beta mode - see Particle Dashboard for product creators
 *
 *  @param completion Completion block with claimCode string returned (48 random bytes base64 encoded to 64 ASCII characters), second argument is a list of the devices currently claimed by current session user and third is NSError object for failure, nil if success
 *  @return NSURLSessionDataTask task for requested network access
 */
-(NSURLSessionDataTask *)generateClaimCodeForOrganization:(NSString *)orgSlug
                                               andProduct:(NSString *)productSlug
                                       withActivationCode:(nullable NSString *)activationCode
                                               completion:(nullable void(^)(NSString *_Nullable claimCode, NSArray * _Nullable userClaimedDeviceIDs, NSError * _Nullable error))completion __deprecated_msg("use generateClaimCodeForProduct:completion instead");

/**
 *  Get a short-lived claiming token for transmitting to soon-to-be-claimed device in soft AP setup process for specific product and organization (different API endpoints)
 *  @param productId - the product id number
 *
 *  @param completion Completion block with claimCode string returned (48 random bytes base64 encoded to 64 ASCII characters), second argument is a list of the devices currently claimed by current session user and third is NSError object for a failure, nil if success
 *  @return NSURLSessionDataTask task for requested network access
 */
-(NSURLSessionDataTask *)generateClaimCodeForProduct:(NSUInteger)productId
                                          completion:(nullable void(^)(NSString *_Nullable claimCode, NSArray * _Nullable userClaimedDeviceIDs, NSError * _Nullable error))completion;


#pragma mark Events subsystem functions
// --------------------------------------------------------------------------------------------------------------------------------------------------------
// Events subsystem:
// --------------------------------------------------------------------------------------------------------------------------------------------------------

/**
 *  Subscribe to the firehose of public events, plus private events published by devices one owns
 *
 *  @param eventHandler ParticleEventHandler event handler method - receiving NSDictionary argument which contains keys: event (name), data (payload), ttl (time to live), published_at (date/time emitted), coreid (device ID). Second argument is NSError object in case error occured in parsing the event payload.
 *  @param eventNamePrefix    Filter only events that match name eventName, if nil is passed any event will trigger eventHandler
 *  @return eventListenerID function will return an id type object as the eventListener registration unique ID - keep and pass this object to the unsubscribe method in order to remove this event listener
 */
-(nullable id)subscribeToAllEventsWithPrefix:(nullable NSString *)eventNamePrefix handler:(nullable ParticleEventHandler)eventHandler;
/**
 *  Subscribe to all events, public and private, published by devices one owns
 *
 *  @param eventHandler     Event handler function that accepts the event payload dictionary and an NSError object in case of an error
 *  @param eventNamePrefix  Filter only events that match name eventNamePrefix, for exact match pass whole string, if nil/empty string is passed any event will trigger eventHandler
 *  @return eventListenerID function will return an id type object as the eventListener registration unique ID - keep and pass this object to the unsubscribe method in order to remove this event listener
 */
-(nullable id)subscribeToMyDevicesEventsWithPrefix:(nullable NSString *)eventNamePrefix handler:(nullable ParticleEventHandler)eventHandler;



/**
 *  Subscribe to events from one specific device. If the API user has the device claimed, then she will receive all events, public and private, published by that device. 
 *  If the API user does not own the device she will only receive public events.
 *
 *  @param eventNamePrefix  Filter only events that match name eventNamePrefix, for exact match pass whole string, if nil/empty string is passed any event will trigger eventHandler
 *  @param deviceID         Specific device ID. If user has this device claimed the private & public events will be received, otherwise public events only are received.
 *  @param eventHandler     Event handler function that accepts the event payload dictionary and an NSError object in case of an error
 *  @return eventListenerID function will return an id type object as the eventListener registration unique ID - keep and pass this object to the unsubscribe method in order to remove this event listener
 */
-(nullable id)subscribeToDeviceEventsWithPrefix:(nullable NSString *)eventNamePrefix deviceID:(NSString *)deviceID handler:(nullable ParticleEventHandler)eventHandler;


// ADD: subscribe to product events...

/**
 *  Unsubscribe from event/events.
 *
 *  @param eventListenerID The eventListener registration unique ID returned by the subscribe method which you want to cancel
 */
-(void)unsubscribeFromEventWithID:(id)eventListenerID;

/**
 *  Subscribe to events from one specific device. If the API user has the device claimed, then she will receive all events, public and private, published by that device.
 *  If the API user does not own the device she will only receive public events.
 *
 *  @param eventName    Publish event named eventName
 *  @param data         A string representing event data payload, you can serialize any data you need to represent into this string and events listeners will get it
 *  @param isPrivate      A boolean flag determining if this event is private or not (only users's claimed devices will be able to listen to it)
 *  @param ttl          TTL stands for Time To Live. It it the number of seconds that the event data is relevant and meaningful. For example, an outdoor temperature reading with a precision of integer degrees Celsius might have a TTL of somewhere between 600 (10 minutes) and 1800 (30 minutes).
 *                      The geolocation of a large piece of farm equipment that remains stationary most of the time but may be moved to a different field once in a while might have a TTL of 86400 (24 hours). After the TTL has passed, the information can be considered stale or out of date.
 *  @return NSURLSessionDataTask task for requested network access
 */
-(NSURLSessionDataTask *)publishEventWithName:(NSString *)eventName
                                         data:(NSString *)data
                                    isPrivate:(BOOL)isPrivate
                                          ttl:(NSUInteger)ttl
                                   completion:(nullable ParticleCompletionBlock)completion;


@end

NS_ASSUME_NONNULL_END
