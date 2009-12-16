#ifndef __NORMALIZED_NETWORKING_H__
#define __NORMALIZED_NETWORKING_H__

#include <Foundation/Foundation.h>

#include <libev/config.h>

#ifdef WIN32
#include <windows.h>
#include <winsock2.h>

#include <Ws2tcpip.h>

#define SHUT_RDWR SD_BOTH
#define SHUT_RD SD_RECEIVE
#define SHUT_WR SD_SEND

#define EWOULDBLOCK WSAEWOULDBLOCK
#define EINPROGRESS WSAEINPROGRESS

#else
#include <sys/fcntl.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif

#include <errno.h>
#include <unistd.h>

BOOL ev_set_nonblock(NSSocketNativeHandle fd);
int ev_last_error();

#ifndef HAVE_INET_ATON
int inet_aton(const char *cp, struct in_addr *pin);
#endif

#endif
