classdef CacheSizeStub < handle
%CacheSizeStub Test double: a handle object that reports its own cache size
%
%   Data-heavy classes can opt out of serialization-based sizing by
%   implementing getCacheSize. This stub exercises that contract.

    properties
        ReportedBytes (1,1) double
    end

    methods
        function obj = CacheSizeStub(reportedBytes)
            obj.ReportedBytes = reportedBytes;
        end

        function numBytes = getCacheSize(obj)
            numBytes = obj.ReportedBytes;
        end
    end
end
