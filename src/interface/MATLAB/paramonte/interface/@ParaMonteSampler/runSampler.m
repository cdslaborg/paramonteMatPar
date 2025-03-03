%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%
%%%%   MIT License
%%%%
%%%%   ParaMonte: plain powerful parallel Monte Carlo library.
%%%%
%%%%   Copyright (C) 2012-present, The Computational Data Science Lab
%%%%
%%%%   This file is part of the ParaMonte library.
%%%%
%%%%   Permission is hereby granted, free of charge, to any person obtaining a
%%%%   copy of this software and associated documentation files (the "Software"),
%%%%   to deal in the Software without restriction, including without limitation
%%%%   the rights to use, copy, modify, merge, publish, distribute, sublicense,
%%%%   and/or sell copies of the Software, and to permit persons to whom the
%%%%   Software is furnished to do so, subject to the following conditions:
%%%%
%%%%   The above copyright notice and this permission notice shall be
%%%%   included in all copies or substantial portions of the Software.
%%%%
%%%%   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%%%%   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
%%%%   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
%%%%   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
%%%%   DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
%%%%   OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
%%%%   OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
%%%%
%%%%   ACKNOWLEDGMENT
%%%%
%%%%   ParaMonte is an honor-ware and its currency is acknowledgment and citations.
%%%%   As per the ParaMonte library license agreement terms, if you use any parts of
%%%%   this library for any purposes, kindly acknowledge the use of ParaMonte in your
%%%%   work (education/research/industry/development/...) by citing the ParaMonte
%%%%   library as described on this page:
%%%%
%%%%       https://github.com/cdslaborg/paramonte/blob/main/ACKNOWLEDGMENT.md
%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   runSampler(getLogFunc, ndim, njob)
%
%   Run the kernel sampler and return nothing.
%
%   Parameters
%   ----------
%
%       ndim
%
%           integer representing the number of dimensions of the
%           domain of the user's objective function getLogFunc().
%           It must be a positive integer.
%
%       getLogFunc()
%
%           represents the user's objective function to be sampled,
%           which must take a single input argument of type numpy
%           float64 array of length ndim and must return the
%           natural logarithm of the objective function.
%
%   Returns
%   -------
%
%       None
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
function runSampler(self, getLogFunc, ndim, njob) %, varargin)

    if nargin < 3
        self.Err.msg    = "The method " + self.objectName + ".runSampler(getLogFunc, ndim) takes at least two input arguments:" + newline + newline ...
                        + "    getLogFunc:  a MATLAB handle to the MATLAB function implementing " + newline ...
                        + "                 the mathematical objective function to be sampled,";
                        + "          ndim:  the number of dimensions of the domain of the " + newline ...
                        + "                 mathematical objective function to be sampled," + newline ...
                        + "          njob:  (optional) the number of parallel MATLAB Toolbox threads" + newline ...
                        + "                 corresponding to individual concurrent calls to getLogFunc()." + newline ...
        self.Err.abort();
    elseif nargin == 3
        njob = 1;
    elseif ~(isnumeric(njob) && floor(njob) == njob)
        self.Err.msg    = "The input argument `njob` must be set to an whole number (integer value) that represents" + newline ...
                        + "                 the number of parallel MATLAB Toolbox threads corresponding" + newline ...
                        + "                 to individual concurrent calls to getLogFunc()." + newline ...
        self.Err.abort();
    end

    if ~isa(self.mpiEnabled, "logical")
        self.Err.msg    = "The input argument " + self.objectName + ".mpiEnabled must be of type bool. " + newline ...
                        + "It is an optional logical (boolean) indicator which is False by default. " + newline ...
                        + "If it is set to True, it will cause the ParaDRAM simulation " + newline ...
                        + "to run in parallel on the requested number of processors. " + newline ...
                        + "See ParaDRAM class information on how to run a simulation in parallel. " + newline ...
                        + "You have entered " + self.objectName + ".mpiEnabled = " + string(self.mpiEnabled);
        self.Err.abort();
    end

    self.ndim = ndim;
    if self.mpiEnabled; self.reportEnabled = false; end

    self.Err.marginTop = 0;
    self.Err.marginBot = 1;
    self.Err.resetEnabled = false;

    if ~isa(ndim,"numeric") || ndim<1
        self.Err.msg    = "The input argument ndim must be a positive integer, " + newline ...
                        + "representing the number of dimensions of the domain of " + newline ...
                        + "the user's objective function getLogFunc(). " + newline ...
                        + "You have entered ndim = " + string(ndim);
        self.Err.abort();
    end

    if ~isa(getLogFunc,"function_handle")
        %if exist("getLogFunc") && ( isa(YourVar,'function_handle')
        %    if isequal(getLogFunc,
        %    end
        %end
    %else
        self.Err.msg    = "The input argument getLogFunc must be a callable function. " + newline ...
                        + "It represents the user's objective function to be sampled, " + newline ...
                        + "which must take a single input argument of type numpy " + newline ...
                        + "float64 array of length ndim and must return the " + newline ...
                        + "natural logarithm of the objective function.";
        self.Err.abort();
    end

    if ~isempty(self.inputFile)
        if isstring(self.inputFile) || ischar(self.inputFile)
            if self.reportEnabled
                self.Err.msg    = "The input argument " + self.objectName + ".inputFile must be of type string. " + newline ...
                                + "It is an optional string input representing the path to " + newline ...
                                + "an external input namelist of simulation specifications. " + newline ...
                                + "USE THIS OPTIONAL ARGUMENT WITH CAUTION AND " + newline ...
                                + "ONLY IF YOU KNOW WHAT YOU ARE DOING. " + newline ...
                                + "Specifying this option will cause ParaDRAM to ignore " + newline ...
                                + "all other paraDRAM simulation specifications set by " + newline ...
                                + "the user via ParaDRAM instance attributes. " + newline ...
                                + "You have entered " + self.objectName + ".inputFile = """ + string(self.inputFile) + """.";
                self.Err.warn();
            end
        else
            self.Err.msg = "The attribute ``inputFile`` must be a string or char vector. ";
            self.Err.abort();
        end
    end

    inputFile = [convertStringsToChars(self.getInputFile())];
    %inputFile = self.getInputFile()

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    cstype = [];
    parallelism = [];
    errorOccurred = ~ischar(self.buildMode) && ~isstring(self.buildMode);
    if ~errorOccurred
        self.buildMode = string(self.buildMode);
        buildModeSplitList = strsplit(lower(self.buildMode),"-");
        for i = 1:length(buildModeSplitList)
            if strcmp(buildModeSplitList(i),"release") || strcmp(buildModeSplitList(i),"testing") || strcmp(buildModeSplitList(i),"debug")
                buildMode = buildModeSplitList(i);
            elseif strcmp(buildModeSplitList(i),"impi") || strcmp(buildModeSplitList(i),"mpich") || strcmp(buildModeSplitList(i),"openmpi")
                parallelism = "_" + buildModeSplitList(i);
            elseif strcmp(buildModeSplitList(i),"intel") || strcmp(buildModeSplitList(i),"gnu")
                cstype = buildModeSplitList(i);
            else
                errorOccurred = true;
                break
            end
        end
    end

    if errorOccurred
        self.Err.msg    = "The attribute " + self.objectName + ".buildMode must be of type string. " + newline ...
                        + "It is an optional string argument with default value ""release"" ." + newline ...
                        + "possible choices are: " + newline ...
                        + "    ""debug"": " + newline ...
                        + "        to be used for identifying sources of bug " + newline ...
                        + "        and causes of code crash. " + newline ...
                        + "    ""release"": " + newline ...
                        + "        to be used in all other normal scenarios " + newline ...
                        + "        for maximum runtime efficiency. " + newline ...
                        + "You have entered " + self.objectName + ".buildMode = " + string(self.buildMode);
        self.Err.abort();
    end

    %%%% determine the mpi library brand. @todo: This could be later moved to pmreqs as it does not need to be executed every time.

    if isempty(parallelism)
        if self.mpiEnabled
            [status,cmdout] = system("mpiexec --version");
            if status==0 || ischar(cmdout) || isstring(cmdout)
                cmdout = lower(string(cmdout));
            else
                cmdout = "";
            end

            if contains(cmdout,"openrte") || contains(cmdout,"open-mpi") || contains(cmdout,"openmpi")
                parallelism = "_openmpi";
            elseif contains(cmdout,"hydra") || contains(cmdout,"mpich")
                parallelism = "_mpich";
            elseif contains(cmdout,"intel")
                parallelism = "_impi";
            else
                if self.platform.isWin32 || self.platform.isLinux
                    parallelism = "_impi";
                elseif self.platform.isMacOS
                    parallelism = "_openmpi";
                end
            end
        else
            parallelism = "";
            if ~self.mpiEnabled
                if self.reportEnabled
                    self.Err.msg    = "Running the ParaDRAM sampler in serial mode..." + newline ...
                                    + "To run the ParaDRAM sampler in parallel visit:" + newline ...
                                    + newline ...
                                    + "    " + href(self.website.home.url) ...
                                    ;
                    % the simulation progress is funneled to the MATLAB session on Windows, so need for the following message.
                    if ~self.platform.isWin32
                    self.Err.msg    = self.Err.msg + newline ...
                                    + newline ...
                                    + "For realtime simulation progress report," + newline ...
                                    + "check the bash terminal from which you started your MATLAB session." ...
                                    ;
                    end
                    self.Err.note();
                end
            end
        end
    end

    %%%% set build mode

    buildModeListRef = ["release","testing","debug"];
    buildModeList = buildModeListRef;
    if ~strcmp(self.buildMode,"release")
        for buildMode = buildModeListRef
            if ~strcmp(buildMode,self.buildMode)
                buildModeList = [ buildModeList , [buildMode] ];
            end
        end
    end

    pmcsListRef = ["intel","gnu"];
    pmcsList = pmcsListRef;

    if isempty(cstype)
        if strcmp(parallelism,"_impi")
            cstype = "intel";
        else
            cstype = "gnu";
        end
    else
        pmcsList = [cstype];
        for pmcs = pmcsListRef
            if ~strcmp(pmcs,cstype)
                pmcsList = [ pmcsList , [pmcs] ];
            end
        end
    end

    %%%% set the library name

    libFound = false;
    libNamePrefix = "libparamonte_" + lower(self.platform.osname) + "_" + getArch() + "_";
    for buildMode = buildModeList
        for pmcs = pmcsList

            libName = libNamePrefix + pmcs + "_" + buildMode + "_shared_heap" + parallelism;
            if exist(libName,'file')==3; libFound = true; break; end

        end
        if libFound; break; end
    end
    self.libName = libName;

    if ~libFound
        self.Err.msg    = "Exhausted all possible ParaMonte shared library search" + newline ...
                        + "names but could not find any compatible library." + newline ...
                        + "It appears your ParaMonte MATLAB interface is missing" + newline ...
                        + "the shared libraries. Please report this issue at:" + newline + newline ...
                        + "    <a href=""https://github.com/cdslaborg/paramonte/issues"">https://github.com/cdslaborg/paramonte/issues</a>" + newline + newline ...
                        + "Visit <a href=""https://www.cdslab.org/paramonte/"">https://www.cdslab.org/paramonte/</a> for instructions" + newline ...
                        + "to build ParaMonte object files on your system."; %...+ newline ...
                        %...+ buildInstructionNote % xxxxxxxxxxxx...
        self.Err.abort();
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    pool = gcp("nocreate");
    if isempty(pool)
        if self.reportEnabled
            pool = parpool("threads");
        else
            evalc('pool = parpool("threads")');
        end
    end

    if ~isempty(njob)
        pool = parpool("threads");
        njob = pool.NumWorkers;
        function LogFunc = getLogFuncWrapperM(Point)
            njob = size(Point, 2);
            LogFunc = zeros(njob, 1);
            parfor ijob = 1 : njob
                LogFunc(ijob) = getLogFunc(Point(:, ijob));
            end
        end
        spec_getLogFunc = functions(getLogFunc);
    end

    if ~(self.reportEnabled || self.platform.iscmd || self.platform.isWin32)
        self.Err.msg = "check the Bash terminal (from which you opened MATLAB) for realtime simulation progress and report.";
        self.Err.note();
    end

    %if strcmp(spec_getLogFunc.type,"simple") && strcmp(spec_getLogFunc.function,"getLogFunc")
    %    expression = string(self.libName + "(self.platform.iscmd,ndim,inputFile)");
    %else
    expression = string(self.libName + "(@getLogFuncWrapperM, ndim, njob, inputFile, self.platform.iscmd)");
    %end

    isGNU = contains(self.libName,"gnu");
    if isGNU
        setenv('GFORTRAN_STDIN_UNIT' , '5')
        setenv('GFORTRAN_STDOUT_UNIT', '6')
        setenv('GFORTRAN_STDERR_UNIT', '0')
    end
    munlock(self.libName)
    eval("clear " + self.libName);

    try
        eval(expression);
    catch ME
        self.Err.msg = "Error occurred: " + string(ME.message) + newline + newline;
        if strcmpi(ME.identifier,'MATLAB:mex:ErrInvalidMEXFile')
            if self.platform.isMacOS
                self.Err.msg = self.Err.msg ...
                             + "This error is most likely due to the ""System Integrity Protection"" (SIP) of your Mac interfering with the ParaMonte MATLAB files." + newline ...
                             + "Follow the directions given on this website to resolve this error:" + newline ...
                             + newline ...
                             + "    " + href(self.website.home.url + "/notes/troubleshooting/macos-developer-cannot-be-verified/") + newline ...
                             + newline ...
                             + "If the problem persists even after following the guidelines in the above page, please report this issue at," + newline ...
                             + newline ...
                             + "    " + href(self.website.github.issues.url) + newline ...
                             + newline ...
                             + "to get help on resolving the error." ...
                             ;
            else
                self.Err.msg = self.Err.msg ...
                             + "If the problem persists, please report this issue at," + newline ...
                             + newline ...
                             + "    " + href(self.website.github.issues.url) + newline ...
                             + newline ...
                             + "to get help on resolving the error." ...
                             ;

            end
        else
           if self.mpiEnabled
                reportFileSuffix = "_process_*_report.txt";
            else
                reportFileSuffix = "_process_1_report.txt";
            end
            self.Err.msg    = self.Err.msg ...
                            + "The " + self.methodName + " simulation failed. Please see the contents of the simulation's output report file(s) for potential diagnostic messages:" + newline + newline ...
                            + "    " + strrep(self.spec.outputFileName+reportFileSuffix,'\','\\') ...
                            ;
        end
        self.Err.marginTop = 1;
        self.Err.wrapSplit = ": "; % important
        self.Err.abort();
    end

    delete(pool);
    munlock(self.libName)
    eval("clear "+self.libName);
    if isGNU
        setenv('GFORTRAN_STDIN_UNIT' , '-1')
        setenv('GFORTRAN_STDOUT_UNIT', '-1')
        setenv('GFORTRAN_STDERR_UNIT', '-1')
    end

    %try
    %    eval(expression);
    %catch
    %    if self.mpiEnabled
    %        reportFileSuffix = "_process_*_report.txt";
    %    else
    %        reportFileSuffix = "_process_1_report.txt";
    %    end
    %    self.Err.msg    = "The " + self.methodName + " simulation failed. Please see the contents of the simulation's output report file(s) for potential diagnostic messages:" + newline + newline ...
    %                    + "    " + strrep(self.spec.outputFileName+reportFileSuffix,'\','\\') ...
    %                    ;
    %    self.Err.abort();
    %end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if self.reportEnabled
        self.Err.msg    = "To read the generated output files, try the following:" + newline ...
                        + newline ...
                        + "    " + self.objectName + ".readReport()      % to read the summary report from the output report file." + newline ...
                        + "    " + self.objectName + ".readSample()      % to read the final i.i.d. sample from the output sample file." + newline ...
                        + "    " + self.objectName + ".readChain()       % to read the uniquely-accepted points from the output chain file." + newline ...
                        + "    " + self.objectName + ".readMarkovChain() % to read the Markov Chain. NOT recommended for extremely-large chains." + newline ...
                        + "    " + self.objectName + ".readRestart()     % to read the contents of an ASCII-format output restart file." + newline ...
                        + "    " + self.objectName + ".readProgress()    % to read the contents of an output progress file." + newline ...
                        + newline ...
                        + "For more information and examples on the usage, visit:" + newline ...
                        + newline ...
                        + "    " + href(self.website.home.url);
        self.Err.note();
    end

end
