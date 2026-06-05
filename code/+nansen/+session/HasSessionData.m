classdef HasSessionData < uim.handle & matlab.mixin.CustomDisplay
%HasSessionData Mixin providing lazy access to a SessionData object
%
%   Adds a Data property holding a nansen.session.SessionData for the
%   object. The SessionData is initialized lazily on first access to Data
%   (initialization scans which variables exist on disk), so constructing
%   many entities stays cheap.
%
%   Initialization is triggered by get.Data, i.e. an explicit obj.Data
%   reference. Display does not trigger it: getPropertyGroups shows the Data
%   property from its private backing field, so rendering the object never
%   calls get.Data and never scans disk.

%   Note: Data is a runtime accessor, not persistent state. It is kept 
%   Transient so it is neither saved with the object nor carried to a 
%   parallel worker (it is per-process runtime state). Because Transient 
%   strips Data_ on save/load and on transfer to a worker, Data is Dependent 
%   and backed by a private Data_.
%   get.Data recreates a fresh SessionData whenever Data_ is empty.

    properties (Dependent, Transient)
        Data nansen.session.SessionData
    end

    properties (Transient, Access = private)
        Data_ nansen.session.SessionData
    end

    methods
        function obj = HasSessionData()
            % Create (but do not initialize) a SessionData for each object.
            for i = 1:numel(obj)
                obj(i).Data_ = nansen.session.SessionData(obj(i)); %#ok<AGROW>
            end
        end

        function delete(obj)
            delete(obj.Data_)
        end
    end

    methods % Set/get
        function data = get.Data(obj)
            for i = 1:numel(obj)
                if isempty(obj(i).Data_)
                    obj(i).Data_ = nansen.session.SessionData(obj(i));
                end

                % Initialize lazily on first explicit access. Display routes
                % through getPropertyGroups instead, so it never reaches here.
                if ~obj(i).Data_.IsInitialized
                    obj(i).Data_.initialize();
                end
            end
            data = obj.Data_;
        end
    end

    methods (Access = protected) % Custom display
        function group = getPropertyGroups(obj)
            if ~isscalar(obj)
                group = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
                return
            end

            % properties() lists the public (non-hidden) properties by name
            % without evaluating any get-methods. We then supply the values
            % ourselves so the Data property can be shown from its backing
            % field (Data_) without calling get.Data - displaying the object
            % therefore never triggers a scan for linked data variables.
            propNames = properties(obj);

            values = struct();
            for i = 1:numel(propNames)
                name = propNames{i};
                if strcmp(name, 'Data')
                    values.Data = obj.Data_;   % shown without initializing
                else
                    values.(name) = obj.(name);
                end
            end

            group = matlab.mixin.util.PropertyGroup(values);
        end
    end
end
