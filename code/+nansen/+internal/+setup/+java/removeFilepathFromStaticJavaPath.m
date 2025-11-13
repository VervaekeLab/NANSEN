function removeFilepathFromStaticJavaPath(filePath)
%
%   Note: This will remove items based on partiam matching, so it can be
%   used for removing many items from the same parent folder for example.
%   Function is currently only used by nansen.config.addons.AddonManager.checkLegacyDirectory

    initDir = prefdir;
    staticJavaFilepath = fullfile(initDir, 'javaclasspath.txt');

    if ~isfile(staticJavaFilepath); return; end

    fileContents = fileread(staticJavaFilepath);

    pathItems = strsplit(fileContents, '\n');

    tf = contains(pathItems, filePath);
    if any(tf)
        pathItems(tf)=[];
    
        updatedPath = strjoin(pathItems, '\n');
    
        fid = fopen(staticJavaFilepath, 'w');
        fwrite(fid, updatedPath);
        fclose(fid);
    end
end
