function hApp = nansen(varargin)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
    
	try
        hApp = nansen.App(varargin{:});
    catch
        hApp = [];
    end
    
    if nargout == 0
        clear hApp
    end

end