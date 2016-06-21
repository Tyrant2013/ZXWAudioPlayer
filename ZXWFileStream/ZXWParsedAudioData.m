//
//  ZXWParsedAudioData.m
//  ZXWAudioPlayer
//
//  Created by 庄晓伟 on 16/6/20.
//  Copyright © 2016年 Zhuang Xiaowei. All rights reserved.
//

#import "ZXWParsedAudioData.h"

@implementation ZXWParsedAudioData

+ (instancetype)parsedAudioDataWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)packetDescription {
    return [[self alloc] initWithBytes:bytes packetDescription:packetDescription];
}

- (instancetype)initWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)packetDescription {
    if (bytes == NULL || packetDescription.mDataByteSize == 0) {
        return nil;
    }
    if (self = [super init]) {
        _data = [NSData dataWithBytes:bytes length:packetDescription.mDataByteSize];
        _packetDescription = packetDescription;
    }
    return self;
}

@end
