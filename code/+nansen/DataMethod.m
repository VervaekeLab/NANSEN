classdef DataMethod < nansen.dataio.DataIoModel & nansen.mixin.HasOptions
    
    % TODO:
    % [ ] Make property to determine what should be done if a method is
    % already completed. I.e rerun and overwrite, rerun and save to new
    % folder, or do nothing...
    %
    % [ ] Implement printStatus method. Create a special class for method
    %     logging?
   
    properties (Constant, Abstract)
        MethodName
        IsManual   % Does method require manual supervision
        IsQueueable
    end
    
    methods (Static) % Make abstract???
        function pathList = getDependentPaths()
            pathList = {};
            % Todo
        end
    end
    
    methods % Constructor
        function obj = DataMethod(varargin)
            
            if numel(varargin) < 2
                varargin{2} = [];
            end
            
            obj@nansen.dataio.DataIoModel(varargin{1})
            obj@nansen.mixin.HasOptions(varargin{2})
            
        end
    end
    
    
    
end