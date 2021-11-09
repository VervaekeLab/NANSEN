function [S, varargin] = validateStruct(varargin)
%validateStruct Checks that first entry in varargin is a valid struct.
%
%   Returns the remaining args in varargin with the struct split of as a
%   separate variable.
    
    if isempty(varargin)
        error('Struct editor needs an input which is a struct or a cell array of structs')
    end
    
    isValidStruct = @(s) isstruct(s) || all(cellfun(@(c) isstruct(c), s));
    
    
    if isValidStruct(varargin{1})
        S = varargin{1};
        varargin = varargin(2:end);
    else
        error('Invalid struct argument, please see help for structeditor.App')
    end

end