classdef ObservableTestItem < handle
    % ObservableTestItem - Minimal metaObject helper for MetaTable cache tests
    %
    %   A handle-based stand-in for a real metadata entity. It exposes the
    %   contract MetaTable relies on when constructing and caching
    %   metaObjects from table rows:
    %     - a constant IDNAME naming the identifier property,
    %     - a PropertyChanged event (so the cache listener wiring attaches),
    %     - SetObservable, table-backed properties whose PostSet triggers
    %       the reverse-sync path back into the MetaTable entries.

    properties (Constant, Hidden)
        IDNAME = 'itemID'
    end

    properties (SetObservable)
        itemID char
        Value double
    end

    events
        PropertyChanged
    end

    methods
        function obj = ObservableTestItem(tableRow)
            if nargin == 0
                return
            end
            obj.itemID = tableRow.itemID{1};
            obj.Value = tableRow.Value;
        end
    end
end
