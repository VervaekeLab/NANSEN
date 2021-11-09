function imOut = makeBinnedMaximum(im, binning)


    nFramesOut = floor(size(im, 3) / binning);
    imOut = squeeze(max(reshape(im(:,:,1:nFramesOut*binning), size(im,1), size(im,2), binning, nFramesOut), [], 3));


end