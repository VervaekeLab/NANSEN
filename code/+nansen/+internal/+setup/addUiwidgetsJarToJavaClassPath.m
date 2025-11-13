function addUiwidgetsJarToJavaClassPath()

    jarFilePath = fullfile( widgetsRoot, 'resource', ...
                            'MathWorksConsultingWidgets.jar' );
                        
    tf = nansen.internal.setup.java.addFilepathToStaticJavapath(jarFilePath);

    % Since matlab has to be restarted before changes to
    % the static Java class path take effect, the path is
    % added to the dynamic path here if its not already on
    % the static javapath
    spath = javaclasspath('-static');
    if ~any( contains(spath, jarFilePath) )
        nansen.internal.setup.java.addFilepathToDynamicJavapath(jarFilePath)
    end
end
