function results = runNansenTestSuite(options)
% runNansenTestSuite Run NANSEN test suite.
%
%   The runNansenTestSuite function provides a simple way to run the 
%   test suite for NANSEN. It writes a JUnit-style XML file containing the
%   test results (testResults.xml) and a Cobertura-style XML file 
%   containing a code coverage report (coverage.xml).
%
%   EXITCODE = runNansenTestSuite() runs all tests in the NANSEN test suite 
%   and returns a logical 1 (true) if any tests failed, or a logical 0 
%   (false) if all tests passed.
%
%   EXITCODE = runNansenTestSuite('Verbosity', VERBOSITY) runs the tests at 
%   the specified VERBOSITY level. VERBOSITY can be specified as either a
%   numeric value (1, 2, 3, or 4) or a value from the
%   matlab.unittest.Verbosity enumeration.
%
%   EXITCODE = runNansenTestSuite(NAME, VALUE, ...) also supports the 
%   following name-value pairs of the matlab.unittest.TestSuite.fromPackage
%   method:
%       * Name                  - Name of the suite element.
%       * ProcedureName         - Name of the test procedure in the test.
%
%   Examples:
%
%     % Run all tests in the NANSEN test suite.
%     runNansenTestSuite()
%
%     % Run all unit tests in the NANSEN test suite.
%     runNansenTestSuite('Name', 'unittest.*')
%
%     % Run only tests that match the ProcedureName 'testSmoke*'.
%     runNansenTestSuite('ProcedureName', 'testSmoke*')
%
%   Acknowledgements:
%       Adapted from matnwb/nwbtest:
%       https://github.com/NeurodataWithoutBorders/matnwb/blob/master/nwbtest.m
%   
%   See also: matlab.unittest.TestSuite/fromPackage

    arguments
        options.Name = "*" % Includes everything by default
        options.ProcedureName = "*" % Includes everything by default
        options.Verbosity = 1
    end

    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner
    import matlab.unittest.plugins.XMLPlugin
    
    import matlab.unittest.plugins.CodeCoveragePlugin
    import matlab.unittest.plugins.codecoverage.CoberturaFormat

    [status, teardownObjects] = setupNansenTestEnvironment(); %#ok<ASGLU>
    if status ~= 0; error('Something went wrong'); end

    verbosity = options.Verbosity;
    options = rmfield(options, 'Verbosity');

    try
        nansenRootPath = nansen.rootpath();
        reportsOutputFolder = fullfile(nansenRootPath, 'docs', 'reports');
        if ~isfolder(reportsOutputFolder); mkdir(reportsOutputFolder); end
        
        nvPairs = namedargs2cell(options);
        suite = TestSuite.fromPackage('nansen.unittest', 'IncludingSubpackages', true, nvPairs{:});
        
        runner = TestRunner.withTextOutput('Verbosity', verbosity);
        
        resultsFile = fullfile(reportsOutputFolder, 'testResults.xml');
        runner.addPlugin(XMLPlugin.producingJUnitFormat(resultsFile));
        
        coverageFile = fullfile(reportsOutputFolder, 'coverage.xml');
        
        % Get mfiles to run the code coverage report on.
        mFilePaths = utility.dir.recursiveDir(nansen.toolboxdir, ...
            'IgnoreList', 'tests', 'FileType', 'm', 'OutputType', 'FilePath');
        if ~verLessThan('matlab', '9.3') && ~isempty(mFilePaths)
            runner.addPlugin(CodeCoveragePlugin.forFile(mFilePaths,...
                'Producing', CoberturaFormat(coverageFile)));
        end
        
        results = runner.run(suite);
        
        display(results);
    catch e
        disp(e.getReport('extended'));
        results = [];
    end
end
