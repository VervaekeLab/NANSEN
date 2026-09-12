function [dec, den, opt] = caiman(dff, varargin)
%caiman Route the "caiman" deconvolution method to the CaImAn integration
%
%   deconvolveDff resolves deconvolution methods by name from this
%   package, so this thin entry point keeps the method name stable while
%   the implementation lives with the CaImAn integration.
%
%   See also nansen.module.twophoton.integration.caiman.deconvolve

    [dec, den, opt] = nansen.module.twophoton.integration.caiman.deconvolve(dff, varargin{:});
end
