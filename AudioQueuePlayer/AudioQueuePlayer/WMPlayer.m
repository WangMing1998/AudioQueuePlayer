//
//  WMPlayer.m
//  BLEShoes
//
//  Created by Heaton on 2017/12/18.
//  Copyright © 2017年 wangming. All rights reserved.
//

#import "WMPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/CADisplayLink.h>
#define MIN_SIZE_PER_FRAME 2000  //每个包的大小
#define QUEUE_BUFFER_SIZE 3   //缓冲器个数


@interface WMPlayer(){
    AudioQueueRef audioQueue;                                 // 音频播放队列
    AudioStreamBasicDescription _format;                      // 音频格式
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE]; // 音频缓存
    BOOL audioQueueBufferUsed[QUEUE_BUFFER_SIZE];             // 判断音频缓存是否在使用
    NSLock *sysnLock;                                         // 同步锁
    NSMutableData *tempData;                                  // 缓存数据
    OSStatus osState;                                         // 播放器状态
    
    NSThread *playerThread;                                   // 播放线程
    NSTimer *playerTimer;                                     // 播放测试定时器
    BOOL     isEnd;                                           // 是否结束了播放
    dispatch_source_t timer;
    
    
}
@end


@implementation WMPlayer
+(void)initialize{
    NSError *error = nil;
    //只想要播放:AVAudioSessionCategoryPlayback
    //只想要录音:AVAudioSessionCategoryRecord
    //想要"播放和录音"同时进行 必须设置为:AVAudioSessionCategoryMultiRoute
    AVAudioSession *session = [AVAudioSession sharedInstance];
    BOOL ret = [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!ret) {
        NSLog(@"设置声音环境失败");
        return;
    }
    //启用audio session
    ret = [session setActive:YES error:&error];
    if (!ret)
    {
        NSLog(@"启动失败");
        return;
    }
    
   
}

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
                       volume:(CGFloat)volume{
    if(self = [super init]){
        _sampleRate = sampleRate;
        _channels = channels;
        _volume = volume;
        _bitsPerChannel = bitsPerChannel;
        [self resetSetting];
//        playerThread = [[NSThread alloc] initWithTarget:self selector:@selector(playerThread) object:nil];
//        [playerThread start];
        
        

//       playerTimer = [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
//        [[NSRunLoop mainRunLoop] addTimer:playerTimer forMode:NSDefaultRunLoopMode];
    }
    return self;
}

-(void)resetSetting{
    [self stopWithInImmediat:YES];
    sysnLock = [[NSLock alloc] init];
    _format.mSampleRate = _sampleRate;
    _format.mFormatID = kAudioFormatLinearPCM;
    _format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked;
    _format.mFramesPerPacket = 1;
    _format.mChannelsPerFrame =_channels;
    _format.mBitsPerChannel = _bitsPerChannel;//
    _format.mBytesPerFrame = (_format.mBitsPerChannel/8) * _format.mChannelsPerFrame;
    _format.mBytesPerPacket = _format.mBytesPerFrame * _format.mFramesPerPacket;
    
    // 使用player的内部线程播放，新建输出
    osState = AudioQueueNewOutput(&_format, AudioPlayerAQInputCallback, (__bridge void * _Nullable)(self), NULL,NULL, 0, &audioQueue);
    if(osState != noErr){
        NSLog(@"AudioQueueNewOutput Fail");
    }
    
    NSLog(@"\n采样率:%.f\n通道数:%u\n采样位数:%u\n",_format.mSampleRate,(unsigned int)_format.mChannelsPerFrame,(unsigned int)_format.mBitsPerChannel);
    
    // 设置音量
    osState = AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume,_volume);
    if(osState != noErr){
        NSLog(@"set Volume Fail");
    }
    // //初始化音频缓冲区--audioQueueBuffers为结构体数组
    for(int i = 0; i < QUEUE_BUFFER_SIZE;i++){
        int result = AudioQueueAllocateBuffer(audioQueue,MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);
        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d", i, result);
    }
    
    NSLog(@"PCMDataPlayer reset");
}


/**
 播放完buffer回调,把buffer状态设为未使用

 @param inUserData
 @param audioQueueRef       当前播放队列
 @param audioQueueBufferRef 已经使用过的buffer
 */
static void AudioPlayerAQInputCallback(void* inUserData,AudioQueueRef audioQueueRef, AudioQueueBufferRef audioQueueBufferRef) {
    NSLog(@"processAudioData :%u", (unsigned int)audioQueueBufferRef->mAudioDataByteSize);
    WMPlayer *player = (__bridge WMPlayer*)inUserData;
    [player playerCallback:audioQueueBufferRef];
}

- (void)playerCallback:(AudioQueueBufferRef)outQB
{
    NSLog(@"---消费了buffer:%d---\r\n",outQB->mAudioDataByteSize);
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        if (outQB == audioQueueBuffers[i]) {
            audioQueueBufferUsed[i] = NO;
        }
    }
}

/**
 停止播放
 
 @param inImmediate 是否立刻停止
 */
- (void)stopWithInImmediat:(BOOL)inImmediate{
    if(audioQueue != nil){
        AudioQueueStop(audioQueue, inImmediate);
        AudioQueueReset(audioQueue);
        audioQueue = nil;
    }
}

