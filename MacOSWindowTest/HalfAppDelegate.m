//
//  CardGameAppDelegate.m
//  MacOSWindowTest
//
//  Created by cara on 9/18/17.
//  Copyright (c) 2017 cara. All rights reserved.
//

#import "HalfAppDelegate.h"

@implementation CardGameAppDelegate

/*
 Called when a new application was launched. Registers for its notifications when the
 application is activated.
 */
- (void)applicationLaunched:(NSNotification *)notification
{
	/* A new application has launched. Make sure we get notifications when it activates. */
    [self registerForAppSwitchNotificationFor:[notification userInfo]];
}


/*
 Called when an application was terminated. Stops watching for this application switch events.
 */
- (void)applicationTerminated:(NSNotification *)notification
{
	/* Get the application's process id  */
    NSNumber *pidNumber = [[notification userInfo] valueForKey:@"NSApplicationProcessIdentifier"];
	/* Get the observer associated to this application */
    AXObserverRef observer = (AXObserverRef)CFBridgingRetain([_observers objectForKey:pidNumber]);
	/* Check whether this observer is valid. If observer is valid, unregister for accessibility notifications
     and display a descriptive message otherwise. */
    if(observer) {
        /* Stop listening to the accessibility notifications for the dead application */
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                              AXObserverGetRunLoopSource(observer),
                              kCFRunLoopDefaultMode);
        [_observers removeObjectForKey:pidNumber];
        NSLog(@"Observer removed.");
    } else {
        NSLog(@"Application \"%@\" that we didn't know about quit!", [[notification userInfo] valueForKey:@"NSApplicationName"]);
    }
}


/*
 Calls the applicationSwitched method.
 */
static void applicationMoved(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *self)
{
    NSLog(@"moving");
    NSDictionary *applicationInfo = [[NSWorkspace sharedWorkspace] activeApplication];
	/* Get the application's process id  */
    pid_t switchedPid = (pid_t)[[applicationInfo valueForKey:@"NSApplicationProcessIdentifier"] integerValue];
	
	/* Do not do anything if we do not have new application in the front or if are in the front ourselves */
    if(switchedPid != getpid()) {
        AXUIElementRef appRef  = AXUIElementCreateApplication(switchedPid);
        AXUIElementRef windowRef;
        CFArrayRef windowList;
        int o_y,screen_h=[[NSScreen mainScreen] frame].size.height;
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute, (CFTypeRef *)&windowList);
        if ((!windowList) || CFArrayGetCount(windowList)<1){
            NSLog(@"Cant get window");
            return;
        }else{
            windowRef = (AXUIElementRef) CFArrayGetValueAtIndex( windowList, 0);
        }
        // get just the first window for now
        NSPoint mouseLoc;
        mouseLoc = [NSEvent mouseLocation];
        NSRect rect=[[NSScreen mainScreen] visibleFrame];
        o_y = rect.origin.y;
        rect.origin.y = 0;
        if(mouseLoc.x<10){
            rect.size.width=rect.size.width*0.5-1;
            rect.origin.x=rect.origin.x;
        }else if(mouseLoc.x>[[NSScreen mainScreen] frame].size.width-10){
            rect.size.width=rect.size.width*0.5-1;
            rect.origin.x=rect.origin.x+rect.size.width+1;
        }else if(mouseLoc.y>[[NSScreen mainScreen] frame].size.height-10){
            rect.size.height=rect.size.height*0.5-1;
        }else if(mouseLoc.y<10){
            rect.origin.y=screen_h-rect.size.height*0.5-o_y;
            rect.size.height=rect.size.height*0.5-1;
        }else return;
        CFTypeRef position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&rect.origin));
        CFTypeRef size = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&rect.size));
        //resize window
        AXUIElementSetAttributeValue(windowRef, kAXPositionAttribute, position);
        AXUIElementSetAttributeValue(windowRef, kAXSizeAttribute, size);
    }
    sleep(1);
}

/*
 Creates an accessibility observer to watch an application switch events.
 */
- (void)registerForAppSwitchNotificationFor:(NSDictionary *)application
{
    NSNumber *pidNumber = [application valueForKey:@"NSApplicationProcessIdentifier"];
    
    /* Don't sign up for our own switch events (that will fail). */
    if([pidNumber intValue] != getpid()) {
        /* Check whether we are not already watching for this application's switch events */
        if(![_observers objectForKey:pidNumber]) {
            pid_t pid = (pid_t)[pidNumber integerValue];
            /* Create an Accessibility observer for the application */
            AXObserverRef observer;
            if(AXObserverCreate(pid, applicationMoved, &observer) == kAXErrorSuccess) {
                NSLog(@"Observer Created");
                /* Register for the application activated notification */
                CFRunLoopAddSource(CFRunLoopGetCurrent(),
                                   AXObserverGetRunLoopSource(observer),
                                   kCFRunLoopDefaultMode);
                AXUIElementRef element = AXUIElementCreateApplication(pid);
                if(AXObserverAddNotification(observer, element, kAXMovedNotification, (__bridge void *)(self)) != kAXErrorSuccess) {
                    NSLog(@"Failed to create observer for application \"%@\".", [application valueForKey:@"NSApplicationName"]);
                } else {
                    /* Remember the observer so that we can unregister later */
                    [_observers setObject:(__bridge id)observer forKey:pidNumber];
                }
                /* The observers dictionary wil hold on to the observer for us */
                CFRelease(observer);
                /* We do not need the element any more */
                CFRelease(element);
            } else {
                /* We could not create an observer to watch this application's switch events */
                NSLog(@"Failed to create observer for application \"%@\".", [application valueForKey:@"NSApplicationName"]);
            }
        } else {
            /* We are already observing this application */
            NSLog(@"Attempted to observe application \"%@\" twice.", [application valueForKey:@"NSApplicationName"]);
        }
    }
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    NSRect rect=[[NSScreen mainScreen] visibleFrame];
    rect.size.width*=0.5;
    rect.origin.x+=rect.size.width;
    [_window setFrame:rect display:YES];
    
}

- (void)awakeFromNib
{
    /* Check if 'Enable access for assistive devices' is enabled. */
    if(!AXAPIEnabled()) {
        /*
         'Enable access for assistive devices' is not enabled, so we will alert the user,
         then quit because we can't update the users status on app switch as we are meant to
         (because we can't get notifications of application switches).
         */
        NSRunCriticalAlertPanel(@"'Enable access for assistive devices' is not enabled.", @"Half requires that 'Enable access for assistive devices' in the 'Security & Privacy' preferences panel be enabled in order to monitor application switching. Go to 'Security & Privacy' panel and click 'Privacy', click unlock on the bottom, then check 'Half'", @"Quit", nil, nil);
        [NSApp terminate:self];
    }
    
    
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    _observers = [[NSMutableDictionary alloc] init];
    
    /* Register for application launch notifications */
    [[workspace notificationCenter] addObserver:self
                                       selector:@selector(applicationLaunched:)
                                           name:NSWorkspaceDidLaunchApplicationNotification
                                         object:workspace];
	/* Register for application termination notifications */
    [[workspace notificationCenter] addObserver:self
                                       selector:@selector(applicationTerminated:)
                                           name:NSWorkspaceDidTerminateApplicationNotification
                                         object:workspace];
    
    /* Register for activation notifications for all currently running applications */
    for(NSDictionary *application in [workspace launchedApplications]) {
        [self registerForAppSwitchNotificationFor:application];
    }
}


@end
