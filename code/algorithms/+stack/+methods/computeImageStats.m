classdef computeImageStats < nansen.stack.ImageStackProcessor
%computeImageStats Compute pixel statistics for imagestack
%
%   Mean, limits and percentiles of all pixels for stack.
      
    properties (Constant)
        MethodName = 'Compute Image Stats'
        IsManual = false        % Does method require manual supervision
        IsQueueable = true      % Can method be added to a queue
        OptionsManager = nansen.OptionsManager('nansen.stack.ImageStackProcessor')
    end
    
    properties %Options
        %pLevels = [0.05, 0.005];
    end
    
    properties (Access = private)  
        ImageStats
        SaturationValue
    end
    
    methods (Static)
        function S = getDefaultOptions()
            S = struct();
            S.PercentileLevels = [0.05, 0.005];
            
            className = mfilename('class');
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            S = nansen.mixin.HasOptions.combineOptions(S, superOptions{:});
        end
    end
    
    
    methods % Structor
        
        function obj = computeImageStats(varargin)
            
            obj@nansen.stack.ImageStackProcessor(varargin{:})
            
            if ~nargout
                obj.runMethod()
                clear obj
            end
        end
        
    end
    
    methods (Access = protected)
        
        function onInitialization(obj)
            
            % obj.openSourceStack() % todo...
            obj.initializeImageStats();
            
            % Get saturation value from ImageStack object.
            dataIntensityLimits = obj.SourceStack.DataTypeIntensityLimits;
            obj.SaturationValue = dataIntensityLimits(2);
        end

    end
    
    methods (Access = protected) % Implement methods from ImageStackProcessor
        
% % %         function openSourceStack(obj)
% % %              
% % %             % Get filepath for raw 2p-images
% % %             DATANAME = 'TwoPhotonSeries_Original';
% % %             filePath = obj.SessionObjects.getDataFilePath(DATANAME);
% % %             
% % %             % Initialize file reference for raw 2p-images
% % %             obj.SourceStack = imviewer.stack.open(filePath);
% % %             
% % %         end
% % %         
        function Y = processPart(obj, Y)
            obj.updateImageStats(Y)
            obj.saveImageStats() % Save results for every part
            Y = [];
        end
        
        function tf = checkIfPartIsFinished(obj, partNumber)
        %checkIfPartIsFinished Check if specified part is completed        
            frameIndices = obj.FrameIndPerPart{partNumber};
            tf = all( ~isnan(obj.ImageStats.meanValue(frameIndices) ) );
        end
        
    end
    
    methods (Access = private) 

        function S = initializeImageStats(obj)
        %initializeImageStats Create new or load existing struct.
        %

            % Check if image stats already exist for this datalocation
            filePath = obj.getDataFilePath('imageStats', ...
                'Subfolder', 'raw_image_info');
            
            if isfile(filePath)
                S = obj.loadData('imageStats');
            else
                
                numFrames = obj.SourceStack.NumFrames;

                nanArray = nan(numFrames, 1);
                    
                S = struct();
                
                S.meanValue = nanArray;
                S.medianValue = nanArray;
                S.minimumValue = nanArray;
                S.maximumValue = nanArray;

                pLevels = [0.05, 0.005];
                pLevels = [pLevels, 100-pLevels];

                S.percentileValues = pLevels;

                S.prctileL1 = nanArray;
                S.prctileL2 = nanArray;
                S.prctileU1 = nanArray;
                S.prctileU2 = nanArray;
                
                S.pctSaturatedValues = nanArray;

                obj.saveData('imageStats', S, ...
                    'Subfolder', 'raw_image_info');
                
            end
            
            obj.ImageStats = S;

        end
        
        function updateImageStats(obj, Y)
        %updateImageStats Update image stats for current part.
        
            % Skip computation if results already exist...
            if obj.checkIfPartIsFinished(obj.CurrentPart)
                return
            end
        
            IND = obj.CurrentFrameIndices;

            Y = single(Y);
            
            % Reshape to 2D array where all pixels from each image is 1D
            Y_ = reshape(Y, [], size(Y, 3));
            
            obj.ImageStats.meanValue(IND) = nanmean( Y_ );
            obj.ImageStats.medianValue(IND) = nanmedian( Y_ );
            obj.ImageStats.minimumValue(IND) = min( Y_ );
            obj.ImageStats.maximumValue(IND) = max( Y_ );
            
            pLevels = obj.ImageStats.percentileValues;

            % Collect different stats.
            prctValues = prctile(Y_, pLevels)';
            if iscolumn(prctValues); prctValues = prctValues'; end % If size(Y, 3)==1. 
            
            obj.ImageStats.prctileL1(IND) = prctValues(:, 1);
            obj.ImageStats.prctileL2(IND) = prctValues(:, 2);
            obj.ImageStats.prctileU1(IND) = prctValues(:, 3);
            obj.ImageStats.prctileU2(IND) = prctValues(:, 4);
            
            obj.ImageStats.pctSaturatedValues(IND) = mean(Y_ == obj.SaturationValue, 1);
                        
        end
        
        function saveImageStats(obj)
        %saveImageStats Save statistical values of image data  
        %
        %   saveImageStats(obj, Y)
        
            % Save updated image stats to data location
            S = obj.ImageStats;
            obj.saveData('imageStats', S)
            
        end

    end
    

end