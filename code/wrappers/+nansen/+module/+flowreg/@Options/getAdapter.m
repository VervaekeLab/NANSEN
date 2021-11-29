function M = getAdapter()
%nansen.module.flowreg.Options.getAdapter
%
%    M = nansen.module.flowreg.Options.getAdapter() returns a struct (M) 
%       where each field of M corresponds to a field from the options, and 
%       the value is the name of that parameter from the original toolbox 
%       options. 

    M                               = struct();

    M.General.smoothness            = 'alpha';
    M.General.verbose               = 'verbose';

    M.Channel.normalization         = 'channel_normalization';
    M.Channel.weighting             = 'weight';
    M.Channel.alpha                 = 'alpha';

    M.Quality.registrationQuality   = 'quality_setting';
    M.Quality.levels                = 'levels';
    M.Quality.minimumLevel          = 'min_level';
    M.Quality.iterations            = 'iterations';

    M.Model.downsamplingFactor      = 'eta';
    M.Model.updateLag               = 'update_lag';
    M.Model.aSmooth                 = 'a_smooth';
    M.Model.aData                   = 'a_data';
    M.Model.sigma                   = 'sigma';
    M.General.binSize               = 'bin_size';
    M.General.verbose               = 'verbose';
    
end
     
