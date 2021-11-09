function foundRois = run(M, config)

    config = get_defaults(config);

    [S, T, summary] = run_extract(M, config);

    imSize = size(M);
    numRois = size(S,2);
    
    S = reshape(S, [imSize(1:2), numRois]);
    
    roiArray = RoI.empty;
    
    
    for i = 1:numRois
        roiArray(i) = RoI('Mask', S(:, :, i)>0.33, imSize(1:2));
    end
    
    foundRois = roiArray;
    
end