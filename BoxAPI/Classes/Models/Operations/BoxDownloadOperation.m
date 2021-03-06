
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

#import "BoxDownloadOperation.h"


@implementation BoxDownloadOperation

@synthesize tempFilePath = _tempFilePath;
@synthesize authToken = _authToken;

+ (BoxDownloadOperation *)operationForFileID:(int)targetFileID
									  toPath:(NSString *)path
								   authToken:(NSString *)authToken
									delegate:(id<BoxOperationDelegate>)delegate
{
	return [[[BoxDownloadOperation alloc] initForFileID:targetFileID
											  localPath:path 
											  authToken:authToken
											   delegate:delegate] autorelease];
}

- (id)initForFileID:(int)targetFileID
		  localPath:(NSString *)path
		  authToken:(NSString *)authToken
		   delegate:(id<BoxOperationDelegate>)delegate
{
	if (self = [super initForType:BoxOperationTypeDownload delegate:delegate path:path]) {
		_targetFileID = targetFileID;
		_outputStream = nil;

		self.authToken = authToken;
		self.summary = [NSString stringWithFormat:@"Downloading \"%@\"â€¦", [path lastPathComponent]];
	}

	return self;
}

- (void)dealloc {
	[_outputStream release];
	self.authToken = nil;
	[super dealloc];
}

- (NSURL *)url {
	self.recordReceivedData = NO;
	_outputStream = [[NSOutputStream alloc] initToFileAtPath:(_tempFilePath ? _tempFilePath : self.path) append:NO];
	[_outputStream open];
	return [NSURL URLWithString:[BoxRESTApiFactory getDownloadUrlString:self.authToken
															  boxFileID:_targetFileID]];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if ([_outputStream write:[data bytes] maxLength:[data length]] == -1) {
		[connection cancel];
		[super connection:connection didFailWithError:[_outputStream streamError]];
		return;
	}

	[super connection:connection didReceiveData:data];
}

- (void)requestDidCompleteWithResponse:(NSHTTPURLResponse *)response {
	BoxOperationResponse responseType = BoxOperationResponseUnknownError;
	NSError *error = nil;

	[_outputStream close];

	if ([response statusCode] == 200) {
		// If the file is particularly short, make sure it isn't an error code
		if (_receivedDataLength < 20) {
			NSString *receivedDataString = [[[NSString alloc] initWithData:[NSData dataWithContentsOfFile:(_tempFilePath ? _tempFilePath : self.path)] encoding:NSUTF8StringEncoding] autorelease];
			if ([receivedDataString isEqualToString:@"wrong auth token"]) {
				responseType = BoxOperationResponseNotLoggedIn;
			}
		}

		if (responseType == BoxOperationResponseUnknownError) {
			if (_outputStream) {
				if (_tempFilePath) {
					// We downloaded the file to a temp file. Delete the original and move the new one in place
					// NOTE: This can fail in normal circumstances if the file simply doesn't exist yet.
					[[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
					if ([[NSFileManager defaultManager] moveItemAtPath:_tempFilePath toPath:self.path error:&error]) {
						responseType = BoxOperationResponseSuccessful;
					} else {
						responseType = BoxOperationResponseDiskError;
						self.error = error;
					}
				} else {
					responseType = BoxOperationResponseSuccessful;
				}
			} else {
				if ([_receivedData writeToFile:_path options:NSDataWritingAtomic error:&error]) {
					responseType = BoxOperationResponseSuccessful;
				} else {
					responseType = BoxOperationResponseDiskError;
					self.error = error;
				}
			}
		}
	} else {
		responseType = BoxOperationResponseInternalAPIError;
	}

	if (!self.error) {
		[self setResponseType:responseType];
	}

	if (_tempFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:_tempFilePath error:nil];
	}

	[super requestDidCompleteWithResponse:response];
}

@end
