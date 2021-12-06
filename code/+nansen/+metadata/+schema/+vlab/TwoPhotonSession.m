classdef TwoPhotonSession < nansen.metadata.schema.generic.Session
    
    
    properties (Constant, Hidden)
        ANCESTOR = 'nansen.metadata.schema.vlab.Mouse';
        
        RequiredVariableList = {...
            'TwoPhotonSeries_Original', ...
            'TwoPhotonSeries_Corrected', ...
            'RoiMasks', ...
            'RoiResponses_Original', ...
            'RoiResponses_DfOverF'}
    end
    
    
    methods % Structors
       
        function obj = TwoPhotonSession(varargin) 
            
            if isempty(varargin)
                return; 
            end
            
            % Todo: some of this should be in superclasses
            
            if isa(varargin{1}, 'table')
                metaTable = varargin{1};
                numObjects = size(metaTable,1);
                obj(numObjects).Notebook = struct.empty;
                obj.fromTable(varargin{1})
                
                
                
            % This case is if input is a "data location"
            elseif isa(varargin{1}, 'struct') % Temporary; data location struct.
                
                % Todo: Generalize for all data locations.
                
                obj.DataLocation = varargin{1};
                % Note: Hardcoded, get path for first entry in data
                % location type.
                fieldNames = fieldnames(obj.DataLocation);
                pathStr = obj.DataLocation.(fieldNames{1});
                
                obj.assignSubjectID(pathStr)
                obj.assignSessionID(pathStr)
                obj.assignDateInfo(pathStr)
                obj.assignTimeInfo(pathStr)
                
% %                 % Todo: Autoassign all data locations
% %                 if numel(obj.DataLocation) ~= numel(dataLocationModel.Data)
% %                     % Should also make sure that names are matching...
% %                     obj.updateDataLocations()
% %                 end
                
                
            elseif isa(varargin{1}, 'char')
                % Todo:
                pathStr = varargin{1};
                obj.assignSubjectID(pathStr)
                obj.assignSessionID(pathStr)
                obj.assignDateInfo(pathStr)
                obj.assignTimeInfo(pathStr)

                [~, fileName, ~] = fileparts(pathStr); 

                obj.DataLocation(1).Path1 = pathStr;
                
            end
        
        
        end
        
        
        
        function delete(obj)
            % pass for now.
        end
        
        
    end
    
    
    methods
        
        function imageStack = openTwoPhotonSeries(obj, type, varargin)
        %openTwoPhotonSeries Return two photon series as imageStack.
        
            % Todo:
            %   [ ] Collect image stats if raw stack is requested
            %   [ ] Initialize stack if it does not exist
            %   [ ] Note: for initialization, stack size and datatype
            %       should be given as inputs
            
            % Determine variable name for two-photon image series
            switch lower( type )
                case {'raw', 'original'}
                    DATANAME = 'TwoPhotonSeries_Original';
                case 'corrected'
                    DATANAME = 'TwoPhotonSeries_Corrected';
            end
            
            % Get filepath
            filePath = obj.getDataFilePath(DATANAME);
            
            % Initialize file reference for raw 2p-images
            imageStack = imviewer.stack.open(filePath);
            

        end
        
        
    end
    
    
end
