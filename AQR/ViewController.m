//
//  ViewController.m
//  AQR
//
//  Created by elpeo on 13/02/16.
//  Copyright (c) 2013年 elpeo. All rights reserved.
//

#import "ViewController.h"
#import "ZBarImageScanner.h"
#import "NSData+Base64.h"
#import <CoreVideo/CoreVideo.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    buffer = [NSMutableDictionary dictionary];
    total = 0;
    
    captureSession = [[AVCaptureSession alloc] init];
    
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *videoCaptureDevice = nil;
    for (AVCaptureDevice *device in videoDevices){
        if (device.position == AVCaptureDevicePositionBack){
            videoCaptureDevice = device;
            break;
        }
    }
    if(!videoCaptureDevice){
        NSLog(@"%s|[ERROR] %@", __PRETTY_FUNCTION__, @"VIDEO DEVICE NOT FOUND.");
        return;
    }
    
    NSError* error = nil;
    AVCaptureDeviceInput* videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoCaptureDevice error:&error];

    if (!videoInput) {
        return;
    }

    [captureSession addInput:videoInput];
    [captureSession beginConfiguration];
    [captureSession setSessionPreset:AVCaptureSessionPreset640x480];
    [captureSession commitConfiguration];
    
    /*
    if ([videoCaptureDevice lockForConfiguration:&error]) {
        if ([videoCaptureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            videoCaptureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            
        } else if ([videoCaptureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            videoCaptureDevice.focusMode = AVCaptureFocusModeAutoFocus;
        }
        if ([videoCaptureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            videoCaptureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        } else if ([videoCaptureDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
            videoCaptureDevice.exposureMode = AVCaptureExposureModeAutoExpose;
        }
        
        if ([videoCaptureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            videoCaptureDevice.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
        } else if ([videoCaptureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
            videoCaptureDevice.whiteBalanceMode = AVCaptureWhiteBalanceModeAutoWhiteBalance;
        }
        
        if ([videoCaptureDevice isFlashModeSupported:AVCaptureFlashModeAuto]) {
            videoCaptureDevice.flashMode = AVCaptureFlashModeAuto;
        }
        [videoCaptureDevice unlockForConfiguration];
        
    } else {
        NSLog(@"%s|[ERROR] %@", __PRETTY_FUNCTION__, error);
    }
    */

    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
//  captureOutput.alwaysDiscardsLateVideoFrames = YES;
//  dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [captureOutput setSampleBufferDelegate:self queue:queue];
//  dispatch_release(queue);
//  NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
//  NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
//                                 [NSNumber numberWithDouble:320], (id)kCVPixelBufferWidthKey,
//                                 [NSNumber numberWithDouble:320], (id)kCVPixelBufferHeightKey,
                                   [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], (id)kCVPixelBufferPixelFormatTypeKey,
                                   nil];
    [captureOutput setVideoSettings:videoSettings];
    [captureSession addOutput:captureOutput];
    
    AVCaptureConnection *connection = [captureOutput connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    connection.videoMinFrameDuration = CMTimeMake(1, 30);
    
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:previewLayer];

    [captureSession startRunning];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tapGesture];
//  UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
//  [self.view addGestureRecognizer:pinchGesture];

    CGSize size = self.view.bounds.size;
    percent = [[UILabel alloc] initWithFrame:CGRectMake(size.width/2-100, size.height/2-100, 200, 100)];
    percent.font = [UIFont fontWithName:@"Futura-Medium" size:100.0];
    percent.adjustsFontSizeToFitWidth = YES;
    percent.numberOfLines = 1;
    percent.textColor = [UIColor whiteColor];
    percent.backgroundColor = [UIColor clearColor];
    percent.hidden = YES;
    [self.view addSubview:percent];    
    progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progress.frame = CGRectMake(20, size.height/2, size.width-40, 11);
    progress.progressTintColor = [UIColor whiteColor];
    progress.trackTintColor = [UIColor blackColor];
    progress.hidden = YES;
    [self.view addSubview:progress];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)handleTap:(UITapGestureRecognizer*)sender
{
    AVCaptureDeviceInput* videoInput = [captureSession.inputs objectAtIndex:0];
    AVCaptureDevice* videoCaptureDevice = videoInput.device;
    NSError* error = nil;
    if ([videoCaptureDevice lockForConfiguration:&error]) {
        if (videoCaptureDevice.focusPointOfInterestSupported) {
            CGPoint p = [sender locationInView:self.view];
            CGSize viewSize = self.view.frame.size;
            CGPoint pointOfInterest = CGPointMake(p.y / viewSize.height, 1.0 - p.x / viewSize.width);
            //NSLog(@"%@ %@ %@", NSStringFromCGPoint(p), NSStringFromCGSize(viewSize), NSStringFromCGPoint(pointOfInterest));
            videoCaptureDevice.focusPointOfInterest = pointOfInterest;
            videoCaptureDevice.focusMode = AVCaptureFocusModeAutoFocus;
        }
        [videoCaptureDevice unlockForConfiguration];
    } else {
        NSLog(@"%s|[ERROR] %@", __PRETTY_FUNCTION__, error);
    }
}

