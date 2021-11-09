function [nvPairs, varargin] = getnvpairs(varargin)

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