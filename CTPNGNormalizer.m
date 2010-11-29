#include "zlib.h"
#include "crc32.h"

#import "CTPNGNormalizer.h"

#define PNG_HEADER "\x89PNG\r\n\x1a\n"

@implementation CTPNGNormalizer

+ (NSData *)dataFromPNGData:(NSData *)d {
	NSMutableData *newpng = [[[NSMutableData alloc] init] autorelease];
	
	uint8 *p = (uint8 *)[d bytes];
	size_t len = [d length];
	
	if (memcmp(p, PNG_HEADER, 8) != 0)
		return nil;
	
	uint32 width = 0;
	uint32 height = 0;
	int isCgBI = 0;
	
	uint8 *decompress_buf = NULL;
	uint8 *compress_buf = NULL;
	
	[newpng appendBytes:p length:8];
	uint8 *head = p + 8;
	
	while (head < p + len) {
		uint32 chunkLen = ntohl(*((uint32 *)head));
		uint8 *chunkType = head + 4;
		uint8 *chunkData = head + 8;
		uint32 chunkCRC = ntohl(*((uint32 *)(head + chunkLen + 8)));
		head += chunkLen + 12;
		
		if (memcmp(chunkType, "IHDR", 4) == 0) {
			width = ntohl(*((uint32 *)chunkData));
			height = ntohl(*((uint32 *)(chunkData + 4)));
		} else if (memcmp(chunkType, "IDAT", 4) == 0 && isCgBI) {
			size_t out_len = width * height * 4 + height;
			if (!decompress_buf) {
				decompress_buf = malloc(out_len);
			}
			
			z_stream strm;
			
			strm.avail_in = chunkLen;
			strm.next_in = chunkData;
			strm.zalloc = Z_NULL;
			strm.zfree = Z_NULL;
			strm.opaque = Z_NULL;
			
			strm.avail_out = out_len;
			strm.next_out = decompress_buf;
			inflateInit2(&strm, -8);
			inflate(&strm, Z_SYNC_FLUSH);
			
			inflateEnd(&strm);
			
			chunkCRC = 0xFFFFFFFF;
			chunkCRC = updateCRC32(chunkType[0], chunkCRC);
			chunkCRC = updateCRC32(chunkType[1], chunkCRC);
			chunkCRC = updateCRC32(chunkType[2], chunkCRC);
			chunkCRC = updateCRC32(chunkType[3], chunkCRC);
			
			off_t i = 0;
			for (uint32 y = 0; y < height; y++) {
				i++;
				
				for (uint32 x = 0; x < width; x++) {
					uint8 first = decompress_buf[i + 2];
					uint8 second = decompress_buf[i + 1];
					uint8 third = decompress_buf[i + 0];
					uint8 fourth = decompress_buf[i + 3];
					decompress_buf[i++] = first;
					decompress_buf[i++] = second;
					decompress_buf[i++] = third;
					decompress_buf[i++] = fourth;
				}
			}
			
			if (!compress_buf) {
				compress_buf = malloc(out_len);
			}
			
			chunkData = compress_buf;
			strm.zalloc = Z_NULL;
			strm.zfree = Z_NULL;
			strm.opaque = Z_NULL;
			strm.avail_in = out_len;
			strm.next_in = decompress_buf;
			strm.avail_out = out_len;
			strm.next_out = chunkData;
			deflateInit(&strm, Z_DEFAULT_COMPRESSION);
			deflate(&strm, Z_FINISH);
			chunkLen = out_len - strm.avail_out;
			deflateEnd(&strm);
			
			for (size_t i = 0; i < chunkLen; i++) {
				updateCRC32(chunkData[i], chunkCRC);
			}
			chunkCRC = (chunkCRC + 0x100000000) % 0x100000000;
		}
		
		if (memcmp(chunkType, "CgBI", 4) == 0) {
			isCgBI = 1;
		} else {
			uint32 l = htonl(chunkLen);
			[newpng appendBytes:&l length:sizeof(uint32)];
			[newpng appendBytes:chunkType length:4];
			if (chunkLen > 0) {
				[newpng appendBytes:chunkData length:chunkLen];
			}
			chunkCRC = htonl(chunkCRC);
			[newpng appendBytes:&chunkCRC length:4];
		}
		
		if (memcmp(chunkType, "IEND", 4) == 0) {
			break;
		}
	}
	
	free(decompress_buf);
	free(compress_buf);
	return newpng;
}

+ (NSData *)dataWithContentsOfPNGFile:(NSString *)path {
	NSData *d = [[[NSData alloc] initWithContentsOfFile:path] autorelease];
	return [self dataFromPNGData:d];
}

+ (NSImage *)imageWithContentsOfPNGFile:(NSString *)path {		
	return [[[NSImage alloc] initWithData:[self dataWithContentsOfPNGFile:path]] autorelease];
}

@end
