classdef (ConstructOnLoad) CurrentProjectChangedEventData < event.EventData
    
    properties
        OldProjectName % Name of previous selection for current project
        NewProjectName % Name of new selection for current project
    end
    
    methods
        function data = CurrentProjectChangedEventData(oldProjectName, newProjectName)
            data.OldProjectName = oldProjectName;
            data.NewProjectName = newProjectName;
        end
    end
end
