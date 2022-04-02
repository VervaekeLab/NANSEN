classdef AbstractMetadata < dynamicprops
%AbstractMetadata Abstract class for metadata

    properties (Access = protected)
        Filename
    end
    
    methods
        
        function assignFilepath(obj, filepath)
        %assignFilepath Assign filepath for accompanying metadata file
            
            [filepath, name, ~] = fileparts(filepath);
            filename = fullfile(filepath, [name, '.yaml']);
            
            appendTxt = getpref('nansen', 'SaveYamlAsTxt', false);
            if appendTxt
                filename = strcat(filename, '.txt');
            end
            
            obj.Filename = filename;
            
        end
        
        function readFromFile(obj)
            if isempty(obj.Filename); return; end
            S = yaml.ReadYaml(obj.Filename);
            obj.fromStruct(S)
        end

        function writeToFile(obj)
            if isempty(obj.Filename); return; end
            S = obj.toStruct();
            yaml.WriteYaml(obj.Filename, S);
        end
        
        function set(obj, name, value)
            
            if isprop(obj, name)
                obj.(name) = value;
            else
                P = obj.addprop(name);
                obj.(name) = value;

                % Dynamic props can only be set from within the class
                %[P.SetAccess] = deal('protected');
            end
            
            obj.writeToFile()
            
        end
    end
        
    
    methods (Access = protected)
        
        function S = toStruct(obj)
            
            propertyNames = obj.getPropertyNames();
            
            S = struct();
            for jProp = 1:numel(propertyNames)
                thisName = propertyNames{jProp};
                S.(thisName) = obj.(thisName);
            end
            
        end
        
        function fromStruct(obj, S, propertyNames)
                
            if nargin < 3
                propertyNames = fieldnames(S);
            end
            
            for jProp = 1:numel(propertyNames)
                if isprop(obj, propertyNames{jProp})
                    [obj.(propertyNames{jProp})] = S.(propertyNames{jProp});
                
                else % Set as dynamic property.
                    P = obj.addprop(propertyNames{jProp});
                    numObjects = numel(obj);
                    for i = 1:numObjects
                        obj(i).(propertyNames{jProp}) = S(i).(propertyNames{jProp});
                    end
                    
                    % Dynamic props can only be set from within the class
                    % [P.SetAccess] = deal('protected');
                end
            end
        end
       
        function propertyNames = getPropertyNames(obj)
            propertyNames = properties(obj);
        end
        
    end

end