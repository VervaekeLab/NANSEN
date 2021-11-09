function dff_true = dffChenEtAl2013(roisignals, npilsignals)
% dF/F is calculated according to the method used by Chen et al (2013,
% Nature) by subtracting neuropil at a weight of 70%. However, while not
% specified in the Chen paper, here the baseline of the neuropil is added
% back into the signal as to not subtract too much.

    npil_true0 = prctile(npilsignals,20);
    f_true = roisignals - (0.7*npilsignals) + npil_true0;
    f_true0 = prctile(f_true,20);
    dff_true = (f_true - f_true0) ./ f_true0;
    
end