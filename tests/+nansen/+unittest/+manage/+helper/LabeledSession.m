classdef LabeledSession < nansen.metadata.type.Session
%LabeledSession - A session type with one property that nansen.metadata.type.Session lacks
%
%   Tests use it as the class of a session table, to check that functions
%   which create sessions for a table create them with the class of the
%   table.

    properties (SetObservable)
        Label char
    end

    methods
        function obj = LabeledSession(varargin)
            obj@nansen.metadata.type.Session(varargin{:})
        end
    end
end
