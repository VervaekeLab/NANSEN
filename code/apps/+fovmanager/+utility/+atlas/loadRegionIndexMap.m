function S = loadRegionIndexMap(atlasName)
%loadRegionIndexMap Load file containing mapping of regions in the atlas

    if nargin == 0; atlasName = 'paxinos'; end
    
    atlasName = validatestring(atlasName, {'paxinos', 'allen'});

    % Create filepath for loading file.
    % rootPath = fileparts( mfilename('fullpath') );
    
    rootPath = fovmanager.localpath('brain_atlas');
    fileName = 'regionIndexMap.mat'; 
    loadPath = fullfile(rootPath, atlasName, fileName);
    
    S = load(loadPath);

end