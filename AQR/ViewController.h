//
//  ViewController.h
//  AQR
//
//  Created by elpeo on 13/02/16.
//  Copyright (c) 2013年 elpeo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession *captureSession;
    UIProgressView* progress;
    UILabel* percent;
    NSMutableDictionary* buffer;
    NSUInteger total;
}

@end
