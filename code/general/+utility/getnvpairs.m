function [nvPairs, varargin] = getnvpairs(varargin)
%getnvpairs Get name value pairs from a list of input arguments
%
%   [nvPairs, varargin] = getnvpairs(varargin)

    
    if numel(varargin)==1 && iscell(varargin{1}) 
        % Assume varargin is passed on directly and need to be unpacked
        varargin = varargin{1};
    end

    nvPairs = {};
    
    for i = numel(varargin) : -2 : 1
        
        if i == 1; break; end
        
        if ischar( varargin{i-1} )
            nvPairs = [nvPairs, varargin(i-1:i)]; %#ok<AGROW>
            varargin(i-1:i) = [];
        else
            break
        end
        
    end
        
end