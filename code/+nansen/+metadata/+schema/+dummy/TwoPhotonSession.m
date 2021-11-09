classdef TwoPhotonSession < nansen.metadata.schema.vlab.TwoPhotonSession
    
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
            %obj@nansen.metadata.schema.vlab.TwoPhotonSession(varargin{:})

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
                pathStr = getDataFilePath@nansen.metadata.schema.vlab.TwoPhotonSession(obj, varName, varargin{:});
            end
    
        end
       
    end

end