function blocks = splitImage(IM, numRows, numCols, overlap)
%SPLITIMAGE Split an H-by-W(-by-T) array into a (numRows x numCols) cell grid.
%
%   blocks = stack.reshape.splitImage(IM, numRows, numCols) splits the
%   first two dimensions of IM into a numRows-by-numCols cell array of
%   sub-arrays. Each block extends one pixel into its neighbours on each
%   side (clamped at the image borders) so that per-pixel computations
%   needing a 1-pixel neighbourhood can be performed block-wise. The third
%   dimension (e.g. time) is preserved in full inside each block.
%
%   blocks = stack.reshape.splitImage(IM, numRows, numCols, overlap) uses
%   a custom overlap (in pixels; default 1).
%
%   Use stack.reshape.mergeImageBlocks to reassemble the blocks; the
%   overlap region is trimmed during reassembly.
%
%   Syntax:
%       blocks = stack.reshape.splitImage(IM, numRows, numCols)
%       blocks = stack.reshape.splitImage(IM, numRows, numCols, overlap)

    arguments
        IM
        numRows (1,1) double {mustBePositive, mustBeInteger}
        numCols (1,1) double {mustBePositive, mustBeInteger}
        overlap (1,1) double {mustBeNonnegative, mustBeInteger} = 1
    end

    [h, w, ~] = size(IM);
    rowEdges = floor(linspace(0, h, numRows + 1));
    colEdges = floor(linspace(0, w, numCols + 1));

    blocks = cell(numRows, numCols);
    for i = 1:numRows
        r0 = max(rowEdges(i)   + 1 - overlap, 1);
        r1 = min(rowEdges(i+1)     + overlap, h);
        for j = 1:numCols
            c0 = max(colEdges(j)   + 1 - overlap, 1);
            c1 = min(colEdges(j+1)     + overlap, w);
            blocks{i,j} = IM(r0:r1, c0:c1, :);
        end
    end
end
