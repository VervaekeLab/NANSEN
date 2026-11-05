classdef Soma < nansen.module.twophoton.autosegmentation.flufinder.Options

    properties (Constant)
        Name = 'Soma'
        Description = 'Optimized for detecting soma-like structures'
    end

    methods (Static)

        function S = getOptions()
            S = getOptions@nansen.module.twophoton.autosegmentation.flufinder.Options();
        end
    end
end
