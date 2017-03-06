//
//  ViewController.m
//  Example usage for CSVideoReverse class
//
//  Created by Chris Sung on 3/5/17.
//  Copyright © 2017 chrissung. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController {
	NSString *outputPath;
	AVPlayer *avPlayer;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	// get our test input file
	NSString *inputPath = [[NSBundle mainBundle] pathForResource:@"input" ofType:@"mov"];
	
	// create a path for our reversed output video
	NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	outputPath = [documentsPath stringByAppendingFormat:@"/reversed.mov"];
	
	// get instance of our reverse video class
	CSVideoReverse *reverser = [[CSVideoReverse alloc] init];
	reverser.delegate = self;
	reverser.showDebug = YES; // NSLog the details from the reversal processing?
	
	// if custom reader settings are desired
	//  kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange seems to be the most common pixel type among Instagram, Facebook, Twitter, et al
	reverser.readerOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey, nil];
	
	// now start the reversal process
	[reverser reverseVideoAtPath:inputPath outputPath:outputPath];
}

#pragma mark CSVideoReverseDelegate Methods
- (void)didFinishReverse:(bool)success withError:(NSError *)error {
	if (!success) {
		NSLog(@"%s error: %@", __FUNCTION__, error.localizedDescription);
		return;
	}
	
	// othewise, let's show the reversed video
	[self showReversedVideo];
}

- (void)showReversedVideo {
	NSURL *outputUrl = [NSURL fileURLWithPath:outputPath isDirectory:NO];
	AVURLAsset *asset = [AVURLAsset URLAssetWithURL:outputUrl options:nil];
	
	AVPlayerItem *item = [[AVPlayerItem alloc] initWithAsset:asset];
	avPlayer = [[AVPlayer alloc] initWithPlayerItem:item];
	
	AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:avPlayer];
	
	// get the view size
	CGSize size = self.view.bounds.size;
	
	// get the video size
	AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
	CGFloat outputWidth = videoTrack.naturalSize.width;
	CGFloat outputHeight = videoTrack.naturalSize.height;
	
	// handle any orientation specifics
	CGAffineTransform txf = [videoTrack preferredTransform];
	bool isPortrait = NO;
	
	if (txf.a == 0 && txf.b == 1.0 && txf.c == -1.0 && txf.d == 0) { // PortraitUp
		isPortrait = YES;
	}
	else if (txf.a == 0 && txf.b == -1.0 && txf.c == 1.0 && txf.d == 0) { // PortraitDown
		isPortrait = YES;
	}
	
	// swap dims if relevant
	if (isPortrait && outputWidth > outputHeight) {
		outputWidth = videoTrack.naturalSize.height;
		outputHeight = videoTrack.naturalSize.width;
	}
	else if (!isPortrait && outputHeight > outputWidth) {
		outputWidth = videoTrack.naturalSize.height;
		outputHeight = videoTrack.naturalSize.width;
	}
	
	// scale the playerLayer to the view
	CGFloat widthScale = outputWidth / size.width;
	CGFloat heightScale = outputHeight / size.height;
	CGFloat maxScale = widthScale > heightScale ? widthScale : heightScale;
	
	CGFloat displayWidth = outputWidth / maxScale;
	CGFloat displayHeight = outputHeight / maxScale;
	
	float x = (size.width - displayWidth) / 2.0;
	float y = (size.height - displayHeight) / 2.0;
	
	playerLayer.frame = CGRectMake(x, y, displayWidth, displayHeight);
	[playerLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
	[self.view.layer addSublayer:playerLayer];
	
	// set up looping
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
																										object:nil
																										 queue:nil
																								usingBlock:^(NSNotification *note) {
																									[avPlayer seekToTime:kCMTimeZero]; // loop
																									[avPlayer play];
																								}];
	
	// add tap events to the view
	[[self view] addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)]];
	
	[avPlayer play];
}

// dual purpose tap for start/stop of video
- (void)handleTap:(UITapGestureRecognizer *)sender {
	if (sender.state == UIGestureRecognizerStateEnded) {
		if (avPlayer.rate > 0 && !avPlayer.error) { // playing, so pause
			[avPlayer pause];
		}
		else { // stopped, so play
			[avPlayer play];
		}
	}
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

@end
