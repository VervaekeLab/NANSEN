classdef TwoPhotonSession < nansen.metadata.type.Session
    
    % Todo: This is not a metadata schema. Should make a framework for
    % sessionData....
    
    properties
        filePath
    end
    
    properties (Access = protected)
        fileName
        folderPath
    end
    
    methods
   
        function obj = TwoPhotonSession(pathStr)
            %obj@nansen.metadata.type.Session(varargin{:})

            obj.filePath = pathStr;
            
            [obj.folderPath, obj.fileName] = fileparts(obj.filePath);
           
        end
        
        function pathStr = getSessionFolder(obj, dataLocation)
            pathStr = fullfile(obj.folderPath, dataLocation);
        end
        
        function pathStr = getDataFilePath(obj, varName, varargin)
           
            if strcmp(varName, 'TwoPhotonSeries_Original')
                pathStr = obj.filePath;
            else
                varargin = [varargin, {'DataLocation', 'Processed'}];
                pathStr = getDataFilePath@nansen.metadata.type.Session(obj, varName, varargin{:});
            end
    
        end
       
    end

end