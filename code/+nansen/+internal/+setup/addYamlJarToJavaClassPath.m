function addYamlJarToJavaClassPath()

    yamlRootDir = fileparts( which('yaml.WriteYaml') );
    jarFilePath = fullfile(yamlRootDir, 'external', 'snakeyaml-1.9.jar');
    
    if ~isfile(jarFilePath)
        error('The snakeyaml Java Archive was not found.')
    end
    
    wasSuccess = nansen.internal.setup.java.addFilepathToStaticJavapath(jarFilePath);

    if ~wasSuccess
        error('Failed to add the snakeyaml Java Archive to the static javapath')
    end
    
    % Since matlab has to be restarted before changes to
    % the static Java class path take effect, the path is
    % added to the dynamic path here if its not already on
    % the static javapath
    spath = javaclasspath('-static');
    if ~any( contains(spath, jarFilePath) )
        nansen.internal.setup.java.addFilepathToDynamicJavapath(jarFilePath)
    end
end
