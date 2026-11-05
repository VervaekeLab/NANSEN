classdef HasSessionDataStub < nansen.session.HasSessionData & dynamicprops
%HasSessionDataStub Stub host of the HasSessionData mixin, for its tests
%
%   A minimal concrete host of nansen.session.HasSessionData (and
%   dynamicprops, like a real Session) used to exercise the mixin in
%   isolation. It supplies only what SessionData touches during an aborted
%   initialize: a sessionID and an empty DataLocationModel, so initialization
%   bails cleanly without needing a project.

    properties
        sessionID (1,1) string = "stub-session"
    end

    properties (Hidden)
        DataLocationModel = []
    end

    methods
        function obj = HasSessionDataStub()
            obj@nansen.session.HasSessionData();
        end
    end
end
