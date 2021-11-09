classdef computeImageStats < nansen.stack.ChunkProcessor & abstract.SessionMethod
    
      
    properties (Constant) % SessionMethod properties
        BatchMode = 'serial'
        IsQueueable = true;
        OptionsManager = []
    end
    
    properties %Options
        %pLevels = [0.05, 0.005];
    end
    
    properties (Access = private)  
        ImageStats
    end
    
    methods % Structor
        
        function obj = computeImageStats(varargin)
            
            obj@abstract.SessionMethod(varargin{:})
            obj@nansen.stack.ChunkProcessor()      
            
        end
        
        function onInitialization(obj)
            obj.openSourceStack()
            obj.initializeImageStats();
        end

    end
    
    methods (Access = protected) % Implementation of methods from ChunkProcessor
        
        function openSourceStack(obj)
             
            % Get filepath for raw 2p-images
            DATANAME = 'TwoPhotonSeries_Original';
            filePath = obj.SessionObjects.getDataFilePath(DATANAME);
            
            % Initialize file reference for raw 2p-images
            obj.SourceStack = imviewer.stack.open(filePath);
            
        end
        

        function Y = processPart(obj, Y, IND)
            
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
            
            saturationValue = 2^16; %Todo: Get from image type/class
            obj.ImageStats.pctSaturatedValues(IND) = mean(Y_ == saturationValue);
            
            obj.saveImageStats() % Save results for every part
        
            Y = [];
        end
        
    end
    
    methods (Access = private)

        function S = initializeImageStats(obj)
        %initializeImageStats Create new or load existing struct.
        %

            % Check if image stats already exist for this session
            iSession = obj.SessionObjects;
            filePath = iSession.getDataFilePath('imageStats', ...
                'Subfolder', 'raw_image_info');
            
            if isfile(filePath)
                S = iSession.loadData('imageStats');
            else
                
                numFrames = obj.SourceStack.numFrames;

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

                iSession.saveData('imageStats', S, ...
                    'Subfolder', 'raw_image_info');
                
            end
            
            obj.ImageStats = S;

        end
        
        function S = saveImageStats(obj, Y, S, IND)
        %saveImageStats Get/save statistical values of image data  
        %
        %   saveImageStats(obj, Y, S, IND)
            
        %   Question: Move this to a more general image processing class?
        
            S = obj.ImageStats;
        
            % Save updated image stats to session
            iSession = obj.SessionObjects;
            iSession.saveData('imageStats', S)
            
        end

    end

end