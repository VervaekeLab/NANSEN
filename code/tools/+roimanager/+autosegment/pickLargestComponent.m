function BW = pickLargestComponent(BW)
%pickLargestComponent Pick component with largest area from a BW mask

    CC = bwconncomp(BW);

    if ~(CC.NumObjects == 0)

        stat = regionprops(CC, 'Area');

        [~, ind] = max([stat.Area]);

        BW(:) = 0;
        BW(CC.PixelIdxList{ind})=1;

    end
    
end