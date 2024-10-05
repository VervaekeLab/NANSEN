classdef TemplateListVariable < nansen.metadata.abstract.TableVariable
%TEMPLATELISTVARIABLE Definition for table variable
%   Detailed explanation goes here
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = []
        LIST_ALTERNATIVES = {}
    end
    
    methods
        function obj = TemplateListVariable(varargin)
            obj@nansen.metadata.abstract.TableVariable(varargin{:});
        end
    end
end
