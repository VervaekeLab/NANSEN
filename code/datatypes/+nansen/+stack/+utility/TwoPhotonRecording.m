classdef TwoPhotonRecording < handle
%nansen.stack.utility.TwoPhotonRecording Mixin class for two-photon-stacks
%
%   This class can be added as a superclass to virtualdata classes that are
%   developed especially for reading two-photon recording data.
%
%   Two photon data have some special artifacts in common, and this class
%   provides methods for correcting these when loading image frames.
%       * Stretch correction : Corrects stretch artifacts in x due to the
%           sinusoidal movement profile of the resonance scanning mirror
%           (Some microscopes might do this internally)
%       * Removal of flyback lines : Some microscope acquire data when the
%           mirrors are resetting to the initial position, and this might
%           create some lines in the top (or bottom?) of image that
%           contains meaning less data. Note: assumes data dimensions are
%           according to matlab images, i.e yx
%       * Bidirectional offset correction : On resonance scanning systems,
%           there might be a line offset between even and odd lines in the
%           image. (Not implemented yet.)
%   


%   Questions in implementation:
%     * Should this be a mixin or just a set of methods that can be
%       enabled/disabled through options for motion correction...???
%
%       Stretch correction depends on several aspects of the acquizition
%       system. not sure if it is easily generalizable.


    properties (Dependent)
        PreprocessDataEnabled % Flag for subclass to decide whether is should invoke the processdata method
        % Is it better if this is just set internally whenever properties
        % are changed?
    end

    properties (Hidden) 
        NumFlybackLines = 8
        StretchCorrectionMethod = 'none' % 'imwarp', 'imresize', 'none'
        CorrectBidirectionalOffset = false;
    end
    
    properties (Access = protected)
        % Todo: StretchCorrectionLookupTable
    end

    methods % Constructor
        
        function obj = TwoPhotonRecording(varargin)
            
            obj.assignNvPairs(varargin{:})

        end
        
        function assignNvPairs(obj, varargin)
            
            import utility.getnvparametervalue
            
            if isempty(varargin); return; end
            
            propertyNames = {...
                'NumFlybackLines', ...
                'StretchCorrectionMethod', ...
                'CorrectBidirectionalOffset' };
            
            for i = 1:numel(propertyNames)
                value = getnvparametervalue(varargin, propertyNames{i});
                
                if ~isempty(value)
                    obj.(propertyNames{i}) = value;
                end
            end

        end
    end
    
    
    methods % Set/get methods
            
        function tf = get.PreprocessDataEnabled(obj)
            
            doFlyBackRemoval = obj.NumFlybackLines ~= 0;
            doStretchCorrection = ~strcmp(obj.StretchCorrectionMethod, 'none');
            doBidirectionOffsetCorrection = obj.CorrectBidirectionalOffset;
            
            tf = doFlyBackRemoval || doStretchCorrection || ...
                    doBidirectionOffsetCorrection;
        end
        
        function set.StretchCorrectionMethod(obj, newValue)
            
            if isempty(newValue); newValue = 'none'; end
            newValue = validatestring(newValue, {'none', 'imwarp', 'imresize'});
            
            % Todo: Make sure value is valid.
            obj.StretchCorrectionMethod = newValue;

        end
        
        function set.NumFlybackLines(obj, newValue)
                        
            % Todo: Make sure value is valid.
            obj.NumFlybackLines = newValue;
            
        end
        
    end
    
    methods (Access = protected)
        
        function data = processData(obj, data)
            
            if obj.NumFlybackLines ~= 0
                data = obj.removeFlybackLines(data);
            end
            
            if ~strcmp(obj.StretchCorrectionMethod, 'none')
                data = obj.correctResonanceStretch(data);
            end
            
            % Should this be done before or after destretching? I thought
            % before....
            if obj.CorrectBidirectionalOffset
                obj.correctBidirectionalOffset()
            end

        end
        
        function data = removeFlybackLines(obj, data)
        %removeFlybackLines Remove flyback lines from data 
        
            firstLineToInclude = obj.NumFlybackLines + 1;
            
            % Create subs
            subs = repmat({':'}, 1, ndims(data));
            yIdx = strfind(obj.DataDimensionArrangement, 'Y');
            subs{yIdx} = firstLineToInclude:size(data,1);
            
            % Get data without flyback lines
            data = data(subs{:});
        end
        
        function data = correctResonanceStretch(obj, data)
                        
            % Correct stretching of images due to the sinusoidal movement profile 
            % of the resonance mirror
            switch obj.StretchCorrectionMethod

                case {'imresize', 'imwarp'}
                    %scanParam = getSciScanVariables(folderpath, {'ZOOM', 'x.correct'});
                    
                    % Todo: Make sure scan params are available...
                    scanParam = struct('zoom', obj.MetaData.zoomFactor, 'xcorrect', 32);
                    
                    isTransposed = strcmp(obj.DataDimensionArrangement(1:2), 'XY');
                    if isTransposed
                        dimOrder = 1:ndims(obj);
                        dimOrder([1:2]) = dimOrder([2,1]);
                        data = permute(data, dimOrder);
                    end
                        
                    % Todo: Add this method...
                    data = ophys.twophoton.sciscan.correctResonanceStretch(data, scanParam, ...
                        obj.StretchCorrectionMethod);
                    
                    if isTransposed
                        data = ipermute(data, dimOrder);
                    end
                    
                case 'none'
                    % Do nothing
                otherwise
                    warning('Unknown stretch correction method, resonance stretch is not corrected')
            end
            
        end
        
        function data = correctBidirectionalOffset(obj, data)
            % Todo...

            % Should this be done before or after destretching? I thought
            % before....
            % [data, bidirBatchSize, colShifts] = correctLineOffsets(data, 100);
            
        end
        
    end
    
    
end