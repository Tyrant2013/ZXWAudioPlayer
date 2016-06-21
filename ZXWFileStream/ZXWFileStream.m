//
//  ZXWFileStream.m
//  ZXWAudioPlayer
//
//  Created by 庄晓伟 on 16/6/20.
//  Copyright © 2016年 Zhuang Xiaowei. All rights reserved.
//

#import "ZXWFileStream.h"

#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 10



@interface ZXWFileStream ()

@property (nonatomic, assign) BOOL                          discontinuous;
@property (nonatomic, assign) AudioFileStreamID             audioFileStreamID;
@property (nonatomic, assign) SInt64                        dataOffset;
@property (nonatomic, assign) NSTimeInterval                packetDuration;
@property (nonatomic, assign) UInt64                        processedPacketsCount;
@property (nonatomic, assign) UInt64                        processedPacketSizeTotal;

- (void)handleAudioFileStreamProperty:(AudioFileStreamPropertyID)propertyID;
- (void)handleAudioFileStreamPackets:(const void *)packets
                       numberOfBytes:(UInt32)numberOfBytes
                     numberOfPackets:(UInt32)numberOfPackets
                  packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions;

@end

@implementation ZXWFileStream

static void ZXWAuioFileStreamPropertyListener(void *inClientData,
                                              AudioFileStreamID inAudioFileStream,
                                              AudioFileStreamPropertyID inPropertyID,
                                              UInt32 *ioFlags) {
    ZXWFileStream *audioFileStream = (__bridge ZXWFileStream *)inClientData;
    [audioFileStream handleAudioFileStreamProperty:inPropertyID];
}

static void ZXWAudioFileStreamPacketsCallback(void *inClientData,
                                              UInt32 inNumberBytes,
                                              UInt32 inNumberPackets,
                                              const void *inInputData,
                                              AudioStreamPacketDescription *inPacketDescriptions) {
    ZXWFileStream *audioFileStream = (__bridge ZXWFileStream *)inClientData;
    [audioFileStream handleAudioFileStreamPackets:inInputData
                                    numberOfBytes:inNumberBytes
                                  numberOfPackets:inNumberPackets
                               packetDescriptions:inPacketDescriptions];
}

- (instancetype)initWithFileType:(AudioFileTypeID)fileType fileSize:(unsigned long long)fileSize error:(NSError *__autoreleasing *)error {
    if (self = [super init]) {
        _discontinuous = NO;
        _fileType = fileType;
        _fileSize = fileSize;
        [self __openAudioFileStreamWithFileTypeHint:fileType error:error];
    }
    return self;
}

- (void)dealloc {
    [self __closeAudioFileStream];
}

- (void)__errorForOSStatus:(OSStatus)status error:(NSError *__autoreleasing *)outError {
    if (status != noErr && outError != NULL) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
}

- (BOOL)__openAudioFileStreamWithFileTypeHint:(AudioFileTypeID)fileTypeHint error:(NSError *__autoreleasing *)error {
    NSLog(@"__openAudioFileStreamWithFileTypeHint");
    OSStatus status = AudioFileStreamOpen((__bridge void *)self,
                                          ZXWAuioFileStreamPropertyListener,
                                          ZXWAudioFileStreamPacketsCallback,
                                          fileTypeHint,
                                          &_audioFileStreamID);
    if (status != noErr) {
        _audioFileStreamID = NULL;
    }
    [self __errorForOSStatus:status error:error];
    return status == noErr;
}

- (void)__closeAudioFileStream {
    if (self.available) {
        AudioFileStreamClose(_audioFileStreamID);
        _audioFileStreamID = NULL;
    }
}

- (void)close {
    [self __closeAudioFileStream];
}

- (BOOL)available {
    return _audioFileStreamID != NULL;
}

- (NSData *)fetchMagicCookie {
    UInt32 cookieSize;
    Boolean writable;
    void *cookieData = malloc(cookieSize);
    OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
    if (status != noErr) {
        return nil;
    }
    NSData *cookie = [NSData dataWithBytes:cookieData length:cookieSize];
    free(cookieData);
    
    return cookie;
}

- (BOOL)parseData:(NSData *)data error:(NSError **)error {
    if (self.readyToProducePackets && _packetDuration == 0) {
        [self __errorForOSStatus:-1 error:error];
        return NO;
    }
    OSStatus status = AudioFileStreamParseBytes(_audioFileStreamID,
                                                (UInt32)[data length],
                                                [data bytes],
                                                _discontinuous ? kAudioFileStreamParseFlag_Discontinuity : 0);
    [self __errorForOSStatus:status error:error];
    return status == noErr;
}

- (SInt64)seekToTime:(NSTimeInterval *)time {
    SInt64 approximateSeekOffset = _dataOffset + (*time / _duration) * _audioDataByteCount;
    SInt64 seekToPacket = floor(*time / _packetDuration);
    SInt64 seekByteOffset;
    UInt32 ioFlags = 0;
    SInt64 outDataByteOffset;
    OSStatus status = AudioFileStreamSeek(_audioFileStreamID, seekToPacket, &outDataByteOffset, &ioFlags);
    if (status == noErr && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated)) {
        *time = ((approximateSeekOffset - _dataOffset) - outDataByteOffset) * 8.0 / _bitRate;
        seekByteOffset = outDataByteOffset + _dataOffset;
    }
    else {
        _discontinuous = YES;
        seekByteOffset = approximateSeekOffset;
    }
    return seekByteOffset;
}

