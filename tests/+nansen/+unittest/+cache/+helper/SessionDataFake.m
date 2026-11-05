classdef SessionDataFake < nansen.session.SessionData
%SessionDataFake Minimal SessionData subclass for cache integration tests
%
%   Exposes registerVariable so tests can add data variables without a full
%   project or VariableModel, exercising the real load-through and display
%   paths directly.

    methods
        function obj = SessionDataFake(sessionObj)
            obj@nansen.session.SessionData(sessionObj);
        end

        function registerVariable(obj, variableName)
            obj.addDataProperty(variableName);
            % Include the fields the display (getPropertyGroups) reads, so a
            % fake-built object can also be rendered without a project.
            item = struct( ...
                "VariableName", char(variableName), ...
                "IsInternal", false, ...
                "IsFavorite", false, ...
                "IsCustom", true);
            obj.appendToVariableList(item);
        end
    end
end
