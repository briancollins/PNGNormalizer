#ifndef CRC32__H
#define CRC32__H

#include <stdlib.h>           /* For size_t                 */
#include <stdint.h>


#define UPDC32(octet,crc) (crc_32_tab[((crc)\
^ ((unsigned char)octet)) & 0xff] ^ ((crc) >> 8))

uint32_t updateCRC32(unsigned char ch, uint32_t crc);

#endif