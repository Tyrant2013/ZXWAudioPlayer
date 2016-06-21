//
//  ZXWParsedAudioData.h
//  ZXWAudioPlayer
//
//  Created by 庄晓伟 on 16/6/20.
//  Copyright © 2016年 Zhuang Xiaowei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface ZXWParsedAudioData : NSObject

@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) AudioStreamPacketDescription packetDescription;

+ (instancetype)parsedAudioDataWithBytes:(const void *)bytes
                       packetDescription:(AudioStreamPacketDescription)packetDescription;

@end
