classdef TiffMultiPartMultiChannel < nansen.stack.virtual.TiffMultiPart
    
    % Todo: Clean up and generalize parts for determining number of
    % channels (and planes)...
    
    properties (Constant, Hidden)
        FilenameExpression = 'ch\d{1}_part_\d{3}.*tif'
        DATA_DIMENSION_ARRANGEMENT = 'YXTCZ';
    end
    
    methods (Access = protected)
        
        function numChannels = detectNumberOfChannels(obj)
        
            nSamplesPerPixel = obj.tiffObj(1).getTag('SamplesPerPixel');

            if nSamplesPerPixel > 1
                numChannels = nSamplesPerPixel;
                obj.ChannelMode = 'multisample';
                return
            end

            % Check if there is a channel expression if there are more than
            % one file
            if numel(obj.FilePathList) > 1
                
                % expression for capturing channel and part numbers as tokens
                expression = 'ch(?<channel>\d{1})_part_(?<part>\d{3})';
                
                tokens = regexp( obj.FilePathList, expression, 'names');
                tokens = cat(1, tokens{:});
                
                channelIdx = cellfun(@(c) str2double(c), {tokens.channel});
                partIdx = cellfun(@(c) str2double(c), {tokens.part});

                tokens = cellfun(@(c) str2double(c), struct2cell(tokens));
                tokens = transpose(tokens); % each row is one file
                
                % channel is first, part numbers are second.
                % Sort according to channels:
                % [~, ix] = sortrows(tokens, [1,2]);
                
                numChannels = numel( unique(channelIdx) );
                obj.ChannelMode = 'multipart';
                
% % %                 return
% % %
% % %                 channelExpression = 'ch\d*';
% % %
% % %                 getChanFcn = @(c)regexp(c, channelExpression, 'match');
% % %                 channelIds = cellfun(@(c)getChanFcn(c), obj.FilePathList);
% % %
% % %                 getNumFcn = @(c) str2double( regexp(c, '\d*', 'match') );
% % %                 channelNums = cellfun(@(c)getNumFcn(c), channelIds);
% % %
% % %                 uniqueChannels = unique(channelNums);
% % %                 numChannels = numel(uniqueChannels);
% % %
% % %                 n = histcounts(channelNums, numChannels);
% % %                 assert( numel(unique(n)) == 1, 'Number of parts per channel does not match' )
% % %
% % %                 % Sort filepaths and tiff objects after channel numbers
% % %                 [~, ix] = sort(channelNums);
% % %                 obj.FilePathList = obj.FilePathList(ix);
% % %                 obj.tiffObj = obj.tiffObj(ix);

                numParts = numel( obj.FilePathList );
                numPartsPerChannel = floor(numParts / numChannels);

                obj.FilePathList = reshape(obj.FilePathList, ...
                    numPartsPerChannel, numChannels);
                obj.tiffObj = reshape(obj.tiffObj, ...
                    numPartsPerChannel, numChannels);

            end
        end
    end
end
