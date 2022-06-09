classdef DataMethodSubStep < handle
%DataMethodSubStep Holds an id and a description for a DataMethod substep
%
%   The purpose of this class is to have a definition of a substep item 
%   for a DataMethod.
%
%   Provides method to find a substep from a list given an id.

    properties
        StepID char
        Description char
    end
    
    methods
        
        function obj = DataMethodSubStep(id, description)
            if nargin == 0
                return
            end
           
            obj.StepID = id;
            obj.Description = description;
        end
        
        function idx = findStep(obj, id)
            idx = find( strcmp({obj.StepID}, id) );
        end
        
        function tf = containsStep(obj, id)
            tf = contains(id, {obj.StepID});
        end
    end
    
end