#import "AudioRecorderAPI.h"
#import <Cordova/CDV.h>

@implementation AudioRecorderAPI

#define RECORDINGS_FOLDER [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]

- (void)record:(CDVInvokedUrlCommand*)command {
    
    NSString* recordingName = @"";
    NSString* recordingNameWithExtension = @"";
    
    if (command.arguments.count > 1) {
        recordingName = [command.arguments objectAtIndex:1];
    }
    else {
        recordingName = [command.arguments objectAtIndex:0];
    }
    
    recorderFilePath = [NSString stringWithFormat:@"%@", RECORDINGS_FOLDER];
    NSArray* filesPresent = [self listFileAtPath:recorderFilePath];
    
    recordingNameWithExtension = [NSString stringWithFormat:@"%@.m4a", recordingName];
    
    for (id arrayElement in filesPresent) {
        if ([arrayElement isEqualToString:recordingNameWithExtension]) {
            [self deleteLast: recordingName];
        }
    }
    
  _command = command;
  if ([_command.arguments count] > 0) {
    duration = [_command.arguments objectAtIndex:0];
  }
  else {
    duration = nil;
  }

  [self.commandDelegate runInBackground:^{

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *err;
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&err];
    if (err)
    {
      NSLog(@"%@ %d %@", [err domain], [err code], [[err userInfo] description]);
    }
    err = nil;
    [audioSession setActive:YES error:&err];
    if (err)
    {
      NSLog(@"%@ %d %@", [err domain], [err code], [[err userInfo] description]);
    }

    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute, sizeof (audioRouteOverride),&audioRouteOverride);

    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    [recordSettings setObject:[NSNumber numberWithInt: kAudioFormatMPEG4AAC] forKey: AVFormatIDKey];
    [recordSettings setObject:[NSNumber numberWithFloat:44100.0] forKey: AVSampleRateKey];
    [recordSettings setObject:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
    [recordSettings setObject:[NSNumber numberWithInt:44100] forKey:AVEncoderBitRateKey];
    [recordSettings setObject:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    [recordSettings setObject:[NSNumber numberWithInt: AVAudioQualityMedium] forKey: AVEncoderAudioQualityKey];

    // Create a new dated file
    //NSString *uuid = [[NSUUID UUID] UUIDString];
    recorderFilePath = [NSString stringWithFormat:@"%@/%@", RECORDINGS_FOLDER, recordingNameWithExtension];
    NSLog(@"recording file path: %@", recorderFilePath);

    NSURL *url = [NSURL fileURLWithPath:recorderFilePath];
    err = nil;
    recorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSettings error:&err];
    if(!recorder){
      NSLog(@"recorder: %@ %d %@", [err domain], [err code], [[err userInfo] description]);
      return;
    }

    [recorder setDelegate:self];

    if (![recorder prepareToRecord]) {
      NSLog(@"prepareToRecord failed");
      return;
    }
    if (duration == nil || duration.integerValue == -1) {
      if (![recorder record]) {
        NSLog(@"record failed");
        return;
      }
    }
    else {
      if (![recorder recordForDuration:(NSTimeInterval)[duration intValue]]) {
        NSLog(@"recordForDuration failed");
        return;
      }
    }

  }];
}

- (void)stop:(CDVInvokedUrlCommand*)command {
  _command = command;
  NSLog(@"stopRecording");
  [recorder stop];
  NSLog(@"stopped");
}

- (void)playback:(CDVInvokedUrlCommand*)command {
  _command = command;
  [self.commandDelegate runInBackground:^{
    NSString *fileToReproduce = [_command.arguments objectAtIndex:0];
    NSLog(@"recording playback %@.m4a", fileToReproduce);
    recorderFilePath = [NSString stringWithFormat:@"%@/%@.m4a", RECORDINGS_FOLDER, fileToReproduce];

    NSURL *url = [NSURL fileURLWithPath:recorderFilePath];
    NSError *err;
    player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
    player.numberOfLoops = 0;
    player.delegate = self;
    [player prepareToPlay];
    [player play];
    if (err) {
      NSLog(@"%@ %d %@", [err domain], [err code], [[err userInfo] description]);
    }
    NSLog(@"playing");
  }];
}

- (void)deleteLastRecord: (CDVInvokedUrlCommand*)command {
    NSString *fileToDelete = [command.arguments objectAtIndex:0];
    [self deleteLast: fileToDelete];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"DeleteCompelte"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) deleteLast: (NSString*) fileToDelete {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error;
    recorderFilePath = [NSString stringWithFormat:@"%@/%@.m4a", RECORDINGS_FOLDER, fileToDelete];
    BOOL success = [fileManager removeItemAtPath:recorderFilePath error:&error];
    if (success) {
        UIAlertView *removedSuccessFullyAlert = [[UIAlertView alloc] initWithTitle:@"Congratulations:" message:@"Successfully removed" delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil];
        [removedSuccessFullyAlert show];
    }
    else
    {
        NSLog(@"Could not delete file -:%@ ",[error localizedDescription]);
    }

}

-(NSArray *)listFileAtPath:(NSString *)path
{
    int count;
    
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
    for (count = 0; count < (int)[directoryContent count]; count++)
    {
        NSLog(@"File %d: %@", (count + 1), [directoryContent objectAtIndex:count]);
    }
    return directoryContent;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
  NSLog(@"audioPlayerDidFinishPlaying");
  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"playbackComplete"];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
  NSURL *url = [NSURL fileURLWithPath: recorderFilePath];
  NSError *err = nil;
  NSData *audioData = [NSData dataWithContentsOfFile:[url path] options: 0 error:&err];
  if(!audioData) {
    NSLog(@"audio data: %@ %d %@", [err domain], [err code], [[err userInfo] description]);
  } else {
    NSLog(@"recording saved: %@", recorderFilePath);
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:recorderFilePath];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
  }
}

@end

