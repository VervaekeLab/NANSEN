function IM = mergeImageBlocks(blocks, outputSize, overlap)
%MERGEIMAGEBLOCKS Reassemble a cell grid of overlapping 2-D blocks.
%
%   IM = stack.reshape.mergeImageBlocks(blocks, outputSize) merges the
%   (numRows x numCols) cell array of overlapping 2-D image blocks
%   produced by stack.reshape.splitImage into a single outputSize image,
%   trimming the 1-pixel overlap on shared edges back to a clean tiling.
%
%   IM = stack.reshape.mergeImageBlocks(blocks, outputSize, overlap)
%   uses a custom overlap (in pixels; default 1). Must match the value
%   used when the blocks were created.
%
%   Syntax:
%       IM = stack.reshape.mergeImageBlocks(blocks, outputSize)
%       IM = stack.reshape.mergeImageBlocks(blocks, outputSize, overlap)

    arguments
        blocks cell
        outputSize (1,2) double {mustBePositive, mustBeInteger}
        overlap (1,1) double {mustBeNonnegative, mustBeInteger} = 1
    end

    [numRows, numCols] = size(blocks);
    h = outputSize(1);
    w = outputSize(2);
    rowEdges = floor(linspace(0, h, numRows + 1));
    colEdges = floor(linspace(0, w, numCols + 1));

    IM = zeros(h, w, 'like', blocks{1,1});
    for i = 1:numRows
        rowDst = (rowEdges(i)+1):rowEdges(i+1);
        srcR0  = rowEdges(i) + 1 - max(rowEdges(i) + 1 - overlap, 1) + 1;
        for j = 1:numCols
            colDst = (colEdges(j)+1):colEdges(j+1);
            srcC0  = colEdges(j) + 1 - max(colEdges(j) + 1 - overlap, 1) + 1;
            IM(rowDst, colDst) = blocks{i,j}( ...
                srcR0 : srcR0 + numel(rowDst) - 1, ...
                srcC0 : srcC0 + numel(colDst) - 1);
        end
    end
end
