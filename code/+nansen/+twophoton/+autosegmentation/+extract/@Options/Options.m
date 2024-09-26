classdef Options < nansen.wrapper.OptionsAdapter
    
    properties (Constant)
        ToolboxName = 'EXTRACT'
        Name = 'EXTRACT Options'
        Description = 'Options for EXTRACT'
    end
    
    methods (Static) % Functions defined in files.
        
        S = getDefaultOptions()
        M = getOptionsConversionMap()
        
    end
    
    methods (Static)
        
        function S = getOptions()
            S = nansen.twophoton.autosegmentation.extract.Options.getDefaultOptions();
        end
        
        function SOut = convert(S)
            
            % Most config fields are just placed in substructs, but some
            % fields where renamed before placing in a substruct called
            % CellFind.
            
            if nargin < 1
                S = nansen.twophoton.autosegmentation.extract.Options.getOptions();
            end
            
            SOut = struct();
            
            fieldsTopLevel = fieldnames(S);
            
            for i = 1:numel(fieldsTopLevel)
                
                % Rename fields from cellfind substruct
                if strcmp(fieldsTopLevel{i}, 'CellFind')
                    nameMap = nansen.twophoton.autosegmentation.extract.Options.getOptionsConversionMap;
                    sTmp = nansen.wrapper.OptionsAdapter.rename(S, nameMap);
                    configNames = fieldnames(sTmp);
                        
                    for j = 1:numel(configNames)
                        SOut.(configNames{j}) = sTmp.(configNames{j});
                    end
                    
                    continue
                end
                
                % Pull config fields out of substructs.
                configNames = fieldnames(S.(fieldsTopLevel{i}));
                for j = 1:numel(configNames)
                    SOut.(configNames{j}) = S.(fieldsTopLevel{i}).(configNames{j});
                end
            end
        end
    end
end
