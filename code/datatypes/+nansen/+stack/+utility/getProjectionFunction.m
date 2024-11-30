function projFcn = getProjectionFunction(projectionName)

projectionPackage = {'stack.zproject'};
fcnFullName = strjoin([projectionPackage, {projectionName}], '.');

projFcn = str2func(fcnFullName);

end
                    
