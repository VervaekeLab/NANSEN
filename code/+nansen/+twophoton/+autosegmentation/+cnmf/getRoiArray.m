function roiArray = getRoiArray(A, options)

    % convert to array of RoI objects
    roiArray = RoI.empty;

    for i = 1:size(A, 2)
        Atemp = reshape(A(:,i), options.d1, options.d2);
        Atemp = full(Atemp);
        mask = Atemp>0;

        %loop through all rois pass roi mask to RoI
        newRoI = RoI('Mask', mask, [options.d1, options.d2]);
        newRoI.structure = 'ad';
        roiArray(i) = newRoI;
    end
    
end