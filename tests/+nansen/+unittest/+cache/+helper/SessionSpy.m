classdef SessionSpy < handle
%SessionSpy Test spy standing in for the Session that a SessionData wraps
%
%   Provides the small surface SessionData's cache path touches (a sessionID
%   and loadData) and records how many times each variable has been loaded,
%   so a test can assert load-through behaviour (e.g. loaded once, reloaded
%   after invalidation).

    properties
        sessionID (1,1) string
        DataLocationModel = []
        LoadCounts          % containers.Map: char varName -> double
    end

    methods
        function obj = SessionSpy(sessionID)
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
