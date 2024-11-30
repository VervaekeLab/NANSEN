function filePath = getDownsampledStackFilename(hImageStack, n, method)
%GETDOWNSAMPLEDSTACKFILENAME Get filepath for a downsampled stack
%
%   Rename file to describe method and "amount" of downsampling.

    if nargin < 3 || isempty(method)
        method = 'mean'; % Todo: temporal mean
    end

    [~, ~, ext] = fileparts(hImageStack.FileName);
    postfix = sprintf('_downsampled_%s_x%d', method, n);
    postfix = strcat(postfix, ext);
    filePath = strrep(hImageStack.FileName, ext, postfix);

end
