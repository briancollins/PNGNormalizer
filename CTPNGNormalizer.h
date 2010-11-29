#import <Foundation/Foundation.h>


@interface CTPNGNormalizer : NSObject {
}

+ (NSData *)dataFromPNGData:(NSData *)d;
+ (NSData *)dataWithContentsOfPNGFile:(NSString *)path;
+ (NSImage *)imageWithContentsOfPNGFile:(NSString *)path;

@end
