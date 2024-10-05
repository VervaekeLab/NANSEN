classdef GenericMetadata < nansen.dataio.metadata.AbstractMetadata
    
    properties (SetAccess = protected)
        MetadataStruct
    end
    
    methods
        function obj = GenericMetadata(filePath, metadataStruct)
            
            if nargin >= 1 && ~isempty(filePath)
                obj.assignFilepath(filePath)
            end
            
            if nargin >= 2 && ~isempty(metadataStruct)
                obj.MetadataStruct = metadataStruct;
            end
        end
    end
    
    methods
        function set(obj, name, value, groupName)
            if nargin < 4 || isempty(groupName)
                groupName = 'Custom';
            end
            obj.MetadataStruct.(groupName).(name) = value;
            %obj.writeToFile() Todo...
        end
    end
    
    methods (Access = protected)
        
        function S = toStruct(obj)
            S = obj.MetadataStruct;
        end
        
        function fromStruct(obj, S)
            obj.MetadataStruct = S;
        end
    end
end
