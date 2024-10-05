function wasSuccess = addFilepathToStaticJavapath(filepath)
%addFilepathToStaticJavapath Add filepath to the static java path
%
%   WASSUCCESS = addFilepathToStaticJavapath(FILEPATH) writes the filepath
%   into the javaclasspath file located in the matlab preferences folder.
%   This makes sure the filepath is on the static java path.
%
%   If the filepath is already in the file, this functions returns.

    wasSuccess = false; 
    
    initDir = prefdir;
    staticJavaFilepath = fullfile(initDir, 'javaclasspath.txt');
    
    % Check if filepath already exists on the static javapath. Note: Need
    % to check the file, because the static classpath is only updated on
    % matlab startup.
    if isfile(staticJavaFilepath)
        str = fileread(staticJavaFilepath);
        existsInPathDef = contains(str, filepath);

        if existsInPathDef
            wasSuccess = true;
            return
        end
    end
    
    % If not, open "javaclasspath.txt" and write the filepath into the file
    if ~isfile(staticJavaFilepath)
        fid = fopen(staticJavaFilepath, 'w', 'n', 'UTF-8');
    else
        fid = fopen(staticJavaFilepath, 'a', 'n', 'UTF-8');
    end

    fprintf(fid, '\n%s', filepath);

    status = fclose(fid);
    if status == 0
        wasSuccess = true;
    end

end