- (void)calculateBitRate {
    if (_packetDuration && _processedPacketsCount > BitRateEstimationMinPackets && _processedPacketsCount <= BitRateEstimationMaxPackets) {
        double averagePacketByteSize = _processedPacketSizeTotal / _processedPacketsCount;
        _bitRate = 8.0 * averagePacketByteSize / _packetDuration;
    }
}

- (void)calculateDuration {
    if (_fileSize > 0 && _bitRate > 0) {
        _duration = ((_fileSize - _dataOffset) * 8.0) / _bitRate;
    }
}

- (void)calculatePacketDuration {
    if (_format.mSampleRate > 0) {
        _packetDuration = _format.mFramesPerPacket / _format.mSampleRate;
    }
}

- (void)handleAudioFileStreamProperty:(AudioFileStreamPropertyID)propertyID {
    switch (propertyID) {
        case kAudioFileStreamProperty_ReadyToProducePackets:
            NSLog(@"__readyToProducePackets");
            [self __readyToProducePackets];
            break;
        case kAudioFileStreamProperty_DataOffset:
            NSLog(@"__dataOffset");
            [self __dataOffset];
            break;
        case kAudioFileStreamProperty_DataFormat:
            NSLog(@"__dataFormat");
            [self __dataFormat];
        default:
            break;
    }
}

- (void)__readyToProducePackets {
    _readyToProducePackets = YES;
    _discontinuous = YES;
    
    UInt32 sizeOfUInt32 = sizeof(_maxPacketSize);
    OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfUInt32, &_maxPacketSize);
    if (status != noErr || _maxPacketSize == 0) {
        status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MaximumPacketSize, &sizeOfUInt32, &_maxPacketSize);
    }
    if (_delegate && [_delegate respondsToSelector:@selector(audioFileStreamReadyToProducePackes:)]) {
        [_delegate audioFileStreamReadyToProducePackes:self];
    }
}

- (void)__dataOffset {
    UInt32 offsetSize = sizeof(_format);
    AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataOffset, &offsetSize, &_dataOffset);
    _audioDataByteCount = _fileSize - _dataOffset;
    [self calculateDuration];
    NSLog(@"offsetSize : %d, fileSize : %lld, dataOffset : %lld", offsetSize, _fileSize, _dataOffset);
}

- (void)__dataFormat {
    UInt32 asbdSize = sizeof(_format);
    AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataFormat, &asbdSize, &_format);
    [self calculatePacketDuration];
}

- (void)__formatList {
    Boolean outWritable;
    UInt32 formatListSize;
    OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, &outWritable);
    if (status == noErr) {
        AudioFormatListItem *formatList = malloc(formatListSize);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
        if (status == noErr) {
            UInt32 supportedFormatsSize;
            status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize);
            if (status != noErr) {
                free(formatList);
                return;
            }
            UInt32 supportedFormatCount = supportedFormatsSize / sizeof(OSType);
            OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
            status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize, supportedFormats);
            if (status != noErr) {
                free(formatList);
                free(supportedFormats);
                return;
            }
            for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem)) {
                AudioStreamBasicDescription format = formatList[i].mASBD;
                for (UInt32 j = 0; j < supportedFormatCount; ++j) {
                    if (format.mFormatID == supportedFormats[j]) {
                        _format = format;
                        [self calculatePacketDuration];
                        break;
                    }
                }
            }
            free(supportedFormats);
        }
        free(formatList);
    }
}

- (void)handleAudioFileStreamPackets:(const void *)packets
                       numberOfBytes:(UInt32)numberOfBytes
                     numberOfPackets:(UInt32)numberOfPackets
                  packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions {
    static NSUInteger index = 0;
    ++index;
//    NSLog(@"numberOfPackets : %d, times : %ld", numberOfPackets, index);
    if (_discontinuous) {
        _discontinuous = NO;
    }
    if (numberOfBytes == 0 || numberOfBytes == 0) {
        return;
    }
    BOOL deletePackDesc = NO;
    if (packetDescriptions == NULL) {
        deletePackDesc = YES;
        UInt32 packetSize = numberOfBytes / numberOfPackets;
        AudioStreamPacketDescription *descriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * numberOfPackets);
        for (int i = 0; i < numberOfPackets; ++i) {
            UInt32 packetOffset = packetSize * i;
            descriptions[i].mStartOffset = packetOffset;
            descriptions[i].mVariableFramesInPacket = 0;
            if (i == numberOfPackets - 1) {
                descriptions[i].mDataByteSize = numberOfBytes - packetOffset;
            }
            else {
                descriptions[i].mDataByteSize = packetSize;
            }
        }
        packetDescriptions = descriptions;
    }
    
    NSMutableArray *parsedDataArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < numberOfPackets; ++i) {
        SInt64 packetOffset = packetDescriptions[i].mStartOffset;
        ZXWParsedAudioData *parsedData = [ZXWParsedAudioData parsedAudioDataWithBytes:packets + packetOffset packetDescription:packetDescriptions[i]];
        [parsedDataArray addObject:parsedData];
        
        if (_processedPacketsCount < BitRateEstimationMaxPackets) {
            _processedPacketSizeTotal += parsedData.packetDescription.mDataByteSize;
            _processedPacketsCount += 1;
            [self calculateBitRate];
            [self calculateDuration];
        }
    }
    
    [_delegate audioFileStream:self audioDataParsed:parsedDataArray];
    if (deletePackDesc) {
        free(packetDescriptions);
    }
}

@end


































































