function [roiArray, cnmfResults] = run(Y, roiDiameter)

    % Get number of rois from user. Set size to the radius
    % specified by the autodetection size property.
    numRois = str2double(inputdlg('Enter number of Rois to search for'));
    if isempty(numRois); return; end

    % % Data pre-processing
    p = 2; % order of autoregressive system (p = 0 no dynamics, p=1 just decay, p = 2, both rise and decay)
    [P, Y] = preprocess_data(Y, p);
    
    roiRadius = round(roiDiameter / 2);
    
    options = autosegment.cnmf.getOptions(size(Y), roiRadius);

    % % fast initialization of spatial components using greedyROI and HALS
    [Ain,Cin,bin,fin,center] = initialize_components(Y, numRois, roiRadius, options, P);

    % % update spatial components
    Yr = reshape(Y, options.d, options.nFrames);
    [A,b,Cin] = update_spatial_components(Yr,Cin,fin,[Ain,bin],P,options);

    % % update temporal components
    P.p = 0;    % set AR temporarily to zero for speed
    [C,f,P,S,YrA] = update_temporal_components(Yr,A,b,Cin,fin,P,options);

    % % merge found components
    [Am,Cm,K_m,merged_ROIs,Pm,Sm] = merge_components(Yr,A,b,C,f,P,S,options);

    % % evaluate components
    options.space_thresh = 0.3;
    options.time_thresh = 0.3;
    [rval_space,rval_time,ind_space,ind_time] = classify_comp_corr(Y,Am,Cm,b,f,options);

    keep = ind_time & ind_space; 
    throw = ~keep;

    % % refine estimates excluding rejected components
    Pm.p = p;    % restore AR value
    [A2,b2,C2] = update_spatial_components(Yr,Cm(keep,:),f,[Am(:,keep),b],Pm,options);
    [C2,f2,P2,S2,YrA2] = update_temporal_components(Yr,A2,b2,C2,f,Pm,options);

    % % do some plotting

    [A_or, C_or, S_or, P_or] = order_ROIs(A2,C2,S2,P2); % order components

    [C_df,~] = extract_DF_F(Yr,A_or,C_or,P_or,options); % extract DF/F values (optional)

    % % convert to array of RoI objects
    roiArray = autosegment.cnmf.getRoiArray(A_or, options);
    
    cnmfResults = struct;
    cnmfResults.A = A_or;
    cnmfResults.C = C_or;
    cnmfResults.S = S_or;
    cnmfResults.Cdff = C_df;

end