//
//  ViewController.m
//  ZXWAudioPlayer
//
//  Created by 庄晓伟 on 16/6/20.
//  Copyright © 2016年 Zhuang Xiaowei. All rights reserved.
//

#import "ViewController.h"
#import "ZXWFileStream.h"

@interface ViewController () <ZXWFileStreamDelegate>

@property (nonatomic, strong) ZXWFileStream                 *audioFileStream;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    int i = 0;
    char *ch = "aaaaaa";
    NSLog(@"%lu, %lu, %lu, %lu, %lu, %lu", sizeof(i), sizeof(int), sizeof("aaaaaa"), sizeof(char *), sizeof(&ch), sizeof(*ch));
}

- (void)viewDidAppear:(BOOL)animated {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
    NSError *error = nil;
    _audioFileStream = [[ZXWFileStream alloc] initWithFileType:kAudioFileMP3Type fileSize:fileSize error:&error];
    _audioFileStream.delegate = self;
    if (error) {
        _audioFileStream = nil;
        NSLog(@"create audio file stream failed, error: %@",[error description]);
    }
    else {
        NSLog(@"audio file opened. size : %lld", fileSize);
        if (file) {
            NSUInteger lengthPerRead = 10000;
            while (fileSize > 0) {
                NSData *data = [file readDataOfLength:lengthPerRead];
                fileSize -= [data length];
                [_audioFileStream parseData:data error:&error];
                if (error) {
                    if (error.code == kAudioFileStreamError_NotOptimized) {
                        NSLog(@"audio not optimized.");
                    }
                    break;
                }
            }
            [_audioFileStream close];
            _audioFileStream = nil;
            NSLog(@"audio file closed.");
            [file closeFile];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)audioFileStream:(ZXWFileStream *)audioFileStream audioDataParsed:(NSArray *)audioData {
//    NSLog(@"data parsed, should be filled in buffer.");
}

- (void)audioFileStreamReadyToProducePackes:(ZXWFileStream *)audioFileStream {
    NSLog(@"audio format: bitrate = %zd, duration = %lf.",_audioFileStream.bitRate,_audioFileStream.duration);
    NSLog(@"audio ready to produce packets.");
}

@end
