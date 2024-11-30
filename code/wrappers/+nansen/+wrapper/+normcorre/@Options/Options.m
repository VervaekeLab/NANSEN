classdef Options < nansen.wrapper.abstract.OptionsAdapter
%nansen.wrapper.normcorre.Options Options adapter for normcorre method
%
%   Implements default options which can be edited in structeditor and
%   a conversion map so that options can be converted to the format
%   required by normcorre.

    properties (Constant)
        ToolboxName = 'NoRMCorre'
    end
    
    methods (Static)
        
        % Static method for getting default options (in separate file)
        [P, V] = getDefaults()
        
        % Static method for getting conversion adapter (in separate file)
        M = getAdapter()
        
    end
    
    methods (Static)
        
        function S = getOptions()
            S = nansen.wrapper.normcorre.Options.getDefaults();
                
            className = 'nansen.wrapper.normcorre.Processor';
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            S = nansen.mixin.HasOptions.combineOptions(S, superOptions{:});
            
        end
        
        function options = convert(S, imageSize)
        %getToolboxOptions Get options compatible with the toolbox.
        %
        %   options = convert(S, imageSize) given a struct S of options,
        %   will convert to a struct which is used in the normcorre
        %   pipeline. imageSize must be supplied, because some parameters
        %   depend on this.
        
            d1 = imageSize(1);
            d2 = imageSize(2);
            
            if numel(imageSize) == 3
                d3 = imageSize(3);
            else
                d3 = 1;
            end
        
            nameMap = nansen.wrapper.normcorre.Options.getAdapter();
            nvPairs = nansen.wrapper.abstract.OptionsAdapter.rename(S, nameMap, 'nvPairs');
            
            if isfield(S, 'Configuration') && isfield(S.Configuration, 'numRows')
                numPatches = [S.Configuration.numRows, S.Configuration.numCols];
                nvPairs{end+1} = 'grid_size';
                nvPairs{end+1} = round( [d1, d2] ./ numPatches );
            end
            
            options = NoRMCorreSetParms('d1', d1, 'd2', d2, 'd3', d3, nvPairs{:});
           
        end
    end
end
