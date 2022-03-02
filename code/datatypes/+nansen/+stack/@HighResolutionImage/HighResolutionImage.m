classdef HighResolutionImage < nansen.stack.ImageStack
%HighResolutionImage Pyramidal multiresolution interface to hires image
%
%   This derivation of ImageStack provides methods to retrieve spatially 
%   downsampled versions of a high resolution image at different
%   magnifications and crops. This is necessary when viewing an image in
%   the imviewer, in order to have a smooth experience. Displaying the full
%   image at the original resolution leads to performance issues.

% %     properties
% %         DataXLim (1,2) double    % When these are set, any call to the getFrameSet will return the portion of the image within these limits
% %         DataYLim (1,2) double    % When these are set, any call to the getFrameSet will return the portion of the image within these limits
% %     end
    
    properties (Access = private)
        DownSamplingFactors = 1; % A list of factors that were used for creating downsampled versions
        DownsampledImageData     % Cell array containing a set of spatially downsampled versions of the original image
    end
    
    
    methods % Constructor
        function obj = HighResolutionImage(datareference, varargin)
            
            obj@nansen.stack.ImageStack(datareference, varargin{:})
            
            frameSizeOrig = max(obj.ImageHeight, obj.ImageWidth);
            obj.DataXLim = [1, obj.ImageWidth];
            obj.DataYLim = [1, obj.ImageHeight];
            
            % calculate downsampling factors
            obj.DownSamplingFactors = 1;
            
            frameSize = frameSizeOrig;
            finished = false;
            count = 0;
            
            while ~finished
                count = count+1;
                frameSize = frameSize/2;

                 obj.DownSamplingFactors(end+1) = round(frameSizeOrig/frameSize);
                
                if frameSize < 512
                    finished = true;
                end
            end
            
            
            % Load data
            imData = obj.getFrameSet('all'); % Load data and add to a in-memory MatlabArray
            obj.Data = nansen.stack.data.MatlabArray(imData);
            
            
            % Create downsampled versions of the image
            imPyramid = cell(count,1);

            for i = 1:numel(imPyramid)
                if  i == 1
                    imPyramid{i} = imresize(imData, 0.5);
                else
                    imPyramid{i} = imresize(imPyramid{i-1}, 0.5);
                end
            end
            
            obj.DownsampledImageData = imPyramid;
        end
        
    end
    
    methods % Methods for getting data
        
        function imArray = getFullImage(obj)
            numDims = ndims(obj.Data);
            
            % Initialize list of subs
            subs = cell(1, numDims);
            subs(:) = {':'};
            
            imArray = obj.Data(subs{:});

        end
        
        function imArray = getFrameSet(obj, frameInd, dsFactor)
            
            if nargin < 3; dsFactor = 1; end
            
            if ~isempty(obj.DownSamplingFactors) % On construction...
                [~, dsInd] = min( abs( dsFactor - obj.DownSamplingFactors) );
            else
                dsInd = 1;
            end
            
            subs = obj.getDataIndexingStructure(frameInd, dsInd);
            
            dsInd = dsInd-1;
            
            if dsInd == 0
                imArray = obj.Data(subs{:});
            else
                imArray = obj.DownsampledImageData{dsInd}(subs{:});
            end
            
        end
        
        function subs = getDataIndexingStructure(obj, frameInd, dsInd)
            
            numDims = ndims(obj.Data);
            
            % Initialize list of subs
            subs = cell(1, numDims);
            subs(:) = {':'};
            
            dsFactor = obj.DownSamplingFactors(dsInd);
            
            for i = 1:numDims
                
                thisDim = obj.DataDimensionOrder(i);
                
                switch thisDim
                    case 'C'
                        subs{i} = obj.CurrentChannel;
                    case 'Z'
                        subs{i} = obj.CurrentPlane;
                    case 'T'
                        if ischar(frameInd) && strcmp(frameInd, 'all')
                            frameInd = 1:obj.NumTimepoints;
                        end
                        
                        subs{i} = frameInd;
                        
                    case 'X'
                        if ~all(obj.DataXLim==0)
                            downsampledXLim = ceil(obj.DataXLim ./ dsFactor);
                            subs{i} = downsampledXLim(1):downsampledXLim(2);
                        end
                        
                    case 'Y'
                        if ~all(obj.DataYLim==0)
                            downsampledYLim = ceil(obj.DataYLim ./ dsFactor);
                            subs{i} = downsampledYLim(1):downsampledYLim(2);
                        end
                end
            end
            
        end
        
    end

end