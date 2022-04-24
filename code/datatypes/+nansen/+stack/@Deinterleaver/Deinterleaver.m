classdef Deinterleaver < handle
%Deinterleaver A class to handle deinterleaving of frames for stacks
%
%   The deinterleaver can be reconfigured on the fly and can be useful if
%   users need to manually specify how stacks should be deinterleaved.


    properties (SetAccess = immutable)
        Dimensions = 'CZT'; % Name of stack dimensions
        NumFrames = 1   % Total number of frames for a stack
    end
    
    properties (Dependent)
        Size % Size of each of the deinterleaved dimensions
    end
    
    properties
        Map % A map giving a frame index for each deinterleaved dimension
    end
    
    properties (Dependent, Access = private)
        NumDimensions % Count of number of dimensions of deinterleaved frameset
    end
    
    properties (Access = private)
        Size_ % Internal cache for the dependent size property
    end
    
    
    methods
        function obj = Deinterleaver(dimensions, numFrames)
        %Deinterleaver Creates a deinterleaver for stacks containing frames
        %
        % 	h = Deinterleaver(dimensions, numFrames) creates a
        % 	deinterleaver for the specified dimensions and number of frames
        %
        %   INPTUS: 
        %       dimensions: character vector with letter for each dimension
        %       numFrames: scalar (total number of frames) or vector
        %       (number of frames per dimension) specifying the number of
        %       frames for the deinterleaver constructor.

        
            obj.Dimensions = dimensions;

            if numel(numFrames) == obj.NumDimensions
                obj.NumFrames = prod(numFrames);
                obj.setSize(numFrames)
            else
                obj.NumFrames = numFrames;
            end

        end
        
        function setSize(obj, varargin)
        %setSize Set size (length of dimensions) that should be deinterleaved
        %
        %   obj.setSize(sz) sets the length of each dimension of the 
        %       deinterleaved frameset. sz is a vector with the length of
        %       each dimension.
        %
        %   obj.setSize(sz1, ..., szN) sets the length of each dimension.
        %       One of the inputs (szI) can be set to [], and it will be
        %       automatically calculated.
        
            % Size was given as array
            if numel(varargin)==1 && numel(varargin{1}) > 1
                obj.Size_ = varargin{1};
                return
            end
            
            % Size was given as separate inputs, where possibly one is an
            % empty (for automatically detecting length of that dimension)
            assert(numel(varargin) == obj.NumDimensions, 'Size must be the same length as number of dimensions')

            isDimensionEmpty = cellfun(@isempty, varargin);

            assert(sum(isDimensionEmpty)<=1, 'Need to specify length of n-1 dimensions')

            sizeCell = varargin;
            
            if any(isDimensionEmpty)
                sizeCell{isDimensionEmpty} = obj.NumFrames / prod([sizeCell{:}]);
            end
         
            obj.Size_ = [sizeCell{:}];
        end
        
        function  data = deinterleaveData(obj, data, subs)
        %deinterleaveData Deinterleave data according to provided subs
        %
        %   Inputs:
        %       data : array (n-dimensional)
        %       subs : subs for indexing into original array where data
        %              comes from. (first two dimensions not required)
        %   
        
            if numel(subs) == obj.NumDimensions + 2
                subs = subs(3:end);
            end
            
            subs = obj.replaceColonSubs(subs);
        
            dataSize = size(data);
            newShape = [dataSize(1:2), cellfun(@numel, subs)];
            data = reshape(data, newShape);

        end

    end
    
    methods
        function set.Size(obj, newValue)
        	assert(numel(newValue) == obj.NumDimensions, 'Size must be the same length as number of dimensions')
            obj.Size = newValue;
        end
        
        function size = get.Size(obj)
            size = obj.Size_;
        end
        
        function n = get.NumDimensions(obj)
            n = numel(obj.Dimensions);
        end

        function set.Size_(obj, newValue)
            obj.Size_ = newValue;
            obj.setupDeinterleavingMap()
        end
    end
    
    
    methods (Access = private)
        function setupDeinterleavingMap(obj)
            map = 1:obj.NumFrames;
            obj.Map = reshape(map, obj.Size);
        end
        
        function subs = replaceColonSubs(obj, subs)
        %replaceColonSubs Replace colons with indices
        
            iscolon = @(sub) ischar(sub) && isequal(sub, ':');
            
            % Need to replace any colons with the length of the dimension
            if any(cellfun(@(sub)iscolon(sub), subs))
                colonIdx = find( cellfun(@(sub)iscolon(sub), subs) );
                for i = colonIdx
                    subs{i} = 1:obj.Size(i);
                end
            end
            
        end
    end
    
end