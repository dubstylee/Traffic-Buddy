<p align="center" >
<img src="http://oi60.tinypic.com/116jd51.jpg" alt="Particle" title="Particle">
</p>

# Particle iOS Cloud SDK
[![Build Status](https://api.travis-ci.org/particle/particle-sdk-ios.svg)](https://travis-ci.org/particle/particle-sdk-ios) [![license](https://img.shields.io/hexpm/l/plug.svg)](https://github.com/particle/particle-sdk-ios/blob/master/LICENSE) [![version](https://img.shields.io/badge/cocoapods-0.6.0-green.svg)](https://github.com/particle/particle-sdk-ios/blob/master/CHANGELOG.md)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

### Introduction

Particle iOS Cloud SDK enables iOS apps to interact with Particle-powered connected products via the Particle Cloud. It’s an easy-to-use wrapper for Particle REST API. The Cloud SDK will allow you to:

- Manage & inject user sessions for the Particle Cloud (access tokens, encrypted session management)
- Claim/Unclaim devices for a user account
- Get a list of instances of user's Particle devices
- Read variables from devices
- Invoke functions on devices
- Publish events from the mobile app and subscribe to events coming from devices
- Get data usage information for Electron devices

All cloud operations take place asynchronously and use the well-known completion blocks (closures for swift) design pattern for reporting results allowing you to build beautiful responsive apps for your Particle products and projects.
iOS Cloud SDK is implemented as an open-source CocoaPods static library and also as Carthage dynamic framework dependency. See [Installation](#installation) section for more details. It works well for both Objective-C and [Swift](#support-for-swift-projects) projects.

**Beta notice**

This SDK is still under development and is currently released as Beta. Although tested, bugs and issues may be present. Some code might require cleanup. In addition, until version 1.0 is released, we cannot guarantee that API calls will not break from one Cloud SDK version to the next. Be sure to consult the [Change Log](https://github.com/particle/particle-sdk-ios/blob/master/CHANGELOG.md) for any breaking changes / additions to the SDK.

### Getting Started

- Perform the installation step described under the **Installation** section below for integrating in your own project
- You can also [Download Particle iOS Cloud SDK](https://github.com/particle/particle-sdk-ios/archive/master.zip) and try out the included iOS example app
- Be sure to check [Usage](#usage) before you begin for some code examples

### Usage examples

Cloud SDK usage involves two basic classes: first is `ParticleCloud` which is a singleton object that enables all basic cloud operations such as user authentication, device listing, claiming etc. Second class is `ParticleDevice` which is an instance representing a claimed device in the current user session. Each object enables device-specific operation such as: getting its info, invoking functions and reading variables from it.

##### Return values

Most SDK functions will return an [`NSURLSessionDataTask`](https://developer.apple.com/library/prerelease/ios/documentation/Foundation/Reference/NSURLSessionDataTask_class/index.html) object that can be queried by the app developer for further information about the status of the network operation.
This is a result of the SDK relying on AFNetworking which is a networking library for iOS and Mac OS X.
It's built on top of the Foundation URL Loading System, extending the powerful high-level networking abstractions built into Cocoa.
The Particle Cloud SDK has been relying on this powerful library since the beginning, but when version 3.0 was released not long ago it contained some breaking changes, the main change from 2.x is that `NSURLConnectionOperation` was deprecated by Apple and `NSURLSessionDataTask` was introduced to replace it.
You can ignore the return value (previously it was just `void`) coming out of the SDK functions, alternatively you can now make use of the `NSURLSessionDataTask` object as described.

Here are few examples for the most common use cases to get your started:

#### Logging in to Particle cloud
You don't need to worry about access tokens and session expiry, SDK takes care of that for you

**Objective-C**
```objc
[[ParticleCloud sharedInstance] loginWithUser:@"username@email.com" password:@"userpass" completion:^(NSError *error) {
    if (!error)
        NSLog(@"Logged in to cloud");
    else
        NSLog(@"Wrong credentials or no internet connectivity, please try again");
}];
```


**Swift**
```swift
ParticleCloud.sharedInstance().login(withUser: "username@email.com", password: "userpass") { (error:Error?) -> Void in
    if let _ = error {
        print("Wrong credentials or no internet connectivity, please try again")
    }
    else {
        print("Logged in")
    }
}
```

#### Injecting a session access token (app utilizes two legged authentication)

If you use your own backend to authenticate users in your app - you can now inject the Particle access token your back end gets from Particle cloud easily using one of the new `injectSessionAccessToken` functions exposed from `ParticleCloud` singleton class.
In turn the `.isLoggedIn` property has been deprecated in favor of `.isAuthenticated` - which checks for the existence of an active access token instead of a username. Additionally the SDK will now automatically renew an expired session if a refresh token exists. As increased security measure the Cloud SDK will no longer save user's password in the Keychain.

**Objective-C**
```objc
if ([[ParticleCloud sharedInstance] injectSessionAccessToken:@"9bb9f7433940e7c808b191c28cd6738f8d12986c"])
    NSLog(@"Session is active!");
else
    NSLog(@"Bad access token provided");
```


**Swift**
```swift
if ParticleCloud.sharedInstance().injectSessionAccessToken("9bb9f7433940e7c808b191c28cd6738f8d12986c") {
    print("Session is active")
} else {
    print("Bad access token provided")
}
```

#### Get a list of all devices
List the devices that belong to currently logged in user and find a specific device by name:

**Objective-C**

```objc
__block ParticleDevice *myPhoton;
[[ParticleCloud sharedInstance] getDevices:^(NSArray *particleDevices, NSError *error) {
    NSLog(@"%@",particleDevices.description); // print all devices claimed to user

    for (ParticleDevice *device in particleDevices)
    {
        if ([device.name isEqualToString:@"myNewPhotonName"])
            myPhoton = device;
    }
}];
```


**Swift**

```swift
var myPhoton : ParticleDevice?
ParticleCloud.sharedInstance().getDevices { (devices:[ParticleDevice]?, error:Error?) -> Void in
    if let _ = error {
        print("Check your internet connectivity")
    }
    else {
        if let d = devices {
            for device in d {
                if device.name == "myNewPhotonName" {
                    myPhoton = device
                }
            }
        }
    }
}
```


#### Read a variable from a Particle device (Core/Photon/Electron)
Assuming here that `myPhoton` is an active instance of `ParticleDevice` class which represents a device claimed to current user:

**Objective-C**
```objc
[myPhoton getVariable:@"temperature" completion:^(id result, NSError *error) {
    if (!error) {
        NSNumber *temperatureReading = (NSNumber *)result;
        NSLog(@"Room temperature is %f degrees",temperatureReading.floatValue);
    }
    else {
        NSLog(@"Failed reading temperature from Photon device");
    }
}];
```


**Swift**
```swift
myPhoton!.getVariable("temperature", completion: { (result:Any?, error:Error?) -> Void in
    if let _ = error {
        print("Failed reading temperature from device")
    }
    else {
        if let temp = result as? NSNumber {
            print("Room temperature is \(temp.stringValue) degrees")
        }
    }
})
```

#### Call a function on a Particle device (Core/Photon/Electron)
Invoke a function on the device and pass a list of parameters to it, `resultCode` on the completion block will represent the returned result code of the function on the device.
This example also demonstrates usage of the new `NSURLSessionDataTask` object returned from every SDK function call.

**Objective-C**
```objc
NSURLSessionDataTask *task = [myPhoton callFunction:@"digitalWrite" withArguments:@[@"D7",@1] completion:^(NSNumber *resultCode, NSError *error) {
    if (!error)
    {
        NSLog(@"LED on D7 successfully turned on");
    }
}];
int64_t bytesToReceive  = task.countOfBytesExpectedToReceive;
// ..do something with bytesToReceive
```


**Swift**
```swift
let funcArgs = ["D7",1]
var task = myPhoton!.callFunction("digitalWrite", withArguments: funcArgs) { (resultCode : NSNumber?, error : Error?) -> Void in
    if (error == nil) {
        print("LED on D7 successfully turned on")
    }
}
var bytesToReceive : Int64 = task.countOfBytesExpectedToReceive
// ..do something with bytesToReceive
```


#### Retrieve current data usage (Electron only)
_Starting SDK version 0.5.0_
Assuming here that `myElectron` is an active instance of `ParticleDevice` class which represents an Electron device:

**Objective-C**
```objc
[myElectron getCurrentDataUsage:^(float dataUsed, NSError * _Nullable error) {
    if (!error) {
        NSLog(@"device has used %f MBs of data this month",dataUsed);
    }
}];
```


**Swift**
```swift
self.selectedDevice!.getCurrentDataUsage { (dataUsed: Float, error :Error?) in
    if (error == nil) {
        print("Device has used "+String(dataUsed)+" MBs this month")
    }
}
```


#### List device exposed functions and variables
Functions is just a list of names, variables is a dictionary in which keys are variable names and values are variable types:

**Objective-C**
```objc
NSDictionary *myDeviceVariables = myPhoton.variables;
NSLog(@"MyDevice first Variable is called %@ and is from type %@", myDeviceVariables.allKeys[0], myDeviceVariables.allValues[0]);

NSArray *myDeviceFunctions = myPhoton.functions;
NSLog(@"MyDevice first Function is called %@", myDeviceFunctions[0]);
```


**Swift**
```swift
let myDeviceVariables : Dictionary? = myPhoton.variables as? Dictionary<String,String>
print("MyDevice first Variable is called \(myDeviceVariables!.keys.first) and is from type \(myDeviceVariables?.values.first)")

let myDeviceFunction = myPhoton.functions
print("MyDevice first function is called \(myDeviceFunction!.first)")
```

#### Get an instance of a device
Get a device instance by its ID:

**Objective-C**
```objc
__block ParticleDevice *myOtherDevice;
NSString *deviceID = @"53fa73265066544b16208184";
[[ParticleCloud sharedInstance] getDevice:deviceID completion:^(ParticleDevice *device, NSError *error) {
    if (!error)
        myOtherDevice = device;
}];
```


**Swift**
```swift
var myOtherDevice : ParticleDevice? = nil
    ParticleCloud.sharedInstance().getDevice("53fa73265066544b16208184", completion: { (device:ParticleDevice?, error:Error?) -> Void in
        if let d = device {
            myOtherDevice = d
        }
    })
```

#### Rename a device
you can simply set the `.name` property or use -rename() method if you need a completion block to be called (for example updating a UI after renaming was done):

**Objective-C**
```objc
myPhoton.name = @"myNewDeviceName";
```

_or_
```objc
[myPhoton rename:@"myNewDeviecName" completion:^(NSError *error) {
    if (!error)
        NSLog(@"Device renamed successfully");
}];
```


**Swift**
```swift
myPhoton!.name = "myNewDeviceName"
```

_or_
```swift
myPhoton!.rename("myNewDeviceName", completion: { (error:Error?) -> Void in
    if (error == nil) {
        print("Device successfully renamed")
    }
})
```

#### Logout
Also clears user session and access token

**Objective-C**
```objc
[[ParticleCloud sharedInstance] logout];
```


**Swift**
```swift
ParticleCloud.sharedInstance().logout()
```

### Events sub-system

You can make an API call that will open a stream of [Server-Sent Events (SSEs)](http://www.w3.org/TR/eventsource/). You will make one API call that opens a connection to the Particle Cloud. That connection will stay open, unlike normal HTTP calls which end quickly. Very little data will come to you across the connection unless your Particle device publishes an event, at which point you will be immediately notified. In each case, the event name filter is `eventNamePrefix` and is optional. When specifying an event name filter, published events will be limited to those events with names that begin with the specified string. For example, specifying an event name filter of 'temp' will return events with names 'temp' and 'temperature'.

#### Subscribe to events

Subscribe to the firehose of public events with name that starts with "temp", plus the private events published by devices one owns:

**Objective-C**
```objc
// The event handler:
ParticleEventHandler handler = ^(ParticleEvent *event, NSError *error) {
        if (!error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Got Event %@ with data: %@",event.event,event.data);
            });
        }
        else
        {
            NSLog(@"Error occured: %@",error.localizedDescription);
        }

    };

// This line actually subscribes to the event stream:
id eventListenerID = [[ParticleCloud sharedInstance] subscribeToAllEventsWithPrefix:@"temp" handler:handler];
```


**Swift**
```swift
var handler : Any?
handler = ParticleCloud.sharedInstance().subscribeToAllEvents(withPrefix: "temp", handler: { (event :ParticleEvent?, error : Error?) in
    if let _ = error {
        print ("could not subscribe to events")
    } else {
        DispatchQueue.main.async(execute: {
            print("got event with data \(event?.data)")
        })
    }
})
```


*Note:* specifying nil or empty string in the eventNamePrefix parameter will subscribe to ALL events (lots of data!)
You can have multiple handlers per event name and/or same handler per multiple events names.

Subscribe to all events, public and private, published by devices the user owns (`handler` is a [Obj-C block](http://goshdarnblocksyntax.com/) or [Swift closure](http://fuckingswiftblocksyntax.com/)):

**Objective-C**

```objc
id eventListenerID = [[ParticleCloud sharedInstance] subscribeToMyDevicesEventsWithPrefix:@"temp" handler:handler];
```


**Swift**

```swift
var eventListenerID : Any?
eventListenerID = ParticleCloud.sharedInstance().subscribeToMyDevicesEvents(withPrefix: "temp", handler: handler)
```


Subscribe to events from one specific device (by deviceID, second parameter). If the API user owns the device, then he'll receive all events, public and private, published by that device. If the API user does not own the device he will only receive public events.

**Objective-C**

```objc
id eventListenerID = [[ParticleCloud sharedInstance] subscribeToDeviceEventsWithPrefix:@"temp" deviceID:@"53ff6c065075535119511687" handler:handler];
```


**Swift**

```swift
var eventListenerID : Any?
eventListenerID = ParticleCloud.sharedInstance().subscribeToDeviceEvents(withPrefix: "temp", deviceID: "53ff6c065075535119511687", handler: handler)
```


other option is calling same method via the `ParticleDevice` instance:

**Objective-C**

```objc
id eventListenerID = [device subscribeToEventsWithPrefix:@"temp" handler:handler];
```


**Swift**

```swift
var eventListenerID : Any?
eventListenerID = device.subscribeToEvents(withPrefix : "temp", handler : handler)
```


this guarantees that private events will be received since having access device instance in your app signifies that the user has this device claimed.

#### Unsubscribing from events

Very straightforward. Keep the id object the subscribe method returned and use it as parameter to call the unsubscribe method:

**Objective-C**

```objc
[[ParticleCloud sharedInstance] unsubscribeFromEventWithID:eventListenerID];
```


**Swift**

```swift
if let sid = eventListenerID {
    ParticleCloud.sharedInstance().unsubscribeFromEvent(withID: sid)
}
```


or via the `ParticleDevice` instance (if applicable):

**Objective-C**

```objc
[device unsubscribeFromEventWithID:self.eventListenerID];
```


**Swift**

```swift
device.unsubscribeFromEvent(withID : eventListenerID)
```


#### Publishing an event

You can also publish an event from your app to the Particle Cloud:

**Objective-C**

```objc
[[ParticleCloud sharedInstance] publishEventWithName:@"event_from_app" data:@"event_payload" isPrivate:NO ttl:60 completion:^(NSError *error) {
    if (error)
    {
        NSLog(@"Error publishing event: %@",error.localizedDescription);
    }
}];
```


**Swift**

```swift
ParticleCloud.sharedInstance().publishEvent(withName: "event_from_app", data: "event_payload", isPrivate: false, ttl: 60, completion: { (error:Error?) -> Void in
    if error != nil
    {
        print("Error publishing event" + e.localizedDescription)
    }
})
```


### Delegate Protocol

_Starting version 0.5.0_
You can opt-in to conform to the `ParticleDeviceDelegate` protocol in your viewcontroller code if you want to register for receiving system events notifications about the specific device.
You do it by setting `device.delegate = self` where device is an instance of `ParticleDevice`.

The function that will be called on the delegate is:
`-(void)particleDevice:(ParticleDevice *)device didReceiveSystemEvent:(ParticleDeviceSystemEvent)event;`

and then you can respond to the various system events by:

```swift
func particleDevice(device: ParticleDevice, receivedSystemEvent event: ParticleDeviceSystemEvent) {
        print("Received system event "+String(event.rawValue)+" from device "+device.name!)
        // do something meaningful
    }
```


The system events types are:
- `CameOnline` (device came online)
- `WentOffline` (device went offline)
- `FlashStarted` (OTA flashing started)
- `FlashSucceeded` (OTA flashing succeeded - new uesr firmware app is live)
- `FlashFailed` (OTA flashing process failed - user firmware app was not updated)
- `AppHashUpdated` (a new app which is different from last one was flashed to the device)
- `EnteredSafeMode` (device has entered safe mode due to system firmware dependency issue )
- `SafeModeUpdater` (device is trying to heal itself out of safe mode)

### OAuth client configuration

If you're creating an app you're required to provide the `ParticleCloud` class with OAuth clientId and secret.
Those are used to identify users coming from your specific app to the Particle Cloud.
Please follow the procedure decribed [in our guide](https://docs.particle.io/guide/how-to-build-a-product/authentication/#creating-an-oauth-client) to create those strings,
then in your `AppDelegate` class you can supply those credentials by setting the following properties in `ParticleCloud` singleton:

```objc
@property (nonatomic, strong) NSString *OAuthClientId;
@property (nonatomic, strong) NSString *OAuthClientSecret;
```

**Important**
Those credentials should be kept as secret. We recommend the use of [Cocoapods-keys plugin](https://github.com/orta/cocoapods-keys) for cocoapods
(which you have to use anyways to install the SDK). It is essentially a key value store for environment and application keys.
It's a good security practice to keep production keys out of developer hands. CocoaPods-keys makes it easy to have per-user config settings stored securely in the developer's keychain,
and not in the application source. It is a plugin that once installed will run on every pod install or pod update.

After adding the following additional lines your project `Podfile`:
```ruby
plugin 'cocoapods-keys', {
    :project => "YourAppName",
    :keys => [
        "OAuthClientId",
        "OAuthSecret"
    ]}
```

go to your project folder in shell and run `pod install` - it will now ask you for "OAuthClientId", "OAuthSecret" - you can copy/paste the generated keys there
and from that point on you can feed those keys into `ParticleCloud` by adding this code to your AppDelegate `didFinishLaunchingWithOptions` function which gets called
when your app starts:

*Swift example code*

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

    var keys = YourappnameKeys()
    ParticleCloud.sharedInstance().OAuthClientId = keys.oAuthClientId()
    ParticleCloud.sharedInstance().OAuthClientSecret = keys.oAuthSecret()

    return true
}
```

Be sure to replace `YourAppName` with your project name.

### Deploying apps with the Particle Cloud SDK

Starting iOS 10 / XCode 8, Apple requires the developer to enable *Keychain sharing* under the app Capabilities tab when clicking on your target in the project navigator pane. Otherwise an exception will be thrown when a user logs in, the the SDK tries to write the session token to the secure keychain and will fail without this capability enabled.
Consult this [screenshot](http://i63.tinypic.com/szc3nc.png) for reference:

![Keychain sharing screenshot](http://i63.tinypic.com/szc3nc.png "Enable keychain sharing capability before deploying")

### Installation

#### CocoaPods

Particle iOS Cloud SDK is available through [CocoaPods](http://cocoapods.org). CocoaPods is an easy to use dependency manager for iOS.
You must have CocoaPods installed, if you don't then be sure to [Install CocoaPods](https://guides.cocoapods.org/using/getting-started.html) before you start:
To install the iOS Cloud SDK, simply add the following line to your Podfile on main project folder:

```ruby
source 'https://github.com/CocoaPods/Specs.git'

target 'YourAppName' do
    pod 'Particle-SDK'
end
```

Replace `YourAppName` with your app target name - usually shown as the root item name in the XCode project.
In your shell - run `pod update` in the project folder. A new `.xcworkspace` file will be created for you to open by Cocoapods, open that file workspace file in Xcode and you can start interacting with Particle cloud and devices by
adding `#import "Particle-SDK.h"`. (that is not required for swift projects)

##### Support for Swift projects

All SDK callbacks return real optionals (`ParticleDevice?`) instead of implicitly unwrapped optionals (`ParticleDevice!`).

To use iOS Cloud SDK from within Swift based projects [read here](http://swiftalicio.us/2014/11/using-cocoapods-from-swift/).
For a detailed step-by-step help on integrating the Cloud SDK within a Swift project check out this [Particle community posting](https://community.particle.io/t/mobile-sdk-building-the-bridge-from-swift-to-objective-c/12020/1).

The [Apple documentation](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/BuildingCocoaApps/InteractingWithObjective-CAPIs.html) is an important resource on mixing Objective-C and Swift code, be sure to read through that as well.

_Notice_ that we've included the required bridging header file in the SDK, you just need to copy it to your project add it as the active bridging header file in the project settings as described in the links above.
There's also an [example app](https://github.com/particle/particle-setup-ios-example), this app also demonstrates the Particle DeviceSetup library usage, as well as several Cloud SDK calls.

#### Carthage (Recommended method)

The SDK is now also available as a [Carthage](https://github.com/Carthage/Carthage) dependency since version 0.4.0.
This should solve many issues SDK users has been reporting with mixing Swift dependencies in their projects and having to use the `use_frameworks!` directive in the `Podfile` -  that flag is required for any dynamic library, which includes anything written in Swift.
You must have Carthage tool installed, if you don't then be sure to [install Carthage](https://github.com/Carthage/Carthage#installing-carthage) before you start.
Then to build the iOS Cloud SDK, simply create a `Cartfile` on your project root folder, containing the following line:

```
github "particle/particle-sdk-ios" "master"
```

and then run the following command:
`carthage update --platform iOS --use-submodules --no-use-binaries`.
A new folder will be created in your project root folder - navigate to the `./Carthage/Build/iOS` folder and drag all the created `.framework`s file into your project in XCode.
Go to your XCode target settings->General->Embedded binaries and make sure the `ParticleSDK.framework` and the `AFNetworking.framework` are listed there.
Build your project - you now have the Particle SDK embedded in your project.

##### Carthage example

A new example app demonstrating the usage of Carthage installation method is available [here](https://github.com/particle/ios-app-example-carthage).
This app is meant to serve as basic example for using the Particle Cloud SDK and Device Setup Library in the Carthage dependencies form.
To get this example app running, clone it, open the project in XCode and:

1. Flash the `firmware.c` (included in the repo project) firmware to an online photon available under your account, use Build or Dev or CLI.
1. Set Photon's name to the constant deviceName in the testCloudSDK() function
1. Set your username/password to the appropriate constants, same place
1. Go the project root folder in your shell, run the setup shell script (under the /bin folder) which will build the latest Particle SDK 1. Carthage dependencies
1. Drag the 3 created .framework files under /Carthage/Build/iOS to your project
1. Go to XCode's target general settings and also add those frameworks to "embedded binaries"
1. Run and experiment!

### Reference

#### ParticleCloud class

  `@property (nonatomic, strong, nullable, readonly) NSString* loggedInUsername`

Currently logged in user name, nil if no valid session

  `@property (nonatomic, readonly) BOOL isAuthenticated`

Currently authenticated (does a access token exist?)

  `@property (nonatomic, strong, nullable, readonly) NSString *accessToken`

Current session access token string, nil if not logged in

  `@property (nonatomic, nullable, strong) NSString *oAuthClientId`

oAuthClientId unique for your app, use 'particle' for development or generate your OAuth creds for production apps (https://docs.particle.io/reference/api/#create-an-oauth-client)

  `@property (nonatomic, nullable, strong) NSString *oAuthClientSecret`

oAuthClientSecret unique for your app, use 'particle' for development or generate your OAuth creds for production apps (https://docs.particle.io/reference/api/#create-an-oauth-client)

  `+ (instancetype)sharedInstance`

Singleton instance of ParticleCloud class

 * **Returns:** initialized ParticleCloud singleton

  `-(NSURLSessionDataTask *)loginWithUser:(NSString *)user password:(NSString *)password completion:(nullable ParticleCompletionBlock)completion`

Login with existing account credentials to Particle cloud

 * **Parameters:**
   * `user` — User name, must be a valid email address
   * `password` — Password
   * `completion` — Completion block will be called when login finished, NS/Error object will be passed in case of an error, nil if success

  `-(NSURLSessionDataTask *)createUser:(NSString *)username password:(NSString *)password accountInfo:(nullable NSDictionary *)accountInfo completion:(nullable ParticleCompletionBlock)completion`

Sign up with new account credentials to Particle cloud

 * **Parameters:**
   * `user` — Required user name, must be a valid email address
   * `password` — Required password
   * `accountInfo` — Optional dictionary with extended account info fields: firstName, lastName, isBusinessAccount [NSNumber @0=false, @1=true], companyName
   * `completion` — Completion block will be called when sign-up finished, NSError object will be passed in case of an error, nil if success

  `-(nullable NSURLSessionDataTask *)createCustomer:(NSString *)username password:(NSString *)password productId:(NSUInteger)productId accountInfo:(nullable NSDictionary *)accountInfo completion:(nullable ParticleCompletionBlock)completion`

Sign up with new account credentials to Particle cloud

 * **Parameters:**
   * `username` — Required user name, must be a valid email address
   * `password` — Required password
   * `productId` — Required ProductID number should be copied from console for your specific product
   * `accountInfo` — Optional account information metadata that contains fields: first_name, last_name, company_name, business_account [boolean] - currently has no effect for customers
   * `completion` — Completion block will be called when sign-up finished, NSError object will be passed in case of an error, nil if success

  `-(void)logout`

Logout user, remove session data

  `-(BOOL)injectSessionAccessToken:(NSString * _Nonnull)accessToken`

Inject session access token received from a custom backend service in case Two-legged auth is being used. This session expected not to expire, or at least SDK won't know about its expiration date.

 * **Parameters:** `accessToken` — Particle Access token string
 * **Returns:** YES if session injected successfully

  `-(BOOL)injectSessionAccessToken:(NSString *)accessToken withExpiryDate:(NSDate *)expiryDate`

Inject session access token received from a custom backend service in case Two-legged auth is being used. Session will expire at expiry date.

 * **Parameters:**
   * `accessToken` — Particle Access token string
   * `expiryDate` — Date/time in which session expire and no longer be active - you'll have to inject a new session token at that point.
 * **Returns:** YES if session injected successfully

  `-(BOOL)injectSessionAccessToken:(NSString *)accessToken withExpiryDate:(NSDate *)expiryDate andRefreshToken:(NSString *)refreshToken`

Inject session access token received from a custom backend service in case Two-legged auth is being used. Session will expire at expiry date, and SDK will try to renew it using supplied refreshToken.

 * **Parameters:**
   * `accessToken` — Particle Access token string
   * `expiryDate` — Date/time in which session expire
   * `refreshToken` — Refresh token will be used automatically to hit Particle cloud to create a new active session access token.
 * **Returns:** YES if session injected successfully

  `-(NSURLSessionDataTask *)requestPasswordResetForCustomer:(NSString *)email productId:(NSUInteger)productId completion:(nullable ParticleCompletionBlock)completion`

Request password reset for customer (in product mode) command generates confirmation token and sends email to customer using org SMTP settings

 * **Parameters:**
   * `email` — user email
   * `productId` — Product ID number
   * `completion` — Completion block with NSError object if failure, nil if success

  `-(NSURLSessionDataTask *)requestPasswordResetForUser:(NSString *)email completion:(nullable ParticleCompletionBlock)completion`

Request password reset for user command generates confirmation token and sends email to customer using org SMTP settings

 * **Parameters:**
   * `email` — user email
   * `completion` — Completion block with NSError object if failure, nil if success

  `-(NSURLSessionDataTask *)getDevices:(nullable void (^)(NSArray<ParticleDevice *> * _Nullable particleDevices, NSError * _Nullable error))completion`

Get an array of instances of all user's claimed devices offline devices will contain only partial data (no info about functions/variables)

 * **Parameters:** `completion` — Completion block with the device instances array in case of success or with NSError object if failure
 * **Returns:** NSURLSessionDataTask task for requested network access

  `-(NSURLSessionDataTask *)getDevice:(NSString *)deviceID completion:(nullable void (^)(ParticleDevice * _Nullable device, NSError * _Nullable error))completion`

Get a specific device instance by its deviceID. If the device is offline the instance will contain only partial information the cloud has cached, notice that the the request might also take quite some time to complete for offline devices.

 * **Parameters:**
   * `deviceID` — required deviceID
   * `completion` — Completion block with first arguemnt as the device instance in case of success or with second argument NSError object if operation failed
 * **Returns:** NSURLSessionDataTask task for requested network access

  `-(NSURLSessionDataTask *)claimDevice:(NSString *)deviceID completion:(nullable ParticleCompletionBlock)completion`

Claim the specified device to the currently logged in user (without claim code mechanism)

 * **Parameters:**
   * `deviceID` — required deviceID
   * `completion` — Completion block with NSError object if failure, nil if success
 * **Returns:** NSURLSessionDataTask task for requested network access

  `-(NSURLSessionDataTask *)generateClaimCode:(nullable void(^)(NSString * _Nullable claimCode, NSArray * _Nullable userClaimedDeviceIDs, NSError * _Nullable error))completion`

Get a short-lived claiming token for transmitting to soon-to-be-claimed device in soft AP setup process

 * **Parameters:** `completion` — Completion block with claimCode string returned (48 random bytes base64 encoded to 64 ASCII characters), second argument is a list of the devices currently claimed by current session user and third is NSError object for failure, nil if success
 * **Returns:** NSURLSessionDataTask task for requested network access


  `-(NSURLSessionDataTask *)generateClaimCodeForProduct:(NSUInteger)productId completion:(nullable void(^)(NSString *_Nullable claimCode, NSArray * _Nullable userClaimedDeviceIDs, NSError * _Nullable error))completion`

Get a short-lived claiming token for transmitting to soon-to-be-claimed device in soft AP setup process for specific product and organization (different API endpoints)

 * **Parameters:**
   * `productId` — - the product id number
   * `completion` — Completion block with claimCode string returned (48 random bytes base64 encoded to 64 ASCII characters), second argument is a list of the devices currently claimed by current session user and third is NSError object for a failure, nil if success
 * **Returns:** NSURLSessionDataTask task for requested network access

  `-(nullable id)subscribeToAllEventsWithPrefix:(nullable NSString *)eventNamePrefix handler:(nullable ParticleEventHandler)eventHandler`

Subscribe to the firehose of public events, plus private events published by devices one owns

 * **Parameters:**
   * `eventHandler` — ParticleEventHandler event handler method - receiving NSDictionary argument which contains keys: event (name), data (payload), ttl (time to live), published_at (date/time emitted), coreid (device ID). Second argument is NSError object in case error occured in parsing the event payload.
   * `eventName` — Filter only events that match name eventName, if nil is passed any event will trigger eventHandler
 * **Returns:** eventListenerID function will return an id type object as the eventListener registration unique ID - keep and pass this object to the unsubscribe method in order to remove this event listener

  `-(nullable id)subscribeToMyDevicesEventsWithPrefix:(nullable NSString *)eventNamePrefix handler:(nullable ParticleEventHandler)eventHandler`

Subscribe to all events, public and private, published by devices one owns

 * **Parameters:**
   * `eventHandler` — Event handler function that accepts the event payload dictionary and an NSError object in case of an error
   * `eventNamePrefix` — Filter only events that match name eventNamePrefix, for exact match pass whole string, if nil/empty string is passed any event will trigger eventHandler
 * **Returns:** eventListenerID function will return an id type object as the eventListener registration unique ID - keep and pass this object to the unsubscribe method in order to remove this event listener

  `-(nullable id)subscribeToDeviceEventsWithPrefix:(nullable NSString *)eventNamePrefix deviceID:(NSString *)deviceID handler:(nullable ParticleEventHandler)eventHandler`

Subscribe to events from one specific device. If the API user has the device claimed, then she will receive all events, public and private, published by that device. If the API user does not own the device she will only receive public events.

 * **Parameters:**
   * `eventNamePrefix` — Filter only events that match name eventNamePrefix, for exact match pass whole string, if nil/empty string is passed any event will trigger eventHandler
   * `deviceID` — Specific device ID. If user has this device claimed the private & public events will be received, otherwise public events only are received.
   * `eventHandler` — Event handler function that accepts the event payload dictionary and an NSError object in case of an error
 * **Returns:** eventListenerID function will return an id type object as the eventListener registration unique ID - keep and pass this object to the unsubscribe method in order to remove this event listener

  `-(void)unsubscribeFromEventWithID:(id)eventListenerID`

Unsubscribe from event/events.

 * **Parameters:** `eventListenerID` — The eventListener registration unique ID returned by the subscribe method which you want to cancel

  `-(NSURLSessionDataTask *)publishEventWithName:(NSString *)eventName data:(NSString *)data isPrivate:(BOOL)isPrivate ttl:(NSUInteger)ttl completion:(nullable ParticleCompletionBlock)completion`

Subscribe to events from one specific device. If the API user has the device claimed, then she will receive all events, public and private, published by that device. If the API user does not own the device she will only receive public events.

 * **Parameters:**
   * `eventName` — Publish event named eventName
   * `data` — A string representing event data payload, you can serialize any data you need to represent into this string and events listeners will get it
   * `private` — A boolean flag determining if this event is private or not (only users's claimed devices will be able to listen to it)
   * `ttl` — TTL stands for Time To Live. It it the number of seconds that the event data is relevant and meaningful. For example, an outdoor temperature reading with a precision of integer degrees Celsius might have a TTL of somewhere between 600 (10 minutes) and 1800 (30 minutes).

     The geolocation of a large piece of farm equipment that remains stationary most of the time but may be moved to a different field once in a while might have a TTL of 86400 (24 hours). After the TTL has passed, the information can be considered stale or out of date.
 * **Returns:** NSURLSessionDataTask task for requested network access

#### ParticleDevice class

  `typedef void (^ParticleCompletionBlock)(NSError * _Nullable error)`

Standard completion block for API calls, will be called when the task is completed with a nullable error object that will be nil if the task was successful.

  `@property (strong, nonatomic, readonly) NSString* id`

DeviceID string

  `@property (strong, nullable, nonatomic) NSString* name`

Device name. Device can be renamed in the cloud by setting this property. If renaming fails name will stay the same.

  `@property (nonatomic, readonly) BOOL connected`

Is device connected to the cloud? Best effort - May not accurate reflect true state.

  `@property (strong, nonatomic, nonnull, readonly) NSArray<NSString *> *functions`

List of function names exposed by device

  `@property (strong, nonatomic, nonnull, readonly) NSDictionary<NSString *, NSString *> *variables`

Dictionary of exposed variables on device with their respective types.

  `@property (strong, nonatomic, readonly) NSString *version`

Device firmware version string

  `-(NSURLSessionDataTask *)getVariable:(NSString *)variableName completion:(nullable void(^)(id _Nullable result, NSError* _Nullable error))completion`

Retrieve a variable value from the device

 * **Parameters:**
   * `variableName` — Variable name
   * `completion` — Completion block to be called when function completes with the variable value retrieved (as id/Any) or NSError object in case on an error

  `-(NSURLSessionDataTask *)callFunction:(NSString *)functionName withArguments:(nullable NSArray *)args completion:(nullable void (^)(NSNumber * _Nullable result, NSError * _Nullable error))completion`

Call a function on the device

 * **Parameters:**
   * `functionName` — Function name
   * `args` — Array of arguments to pass to the function on the device. Arguments will be converted to string maximum length 63 chars.
   * `completion` — Completion block will be called when function was invoked on device. First argument of block is the integer return value of the function, second is NSError object in case of an error invoking the function

  `-(NSURLSessionDataTask *)signal:(BOOL)enable completion:(nullable ParticleCompletionBlock)completion`

Signal device Will make the onboard LED "shout rainbows" for easy physical identification of a device

 * **Parameters:** `enale` — - YES to start or NO to stop LED signal.

  `-(NSURLSessionDataTask *)refresh:(nullable ParticleCompletionBlock)completion`

Request device refresh from cloud update online status/functions/variables/device name, etc

 * **Parameters:** `completion` — Completion block called when function completes with NSError object in case of an error or nil if success.

  `-(NSURLSessionDataTask *)unclaim:(nullable ParticleCompletionBlock)completion`

Remove device from current logged in user account

 * **Parameters:** `completion` — Completion block called when function completes with NSError object in case of an error or nil if success.

  `-(NSURLSessionDataTask *)rename:(NSString *)newName completion:(nullable ParticleCompletionBlock)completion`

Rename device

 * **Parameters:**
   * `newName` — New device name
   * `completion` — Completion block called when function completes with NSError object in case of an error or nil if success.

  `-(NSURLSessionDataTask *)getCurrentDataUsage:(nullable void(^)(float dataUsed, NSError* _Nullable error))completion`

Retrieve current data usage report (For Electron only)

 * **Parameters:** `completion` — Completion block to be called when function completes with the data used in current payment period in (float)MBs. All devices other than Electron will return an error with -1 value

  `-(nullable NSURLSessionDataTask *)flashFiles:(NSDictionary *)filesDict completion:(nullable ParticleCompletionBlock)completion`

Flash files to device

 * **Parameters:**
   * `filesDict` — files dictionary in the following format: @{@"filename.bin" : <NSData>, ...} - that is a NSString filename as key and NSData blob as value. More than one file can be flashed. Data is alway binary.
   * `completion` — Completion block called when function completes with NSError object in case of an error or nil if success. NSError.localized descripion will contain a detailed error report in case of a

  `-(NSURLSessionDataTask *)flashKnownApp:(NSString *)knownAppName completion:(nullable ParticleCompletionBlock)completion`

Flash known firmware images to device

 * **Parameters:**
   * `knownAppName` — NSString of known app name. Currently @"tinker" is supported.
   * `completion` — Completion block called when function completes with NSError object in case of an error or nil if success. NSError.localized descripion will contain a detailed error report in case of a

  `-(nullable id)subscribeToEventsWithPrefix:(nullable NSString *)eventNamePrefix handler:(nullable ParticleEventHandler)eventHandler`

Subscribe to events from this specific (claimed) device - both public and private.

 * **Parameters:**
   * `eventNamePrefix` — Filter only events that match name eventNamePrefix, for exact match pass whole string, if nil/empty string is passed any event will trigger eventHandler
   * `eventHandler` — Event handler function that accepts the event payload dictionary and an NSError object in case of an error

  `-(void)unsubscribeFromEventWithID:(id)eventListenerID`

Unsubscribe from event/events.

 * **Parameters:** `eventListenerID` — The eventListener registration unique ID returned by the subscribe method which you want to cancel

### Communication

- If you **need help**, use [Our community website](http://community.particle.io), use the `Mobile` category for dicussion/troubleshooting iOS apps using the Particle iOS Cloud SDK.
- If you are certain you **found a bug**, _and can provide steps to reliably reproduce it_, open an issue, label it as `bug`.
- If you **have a feature request**, open an issue with an `enhancement` label on it
- If you **want to contribute**, submit a pull request, be sure to check out particle.github.io for our contribution guidelines, and please sign the [CLA](https://docs.google.com/a/particle.io/forms/d/1_2P-vRKGUFg5bmpcKLHO_qNZWGi5HKYnfrrkd-sbZoA/viewform).

### Maintainers

- Ido Kleinman [Github](https://www.github.com/idokleinman) | [Twitter](https://www.twitter.com/idokleinman)

### License

Particle iOS Cloud SDK is available under the Apache License 2.0. See the LICENSE file for more info.
