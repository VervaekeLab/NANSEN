classdef RoiAdapter < handle
%RoiAdapter Interface for a roi data adapter.
%
%   In order to work with the RoiConverter, each specific implementation
%   should be placed in its own a class folders in the +adapter package
%   folder (See existing adapters for examples).
%   A roi adapter should implement the following methods:

    properties
        FilePath
    end

    methods % Constructor
        
        function obj = RoiAdapter(filepath)
            if ~nargin; return; end
            obj.FilePath = filepath;
        end
    end

    methods (Abstract)
        
        % Return the following outputs given data as input
        [roiArray, classification, stats, images] = convertRois(obj, data)

    end

    methods (Abstract, Static)
        
        % Return true if a filePath and/or data matches the roi format of
        % the specific adapter.
        tf = isRoiFormatValid(filePath, data)

    end
end
