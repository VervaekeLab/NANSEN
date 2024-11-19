function createTestedWithBadgeforToolbox(versionNumber)
    arguments
        versionNumber (1,1) string
    end
    nansentools.installMatBox()
    projectRootDirectory = nansentools.projectdir();
    matbox.tasks.createTestedWithBadgeforToolbox(versionNumber, projectRootDirectory)
end
