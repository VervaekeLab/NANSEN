function addFilepathToDynamicJavapath(jFilepath)
%addFilepathToDynamicJavapath Add (append) a filepath to the dynamic java
%class path
    dPath = javaclasspath();
    dPath = [dPath, jFilepath];
    javaclasspath(dPath)
end