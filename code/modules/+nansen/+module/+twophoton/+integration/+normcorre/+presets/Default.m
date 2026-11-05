classdef Default < nansen.module.twophoton.integration.normcorre.Options

    properties (Constant)
        Name = 'Nonrigid (4x4)'
        Description = 'The original preset options for nonrigid correction'
    end

    methods (Static)

        function S = getOptions()
            S = getOptions@nansen.module.twophoton.integration.normcorre.Options();
        end
    end
end
