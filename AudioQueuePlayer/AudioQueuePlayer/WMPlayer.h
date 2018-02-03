//
//  WMPlayer.h
//  BLEShoes
//
//  Created by Heaton on 2017/12/18.
//  Copyright © 2017年 wangming. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface WMPlayer : NSObject
// 采样率
@property(nonatomic,assign) Float64 sampleRate;
// 声道数
@property(nonatomic,assign) UInt32  channels;
// 量化数
@property(nonatomic,assign) UInt32  bitsPerChannel;
// 音量
@property(nonatomic,assign) CGFloat volume;

// 数据队列
@property(nonatomic,strong) NSMutableData *dataQueue;

/**
 初始化播放器参数
 
 @param sampleRate     音频采样率
 @param channels       音频声道数 1位单声道
 @param bitsPerChannel 每个采样点的量化数,一般为8或16
 @param volume         音量
 @return player
 
 */
-(instancetype)initSampleRate:(Float64)sampleRate
               ChannelsNumber:(UInt32)channels
               BitsPerChannel:(UInt32)bitsPerChannel
                       volume:(CGFloat)volume;
// 播放的数据流数据
-(void)playWithData:(NSData *)data length:(UInt32)length;
// 声音播放出现问题的时候可以重置一下
- (void)resetPlay;
// 是否立刻停止播放
- (void)stopWithInImmediat:(BOOL)inImmediate;
- (void)addBufferWithData:(NSData *)buffer;
@end
