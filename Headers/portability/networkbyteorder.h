#import <portability/endianness.h>

/* Macros to swap the order of bytes in integer values.
   Copyright (C) 1997,1998,2000,2001,2002,2005 Free Software Foundation, Inc. */
#ifndef _BITS_BYTESWAP_H
#define _BITS_BYTESWAP_H 1

/* Swap bytes in 16 bit value.  */
#define __bswap_constant_16(x) \
     ((((x) >> 8) & 0xffu) | (((x) & 0xffu) << 8))

#ifdef __GNUC__
# define __bswap_16(x) \
    (__extension__							      \
     ({ unsigned short int __bsx = (x); __bswap_constant_16 (__bsx); }))
#else
static __inline unsigned short int
__bswap_16 (unsigned short int __bsx)
{
  return __bswap_constant_16 (__bsx);
}
#endif

/* Swap bytes in 32 bit value.  */
#define __bswap_constant_32(x) \
     ((((x) & 0xff000000u) >> 24) | (((x) & 0x00ff0000u) >>  8) |	      \
      (((x) & 0x0000ff00u) <<  8) | (((x) & 0x000000ffu) << 24))

#ifdef __GNUC__
# define __bswap_32(x) \
  (__extension__							      \
   ({ register unsigned int __bsx = (x); __bswap_constant_32 (__bsx); }))
#else
static __inline unsigned int
__bswap_32 (unsigned int __bsx)
{
  return __bswap_constant_32 (__bsx);
}
#endif

#if defined __GNUC__ && __GNUC__ >= 2
/* Swap bytes in 64 bit value.  */
# define __bswap_constant_64(x) \
     ((((x) & 0xff00000000000000ull) >> 56)				      \
      | (((x) & 0x00ff000000000000ull) >> 40)				      \
      | (((x) & 0x0000ff0000000000ull) >> 24)				      \
      | (((x) & 0x000000ff00000000ull) >> 8)				      \
      | (((x) & 0x00000000ff000000ull) << 8)				      \
      | (((x) & 0x0000000000ff0000ull) << 24)				      \
      | (((x) & 0x000000000000ff00ull) << 40)				      \
      | (((x) & 0x00000000000000ffull) << 56))

# define __bswap_64(x) \
     (__extension__							      \
      ({ union { __extension__ unsigned long long int __ll;		      \
		 unsigned int __l[2]; } __w, __r;			      \
         if (__builtin_constant_p (x))					      \
	   __r.__ll = __bswap_constant_64 (x);				      \
	 else								      \
	   {								      \
	     __w.__ll = (x);						      \
	     __r.__l[0] = __bswap_32 (__w.__l[1]);			      \
	     __r.__l[1] = __bswap_32 (__w.__l[0]);			      \
	   }								      \
	 __r.__ll; }))
#endif

#endif /* _BITS_BYTESWAP_H */

#if __BYTE_ORDER == __LITTLE_ENDIAN
#define U16_NTOH(x) __bswap_16(x)
#define U16_HTON(x) __bswap_16(x)
#define U32_NTOH(x) __bswap_32(x)
#define U32_HTON(x) __bswap_32(x)
#define U64_NTOH(x) __bswap_64(x)
#define U64_HTON(x) __bswap_64(x)
#else 
#define U16_NTOH(x) (x)
#define U16_HTON(x) (x)
#define U32_NTOH(x) (x)
#define U32_HTON(x) (x)
#define U64_NTOH(x) (x)
#define U64_HTON(x) (x)
#endif

// Им здесь вообще не очень место :-(
// Им место где-то в контекстах сериализации/десериализации.
// (…которые надо сделать из битстрима?)

#define READ_U16N(ptr) U16_NTOH(*(uint16_t *)(ptr))
#define READ_U32N(ptr) U32_NTOH(*(uint32_t *)(ptr))
#define READ_U64N(ptr) U64_NTOH(*(uint64_t *)(ptr))

#define DUMP_U16N(ptr,val) do { (*(uint16_t *)(ptr)) = U16_HTON(val); } while (0)
#define DUMP_U32N(ptr,val) do { (*(uint32_t *)(ptr)) = U32_HTON(val); } while (0)
#define DUMP_U64N(ptr,val) do { (*(uint64_t *)(ptr)) = U64_HTON(val); } while (0)
