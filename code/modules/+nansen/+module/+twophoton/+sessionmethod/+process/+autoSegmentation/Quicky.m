classdef Quicky < nansen.module.twophoton.sessionmethod.process.autoSegmentation.FluFinder
%Quicky Compatibility alias for the FluFinder session method.
%
%   Persisted pipelines and session-method catalogs may still refer to
%   this name. The canonical method is FluFinder; this class only forwards
%   to it.
%
%   A chained superclass constructor always sees nargout == 1, so the
%   "run when called without an output" behaviour has to be repeated here.
%
%   See also nansen.module.twophoton.sessionmethod.process.autoSegmentation.FluFinder

    methods

        function obj = Quicky(varargin)
            obj@nansen.module.twophoton.sessionmethod.process.autoSegmentation.FluFinder(varargin{:})

            if ~nargin; return; end

            if ~nargout
                obj.runMethod()
                clear obj
            end
        end
    end
end
