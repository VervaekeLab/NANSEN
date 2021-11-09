function [roiArray, cnmfResults] = finishAutoSegmentation(cnmfData)

    % % "Unzip variables"

    Y = cnmfData.Y;
    P = cnmfData.P;
    options = cnmfData.options;
    T = cnmfData.options.nFrames;
    d = cnmfData.options.d;
    d1 = cnmfData.options.d1;
    d2 = cnmfData.options.d2;
    Ain = cnmfData.Ain;
    Cin = cnmfData.Cin;
    bin = cnmfData.bin;
    fin = cnmfData.fin;
    p = 2;
    
    clearvars cnmfData

    
     

end
