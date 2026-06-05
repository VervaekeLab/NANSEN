classdef FakeSessionEntity < nansen.session.HasSessionData & dynamicprops
%FakeSessionEntity Minimal HasSessionData host for lazy-Data tests
%
%   Mirrors a real Session closely enough for display/lazy-init tests: it is
%   a dynamicprops host (so dynamic "metadata" properties can be added) and
%   provides what SessionData touches during an (aborted) initialize - a
%   sessionID and an empty DataLocationModel, so init bails cleanly without
%   needing a project.

    properties
        sessionID (1,1) string = "fake-1"
    end

    properties (Hidden)
        DataLocationModel = []
    end

    methods
        function obj = FakeSessionEntity()
            obj@nansen.session.HasSessionData();
        end
    end
end
