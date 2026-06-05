classdef SessionDataHarness < nansen.session.SessionData
%SessionDataHarness Test harness exposing protected SessionData internals
%
%   Lets a test register a data variable without a full project or
%   VariableModel, so the real subsref -> shared-cache load-through path can
%   be exercised directly.

    methods
        function obj = SessionDataHarness(sessionObj)
            obj@nansen.session.SessionData(sessionObj);
        end

        function registerVariable(obj, variableName)
            obj.addDataProperty(variableName);
            % Include the fields the display (getPropertyGroups) reads, so a
            % harness-built object can also be rendered without a project.
            item = struct( ...
                "VariableName", char(variableName), ...
                "IsInternal", false, ...
                "IsFavorite", false, ...
                "IsCustom", true);
            obj.appendToVariableList(item);
        end
    end
end
