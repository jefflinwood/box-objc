
//
// Copyright 2011 Box.net, Inc.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

#import "BoxLoginBuilder.h"
#import "BoxGetTicketOperation.h"
#import "BoxGetAuthTokenOperation.h"

@implementation BoxLoginBuilder

- (id)initWithWebview:(UIWebView *)webView delegate:(id<BoxLoginBuilderDelegate>)delegate {
	if ((self = [super init])) {
		_webView = webView;
		webView.delegate = self;
		
		_delegate = delegate;
		
		_ticketOperation = [[BoxGetTicketOperation alloc] initWithDelegate:self];
		_authTokenOperation = [[BoxGetAuthTokenOperation alloc] initWithTicket:nil delegate:self];
	}
	
	return self;
}

- (void)dealloc {
	
	_webView.delegate = nil;
	_ticketOperation.delegate = nil;
	_authTokenOperation.delegate = nil;
	
	[_ticketOperation release];
	[_authTokenOperation release];
	
	[super dealloc];
}

- (void)startLoginProcess {
	
	// if we don't have the ticket, request it
	// otherwise, go straight to the next step
	NSLog(@"starting login process");
	if (!_ticketOperation.ticket || _ticketOperation.ticket == @"") {
		NSLog(@"starting the ticket operation");
		[_delegate startActivityIndicator];
		[_ticketOperation start];
	} else {
		NSLog(@"going straight to operation did complete");
		[self operation:_ticketOperation didCompleteForPath:nil response:BoxOperationResponseSuccessful];
	}
}

#pragma mark -
#pragma mark BoxOperationDelegate

- (void)operation:(BoxOperation *)op didCompleteForPath:(NSString *)path response:(BoxOperationResponse)response {
	
	if (response != BoxOperationResponseSuccessful) {
		[_delegate loginFailedWithError:BoxLoginBuilderResponseTypeFailed];
		return;
	}
	
	// what we do depends on which operation completed
	if (op == _ticketOperation) {
		NSLog(@"have the ticket operation...");
		// need to launch the webview
		_webViewStep = BoxLoginBuilderWebViewStepBegin;
		NSLog(@"loading request");
		[_delegate startActivityIndicator];
		[_webView loadRequest:[NSURLRequest requestWithURL:[_ticketOperation authenticationURL]]];
	} else if (op == _authTokenOperation) {
		// login complete!
		[_delegate loginCompletedWithUser:_authTokenOperation.user];
		[_delegate stopActivityIndicator];
	}
}

#pragma mark -
#pragma mark UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	
	NSLog(@"got loading request complete");
	if (_webViewStep == BoxLoginBuilderWebViewStepFormSubmitted) {
		NSLog(@"it was for the submitted form");
		// start the authentication request
		[_delegate startActivityIndicator];
		[_webView setHidden:YES];
		_authTokenOperation.ticket = _ticketOperation.ticket;
		[_authTokenOperation start];
	} else if (_webViewStep == BoxLoginBuilderWebViewStepUserPassField) {
		NSLog(@"it was for the user pass field");
		[_delegate stopActivityIndicator];
		[_webView setHidden:NO];
		NSLog(@"the webview is now not hidden");
	}
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	// request type  UIWebViewNavigationTypeFormSubmitted means they hit log in
	// request type UIWebViewNavigationTypeOther means we fed it to the UIWebView
	if (navigationType == UIWebViewNavigationTypeOther) {
		_webViewStep = BoxLoginBuilderWebViewStepUserPassField;
	} else if (navigationType == UIWebViewNavigationTypeFormSubmitted) {
		_webViewStep = BoxLoginBuilderWebViewStepFormSubmitted;
	}
	return YES;
}

@end
