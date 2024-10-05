function addUiwidgetsJarToJavaClassPath()

    jarFilePath = fullfile( widgetsRoot, 'resource', ...
                            'MathWorksConsultingWidgets.jar' );
                        
    tf = utility.system.addFilepathToStaticJavapath(jarFilePath);

    % Since matlab has to be restarted before changes to
    % the static Java class path take effect, the path is
    % added to the dynamic path here if its not already on
    % the static javapath
    spath = javaclasspath('-static');
    if ~any( contains(spath, jarFilePath) )
        utility.system.addFilepathToDynamicJavapath(jarFilePath)
    end
end
