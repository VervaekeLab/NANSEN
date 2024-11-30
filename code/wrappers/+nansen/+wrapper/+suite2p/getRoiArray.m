function roiArray = getRoiArray(stat, imsize)
%getRoiArray Get roi array from stats output of suite2p

    numRois = numel(stat);
    roiArray = RoI.empty;
    [roiArray(1:numRois)] = deal(RoI);

    if isa(stat, 'cell')
        stat = cat(1, stat{:});
    end
    
    mask = zeros(imsize, 'single');
    
    if isfield(stat(1), 'ipix') % matlab version
        mask = logical(mask);
        for i = 1:numel(stat)

           mask(stat(i).ipix) = true;
           roiArray(i) = RoI('Mask', mask, imsize);

           mask(stat(i).ipix) = false;
        
        end
        
    else % python version
        
        for i = 1:numel(stat)
            %ind = sub2ind(imsize, stat(i).ypix, stat(i).xpix);
            %mask(ind) = stat(i).lam;
            
            coords = [single(stat(i).xpix)', single(stat(i).ypix)', stat(i).lam'];
            roiArray(i) = RoI('IMask', coords, imsize);
            
            %roiArray(i) = RoI('Mask', logical(mask), imsize);

            % Reset mask
            %mask(ind) = 0;
        
        end
    end
end
