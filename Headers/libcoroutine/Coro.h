/*
*/

#ifndef CORO_DEFINED
#define CORO_DEFINED 1

#if defined(__APPLE__)
#define _XOPEN_SOURCE   /* decl of ucontext_t in <sys/_structs.h> is wrong unless this is defined */
#endif


#include <stddef.h>

#if !defined(__MINGW32__) && defined(WIN32)
#if defined(BUILDING_CORO_DLL) || defined(BUILDING_IOVMALL_DLL)
#define CORO_API __declspec(dllexport)
#else
#define CORO_API __declspec(dllimport)
#endif

#else
#define CORO_API
#endif

/*
#if defined(__amd64__) && !defined(__x86_64__)
	#define __x86_64__ 1
#endif
*/

#ifdef __cplusplus
extern "C" {
#endif

struct Coro;
typedef struct Coro Coro;


CORO_API Coro *Coro_new(void);
CORO_API void Coro_free(Coro *self);

// stack

CORO_API void *Coro_stack(Coro *self);
CORO_API size_t Coro_stackSize(Coro *self);
CORO_API void Coro_setStackSize_(Coro *self, size_t sizeInBytes);
CORO_API size_t Coro_bytesLeftOnStack(Coro *self);
CORO_API int Coro_stackSpaceAlmostGone(Coro *self);

CORO_API void Coro_initializeMainCoro(Coro *self);

typedef void (CoroStartCallback)(void *);

CORO_API void Coro_startCoro_(Coro *self, Coro *other, void *context, CoroStartCallback *callback);
CORO_API void Coro_switchTo_(Coro *self, Coro *next);
CORO_API void Coro_setup(Coro *self, void *arg); // private

#ifdef __cplusplus
}
#endif
#endif
