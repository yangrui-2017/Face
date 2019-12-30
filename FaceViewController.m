//
//  FaceViewController.m
//  Demo02
//
//  Created by sinosoft on 2019/12/27.
//  Copyright © 2019 sinosoft. All rights reserved.
//

#import "FaceViewController.h"
#import <AVFoundation/AVFoundation.h>
#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define WS(weakSelf) __weak __typeof(&*self) weakSelf = self
@interface FaceViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic,strong) AVCaptureSession *session;
@property (nonatomic,strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic,strong) AVCaptureDeviceInput*input;
@property (nonatomic,strong) AVCaptureVideoDataOutput *videoOutput;
@property(nonatomic,strong) UIImageView *faceImgView;
@property(nonatomic,assign)BOOL isFirst;


@end

@implementation FaceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"人脸识别";

    _isFirst = YES;
    [self deviceInit];
    [self initUI];
}


-(void)initUI{
    _faceImgView = [[UIImageView alloc] initWithFrame:CGRectMake(kWidth - 120 , 64, 120, 120)];
    _faceImgView.backgroundColor = [UIColor blueColor];
    [self.view addSubview:_faceImgView];


    UILabel *titleLab = [[UILabel alloc] initWithFrame:CGRectMake(52, 100, kWidth - 108, 18)];
    titleLab.text = @"请对准脸部拍摄  提高认证成功率";
    titleLab.textAlignment = NSTextAlignmentCenter;
    titleLab.textColor = [UIColor redColor];
    titleLab.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:titleLab];
}


-(void)deviceInit{

    //1.获取输入设备（摄像头）
    NSArray *devices = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront].devices;
    AVCaptureDevice *deviceF = devices[0];

    //2.根据输入设备创建输入对象
    self.input = [[AVCaptureDeviceInput alloc] initWithDevice:deviceF error:nil];

    // 设置代理监听输出对象输出的数据
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];

    //对实时视频帧进行相关的渲染操作,指定代理
    [_videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];

    self.session = [[AVCaptureSession alloc] init];

    //5.设置输出质量(高像素输出)
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [self.session setSessionPreset:AVCaptureSessionPreset640x480];
    }
    //6.添加输入和输出到会话
    [self.session beginConfiguration];

    if ([self.session canAddInput:_input]) {
        [self.session addInput:_input];
    }

    if ([self.session canAddOutput:_videoOutput]) {
        [self.session addOutput:_videoOutput];
    }

    [self.session commitConfiguration];

    AVCaptureSession *session = (AVCaptureSession *)self.session;

    //8.创建预览图层
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _previewLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:_previewLayer atIndex:0];


    //10. 开始扫描
    [self.session startRunning];

}


//显示图片，这里可以请求后台接口
-(void)uploadFaceImg:(UIImage *)image{
    _faceImgView.image = image;

    WS(weakSelf);
    //这里设置为2秒后可以进行继续检测
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        weakSelf.isFirst = YES;
    });
}


//imageFromSampleBuffer:方法，将CMSampleBufferRef转为NSImage
- (void )imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    //CIImage -> CGImageRef -> UIImage
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);  //拿到缓冲区帧数据
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];            //创建CIImage对象
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];           //创建上下文

    //识别脸部
    CIDetector *detector=[CIDetector detectorOfType:CIDetectorTypeFace context:temporaryContext options:@{CIDetectorAccuracy: CIDetectorAccuracyLow}]; //CIDetectorAccuracyLow：识别精度低，但识别速度快、性能高
    //CIDetectorAccuracyHigh：识别精度高、但识别速度比较慢
    NSArray *faceArray = [detector featuresInImage:ciImage
                                           options:nil];

    //得到人脸图片的尺寸
    if (faceArray.count) {
        NSLog(@"faceArray == %@",faceArray);
        WS(weakSelf);
        for (CIFaceFeature * faceFeature in faceArray) {
            if (faceFeature.hasLeftEyePosition && faceFeature.hasRightEyePosition  && faceFeature.hasMouthPosition) {
                NSLog(@"_isFirst == %d",_isFirst);
                //这个布尔值用于判断检测到人脸后，获取到人脸照片，不用再进行持续检测
                if (_isFirst) {
                    //因为刚开始扫描到的人脸是模糊照片，所以延迟几秒获取
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        CGImageRef cgImageRef = [temporaryContext createCGImage:ciImage fromRect:faceFeature.bounds];

                        //resultImg即为获得的人脸图片
                        UIImage   *resultImg = [[UIImage alloc] initWithCGImage:cgImageRef scale:2.0 orientation:UIImageOrientationLeftMirrored];

                        //显示人脸图片，这里可以将图片转为NSdata类型
                        [self uploadFaceImg:resultImg];
                        //置为NO
                        weakSelf.isFirst = NO;
                    });

                }
            }
        }
    }

}


#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
//AVCaptureVideoDataOutput获取实时图像，这个代理方法的回调频率很快，几乎与手机屏幕的刷新频率一样快
- (void)captureOutput:(AVCaptureOutput*)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection{
    [self imageFromSampleBuffer:sampleBuffer];
}






/*
 #pragma mark - Navigation
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */


@end
