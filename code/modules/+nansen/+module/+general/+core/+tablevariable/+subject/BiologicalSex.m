classdef BiologicalSex < nansen.metadata.abstract.TableVariable
%TEST Definition for table variable
%   Detailed explanation goes here
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = true
        DEFAULT_VALUE = {'N/A'}
        LIST_ALTERNATIVES = {'male','female','not detected'}
    end
    
    methods
        function obj = BiologicalSex(varargin)
            obj@nansen.metadata.abstract.TableVariable(varargin{:});
        end
    end
end
