classdef Species < nansen.metadata.abstract.TableVariable
%TEST Definition for table variable
%   Detailed explanation goes here
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = true
        DEFAULT_VALUE = {'N/A'}
        LIST_ALTERNATIVES = nansen.module.general.core.tablevariable.subject.Species.getSpeciesInstances()
    end
    
    methods
        function obj = Species(varargin)
            obj@nansen.metadata.abstract.TableVariable(varargin{:});
        end
    end

    methods (Static)
        function instances = getSpeciesInstances()

            % Todo: Assert openMINDS is on path
            instances = openminds.controlledterms.Species.CONTROLLED_INSTANCES;
            instances = cellfun(@(c) utility.string.varname2label(c), instances, 'uni', 0);
            instances = lower(instances);
        end
    end
    
end