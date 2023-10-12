classdef ImageStackIterator < handle & uiw.mixin.AssignPVPairs
%ImageStackIterator Iterator for frame dimensions of an ImageStack
%
%   This class is used by the ImageStackProcessor for managing the
%   iteration over channels and/or planes during processing.
%
%   Construction:
%       iterator = nansen.stack.ImageStackIterator(numChannels) creates an
%       iterator for an ImageStack with given number of channels
%
%       iterator = nansen.stack.ImageStackIterator(numChannels, numPlanes)
%       creates an iterator for an ImageStack with given number of channels
%       and planes.
%
%       iterator = nansen.stack.ImageStackIterator(numChannels, numPlanes, varargin)
%       specifies additional options that determine how the iterator works
%
%   The processing mode for channels and planes can be set according to
%   different criteria:
%       'single' : iterate over a single item (only channels)
%       'serial' : iterate over items in sequence
%       'batch'  : iterate over all items in one iteration
%
%   Setting the mode determines how many iteration counts will be used for
%   each dimension and it determines the values of CurrentChannel and 
%   CurrentPlane for each iteration.
%
%   This class provides the following methods:
%       next() : increase the iteration counter by 1
%       hasMore() : check if more iterations are available
%       reset() : reset iteration counter


%   Question: Should the chunking of image stacks (division of subparts
%   along main dimension) also be taken care of by this class?


    properties
        ChannelProcessingMode = 'serial'    % Mode for processing of multiple channels. 'single', 'serial' or 'batch'
        PrimaryChannel = 1                  % Channel to process if processing mode is single, or use as reference is processing mode is serial.
        PlaneProcessingMode = 'serial'      % Mode for processing of multiple planes. 'serial' or 'batch'
    end
    
    properties (SetAccess = immutable)
        NumChannels = 1
        NumPlanes = 1
    end
    
    properties (SetAccess = private)
        CurrentChannel  % Current channel of ImageStack
        CurrentPlane    % Current plane of ImageStack 
        
        CurrentIterationC (1,1) double = 0
        CurrentIterationZ (1,1) double = 0
    end
    
    properties (Dependent)
        CurrentIteration;
        NumIterations
        
        NumIterationsC
        NumIterationsZ
    end
    
    properties (Access = private)
        IterationValuesC cell
        IterationValuesZ cell
        
        IsInitialized = false
    end
    

    methods
        
        function obj = ImageStackIterator(numChannels, numPlanes, varargin)
            
            if nargin < 1 || isempty(numChannels)
                numChannels = 1;
            end
            if nargin < 2 || isempty(numPlanes)
                numPlanes = 1;
            end
            
            obj.NumChannels = numChannels;
            obj.NumPlanes = numPlanes;
            
            obj.assignPVPairs(varargin{:})
            
            obj.assignIterationValuesC()
            obj.assignIterationValuesZ()
        end
        
    end
    
    methods % Set/get
        
        function set.ChannelProcessingMode(obj, newValue)
            obj.assertIteratorUninitialized()
                        
            validModes = {'single', 'serial', 'batch'};
            newValue = validatestring(newValue, validModes);
            
            obj.ChannelProcessingMode = newValue;
            obj.assignIterationValuesC()
        end
        
        function set.PrimaryChannel(obj, newValue)
            obj.assertIteratorUninitialized()
            
            validAttributes = {'scalar', 'integer', 'nonnegative'};
            validateattributes(newValue, 'numeric', validAttributes)
            
            obj.PrimaryChannel = newValue;
            obj.assignIterationValuesC()
        end
        
        function set.PlaneProcessingMode(obj, newValue)
            obj.assertIteratorUninitialized()
                        
            validModes = {'serial', 'batch'};
            newValue = validatestring(newValue, validModes);
            
            obj.PlaneProcessingMode = newValue;
            obj.assignIterationValuesZ()
        end
        
        function numIterC = get.NumIterationsC(obj)
            numIterC = numel(obj.IterationValuesC);
        end
        
        function numIterZ = get.NumIterationsZ(obj)
            numIterZ = numel(obj.IterationValuesZ);
        end
        
        function numIter = get.NumIterations(obj)
           numIter = obj.NumIterationsC * obj.NumIterationsZ;
        end
        
        function currIter = get.CurrentIteration(obj)
            if ~obj.IsInitialized
                currIter = 0; return
            else
                currIter = (obj.CurrentIterationC-1) .* obj.NumIterationsZ ...
                    + obj.CurrentIterationZ;
            end
        end
    end
    
    methods %(Access = ?nansen.stack.ImageStackProcessor)
        
        function [iZ, iC] = next(obj)
        %next Move the iterator to the next iteration state
        %
        %   iteratorObj.next() moves the iterator to the next iteration
        %       state.
        %
        %   [iZ, iC] = iteratorObj.next() moves the iterator to the next 
        %       iteration state and returns the current iteration numbers
        %       for planes (iZ) and channels (iC)
        
            if ~obj.IsInitialized
                obj.IsInitialized = true;
                obj.CurrentIterationC = 1;
                obj.CurrentIterationZ = 1;
            else
                
                if obj.CurrentIterationZ < obj.NumIterationsZ % Increment Z
                    obj.CurrentIterationZ = obj.CurrentIterationZ + 1;
                else % Reached end of Z, increment C
                    obj.CurrentIterationZ = 1; 
                    obj.CurrentIterationC = obj.CurrentIterationC + 1;
                end
                
                if obj.CurrentIterationC > obj.NumIterationsC
                    error('Iterator has run out of iterable values.')
                end
            end
            
            obj.CurrentChannel = obj.IterationValuesC{obj.CurrentIterationC};
            obj.CurrentPlane = obj.IterationValuesZ{obj.CurrentIterationZ};
            
            if nargout
                iZ = obj.CurrentIterationZ;
                iC = obj.CurrentIterationC;
            end
        end
        
        function tf = hasMore(obj)
            tf = obj.CurrentIteration < obj.NumIterations;
        end
        
        function reset(obj)
        %reset Reset the iterator
            obj.IsInitialized = false;
            obj.CurrentIterationC = 1;
            obj.CurrentIterationZ = 1;
        end
        
    end
        
    methods (Access = private)
                
        function assignIterationValuesC(obj)
        %assignIterationValuesC Assign index values for channels (C)
            mode = obj.ChannelProcessingMode;
            numC = obj.NumChannels;
            refC = obj.PrimaryChannel;
            
            if refC > obj.NumChannels
                warning('The stack has %d channels, but the reference channel was set to %d. Resetting the reference channel to 1.', obj.NumChannels, refC)
                refC = 1;
            end
            
            obj.IterationValuesC = obj.getIterationValues(mode, numC, refC);
        end
        
        function assignIterationValuesZ(obj)
        %assignIterationValuesZ Assign index values for channels (Z)
            mode = obj.PlaneProcessingMode;
            numZ = obj.NumPlanes;
            refZ = 1;
            obj.IterationValuesZ = obj.getIterationValues(mode, numZ, refZ);
        end

        function assertIteratorUninitialized(obj)
            assert( ~obj.IsInitialized, ...
                'Can not set ChannelProcessingMode when iterator is running')
        end
        
    end

    
    methods (Static, Access = private)
        
        function values = getIterationValues(mode, numItems, primaryItem)
        %getIterationValues Get iteration values depending on mode
        %
        %   values = getIterationValues(mode, numItems, primaryItem)
        %   returns a cell array where each cell contains the values for 
        %   one iteration step.
        %
        %   mode is a char which can have the following values:
        %       'single' : iterate over a single item
        %       'serial' : iterate over items in sequence
        %       'batch'  : iterate over all items in on iteration
        %
        %   numItems is a numeric describing how many items to iterate over
        %   primaryItem is the item to use in 'single' mode or the item to
        %   use as reference (i.e first iteration) in 'serial' mode.
        
            switch mode
                case 'single'
                    values = {primaryItem};
                    
                case 'serial'
                    values = arrayfun(@(i) i, 1:numItems, 'uni', 0);
                    values(primaryItem) = [];
                    values = [{primaryItem}, values];
                    
                case 'batch'
                    values = {1:numItems};
            end
        end
        
    end

end


function test()
    
    iterator = nansen.stack.ImageStackIterator(2,4);
    iterator.reset()
    for i = 1:iterator.NumIterations
        iterator.next()
        fprintf('Current channel %d, current plane %d\n', ...
            iterator.CurrentChannel, iterator.CurrentPlane)
    end
    
    iterator.reset()
    iterator.ChannelProcessingMode = 'batch';
    for i = 1:iterator.NumIterations
        iterator.next()
        fprintf('Current channel %s, current plane %s\n', ...
            num2str(iterator.CurrentChannel), ...
            num2str(iterator.CurrentPlane) )
    end
    
end
