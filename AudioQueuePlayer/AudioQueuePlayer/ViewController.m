//
//  ViewController.m
//  AudioQueuePlayer
//
//  Created by Heaton on 2017/12/18.
//  Copyright © 2017年 WangMingDeveloper. All rights reserved.
//

#import "ViewController.h"
#import "WMPlayer.h"
@interface ViewController ()
{
    WMPlayer *player;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    player = [[WMPlayer alloc] initSampleRate:8000 ChannelsNumber:1 BitsPerChannel:8 volume:1.0];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"8000K-8bit-1channels.pcm" ofType:nil];
    NSData *data = [NSData dataWithContentsOfFile:path];
    [player addBufferWithData:data];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        player = nil;
        player = [[WMPlayer alloc] initSampleRate:8000 ChannelsNumber:1 BitsPerChannel:16 volume:1.0];
        NSString *path = [[NSBundle mainBundle] pathForResource:@"8000K-16bit-1channels.pcm" ofType:nil];
        NSData *data = [NSData dataWithContentsOfFile:path];
        [player addBufferWithData:data];
    });
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
