classdef FakeSession < handle
%FakeSession Minimal session stand-in for SessionData cache integration tests
%
%   Provides only the surface that SessionData's cache path touches: a
%   sessionID and a loadData method that records how many times each
%   variable has been loaded, so a test can assert load-through behaviour.

    properties
        sessionID (1,1) string
        DataLocationModel = []
        LoadCounts          % containers.Map: char varName -> double
    end

    methods
        function obj = FakeSession(sessionID)
            obj.sessionID = sessionID;
            obj.LoadCounts = containers.Map("KeyType", "char", "ValueType", "double");
        end

        function data = loadData(obj, varName, varargin)
            key = char(varName);
            if obj.LoadCounts.isKey(key)
                obj.LoadCounts(key) = obj.LoadCounts(key) + 1;
            else
                obj.LoadCounts(key) = 1;
            end
            data = magic(8);   % deterministic, non-empty payload
        end

        function n = loadCount(obj, varName)
            key = char(varName);
            if obj.LoadCounts.isKey(key)
                n = obj.LoadCounts(key);
            else
                n = 0;
            end
        end
    end
end
