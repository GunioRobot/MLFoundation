#ifndef __NORMALIZED_MSG_H__
#define __NORMALIZED_MSG_H__
#ifdef WIN32
struct msghdr {
	void		*msg_name;	/* [XSI] optional address */
	socklen_t	msg_namelen;	/* [XSI] size of address */
	struct		iovec *msg_iov;	/* [XSI] scatter/gather array */
	int		msg_iovlen;	/* [XSI] # elements in msg_iov */
	void		*msg_control;	/* [XSI] ancillary data, see below */
	socklen_t	msg_controllen;	/* [XSI] ancillary data buffer len */
	int		msg_flags;	/* [XSI] flags on received message */
};

struct cmsghdr {
	socklen_t	cmsg_len;	/* [XSI] data byte count, including hdr */
	int		cmsg_level;	/* [XSI] originating protocol */
	int		cmsg_type;	/* [XSI] protocol-specific type */
/* followed by	unsigned char  cmsg_data[]; */
};

struct iovec {
	u_long iov_len;
	char *iov_base;
};

#ifndef SCM_RIGHTS
#  define SCM_RIGHTS 0x01
#endif
#endif /* WIN32 */
#endif /* __NORMALIZED_MSG_H__ */