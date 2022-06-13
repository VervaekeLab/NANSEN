classdef PixelStatCalculator < nansen.stack.ImageStackProcessor
%PixelStatCalculator Calculate pixel statistics for imagestack
%
%   Mean, limits and percentiles of all pixels for stack.

%   Todo:
%       [ ] Calculate noise levels...
%       [ ] Use ImageStackProcessor's Results instead of ImageStats?
    
    properties (Constant)
        MethodName = 'Compute Pixel Stats'
        IsManual = false        % Does method require manual supervision
        IsQueueable = true      % Can method be added to a queue
        OptionsManager = nansen.OptionsManager('nansen.stack.ImageStackProcessor')
    end
    
    properties (Constant, Hidden) % Inherited from DataMethod
        DATA_SUBFOLDER = 'image_pixel_stats';
        VARIABLE_PREFIX = 'PixelStats';
    end
    
    properties %Options
        %ChannelMode = 'serial'  % Compute values for each channel individually
        %PlaneMode = 'serial'    % Compute values for each plane individually
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
        
        function obj = PixelStatCalculator(varargin)
            
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
        
        function [Y, results] = processPart(obj, Y)
            obj.updateImageStats(Y)
            obj.saveImageStats() % Save results for every part
            Y = []; results = true;
        end
        
        function tf = allIsFinished(obj)
            tf = all( cellfun(@(c) ~isempty(c), obj.ImageStats(:)) );
        end

        function tf = checkIfPartIsFinished(obj, partNumber)
        %checkIfPartIsFinished Check if specified part is completed        
            
            frameIndices = obj.FrameIndPerPart{partNumber};
            i = obj.CurrentChannel;
            j = obj.CurrentPlane;
            
            if isempty(obj.ImageStats{i,j}) || ~isfield( obj.ImageStats{i,j}, 'meanValue' )
                obj.initializeImageStats('reset')
            end
            tf = all( ~isnan(obj.ImageStats{i,j}.meanValue(frameIndices) ) );
        end
        
        function saveResults(obj)
            % Skip for now, in this class results have a special
            % implementation (see saveShifts on subclasses)
        end

        function saveMergedResults(obj)
            % Skip for now, in this class results have a special
            % implementation (see save shifts)
        end

    end
    
    methods (Access = private) 

        function S = initializeImageStats(obj, mode)
        %initializeImageStats Create new or load existing struct.
        %
        %   S = initializeImageStats(obj) initializes a struct of image
        %   stats.
        %
        %   S = initializeImageStats(obj, mode) initializes image stats
        %   using specified mode. mode can be 'initialize' (default) or 
        %   'reset'
        
            if nargin < 2
                mode = 'initialize';
            end
        
            % Check if image stats already exist for this datalocation
            filePath = obj.getDataFilePath('ImageStats', '-w', ...
                'Subfolder', 'raw_image_info', 'IsInternal', true);
            
            if isfile(filePath) && ~strcmp(mode, 'reset')
                S = obj.loadData('ImageStats');
                if ~isa(S, 'cell') % Stats were saved before multichannel/multiplance 
                    S = {S};
                end
            else
                
                numFrames = obj.SourceStack.NumTimepoints;

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
                
                S = obj.repeatStructPerDimension(S);
                
                obj.saveData('ImageStats', S);
                
            end
            
            obj.ImageStats = S;
            
            if ~nargout 
                clear S
            end
        end
        
        function updateImageStats(obj, Y)
        %updateImageStats Update image stats for current part.
        
            % Skip computation if results already exist...
            if obj.checkIfPartIsFinished(obj.CurrentPart)
                return
            end
            
            i = obj.CurrentChannel;
            j = obj.CurrentPlane;
            IND = obj.CurrentFrameIndices;

            Y = single(Y);
            
            % Reshape to 2D array where all pixels from each image is 1D
            Y_ = reshape(Y, [], size(Y, 3));
            
            obj.ImageStats{i,j}.meanValue(IND) = nanmean( Y_ );
            obj.ImageStats{i,j}.medianValue(IND) = nanmedian( Y_ );
            obj.ImageStats{i,j}.minimumValue(IND) = min( Y_ );
            obj.ImageStats{i,j}.maximumValue(IND) = max( Y_ );
            
            pLevels = obj.ImageStats{i,j}.percentileValues;

            % Collect different stats.
            prctValues = prctile(Y_, pLevels)';
            if iscolumn(prctValues); prctValues = prctValues'; end % If size(Y, 3)==1. 
            
            obj.ImageStats{i,j}.prctileL1(IND) = prctValues(:, 1);
            obj.ImageStats{i,j}.prctileL2(IND) = prctValues(:, 2);
            obj.ImageStats{i,j}.prctileU1(IND) = prctValues(:, 3);
            obj.ImageStats{i,j}.prctileU2(IND) = prctValues(:, 4);
            
            obj.ImageStats{i,j}.pctSaturatedValues(IND) = mean(Y_ == obj.SaturationValue, 1);
        end
        
        function saveImageStats(obj)
        %saveImageStats Save statistical values of image data  
        %
        %   saveImageStats(obj, Y)
        
            % Save updated image stats to data location
            S = obj.ImageStats;
            obj.saveData('ImageStats', S)
        end

    end
    
end