function roiArray = removeOverlappingRois(roiArrayA, roiArrayB)

    if ~isempty(roiArrayA)
        [iA, iB] = roimanager.utilities.findOverlappingRois(roiArrayA, roiArrayB);
        for n = 1:numel(iA)
            roiArrayB(iB(n)).uid = roiArrayA(iA(n)).uid;
        end
        roiArrayA(iA) = [];
    end

    roiArray = cat(2, roiArrayB, roiArrayA);

end
