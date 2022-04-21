classdef AbstractMetadata < dynamicprops
%AbstractMetadata Abstract class for metadata

% This class provides interface for loading and saving metadata from the
% properties of implementing subclasses. Could be generalized to accept
% different formats like json, xml, ini etc..

% This is a bit of a mess because I wanted to have a preference for saving
% files with txt extension (to support preview of files on mac without 
% installing plugins)

    properties (Access = protected)
        Filename        
    end
    
    properties (Dependent, Access = private)
        ExistAsYaml % Does metadata yaml file exist?
        ExistAsText % Does metadata yaml file with .txt extension exist?
    end
    
    methods
        
        function assignFilepath(obj, filepath)
        %assignFilepath Assign filepath for accompanying metadata file
            
            [filepath, name, ~] = fileparts(filepath);
            filename = fullfile(filepath, [name, '.yaml']);
            
            obj.Filename = filename;
        end
        
        function readFromFile(obj)
            if isempty(obj.Filename); return; end
            
            filepath = obj.getFilepathRead();
            if ~isempty(filepath)
                S = yaml.ReadYaml(filepath);
                obj.fromStruct(S)
            end
        end

        function writeToFile(obj, S)
            if isempty(obj.Filename); return; end
            if nargin < 2
                S = obj.toStruct();
            end
            filepath = obj.getFilepathWrite();
            yaml.WriteYaml(filepath, S);
            
            obj.checkForDuplicateFiles()
        end
        
        function deleteFile(obj)
        
            if obj.ExistAsYaml
                delete(obj.Filename)
            end
            
            if obj.ExistAsText        
                delete( strcat(obj.Filename, '.txt') )
            end
            
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
        
        function tf = isfile(obj)
            tf = obj.ExistAsYaml || obj.ExistAsText;
        end
        
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
        %getPropertyNames Get list of property names
            propertyNames = properties(obj);
            
            % Subclasses can override. Usefeul for controlling which
            % propertynames are written to file.
        end
        
    end
    
    methods (Access = private)
        
        function filepath = getFilepathRead(obj)
            
            if obj.ExistAsYaml
                filepath = obj.Filename;
            elseif obj.ExistAsText
                filepath = [obj.Filename, '.txt'];
            else
                filepath = '';
            end
            
        end
        
        function filepath = getFilepathWrite(obj)
            appendTxt = getpref('nansen', 'SaveYamlAsTxt', false);
            if appendTxt
                filepath = strcat(obj.Filename, '.txt');
            else
                filepath = obj.Filename;
            end
        end
        
        function checkForDuplicateFiles(obj)
        %checkForDuplicateFiles Delete .yaml or .txt file if both exist
        
            if obj.ExistAsYaml && obj.ExistAsText        
                appendTxt = getpref('nansen', 'SaveYamlAsTxt', false);
                if appendTxt
                    delete(obj.Filename)
                else
                    delete( strcat(obj.Filename, '.txt') )
                end
            end
        end
        
    end
    
    methods
        
        function tf = get.ExistAsYaml(obj)
            tf = exist(obj.Filename, 'file')==2;
        end
        
        function tf = get.ExistAsText(obj)
            tf = exist([obj.Filename,'.txt'], 'file')==2;
        end
        
    end
    
end