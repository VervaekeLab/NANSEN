function jData = mat2java(mData,varargin)
% mat2java - Utility to convert MATLAB array to Java array
% 
% Abstract: This utility will convert MATLAB arrays to a Java equivalent
%
% Syntax:
%           jData = uiw.utility.mat2java(mData)
%
% Inputs:
%           mData - the MATLAB array
%
%           javaClass - for certain formats, optionally specify the Java
%                   class to create
%
% Outputs:
%           jData - the Java array
%
% Examples:
%           none
%
% Notes: none
%

%   Copyright 2017-2019 The MathWorks Inc.
%
% Auth/Revision:
%   MathWorks Consulting
%   $Author: rjackey $
%   $Revision: 324 $  $Date: 2019-04-23 08:05:17 -0400 (Tue, 23 Apr 2019) $
% ---------------------------------------------------------------------

% Validate input
validateattributes(mData,{'numeric','logical','char','cell','datetime'},{'2d'})

% Constants that may be needed
persistent epochDate



%% If a special class was specified, use it and return

if nargin>=2 && ~iscell(mData)
    
    if isnumeric(mData)
        inArgs = num2cell(mData);
        jData = javaObject(varargin{:}, inArgs{:});
    else
        jData = javaObject(varargin{:}, mData);
    end
    return
    
end %if nargin>=2 && ~iscell(mData)


%% What type of data is this?

switch class(mData)
    
    case 'cell'
        
        % Requres recursion in each cell
        jData = cell(size(mData));
        for idx=1:numel(mData)
            if ~isempty(mData{idx}) %added by EH - 2022-03-03 (Otherwise, would fail if cell is empty...)
                jData{idx} = uiw.utility.mat2java(mData{idx},varargin{:});
            end                     %added by EH - 2022-03-03
        end
        
    case 'datetime'
        
        % Populate this constant value if not yet done
        if isempty(epochDate)
            epochDate = datetime([1970 1 1],'TimeZone','GMT');
        end
        
        % Prepare an array
        if isscalar(mData)
            jData = javaObject('java.util.GregorianCalendar');
        else
            sz = size(mData);
            jData(sz) = javaObject('java.util.GregorianCalendar');
        end
        
        % Loop on each element
        for idx = 1:numel(mData)
            
            % Time zone is required for the conversion
            thisDateTime = mData(idx);
            if isempty(thisDateTime.TimeZone)
                thisDateTime.TimeZone = 'local';
            end
            
            % Set the time zone and offset in the java date
            jTimeZone = java.util.TimeZone.getTimeZone(thisDateTime.TimeZone);
            jData(idx).setTimeZone(jTimeZone);
            jData(idx).setTimeInMillis(milliseconds(thisDateTime-epochDate))
            
        end %for 1:numel(mData)
        
    case 'char'
        
        % Convert to Java string
        jData = javaObject('java.lang.String',mData);
        
    case 'double'
        
        jData = javaObject('java.lang.Double',mData);
        
    case 'single'
        
        jData = javaObject('java.lang.Float',mData);
        
    case 'int64'
        
        jData = javaObject('java.lang.Long',mData);
        
    case 'int32'
        
        jData = javaObject('java.lang.Integer',mData);
        
    case 'int16'
        
        jData = javaObject('java.lang.Short',mData);
        
    case 'int8'
        
        jData = javaObject('java.lang.Byte',mData);
        
    case {'uint8','uint16','uint32','uint64'}
        
        warning('mat2java:unsigned','Java does not support unsigned types.');
        
        % Leave as-is
        jData = mData;
        
    case 'logical'
        
        jData = javaObject('java.lang.Boolean',mData);
        
    otherwise
        
        % Leave as-is
        jData = mData;
        
end %switch class(mData)

end %function mat2java
