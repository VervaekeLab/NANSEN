classdef Options < nansen.wrapper.abstract.OptionsAdapter
    
    properties (Constant)
        ToolboxName = 'EXTRACT'
        Name = 'EXTRACT Options'
        Description = 'Options for EXTRACT'
    end
    
    
    methods (Static) % Functions defined in files.
        
        [P, V] = getDefaults()
        M = getAdapter()
        
    end
    
    methods (Static)
        
        function S = getOptions()
            S = nansen.wrapper.extract.Options.getDefaults();
        end
        
        function SOut = convert(S)
            
            % Most config fields are just placed in substructs, but some
            % fields where renamed before placing in a substruct called
            % CellFind. 
            
            if nargin < 1
                S = nansen.wrapper.extract.Options.getDefaults();
            end
            
            SOut = struct();
            
            fieldsTopLevel = fieldnames(S);
            
            for i = 1:numel(fieldsTopLevel)
                
                % Rename fields from cellfind substruct
                if strcmp(fieldsTopLevel{i}, 'CellFind')
                    
                    nameMap = nansen.wrapper.extract.Options.getAdapter();
                    sTmp = nansen.wrapper.abstract.OptionsAdapter.rename(S, nameMap);
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