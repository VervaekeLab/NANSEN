classdef DataMethod < nansen.mixin.HasOptions %nansen.dataio.DataIoModel & 
    
    % TODO:
    % [ ] Make property to determine what should be done if a method is
    % already completed. I.e rerun and overwrite, rerun and save to new
    % folder, or do nothing...
    %
    % [ ] Implement printStatus method. Create a special class for method
    %     logging?
   
    properties (Constant, Abstract)
        MethodName      % Name of method
        IsManual        % Does method require manual supervision
        IsQueueable     % Is method suitable for queueing. Examples were not: method creates figures or requires manual input
    end
    
    properties (Access = protected)
        DataIoModel
    end
    
    methods (Static) % Make abstract???
        function pathList = getDependentPaths()
            pathList = {};
            % Todo: what was this again?
        end
    end
    
    methods % Constructor
        function obj = DataMethod(varargin)
            
            if isempty(varargin)
                return
                % Todo: Assign default data io model...
            end
            
            %obj@nansen.dataio.DataIoModel(varargin{1})
            obj.DataIoModel = varargin{1};
            
            
        end
    end
    
    methods (Access = public)
    
        function data = loadData(obj, varargin)
            data = obj.DataIoModel.loadData(varargin{:});
        end
        
        function saveData(obj, varargin)
            obj.DataIoModel.saveData(varargin{:})
        end
        
        function filePath = getDataFilePath(obj, varargin)
            filePath = obj.DataIoModel.getDataFilePath(varargin{:});
        end
        
    end
    
end