/*
- (void)handlePinch:(UIPinchGestureRecognizer*)sender
{
//    AVCaptureVideoDataOutput* captureOutput = [captureSession.outputs objectAtIndex:0];
//    AVCaptureConnection *connection = [captureOutput connectionWithMediaType:AVMediaTypeVideo];
    CGAffineTransform scale = CGAffineTransformMakeScale(sender.scale, sender.scale);
    CALayer* layer = [self.view.layer.sublayers objectAtIndex:0];
    CGAffineTransform at = CGAffineTransformConcat(scale, [layer affineTransform]);
//    NSLog(@"%f", f);
    [CATransaction begin];
    [CATransaction setAnimationDuration:.025];
    [layer setAffineTransform:scale];
    [CATransaction commit];
}
 */

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if(total > 0 && [buffer count] == total) return;
    
    @autoreleasepool {
        CVImageBufferRef buf = CMSampleBufferGetImageBuffer(sampleBuffer);
        if(CMSampleBufferGetNumSamples(sampleBuffer) != 1 ||
           !CMSampleBufferIsValid(sampleBuffer) ||
           !CMSampleBufferDataIsReady(sampleBuffer) ||
           !buf) {
            NSLog(@"ERROR: invalid sample");
            return;
        }
        
        OSType format = CVPixelBufferGetPixelFormatType(buf);
        int planes = CVPixelBufferGetPlaneCount(buf);
        
        if(format != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
           !planes) {
            NSLog(@"ERROR: invalid buffer format");
            return;
        }
        
        int w = CVPixelBufferGetBytesPerRowOfPlane(buf, 0);
        int h = CVPixelBufferGetHeightOfPlane(buf, 0);
        CVReturn rc = CVPixelBufferLockBaseAddress(buf, kCVPixelBufferLock_ReadOnly);
        if(!w || !h || rc) {
            NSLog(@"ERROR: invalid buffer data");
            return;
        }
        
//        NSLog(@"%dx%d", w, h);
        
        void *data = CVPixelBufferGetBaseAddressOfPlane(buf, 0);
        if(!data){
            NSLog(@"ERROR: invalid data");
            CVPixelBufferUnlockBaseAddress(buf, 0);
            return;
        }

        ZBarImage* image = [ZBarImage new];
        image.format = [ZBarImage fourcc: @"Y800"];
        image.size = CGSizeMake(w, h);
        [image setData: data withLength: w*h];
        
        ZBarImageScanner* scanner = [ZBarImageScanner new];
        scanner.enableCache = NO;
        [scanner setSymbology:0 config:ZBAR_CFG_ENABLE to:0];
        [scanner setSymbology:ZBAR_QRCODE config:ZBAR_CFG_ENABLE to:1];
//      [scanner setSymbology: 0 config: ZBAR_CFG_X_DENSITY to: 3];
//      [scanner setSymbology: 0 config: ZBAR_CFG_Y_DENSITY to: 3];
        [scanner scanImage: image];

        CVPixelBufferUnlockBaseAddress(buf, kCVPixelBufferLock_ReadOnly);

        ZBarSymbolSet *symbols = scanner.results;
        for(ZBarSymbol *symbol in symbols) {
// for raw binary
            const char* buf = zbar_symbol_get_data(symbol.zbarSymbol);
            int len = zbar_symbol_get_data_length(symbol.zbarSymbol);
            int num = (int)(buf[0] & 0xff);
            int all = (int)(buf[1] & 0xff);
            
            NSLog(@"%d/%d", num, all);

            NSNumber* key = [NSNumber numberWithInt:num];
            @synchronized(buffer){
                if(![buffer objectForKey:key]){
                    NSData* value = [NSData dataWithBytes:buf+2 length:len-2];
                    [buffer setObject:value forKey:key];
                    total = all;
                    if([buffer count] == total){
                        NSLog(@"Complete!");
                        [self performSelectorOnMainThread:@selector(showImage) withObject:nil waitUntilDone:NO];
                    }else{
                        [self performSelectorOnMainThread:@selector(showProgress) withObject:nil waitUntilDone:NO];
                    }
                }
            }
            
// for base64 binary
/*
            int num = [[symbol.data substringWithRange:NSMakeRange(0, 3)] intValue];
            int all = [[symbol.data substringWithRange:NSMakeRange(3, 3)] intValue];

            NSLog(@"%d/%d", num, all);

            NSNumber* key = [NSNumber numberWithInt:num];
            @synchronized(buffer){
                if(![buffer objectForKey:key]){
                    NSString* value = [symbol.data substringFromIndex:6];
                    [buffer setObject:value forKey:key];
                    total = all;
                    if([buffer count] == total){
                        NSLog(@"Complete!");
                        [self performSelectorOnMainThread:@selector(showImage) withObject:nil waitUntilDone:NO];
                    }else{
                        [self performSelectorOnMainThread:@selector(showProgress) withObject:nil waitUntilDone:NO];
                    }
                }
            }
 */
            break;
        }
    }
}

