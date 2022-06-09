classdef HasSubSteps < handle
%HasSubSteps Mixin class for DataMethod providing interface for displaying
% descriptions about substeps of the method.
    
    % Todo: Abstract property DialogInterface... I.e subclasses must
    % implement a dialog interface...
    
    properties
        % Flag for whether the method with substeps is itself a subprocess 
        % (in which case, message display is skipped).
        IsSubProcess (1,1) logical = false 
    end
    
    properties (Access = private)
        % List with information of substeps. Used for progress display
        StepList nansen.processing.util.DataMethodSubStep 
    end
    
    properties (Dependent)
        NumSteps % Number of substeps in method
    end
    
    methods (Abstract)
        printTask(obj, varargin) % Should be implemented on subclasses.
    end
    
    methods
        function numSteps = get.NumSteps(obj)
            numSteps = numel(obj.StepList);
        end
    end
    
    methods (Access = protected)
        
        function addStep(obj, id, description, listPosition)
        %addStep Add step to step list    
            import nansen.processing.util.DataMethodSubStep
            
            if nargin < 4; listPosition = 'end'; end
            listPosition = validatestring(listPosition, {'beginning', 'end'});
            
            if obj.hasStep(id) 
                warning('Step with id "%s" already exists in the step list', id)
            else
                newSubStep = DataMethodSubStep(id, description);

                switch listPosition
                    case 'beginning'
                        obj.StepList = [newSubStep, obj.StepList];
                    case 'end'
                        obj.StepList = [obj.StepList, newSubStep];
                end
            end
        end
        
        function tf = hasStep(obj, id)
            tf = contains(id, {obj.StepList.StepID});
        end
        
        function idx = findStep(obj, id)
            idx = find( strcmp({obj.StepList.StepID}, id) );
        end
        
        function displayProcessingSteps(obj)
        %displayProcessingSteps Display the processing steps for process    
                        
            obj.printTask('Processing will happen in %d steps:', obj.NumSteps);
            
            for i = 1:obj.NumSteps
                 obj.printTask('Step %d/%d: %s', i, obj.NumSteps, ...
                     obj.StepList(i).Description)
            end
            fprintf( newline )
        end
        
        function displayStartStep(obj, stepId)
        %displayStartStep Display message when specified step is started   
            
            idx = obj.findStep(stepId);

            obj.printTask('Running step %d/%d: %s...', idx, obj.NumSteps, ...
                obj.StepList(idx).Description )
        end
        
        function displayFinishStep(obj, stepId)
        %displayFinishStep Display message when specified step is finished    
            
            idx = obj.findStep(stepId);
            
            obj.printTask('Finished step %d/%d: %s.\n', idx, obj.NumSteps, ...
                obj.StepList(idx).Description)
        end
        
    end
    
end