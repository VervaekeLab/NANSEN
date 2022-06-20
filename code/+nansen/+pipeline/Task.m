classdef Task
%TASK Task that can be added to a pipeline.
    %   Detailed explanation goes here
    
    % Questions: 
    % Inherit from DataMethod???
    %   Need to update session object to indicate that task finished.
    
    
    
    
    properties
        TaskName char           % Name of task (for displays)
        FunctionName char       % Name of function to run this task
        OptionsName char        % Name of options preset to use for task
        IsManual logical        % Dependent on function name
        WasAborted logical      % Depends on task execution...
        IsFinished logical      % Boolean flag to indicate if task was completed
        DateFinished datetime   % Datetime for when task is finished
    end
    
    properties (Dependent, SetAccess = private)    
        %IsFinished logical      % Flag for whether task is finished
    end
    
    methods
        function obj = Task()
            %TASK Construct an instance of a pipeline Task
            %   Detailed explanation goes here

        end
        
    end
    
    methods 
%         function isFinished = get.IsFinished(obj)
%             isFinished = ~isempty(obj.DateFinished);
%         end
    end
    
    methods % Methods for converting to and from struct. Todo: Structadapter
        
        function S = struct(obj)
        %struct Get a struct from a note instance.    
            warning('off', 'MATLAB:structOnObject')
            S = builtin('struct', obj);        
            warning('on', 'MATLAB:structOnObject')
        end
        
        function obj = fromStruct(obj, S)
        %fromStruct Get property values from fields of struct
        
            propNames = fieldnames(S);
            numTasks = numel(S);
            
            obj(numTasks) = nansen.pipeline.Task;
            
            for iObj = 1:numel(S)
                for jProp = 1:numel(propNames)
                    obj(iObj).(propNames{jProp}) = S(iObj).(propNames{jProp});
                end
            end

        end
        
    end
    
end

