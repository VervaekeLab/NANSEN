classdef StructEditorSpy < structeditor.App
%StructEditorSpy Struct editor that records input problems instead of showing them
%
%   Records the text the editor would show in an error dialog, so a test
%   that presses Save does not open a window that takes focus.

    properties (SetAccess = private)
        ReportedProblems (1,:) string = string.empty(1, 0)
    end

    methods

        function obj = StructEditorSpy(varargin)
            obj@structeditor.App(varargin{:})
        end
    end

    methods (Access = protected)

        function showInputProblem(obj, problem)
            obj.ReportedProblems = [obj.ReportedProblems, reshape(problem, 1, [])];
        end
    end
end