-(void)playWithData:(NSData *)data length:(UInt32)length{
    if(audioQueue == nil || ![self checkBufferHasUsed]){
        [self resetSetting];
        AudioQueueStart(audioQueue,NULL);
    }

    [sysnLock lock];// 上锁
  //  data = [self changeMonoToStereo:data muteLeft:YES];
    AudioQueueBufferRef audioQueueBuffer = NULL;
    while(true){// 取出音频缓存数组
        audioQueueBuffer = [self getNotUsedBuffer];
        if(audioQueueBuffer != NULL){
            break;
        }
    }
    // 将数据填充到缓存数组并加入队列
    audioQueueBuffer->mAudioDataByteSize = length;// 填充数据长度
    Byte *audioData = audioQueueBuffer->mAudioData;// 数据指针指向填充的数据
    memcpy(audioData,[data bytes],length);// 给audioData赋值即是给audioQueueBuffer赋值
    AudioQueueEnqueueBuffer(audioQueue,audioQueueBuffer,0, NULL);// 填充buffer,系统自动播放
    
    [sysnLock unlock];
}

- (AudioQueueBufferRef)getNotUsedBuffer
{
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        if (NO == audioQueueBufferUsed[i]) {
            audioQueueBufferUsed[i] = YES;
            NSLog(@"PCMDataPlayer play buffer index:%d", i);
            return audioQueueBuffers[i];
        }
    }
    return NULL;
}

- (BOOL)checkBufferHasUsed
{
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        if (YES == audioQueueBufferUsed[i]) {
            return YES;
        }
    }
    NSLog(@"Player 播放中断............");
    return NO;
}

/**
 声音播放出现问题的时候 重置播放器
 */
- (void)resetPlay{
    if(audioQueue != nil){
        AudioQueueReset(audioQueue);
    }
}

- (void)dealloc
{
    if (audioQueue != nil) {
        AudioQueueStop(audioQueue, true);
    }
    audioQueue = nil;
    
    sysnLock = nil;
    
    NSLog(@"WMPlayer dealloc...");
}
#pragma mark 单声道转双声道,静音其中一声道
/**
 双通道转单通道，将其中一通道填0即是静音

 @param srcData 输入数据
 @param muteleft 禁止通道
 @return 新的音频数据
 */
- (NSData *) changeMonoToStereo:(NSData *) srcData muteLeft:(BOOL )muteleft
{
    NSMutableData * mdata = [[NSMutableData alloc] initWithCapacity:srcData.length*2];
    Byte  muteData[2] ={0x00,0x00};
    Byte * srcDatap= (Byte *)srcData.bytes;
    for (long i=0;i<srcData.length/2; i++) {
        if (muteleft) {
            [mdata appendBytes:muteData length:2];
            [mdata appendBytes:srcDatap length:2];
        }
        else{
            [mdata appendBytes:srcDatap length:2];
            [mdata appendBytes:muteData length:2];
        }
        srcDatap +=2;
    }
    return [mdata subdataWithRange:NSMakeRange(0, mdata.length)];
}

#pragma mark getter dataQueue
-(NSMutableData *)dataQueue{
    if(_dataQueue == nil){
        _dataQueue = [NSMutableData data];
    }
    return _dataQueue;
}

-(void)addBufferWithData:(NSData *)buffer{
    NSLog(@"添加buffer,length = %ld",buffer.length);
    @synchronized(self.dataQueue)
    {
        [self.dataQueue appendData:buffer];
        NSLog(@"commandLstLength:%ld\n",self.dataQueue.length);
        
    }
}

-(NSData *)readBufferWithSize:(NSInteger)length isEof:(BOOL *) eof
{
    *eof = NO;
    @synchronized(self.dataQueue)
    {
        NSMutableData * data = [[NSMutableData alloc] init];
        Byte replacesample = 0x00;
        NSInteger minlength = length > _dataQueue.length ? _dataQueue.length:length;
        if (_dataQueue.length > 0) {
     
            [data appendData:[_dataQueue subdataWithRange:NSMakeRange(0, minlength)]];
            NSLog(@"队列长度:%ld",_dataQueue.length);
            [_dataQueue replaceBytesInRange:NSMakeRange(0,minlength) withBytes:NULL length:0];
        }
        
//        long rewindSamplesCount = (length - minlength)/2;
//        if(minlength != length)
//        {
//            //            for(NSInteger i=0;i< length - minlength;i++)
//            //                [data appendBytes:&replacesample length:1];
//            int16_t posiSample = 10000;
//            int16_t negeSample = -10000;
//            for(NSInteger i=0;i<rewindSamplesCount;i++)
//            {
//                if(i%2 == 0){
//                    [data appendBytes:&posiSample length:2];
//                }else{
//                    [data appendBytes:&negeSample length:2];
//                }
//            }
//        }
        
        return data;
    }
}


-(void)timerFired:(NSTimer *)timer{
//    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
//    [formatter setDateFormat:@"YYYY-MM-dd hh:mm:ss:SSS"];
//    NSDate *datenow = [NSDate date];
//    NSString *nowtimeStr = [formatter stringFromDate:datenow];
//    NSLog(@"\n当前时间:%@\n",nowtimeStr);
    NSData *data = [self readBufferWithSize:MIN_SIZE_PER_FRAME/2 isEof:&isEnd];
    if(data.length > 0){
        [self playWithData:data length:data.length];
    }
}


-(void)playerThread{
    while(1){
       
            NSLog(@"current Thread:%@",[NSThread currentThread]);
            NSData *data = [self readBufferWithSize:MIN_SIZE_PER_FRAME/2 isEof:&isEnd];
            if(data.length > 0){
                [self playWithData:data length:data.length];
            }
            [NSThread sleepForTimeInterval:0.05];
            
        }
}
@end
