//
//  ZXWFileStream.h
//  ZXWAudioPlayer
//
//  Created by 庄晓伟 on 16/6/20.
//  Copyright © 2016年 Zhuang Xiaowei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "ZXWParsedAudioData.h"

@class ZXWFileStream;

@protocol ZXWFileStreamDelegate <NSObject>

@required
- (void)audioFileStream:(ZXWFileStream *)audioFileStream audioDataParsed:(NSArray *)audioData;

@optional
- (void)audioFileStreamReadyToProducePackes:(ZXWFileStream *)audioFileStream;

@end

@interface ZXWFileStream : NSObject

@property (nonatomic, assign, readonly) AudioFileTypeID             fileType;
@property (nonatomic, assign, readonly) BOOL                        available;
@property (nonatomic, assign, readonly) BOOL                        readyToProducePackets;
@property (nonatomic, weak) id<ZXWFileStreamDelegate>               delegate;

@property (nonatomic, assign, readonly) AudioStreamBasicDescription format;
@property (nonatomic, assign, readonly) unsigned long long          fileSize;
@property (nonatomic, assign, readonly) NSTimeInterval              duration;
@property (nonatomic, assign, readonly) UInt32                      bitRate;
@property (nonatomic, assign, readonly) UInt32                      maxPacketSize;
@property (nonatomic, assign, readonly) UInt64                      audioDataByteCount;

- (instancetype)initWithFileType:(AudioFileTypeID)fileType fileSize:(unsigned long long)fileSize error:(NSError **)error;

- (BOOL)parseData:(NSData *)data error:(NSError **)error;

/**
 seek to timeinterval
 @param 输入，需要跳转的时间
        输出，调整后的跳转时间
 @return seek byte offset
 */
- (SInt64)seekToTime:(NSTimeInterval *)time;

- (NSData *)fetchMagicCookie;

- (void)close;

@end
