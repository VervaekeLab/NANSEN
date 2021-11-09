/********************************************************************
 *
 *  uuidgen_cimp.cpp
 *
 *  The C++ mex implementation of UUID generation
 *
 *  Created by Dahua Lin, on Oct 3, 2008
 *
 ********************************************************************/

#include "mex.h"

#include <string.h>


/*---------------------------------------------------
 *
 *  POSIX Implementation
 *
 *  Based on libuuid
 *
 *--------------------------------------------------- */

#if defined(__unix__)

typedef unsigned char uuid_t[16];

/*
 * The include and library preparation
 *
 * Necessary declaration is written directly as follows, 
 * eliminating the need of having the external UUID dev
 * library in the box.
 */

#ifdef __cplusplus
extern "C"{
#endif

void uuid_generate(uuid_t out);
void uuid_unparse(const uuid_t uu, char *out);

#ifdef __cplusplus
}
#endif

void uuidgen(char *s)
{
    uuid_t uid;
    uuid_generate(uid);
    
    uuid_unparse(uid, s);
    s[36] = '\0';
}



/*---------------------------------------------------
 *
 *  Windows Implementation
 *
 *  Based on RPC
 *
 *--------------------------------------------------- */

#elif defined(_WIN32) || defined(_WIN64)

#include <Rpc.h>

#pragma comment(lib, "Rpcrt4")

void uuidgen(char *s)
{
    UUID uid;    
    RPC_STATUS ret = UuidCreate(&uid);
    
    if (ret == RPC_S_OK || ret == RPC_S_UUID_LOCAL_ONLY)
    {
	unsigned char *ts = 0;
	UuidToString(&uid, &ts);
	memcpy(s, ts, 36);
	s[36] = '\0';
	RpcStringFree(&ts);
    }
    else
    {
	mexErrMsgIdAndTxt("uuidgen:rpcerror", 
		"Cannot get Ethernet or token-ring hardware address for this computer");
    }
}


#else
#error "The platform (operating system) of this machine is not supported."
#endif


/*
 * Main entry
 */
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    char uidstr[40];
    uuidgen(uidstr);

    const char *s = uidstr;
    const char **ps = &s;

    plhs[0] = mxCreateCharMatrixFromStrings(1, ps);    
}





