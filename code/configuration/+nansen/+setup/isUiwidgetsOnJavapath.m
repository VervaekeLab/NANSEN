function tf = isUiwidgetsOnJavapath()

    jarFilePath = fullfile( widgetsRoot, 'resource', ...
                            'MathWorksConsultingWidgets.jar' );
                        
    spath = javaclasspath('-static');

    tf = any( contains(spath, jarFilePath) );
    
    
end