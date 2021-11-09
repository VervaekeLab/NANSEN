function mex_uuid()
%MEX_UUID Compiles the mex files for UUID
%
%   mex_uuid;
%       builds the C++ mex files for uuid manipulation
%
%   Prerequisites for mex building
%   ------------------------------
%       1. In Windows, RPC is required for compiling and executing
%          uuidgen_cimp. The library for RPC-based development is 
%          shipped with Microsoft Visual Studio.Net.
%
%          The precompiled uuidgen_cimp.mexw32 is built with MSVC 2008.
%
%       2. In Linux, uuidlib is required for compiling and executing
%          uuidgen_cimp. The runtime shared object is typically shipped
%          with the Linux distro. However, to build the mex file, you
%          also need the development files. 
%
%          In Debian or Ubuntu, you may install the development files
%          by the following command
%
%           sudo apt-get install uuid-dev
%
%          Note that libuuid is part of the e2fsprogs package and is
%          available from http://e2fsprogs.sourceforge.net/.
%       

%   History
%   -------
%       - Created by Dahua Lin, on Oct 9, 2008
%

switch computer
    case {'PCWIN', 'PCWIN64'}
        mex -O uuidgen_cimp.cpp
        
    case {'GLNX86', 'GLNXA64'}
        mex -O -luuid uuidgen_cimp.cpp
        
end
