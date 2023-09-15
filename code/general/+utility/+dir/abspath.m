function absolutePathList = abspath(folderContentList)
%abspath Combine folder and name for each element in a folderContent struct array
    
    absolutePathList = cell(size(folderContentList));
    for i = 1:numel(folderContentList)
        absolutePathList{i} = fullfile(folderContentList(i).folder, ...
            folderContentList(i).name);
    end
end