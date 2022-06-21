classdef DataMethod < nansen.mixin.HasOptions %nansen.dataio.DataIoModel & 
    
    % TODO:
    % [ ] Make property to determine what should be done if a method is
    %     already completed. I.e rerun and overwrite, rerun and save to new
    %     folder, or do nothing...
    %
    % [ ] Implement printStatus method. Create a special class for method
    %     logging?
    
   
    properties (Constant, Abstract)
        MethodName      % Name of method
        IsManual        % Does method require manual supervision
        IsQueueable     % Is method suitable for queueing. Examples were not: method creates figures or requires manual input
    end
    
    properties
        RedoIfCompleted = false % Run method again if results already exist from before? i.e force redo
    end
    
    properties (Access = protected)
        DataIoModel
        Parameters % Todo: Resolve: Same as options...

    end
    
    methods (Static)
        function pathList = getDependentPaths()
        %getDependentPaths Get dependent paths for this method.
        %
        %   Note: Dependent paths are necessary in order to create batch
        %   jobs, or run methods on a different worker.
        
            pathList = {};
        
            % Todo: return the nansen code directory.
            
        end
    end
    
    methods % Constructor
        function obj = DataMethod(varargin)
            
            if isempty(varargin)
                return
                % Todo: Assign default data io model...
            end
            
            % Todo: if input is a file/folder path, create a generic data
            % input/output model. 
            %obj@nansen.dataio.DataIoModel(varargin{1})
            obj.DataIoModel = varargin{1};

            if nargin >= 2
                obj.Options = varargin{2};
            end
            
        end
    end

    methods (Access = public) % Todo: Use methods of hasOptions superclass
        
        function wasSuccess = preview(obj) %_workinprogress(obj)
            %Todo: Combine this with methods that are already present in
            %some subclasses (motion correction / auto segmentation)
            
            [~, wasAborted] = obj.editOptions();
            wasSuccess = ~wasAborted;

            if wasSuccess
                obj.Parameters = obj.OptionsManager.Options;
            end
        end
        
        function wasSuccess = finishPreview(obj, hPreviewApp)
        %finishPreview For wrapping up preview if using a preview app...
        
            % Abort if h is invalid (improper exit)
            if ~isvalid(hPreviewApp); wasSuccess = false; return; end
            
            obj.Parameters = hPreviewApp.settings;
            obj.Options = hPreviewApp.settings;
            wasSuccess = ~hPreviewApp.wasAborted;
            
            delete(hPreviewApp)
        end
        
    end
    
    methods (Access = public) % Shortcuts for methods of DataIOModel
    %Todo: Get this from a superclass / mixin class.
    
        function data = loadData(obj, varargin)
            data = obj.DataIoModel.loadData(varargin{:});
        end
        
        function saveData(obj, varargin)
            obj.DataIoModel.saveData(varargin{:})
        end
        
        function filePath = getDataFilePath(obj, varargin)
            filePath = obj.DataIoModel.getDataFilePath(varargin{:});
        end
        
        function folder = getTargetFolder(obj)
            if isa(obj.DataIoModel, 'nansen.metadata.type.Session')
                folder = obj.DataIoModel.getSessionFolder(); % Todo: Generalize away from session data location...
            else
                error('Not implemented yet')
            end
        end
        
        function tf = existVariable(obj, varName)
            tf = isfile( obj.getDataFilePath(varName) );
        end
    end
    
    methods (Access = protected)
        
        function initializeVariables(obj)
        %initializeVariables Initialize variables that is created by method
            
            % The purpose of this method is to initialize variable in the
            % variable model for this method, so that they can be accessed
            % without using "attributes".
        
            % Get variable names from property
            varNames = obj.DataVariableNames;
            for i = 1:numel(varNames)
                obj.setVariable(varNames{i}, 'Subfolder', ...
                    obj.DATA_SUBFOLDER, 'IsInternal', true);
            end
            
            % Todos:
            % 1) Implement the DataVariableNames property
            % 2) Implement a DATA_SUBFOLDER abstract property
            % 3) Implement a setVariable on the DataIoModel / VariableModel
            
        end
        
    end
end