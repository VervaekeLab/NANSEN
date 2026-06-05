classdef RefreshableTestItem < nansen.metadata.abstract.MetadataEntity
    %RefreshableTestItem Minimal MetadataEntity for cache refresh tests.

    properties (Constant, Hidden)
        ANCESTOR = ''
        IDNAME = 'itemID'
    end

    properties (SetObservable)
        itemID char
        Value double
        NonnegativeValue (1,1) double {mustBeNonnegative} = 0
    end

    methods
        function obj = RefreshableTestItem(varargin)
            obj@nansen.metadata.abstract.MetadataEntity(varargin{:})
        end
    end
end
