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
        ProcessData % Flag for subclass to decide whether is should invoke the processdata method
        % Is it better if this is just set internally whenever properties
        % are changed?
    end


    properties (Hidden) % Todo: Add a twophoton mixin class for data preprocessing
        StretchCorrectionMethod = 'imwarp'
        % Todo: StretchCorrectionLookupTable
        NumFlybackLines = 8
        CorrectBidirectionalOffset = false; 
    end
    
    
    methods % Set/get methods
        
        function set.StretchCorrectionMethod(obj, newValue)
            
            % Todo: Make sure value is valid.
            obj.StretchCorrectionMethod = newValue;
            obj.onStretchCorrectionMethodChanged()

        end
        
        function set.NumFlybackLines(obj, newValue)
            
            % Todo: Make sure value is valid.
            obj.NumFlybackLines = newValue;
            obj.onNumFlybackLinesChanged()

        end
        
        function tf = get.ProcessData(obj)
            
            doFlyBackRemoval = obj.NumFlybackLines ~= 0;
            doStretchCorrection = ~strcmp(obj.StretchCorrectionMethod, 'none');
            doBidirectionOffsetCorrection = obj.CorrectBidirectionalOffset;
            
            tf = doFlyBackRemoval || doStretchCorrection || ...
                    doBidirectionOffsetCorrection;
        end
        
    end
    
    methods (Access = protected)
        
        function data = processData(obj, data)
            
            if obj.NumFlybackLines ~= 0
                firstLine = obj.NumFlybackLines + 1;
                % Create subs
                subs = repmat({':'}, 1, ndims(data));
                subs{1} = firstLine:size(data,1);
                % Get data without flyback lines
                data = data(subs{:});
            end
        
            
            % Correct stretching of images due to the sinusoidal movement profile 
            % of the resonance mirror
            switch obj.StretchCorrectionMethod
                
                case {'imresize', 'imwarp'}
                    %scanParam = getSciScanVariables(folderpath, {'ZOOM', 'x.correct'});
                    
                    % Todo: Make sure scan params are available...
                    scanParam = struct('zoom', obj.MetaData.zoomFactor, 'xcorrect', 32);
                    % Todo: Add this method...
                    data = correctResonanceStretch(data, scanParam, ...
                        obj.StretchCorrectionMethod);
                    
                case 'none'
                    % Do nothing
                otherwise
                    warning('Unknown strtch correction method, resonance stretch is not corrected')
            end
        
            
            % TODO:
                % Should this be done before or after destretching? I thought
                % before....
               % [data, bidirBatchSize, colShifts] = correctLineOffsets(data, 100);


        end
        
    end
    
    
    methods (Access = private)
        
        function onStretchCorrectionMethodChanged(obj)
            % Todo:
            % Update the size of virtual data.
            
            % Reinitialize the cache (if cache is active) Perhaps this
            % should be done in the virtual array class, if the size is
            % ever changed...
            
        end
        
        function onNumFlybackLinesChanged(obj)
            % Update the size of virtual data.
            % Re-initialize the cache. See onStretchCorrectionMethodChanged
        end
        
    end

    
    
    
    
end