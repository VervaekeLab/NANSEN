classdef TemplateVariable < nansen.metadata.abstract.TableVariable
%TEMPLATEVARIABLE Definition for table variable
%   Detailed explanation goes here
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = []
    end
    
    methods
        function obj = TemplateVariable(varargin)
            obj@nansen.metadata.abstract.TableVariable(varargin{:});
        end
    end
end
