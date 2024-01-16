classdef DateOfBirth < nansen.metadata.abstract.TableVariable
%TEST Definition for table variable
%   Detailed explanation goes here
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = true
        DEFAULT_VALUE = datetime.empty
    end    
end