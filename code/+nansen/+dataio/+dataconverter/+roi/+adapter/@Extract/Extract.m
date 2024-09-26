classdef Extract < nansen.dataio.dataconverter.roi.RoiAdapter

    methods (Static) % Methods in separate files
        tf = isRoiFormatValid(filePath, data)
    end

    methods

        [roiArray, classification, stats, images] = convertRois(obj, data)

    end
end
