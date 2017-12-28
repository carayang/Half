//
//  CardGameAppDelegate.h
//  MacOSWindowTest
//
//  Created by cara on 9/18/17.
//  Copyright (c) 2017 cara. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CardGameAppDelegate : NSObject <NSApplicationDelegate>{
NSMutableDictionary     *_observers;
pid_t                    _currentPid;
}
@property (assign) IBOutlet NSWindow *window;

@end
