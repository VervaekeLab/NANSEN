classdef Species < nansen.metadata.abstract.TableVariable
%TEST Definition for table variable
%   Detailed explanation goes here
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = true
        DEFAULT_VALUE = {'N/A'}
        LIST_ALTERNATIVES = openminds.controlledterms.Species.CONTROLLED_INSTANCES
    end
    
    methods
        function obj = Species(varargin)
            obj@nansen.metadata.abstract.TableVariable(varargin{:});
        end
    end
    
end