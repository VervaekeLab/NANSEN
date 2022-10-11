function addFilepathToDynamicJavapath(jFilepath)
%addFilepathToDynamicJavapath Add (append) a filepath to the dynamic java
%class path

    % Make sure jFilepath is a column oriented cell array
    if ischar(jFilepath); jFilepath = {jFilepath}; end
    if isrow(jFilepath); jFilepath = jFilepath'; end

    dPath = javaclasspath();

    if isrow(dPath); dPath = transpose(dPath); end
       
    dPath = vertcat(dPath, jFilepath);
    dPath = unique(dPath);

    javaclasspath(dPath)
end