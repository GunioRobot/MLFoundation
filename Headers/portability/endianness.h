#import <libev/config.h>

#if HAVE_MACHINE_ENDIAN_H == 1
#  include <machine/endian.h>
#elif HAVE_ENDIAN_H == 1
#  include <endian.h>
#else
#	 ifdef WIN32
#    define __LITTLE_ENDIAN 1
#    define __BYTE_ORDER __LITTLE_ENDIAN
#  else
#    error Do not know the endianess of this architecture
#  endif
#endif

//  ========================= DEPRECATED ==============================
//  =================== USE networkbyteorder.h ========================
#if __BYTE_ORDER == __LITTLE_ENDIAN
#define UINT16_NTOH(s) \
	( ((uint16_t)((s)[1])) |  ((uint16_t)((s)[0]) << 8 ) )

#define UINT32_NTOH(s) \
	( ((uint32_t)((s)[3])) |  ((uint32_t)((s)[2]) << 8 ) \
  |  ((uint32_t)((s)[1]) << 16 ) | ( ((uint32_t)((s)[0]) << 24 ) ) )

#define UINT64_NTOH(a) \
    ((uint64_t)((a)[7]) |  ((uint64_t)((a)[6]) << 8 ) \
    | ((uint64_t)((a)[5]) << 16 ) | ( ((uint64_t)((a)[4]) << 24 ) ) \
    | ((uint64_t)((a)[3]) << 32 ) | ( ((uint64_t)((a)[2]) << 40 ) ) \
    | ((uint64_t)((a)[1]) << 48 ) | ( ((uint64_t)((a)[0]) << 52 ) ) ) 

#else /* __BYTE_ORDER is __BIG_ENDIAN */

#error Big-endian architectures currently unsupported.

#endif


