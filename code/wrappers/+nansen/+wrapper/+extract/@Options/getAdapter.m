function S = getAdapter() % todo: remame: getOptionsConversionMap()

    S = struct();

    % Cell finding parameters
    S.CellFind.min_snr                          = 'cellfind_min_snr';
    S.CellFind.dendrite_aware                   = 'dendrite_aware';
    S.CellFind.max_steps                        = 'cellfind_max_steps';
    S.CellFind.kappa_std_ratio                  = 'cellfind_kappa_std_ratio';
    S.CellFind.adaptive_kappa                   = 'adaptive_kappa';
    S.CellFind.spatial_lowpass_cutoff           = 'spatial_lowpass_cutoff';
    S.CellFind.init_with_gaussian               = 'init_with_gaussian';
    S.CellFind.filter_type                      = 'cellfind_filter_type';
    S.CellFind.moving_radius                    = 'moving_radius';
    S.CellFind.numpix_threshold                 = 'cellfind_numpix_threshold';
    S.CellFind.high2low_brightness_ratio        = 'high2low_brightness_ratio';
    S.CellFind.S_init                           = 'S_init';

end