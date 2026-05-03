function addFilepathToDynamicJavapath(jFilepath)
%addFilepathToDynamicJavapath Add (append) a filepath to the dynamic java
%class path

    % We are appending to the path. If the path already contains unrelated
    % duplicates (both on static and dynamic path) a warning is shown.
    % We suppress this here, as this is noise.
    warningId = 'MATLAB:javaclasspath:jarAlreadySpecified';
    warningCleanupObj = nansen.common.suppressWarning(warningId); %#ok<NASGU>

    % Make sure jFilepath is a column oriented cell array
    if ischar(jFilepath); jFilepath = {jFilepath}; end
    if isrow(jFilepath); jFilepath = jFilepath'; end

    dPath = javaclasspath();

    if isrow(dPath); dPath = transpose(dPath); end
       
    dPath = vertcat(dPath, jFilepath);
    dPath = unique(dPath);

    javaclasspath(dPath)
end
