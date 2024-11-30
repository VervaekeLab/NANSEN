classdef Preferences < handle

    properties
        RequiredModule char
        OptionalModules cell
    end

    methods (Access = ?nansen.config.project.Project)
        function obj = Preferences()
            
        end
    end
end
