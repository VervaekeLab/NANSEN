function uid = uuidgen(opt)
%UUIDGEN Generates a UUID
%
%   uid = uuidgen();
%       Generates a Universally Unique Identifier and returns it in 
%       a canonical form (8-4-4-4-12 string of hex digits).
%
%       Here is an example:
%           550e8400-e29b-41d4-a716-446655440000
%
%   uid = uuidgen('mex');
%       generates the UUID using C++ mex implementation.
%
%   uid = uuidgen('java');
%       generates the UUID by invoking Java virtual machine.
%
%   Notes
%   -----
%       - The function relies on either C++ mex implementation or JVM
%         to generate UUID. By default, it calls the mex implementation
%         if it is available, otherwise it invokes JVM.
%
%       - In this version, C++ mex implementation is available in Windows
%         and Linux platform (requires libuuid). Pre-compiled binaries have
%         been in the package. However, if it does not work in your
%         environment, you may rebuild it by calling mex_uuid. Please
%         refer to the help of mex_uuid for details.         
%

%   History
%   -------
%       - Created by Dahua Lin, on Oct 3, 2008
%           - with mex implementation based on libuuid in Linux.
%       - Modified by Dahua Lin, on Oct 8, 2008
%           - add mex implementation based on Windows RPC.
%       - Modified by Dahua Lin, on Oct 9, 2008
%           - add Java-based implementation.
%           - add implementation selection part.
%

%% decide which implementation to use

if nargin == 0  % auto selection 
    if is_mex_works
        impl = 1;   % use mex        
    elseif is_java_works
        impl = 2;   % use java
    else
        error('uuidgen requires either mex implementation or jvm support, however, neither is available.');
    end
    
else
    switch opt
        case 'mex'            
            if is_mex_works
                impl = 1;
            else
                error('The mex implementation %s is not found.', mex_filename());
            end
            
        case 'java'
            if is_java_works
                impl = 2;
            else
                error('The JVM is not loaded.');
            end            
    end
end

%% call internal implementation

if impl == 1
    uid = uuidgen_cimp();
else
    uid = char(java.util.UUID.randomUUID());
end


function b = is_mex_works()
% judge whether mex implementation works

b = exist('uuidgen_cimp', 'file') == 3;

function b = is_java_works()
% judge whether jvm works

b = usejava('jvm');

function fn = mex_filename()

fn = ['uuidgen_cimp.', mexext];

