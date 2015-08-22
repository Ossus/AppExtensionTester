//
//  ViewController.m
//  AppExtensionTester
//
//  Created by Pascal Pfiffner on 8/16/15.
//  Copyright (c) 2015 Ossus. All rights reserved.
//

#import "ViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define VERSION_NUMBER @(100)


@interface ViewController ()

@property (copy, nonatomic) NSString *symmetricKey;

@end


@implementation ViewController


- (NSExtensionItem *)extensionItem {
	NSString *typeIdentifier = @"app.medcalc.v3.user-data";
	
	// TODO: generate random key and encrypt using MedCalc public key
	self.symmetricKey = @"abcd";
	NSData *encKey = [_symmetricKey dataUsingEncoding:NSUTF8StringEncoding];
	NSItemProvider *itemProvider = [[NSItemProvider alloc] initWithItem:encKey typeIdentifier:typeIdentifier];
	
	NSExtensionItem *item = [[NSExtensionItem alloc] init];
	item.attachments = @[ itemProvider ];
	
	return item;
}

- (IBAction)launchExtension:(id)sender {
	UIActivityViewController *activityViewController = [self activityViewControllerForItems:@[[self extensionItem]] sender:sender];
	activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
		if (!completed) {
			return;
		}
		if (activityError || 0 == returnedItems.count) {
			NSError *error = activityError ?: [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"No item data received"}];
			[self presentError:error];
			return;
		}
		
		// process first item which should contain all data we're interested in
		[self handleDataInItems:returnedItems.firstObject completion:^(NSArray *errors) {
			if ([errors count] > 0) {
				NSLog(@"xx>  Errors: %@", errors);
			}
			else {
				NSLog(@"-->  Done");
			}
		}];
	};
	
	[self presentViewController:activityViewController animated:YES completion:nil];
}

- (void)handleDataInItems:(NSExtensionItem *)item completion:(void (^)(NSArray *errors))completion {
	if (item.attachments.count == 0) {
		if (completion) {
			NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"No data received"};
			NSError *error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:0 userInfo:userInfo];
			completion(@[error]);
		}
		return;
	}
	
	// loop attachments and handle all
	dispatch_group_t group = dispatch_group_create();
	NSMutableArray *errors = [NSMutableArray arrayWithCapacity:3];
	for (NSItemProvider *provider in item.attachments) {
		for (NSString *dataType in @[@"app.medcalc.v3.user-data.preferences", @"app.medcalc.v3.user-data.favorites", @"app.medcalc.v3.user-data.dilutions"]) {
			if ([provider hasItemConformingToTypeIdentifier:dataType]) {
				dispatch_group_enter(group);
				[provider loadItemForTypeIdentifier:dataType options:nil completionHandler:^(NSData *data, NSError *providerError) {
					NSError *error = providerError;
					if (error || 0 == data.length) {
						NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Did not receive appropriate data for user preferences."};
						error = error ?: [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:userInfo];
						[errors addObject:error];
					}
					else if (data) {
						NSError *hError = [self handleData:data ofType:dataType];
						if (hError) {
							[errors addObject:hError];
						}
					}
					dispatch_group_leave(group);
				}];
			}
		}
		
		// TODO: favorites, dilutions
	}
	
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		if (completion) {
			completion(errors);
		}
	});
}

- (NSError *)handleData:(NSData *)prefData ofType:(NSString *)dataType {
	NSParameterAssert(prefData);
	NSParameterAssert(dataType);
	// TODO: decrypt using symmetric key
	NSError *error = nil;
	
	if ([@"app.medcalc.v3.user-data.preferences" isEqualToString:dataType]) {
		NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:prefData options:0 error:&error];
		if (!dict) {
			return error;
		}
		NSLog(@"--->  Prefs: %@", dict);
	}
	else if ([@"app.medcalc.v3.user-data.favorites" isEqualToString:dataType]) {
		
	}
	else if ([@"app.medcalc.v3.user-data.dilutions" isEqualToString:dataType]) {
		
	}
	
	return nil;
}


// MARK: - User Actions

- (UIActivityViewController *)activityViewControllerForItems:(NSArray *)items sender:(id)sender {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && sender == nil) {
		[NSException raise:@"Invalid argument: sender must not be nil on iPad." format:@""];
	}
	
	// show activity controller for our item
	UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
	if ([sender isKindOfClass:[UIBarButtonItem class]]) {
		controller.popoverPresentationController.barButtonItem = sender;
	}
	else if ([sender isKindOfClass:[UIView class]]) {
		controller.popoverPresentationController.sourceView = [sender superview];
		controller.popoverPresentationController.sourceRect = [sender frame];
	}
	else {
		NSLog(@"sender can be nil on iPhone");
	}
	
	return controller;
}

- (void)presentError:(NSError *)error {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}


@end