- (void)showImage
{
    progress.progress = 1.0f;
// for raw binary
    NSMutableData* data = [NSMutableData data];
    for(int i=0;i<total;i++){
        NSNumber* key = [NSNumber numberWithInt:i];
        NSData* value = [buffer objectForKey:key];
        if(value){
            [data appendData:value];
        }else{
            NSLog(@"%d is not found.", i);
        }
    }
// for base64 binary
/*
    NSMutableString* str = [NSMutableString string];
    for(int i=0;i<total;i++){
        NSNumber* key = [NSNumber numberWithInt:i];
        NSString* value = [buffer objectForKey:key];
        if(value){
            [str appendString:value];
        }else{
            NSLog(@"%d is not found.", i);
        }
    }
    NSData* data = [NSData dataFromBase64String:str];
*/
    UIImage* image = [UIImage imageWithData:data];
    NSLog(@"width=%d height=%d", (int)image.size.width, (int)image.size.height);

    if(image){
        UIView* view = [[UIView alloc] initWithFrame:self.view.bounds];
        view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        
        UIImageView* iv = [[UIImageView alloc] initWithImage:image];
        iv.userInteractionEnabled = YES;
//        UIWebView* iv  = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, image.size.width, image.size.height)];
//        [iv loadData:data MIMEType:@"image/jpeg" textEncodingName:nil baseURL:nil];
        CGRect rect = iv.bounds;
        rect.origin.x = (self.view.bounds.size.width - rect.size.width)/2;
        rect.origin.y = (self.view.bounds.size.height - rect.size.height)/2;
        iv.frame = rect;
        CALayer* layer = iv.layer;
        layer.shadowOffset = CGSizeMake(2.5, 2.5);
        layer.shadowColor = [[UIColor blackColor] CGColor];
        layer.shadowOpacity = 0.5;
        [view addSubview:iv];
        [self.view addSubview:view];
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(reset:)];
        [view addGestureRecognizer:tapGesture];
    }else{
        NSLog(@"Image error");
        [buffer removeAllObjects];
        total = 0;
//      NSLog(@"%@", data);
    }
    percent.hidden = YES;
    progress.hidden = YES;
}

- (void)showProgress
{
    float f =  (float)[buffer count]/total;
    percent.text = [NSString stringWithFormat:@"%d%%", (int)(f*100)];
    percent.hidden = NO;
    progress.progress = (float)[buffer count]/total;
    progress.hidden = NO;
}

- (void)reset:(UITapGestureRecognizer*)sender
{
    NSLog(@"Reset");
    [buffer removeAllObjects];
    total = 0;
    [sender.view removeFromSuperview];
}

@end
