function M = getAdapter()
%normcorre.Options.getAdapter
%
%    M = normcorre.Options.getAdapter() returns a struct (M) where each 
%       field of M corresponds to a field from the options, and the value 
%       is the name of that parameter from the original toolbox options. 

    M                               = struct();
    
    M.Configuration.patchOverlap    = 'overlap_pre';
    M.Configuration.gridUpsampling  = 'mot_uf';

    M.Template.initialBatchSize     = 'init_batch';
    M.Template.updateTemplate       = 'upd_template';
    M.Template.binWidth             = 'bin_width';

    M.Correction.maximumShift       = 'max_shift';
    M.Correction.maximumDeviation   = 'max_dev';
    M.Correction.subpixelUpsampling = 'us_fac';
    M.Correction.numIterations      = 'iter';
    M.Correction.shiftsMethod       = 'shifts_method';
    M.Correction.boundary           = 'boundary';
    M.Correction.phaseFlag          = 'phase_flag';

    M.Misc.Verbose                  = 'print_msg';
    M.Misc.UseParallell             = 'use_parallel';

end
     
