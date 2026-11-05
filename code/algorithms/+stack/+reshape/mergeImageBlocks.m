function IM = mergeImageBlocks(blocks, outputSize, overlap)
%MERGEIMAGEBLOCKS Reassemble a cell grid of overlapping 2-D blocks.
%
%   IM = stack.reshape.mergeImageBlocks(blocks, outputSize) merges the
%   (numRows x numCols) cell array of overlapping 2-D image blocks
%   produced by stack.reshape.splitImage into a single outputSize image,
%   trimming the overlap region on shared edges back to a clean tiling.
%
%   Each block from splitImage contains its canonical tile plus `overlap`
%   context rows/cols on every side where room exists in the original
%   image. Those context rows duplicate the canonical region of the
%   neighbouring block, so they must be skipped here to avoid writing
%   each output pixel twice. trimTop / trimLeft is the per-block offset
%   into the block where the canonical region starts (0 at the image
%   boundary, `overlap` for interior tiles).
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
    imageHeight = outputSize(1);
    imageWidth  = outputSize(2);
    rowEdges = floor(linspace(0, imageHeight, numRows + 1));
    colEdges = floor(linspace(0, imageWidth,  numCols + 1));

    IM = zeros(imageHeight, imageWidth, 'like', blocks{1,1});
    for i = 1:numRows
        dstRowStart = rowEdges(i) + 1;
        dstRowEnd = rowEdges(i+1);
        trimTop = min(overlap, dstRowStart - 1);   % overlap rows above the tile
        srcRows = trimTop + (1 : dstRowEnd - dstRowStart + 1);
        for j = 1:numCols
            dstColStart = colEdges(j) + 1;
            dstColEnd = colEdges(j+1);
            trimLeft = min(overlap, dstColStart - 1);
            srcCols = trimLeft + (1 : dstColEnd - dstColStart + 1);
            IM(dstRowStart:dstRowEnd, dstColStart:dstColEnd) = ...
                blocks{i,j}(srcRows, srcCols);
        end
    end
end
