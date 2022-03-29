function [S, stat] = mesti_matrix_solver(A, B, C, opts)
%MESTI_MATRIX_SOLVER Computes C*inv(A)*B or inv(A)*B.
%   [X, stat] = MESTI_MATRIX_SOLVER(A, B) returns X = inv(A)*B for sparse matrix
%   A and (sparse or dense) matrix B, with the statistics of the computation
%   returned in structure 'stat'.
%
%   [S, stat] = MESTI_MATRIX_SOLVER(A, B, C) returns S = C*inv(A)*B where matrix
%   C is either sparse or dense. When the MUMPS function zmumps() is available,
%   this is done by computing the Schur complement of matrix K = [A,B;C,0].
%
%   [X, stat] = MESTI_MATRIX_SOLVER(A, B, [], opts) and
%   [S, stat] = MESTI_MATRIX_SOLVER(A, B, C, opts) allow detailed options to be
%   specified with structure 'opts' of the input arguments.
%
%   === Input Arguments ===
%   A (sparse matrix; required):
%      Matrix A in returned C*inv(A)*B or inv(A)*B.
%   B (sparse or full numeric matrix; required):
%      Matrix B in returned C*inv(A)*B or inv(A)*B.
%   C (sparse or full numeric matrix, or []; optional):
%      Matrix C in returned C*inv(A)*B. If nargin > 2 (i.e., C is given as an
%      input argument), C must be set to an empty array [] when opts.return_X =
%      true or when opts.use_transpose_B = true.
%   opts (scalar structure; optional):
%      A structure that specifies the options of computation; defaults to an
%      empty strucgture. It can contain the following fields (all optional):
%      opts.verbal (logical scalar; optional, defaults to true):
%         Whether to print info and timing to the standard output.
%      opts.use_transpose_B (logical scalar; optional, defaults to false):
%         Whether to use C = transpose(B) or not. When opts.use_transpose_B =
%         false (default), the input argument C is used. When
%         opts.use_transpose_B = true, transpose(B) will be used as C; C in the
%         input argument must be [], and opts.return_X must be false in this
%         case. If opts.use_transpose_B = true, opts.is_symmetric_A = true,
%         opts.solver = 'MUMPS', and opts.method = 'SCSA', the matrix K =
%         [A,B;C,0] will be treated as symmetric when computing its Schur
%         complement; this lowers computing time and memory usage.
%      opts.return_X (logical scalar; optional):
%         Whether to return X=inv(A)*B or not. Defaults to false when C is given
%         (when input argument C is nonempty or when opts.use_transpose_B =
%         true), true otherwise. When opts.return_X = false, S=C*inv(A)*B is
%         returned. When opts.return_X = true, X=inv(A)*B is returned; C in the
%         input argument must be [], and opts.use_transpose_B must be false in
%         this case. Since the default choice is the only sensible option, the
%         user should never need to specify opts.return_X.
%      opts.is_symmetric_A (logical scalar; optional):
%         Whether matrix A is symmetric or not. This is only used when
%         opts.solver = 'MUMPS', in which case opts.is_symmetric_A will be
%         determined by the issymmetric(A) command if not specified by user.
%      opts.solver (character vector; optional):
%         The software used for sparse matrix factorization. Available choices
%         are (case-insensitive):
%            'MUMPS'  - (default) Uses MUMPS. Its MATLAB interface zmumps.m must
%                       be in MATLAB's search path. This is much faster and uses
%                       less memory.
%            'MATLAB' - Uses the built-in lu() function in MATLAB, which uses
%                       UMFPACK with AMD ordering. This requires no installation
%                       but is much slower. This is be used by default if
%                       zmumps.m is not found in the search path.
%      opts.method (character vector; optional):
%         The solution method. Available choices are (case-insensitive):
%            'SCSA' - Schur complement scattering analysis. When opts.solver =
%                     'MUMPS', C*inv(A)*B is obtained through the Schur
%                     complement of matrix K = [A,B;C,0]; this is the true SCSA
%                     but requires MUMPS to be installed. When opts.solver =
%                     'MATLAB', C*inv(A)*B is obtained as C*inv(U)*inv(L)*B with
%                     optimized grouping, which is not the true SCSA but is
%                     slightly better than factorize_and_solve. Cannot be used
%                     for computing X=inv(A)*B or with iterative refinement.
%            'FS'   - Factorize and solve. Factorize A=L*U, solve for X=inv(A)*B
%                     with forward and backward substitutions, and project with
%                     C as C*inv(A)*B = C*X.
%            'factorize_and_solve' - Same as 'FS'.
%         By default, if opts.return_X = false and opts.iterative_refinement =
%         false, then 'SCSA' is used. Otherwise, 'factorize_and_solve' is used.
%      opts.verbal_solver (logical scalar; optional, defaults to false):
%         Whether to have the solver print detailed information to the standard
%         output. Note the behavior of output from MUMPS depends on compiler.
%      opts.clear_memory (logical scalar; optional, defaults to false):
%         Whether or not to clear variables to reduce peak memory usage. When
%         opts.clear_memory = true, the following variables may be cleared in
%         the caller's workspace if they exist: A, B, C. Some other variables
%         inside mesti_matrix_solver() will be cleared too.
%      opts.use_METIS (logical scalar; optional, defaults to false):
%         Whether to use METIS (instead of the default AMD) to compute the
%         ordering in MUMPS. Using METIS can sometimes reduce memory usage
%         and/or factorization and solve time, but it typically takes longer at
%         the analysis (i.e., ordering) stage.
%      opts.nrhs (positive integer scalar; optional):
%         The number of right-hand sides (number of columns of matrix B) to
%         consider simultaneously, used only when opts.method =
%         'factorize_and_solve' and opts.return_X = false. Defaults to 1 if
%         opts.iterative_refinement = true, 10 if opts.solver = 'MUMPS' with
%         opts.iterative_refinement = false, 4 otherwise.
%      opts.store_ordering (logical scalar; optional, defaults to false):
%         Whether to store the ordering sequence (permutation) for matrix A or
%         matrix K; only possible when opts.solver = 'MUMPS'. If
%         opts.store_ordering = true, the ordering will be returned in
%         stat.ordering.
%      opts.ordering (positive integer vector; optional):
%         A user-specified ordering sequence for matrix A or matrix K, used only
%         when opts.solver = 'MUMPS'. Using the ordering from a previous
%         computation can speed up the analysis stage, but the matrix size must
%         be the same.
%      opts.nthreads_OMP (positive integer scalar; optional):
%         Number of OpenMP threads used in MUMPS; overwrites the OMP_NUM_THREADS
%         environment variable.
%      opts.iterative_refinement (logical scalar; optional, defaults to false):
%         Whether to use iterative refinement in MUMPS to lower round-off
%         errors. Iterative refinement can only be used when opts.solver =
%         'MUMPS' and opts.method = 'factorize_and_solve' and opts.return_X =
%         false, in which case opts.nrhs must equal 1. When iterative refinement
%         is used, the relevant information will be returned in
%         stat.itr_ref_nsteps, stat.itr_ref_omega_1, and stat.itr_ref_omega_2.
%
%   === Output Arguments ===
%   S (full numeric matrix):
%      C*inv(A)*B or inv(A)*B.
%   stat (scalar structure):
%      A structure that contains the following fields:
%      stat.opts (scalar structure):
%         The final 'opts' used, excluding the user-specified matrix ordering.
%      stat.timing (scalar structure):
%         A structure containing timing of the various stages, in seconds, in
%         fields 'total', 'init', 'build', 'analyze', 'factorize', 'solve'.
%      stat.ordering_method (integer scalar; optional):
%         Ordering method used in MUMPS.
%      stat.ordering (positive integer vector; optional):
%         Ordering sequence returned by MUMPS when opts.store_ordering = true.
%      stat.itr_ref_nsteps (integer vector; optional):
%         Number of steps of iterative refinement for each input, if
%         opts.iterative_refinement = true; 0 means no iterative refinement.
%      stat.itr_ref_omega_1 (real vector; optional):
%         Scaled residual omega_1 at the end of iterative refinement for each
%         input; see MUMPS user guide section 3.3.2 for definition.
%      stat.itr_ref_omega_2 (real vector; optional):
%         Scaled residual omega_2 at the end of iterative refinement for each
%         input; see MUMPS user guide section 3.3.2 for definition.

%% Part 1: Initialization
%% Check validity & consistency of input arguments and assign default values

t0 = clock;

if nargin < 2
    error('Not enough input arguments.');
end

if ~issparse(A)
    error('Input argument ''A'' must be a sparse matrix.');
end
A_name = inputname(1); % name of the variable we call A in the caller's workspace; will be empty if there's no variable for it in the caller's workspace

if ~(ismatrix(B) && isnumeric(B))
    error('Input argument ''B'' must be a numeric matrix.');
end
B_name = inputname(2); % name of the variable we call B in the caller's workspace; will be empty if there's no variable for it in the caller's workspace

% C is an optional argument
if nargin < 3
    C = [];
end
if ~((ismatrix(C) && isnumeric(C)) || isempty(C))
    error('Input argument ''C'' must be a numeric matrix or [], if given.');
end
C_name = inputname(3); % name of the variable we call C in the caller's workspace; will be empty if there's no variable for it in the caller's workspace

% opts is an optional argument
if nargin < 4 || isempty(opts)
    opts = struct();
end
if ~(isstruct(opts) && isscalar(opts))
    error('Input argument ''opts'' must be a scalar structure or [], if given.');
end

% Check that the user did not accidentally use options only in mesti2s()
if isfield(opts, 'symmetrize_K') && ~isempty(opts.symmetrize_K)
    error('opts.symmetrize_K is not used in mesti_matrix_solver(); to symmetrize matrix K = [A,B;C,0], use opts.use_transpose_B = true, set input argument C to [], make sure matrix A is symmetric, set opts.solver = ''MUMPS'', and set opts.method = ''SCSA''.');
end

% Turn on verbal output by default
if ~isfield(opts, 'verbal') || isempty(opts.verbal)
    opts.verbal = true;
elseif ~(islogical(opts.verbal) && isscalar(opts.verbal))
    error('opts.verbal must be a logical scalar, if given.');
end

% By default, we don't set C = transpose(B)
if ~isfield(opts, 'use_transpose_B') || isempty(opts.use_transpose_B)
    opts.use_transpose_B = false;
elseif ~(islogical(opts.use_transpose_B) && isscalar(opts.use_transpose_B))
    error('opts.use_transpose_B must be a logical scalar, if given.');
elseif opts.use_transpose_B && ~isempty(C)
    error('Input argument ''C'' must be empty when opts.use_transpose_B = true.');
end

% By defulat, we return S=C*inv(A)*B if C is given (from input argument or from opts.use_transpose_B); else we return X=inv(A)*B
if ~isfield(opts, 'return_X') || isempty(opts.return_X)
    if ~isempty(C) || opts.use_transpose_B 
        opts.return_X = false;
    else
        opts.return_X = true;
    end
elseif ~(islogical(opts.return_X) && isscalar(opts.return_X))
    error('opts.return_X must be a logical scalar, if given.');
elseif opts.return_X && ~isempty(C)
    error('Input argument ''C'' must be empty when opts.return_X = true.');
end

% No iterative refinement by default; only used in factorize_and_solve when computing S=C*inv(A)*B with MUMPS
str_itr_ref = [];
if ~isfield(opts, 'iterative_refinement') || isempty(opts.iterative_refinement)
    opts.iterative_refinement = false;
elseif ~(islogical(opts.iterative_refinement) && isscalar(opts.iterative_refinement))
    error('opts.iterative_refinement must be a logical scalar, if given.');
elseif opts.iterative_refinement
    str_itr_ref = ' with iterative refinement';
end

% Use SCSA for opts.method unless opts.return_X = true or opts.iterative_refinement = true
if ~isfield(opts, 'method') || isempty(opts.method)
    if opts.return_X || opts.iterative_refinement
        opts.method = 'factorize_and_solve';
    else
        opts.method = 'SCSA';
    end
elseif ~((ischar(opts.method) && isrow(opts.method)) || (isstring(opts.method) && isscalar(opts.method)))
    error('opts.method must be a character vector or string, if given.');
elseif ~ismember(lower(opts.method), {'scsa', 'factorize_and_solve', 'fs'})
    error('opts.method = ''%s'' is not a supported option; use ''SCSA'' or ''factorize_and_solve''.', opts.method);
elseif opts.return_X && strcmpi(opts.method, 'SCSA')
    error('opts.method = ''%s'' cannot be used when opts.return_X = true; use opts.method = ''factorize_and_solve'' instead.', opts.method)
elseif strcmpi(opts.method, 'FS')
    opts.method = 'factorize_and_solve';  % opts.method = 'FS' is short for opts.method = 'factorize_and_solve'
end

% Use MUMPS for opts.solver when it is available
MUMPS_available = exist('zmumps','file');
if ~isfield(opts, 'solver') || isempty(opts.solver)
    if MUMPS_available
        opts.solver = 'MUMPS';
    else
        opts.solver = 'MATLAB';
    end
elseif ~((ischar(opts.solver) && isrow(opts.solver)) || (isstring(opts.solver) && isscalar(opts.solver)))
    error('opts.solver must be a character vector or string, if given.');
elseif ~ismember(lower(opts.solver), {'mumps', 'matlab'})
    error('opts.solver = ''%s'' is not a supported option; use ''MUMPS'' or ''MATLAB''.', opts.solver);
elseif strcmpi(opts.solver, 'MUMPS') && ~MUMPS_available
    error('opts.solver = ''%s'' but function zmumps() is not found.', opts.solver)
end

% When opts.method = 'SCSA' and opts.solver = 'MATLAB', the solution method is not actually SCSA, so we give it a more descriptive name
str_method = opts.method;
if strcmpi(opts.method, 'SCSA') && strcmpi(opts.solver, 'MATLAB')
    str_method = 'C*inv(U)*inv(L)*B';
end

if opts.iterative_refinement && ~(strcmpi(opts.method, 'factorize_and_solve') && strcmpi(opts.solver, 'MUMPS') && ~opts.return_X)
    error('To use opts.iterative_refinement = true, one must have opts.return_X = false, opts.method = ''factorize_and_solve'', opts.solver = ''MUMPS''.\nHere opts.return_X = %d, opts.method = ''%s'', opts.solver = ''%s''.', opts.return_X, opts.method, opts.solver);
end

% Turn off solver's verbal output by default
if ~isfield(opts, 'verbal_solver') || isempty(opts.verbal_solver)
    opts.verbal_solver = false;
elseif ~(islogical(opts.verbal_solver) && isscalar(opts.verbal_solver))
    error('opts.verbal_solver must be a logical scalar, if given.');
end

if opts.use_transpose_B && opts.return_X
    error('opts.use_transpose_B and opts.return_X cannot both be true.')
end

% Determine whether matrix C will be used
use_C = true;
if opts.return_X
    use_C = false;
elseif opts.use_transpose_B
    if strcmpi(opts.method, 'SCSA') && strcmpi(opts.solver, 'MUMPS')
        % In this case, we keep C=[] here and use transpose(B) later so the memory of transpose(B) can be automatically cleared after use
        use_C = false;
    else
        % In other cases, we may as well allocate the memory for C now
        C = transpose(B);
    end
end
% At this point, there are two possibilites for which use_C=false (and C=[]):
% (1) opts.return_X = true,  opts.use_transpose_B = false, opts.method = 'factorize_and_solve'
% (2) opts.return_X = false, opts.use_transpose_B = true,  opts.method = 'SCSA', opts.solver = 'MUMPS'

% Check matrix sizes
[sz_A_1, sz_A_2] = size(A);
[sz_B_1, sz_B_2] = size(B);
[sz_C_1, sz_C_2] = size(C);
if sz_A_1~=sz_A_2; error('Input argument ''A'' must be a square matrix; size(A) = [%d, %d].', sz_A_1, sz_A_2); end
if sz_A_2~=sz_B_1; error('size(A,2) must equal size(B,1); size(A,2) = %d, size(B,1) = %d.', sz_A_2, sz_B_1); end
if sz_C_2~=sz_A_1 && use_C; error('size(C,2) must equal size(A,1); size(C,2) = %d, size(A,1) = %d.', sz_C_2, sz_A_1); end

% By default, we don't clear variables unless specified by user
if ~isfield(opts, 'clear_memory') || isempty(opts.clear_memory)
    opts.clear_memory = false;
elseif ~(islogical(opts.clear_memory) && isscalar(opts.clear_memory))
    error('opts.clear_memory must be a logical scalar, if given.');
end

% Go over options only relevant when MUMPS is used
opts.use_given_ordering = false;
str_ordering = [];
str_sym_K = [];
if strcmpi(opts.solver, 'MUMPS')
    % Determine the symmetry of matrix A if not specified
    % To skip this step (which can be slow), the user should specify opts.is_symmetric_A
    if ~isfield(opts, 'is_symmetric_A') || isempty(opts.is_symmetric_A)
        opts.is_symmetric_A = issymmetric(A);
    elseif ~(islogical(opts.is_symmetric_A) && isscalar(opts.is_symmetric_A))
        error('opts.is_symmetric_A must be a logical scalar, if given.');
    end

    % Whether matrix K = [A,B;C,0] will be treated as symmetric
    if opts.use_transpose_B && opts.is_symmetric_A && strcmpi(opts.method, 'SCSA')
        str_sym_K = ' (symmetric K)';
    end

    % Use AMD by default because its ordering/analysis stage is typically faster
    if ~isfield(opts, 'use_METIS') || isempty(opts.use_METIS)
        opts.use_METIS = false;
    elseif ~(islogical(opts.use_METIS) && isscalar(opts.use_METIS))
        error('opts.use_METIS must be a logical scalar, if given.');
    end
    if opts.use_METIS
        str_ordering = ' with METIS ordering';
    else
        str_ordering = ' with AMD ordering';
    end

    % We don't store matrix ordering by default
    if ~isfield(opts, 'store_ordering') || isempty(opts.store_ordering)
        opts.store_ordering = false;
    elseif ~(islogical(opts.store_ordering) && isscalar(opts.store_ordering))
        error('opts.store_ordering must be a logical scalar, if given.');
    end

    % Use the user-specified ordering, if given
    if isfield(opts, 'ordering') && ~isempty(opts.ordering)
        opts.use_given_ordering = true;
        str_ordering = ' with user-specified ordering';
    end

    % Number of openMP threads in MUMPS; leave empty if not specified
    if isfield(opts, 'nthreads_OMP') && ~isempty(opts.nthreads_OMP)
        if ~(isreal(opts.nthreads_OMP) && isscalar(opts.nthreads_OMP) && round(opts.nthreads_OMP)==opts.nthreads_OMP && opts.nthreads_OMP>0)
            error('opts.nthreads_OMP must be a positive integer scalar, if given.');
        end
    end
else
    if isfield(opts, 'is_symmetric_A') && ~isempty(opts.is_symmetric_A)
        opts = rmfield(opts, 'is_symmetric_A');
    end

    if isfield(opts, 'use_METIS') && ~isempty(opts.use_METIS)
        warning('opts.use_METIS is only used when opts.solver = ''MUMPS''; will be ignored.');
        opts = rmfield(opts, 'use_METIS');
    end

    if isfield(opts, 'store_ordering') && isequal(opts.store_ordering, true)
        error('opts.store_ordering = true can only be used when opts.solver = ''MUMPS''.');
    end

    if isfield(opts, 'ordering') && ~isempty(opts.ordering)
        warning('opts.ordering is only used when opts.solver = ''MUMPS''; will be ignored.');
        opts = rmfield(opts, 'ordering');
    end

    if isfield(opts, 'nthreads_OMP') && ~isempty(opts.nthreads_OMP)
        warning('opts.nthreads_OMP is only used when opts.solver = ''MUMPS''; will be ignored.');
        opts = rmfield(opts, 'nthreads_OMP');
    end
end

% Number of columns to solve for simultaneously; only used in factorize_and_solve when computing S=C*inv(A)*B
str_nrhs = [];
if strcmpi(opts.method, 'factorize_and_solve') && ~opts.return_X
    if ~isfield(opts, 'nrhs') || isempty(opts.nrhs)
        if strcmpi(opts.solver, 'MUMPS')
            if opts.iterative_refinement
                opts.nrhs = 1; % iterative refinement requires nrhs = 1
            else
                opts.nrhs = min([10, sz_B_2]);
            end
        else
            opts.nrhs = min([4, sz_B_2]);
        end
    elseif ~(isreal(opts.nrhs) && isscalar(opts.nrhs) && round(opts.nrhs)==opts.nrhs && opts.nrhs>0)
        error('opts.nrhs must be a positive integer scalar, if given.');
    elseif opts.iterative_refinement && opts.nrhs ~= 1
        error('When opts.iterative_refinement = true, opts.nrhs must be 1, if given.');
    end
    str_nrhs = sprintf(' with nrhs = %d', opts.nrhs);
elseif isfield(opts, 'nrhs') && ~isempty(opts.nrhs)
    warning('opts.nrhs is not used when opts.method = ''%s'' and opts.return_X = %d; will be ignored.', opts.method, opts.return_X);
    opts = rmfield(opts, 'nrhs');
end

t2 = clock; timing_init = etime(t2,t0);

%% Computation Part

% No need to compute if numel(S) = 0 and we don't need to keep the ordering
if (sz_B_2 == 0 || (sz_C_1 == 0 && use_C)) && ~opts.store_ordering
    opts.method = 'None';
    opts.solver = 'None';
    if opts.verbal; fprintf('No computation needed\n'); end
elseif opts.verbal
    fprintf('< Method: %s using %s%s%s%s%s >\n', str_method, opts.solver, str_nrhs, str_ordering, str_itr_ref, str_sym_K);
end

if strcmpi(opts.method, 'None')
    S = zeros(sz_C_1, sz_B_2);
    stat.timing.build = 0;
    stat.timing.analyze = 0;
    stat.timing.factorize = 0;
    stat.timing.solve = 0;
elseif strcmpi(opts.method, 'SCSA')
%% Compute S=C*inv(A)*B with SCSA (Schur complement scattering analysis)
    if strcmpi(opts.solver, 'MUMPS') % Build matrix K=[A,B;C,0] and use MUMPS to compute its Schur complement -C*inv(A)*B with the LU factors discarded.
        t1 = clock;
        if opts.verbal; fprintf('Building K...   '); end

        N = size(A,1);
        is_symmetric_K = opts.is_symmetric_A;
        if opts.use_transpose_B
            M_tot = size(B, 2);
            D = sparse(M_tot, M_tot); % zero matrix
            K = [[A; transpose(B)], [B; D]];  % C = transpose(B)
        else
            % pad zeros so that size(B,2) = size(C,1)
            M_in = size(B,2);
            M_out = size(C,1);
            M_tot = max([M_in, M_out]);
            if M_tot > M_in
                % pad M_tot-M_in columns of zeros to B
                B = [B, sparse(N, M_tot-M_in)];
            elseif M_tot > M_out
                % pad M_tot-M_out rows of zeros to C
                C = [C; sparse(M_tot-M_out, N)];
            end
            D = sparse(M_tot, M_tot); % zero matrix
            K = [[A; C], [B; D]];
            is_symmetric_K = false; % even if A is symmetric, generally C won't equal transpose(B); we will not check whether C equals B.' or not; the user should set opts.use_transpose_B = true if C=B.'
        end
        if opts.clear_memory
            clear A B C D
            if ~isempty(A_name) || ~isempty(B_name) || ~isempty(C_name)
                evalin('caller', ['clear ', A_name, ' ', B_name, ' ', C_name]); % do 'clear A B C' in caller's workspace
            end
        end
        ind_schur = N + (1:M_tot); % indices for the Schur variables; must be a row vector

        t2 = clock; timing_build = etime(t2,t1);
        if opts.verbal; fprintf('elapsed time: %7.3f secs\n', timing_build); end

        % Call MUMPS to analyze and compute the Schur complement (using a partial factorization)
        % This is typically the most memory-consuming part of the whole simulation
        [id, stat] = MUMPS_analyze_and_factorize(K, opts, is_symmetric_K, ind_schur);

        stat.timing.build = timing_build;  % the build time for A, B, C will be added in addition to this
        t1 = clock;

        % Retrieve C*inv(A)*B = -H = -K/A, stored as a dense matrix
        S = -(id.SCHUR);

        % Remove the padded zeros
        if ~opts.use_transpose_B
            if M_tot > M_in
                S = S(:, 1:M_in);
            elseif M_tot > M_out
                S = S(1:M_out, :);
            end
        end

        % Destroy the MUMPS instance and deallocate memory
        id.JOB = -2;  % what to do: terminate the instance
        [~] = zmumps(id);

        t2 = clock;
        stat.timing.factorize = stat.timing.factorize + etime(t2,t1);
        stat.timing.solve = 0;
    else % Compute C*inv(U)*inv(L)*B where A=LU, with the order of multiplication based on matrix nnz
        % Factorize as P*inv(R)*A*Q = L*U where R is diagonal, L and U are lower and upper triangular, and P and Q are premutation matrices
        % For simplicity, we refer to this as A = L*U below
        [L, U, P, Q, R, stat] = MATLAB_factorize(A, opts);
        stat.timing.build = 0;  % the build time for A, B, C will be added in addition to this
        if opts.clear_memory
            clear A
            if ~isempty(A_name)
                evalin('caller', ['clear ', A_name]); % do 'clear A' in caller's workspace
            end
        end

        % Here, we evalulate C*inv(A)*B, not necessarily as C*[inv(A)*B], but more generally as C*inv(U)*inv(L)*B.
        % The full expression is C*inv(A)*B = C*Q*inv(U)*inv(L)*P*inv(R)*B.
        % There are a few ways to group the mldivide or mrdivide operations. Like matrix multiplications, it is generally faster and more memory efficient to group such that we operate onto the side with fewer elements first.
        if opts.verbal; fprintf('Solving...      '); end
        t1 = clock;
        nnz_B = nnz(B);
        nnz_C = nnz(C);
        if nnz_B <= nnz_C
            % Operate onto B first
            inv_L_B = L\(P*(R\B)); % inv(L)*B
            if opts.clear_memory
                clear L P R B
                if ~isempty(B_name)
                    evalin('caller', ['clear ', B_name]); % do 'clear B' in caller's workspace
                end
            end
            if nnz_C < nnz(inv_L_B)
                S = full(((C*Q)/U)*inv_L_B); % [C*inv(U)]*[inv(L)*B]
            else
                % This version essentially is the same as factorize_and_solve except that here we project with C after the whole X is computed
                S = (C*Q)*full(U\inv_L_B);   % C*[inv(U)*[inv(L)*B]]
                if issparse(S); S = full(S); end
            end
        else
            % Operate onto C first
            C_inv_U = (C*Q)/U; % C*inv(U)
            if opts.clear_memory
                clear U Q C
                if ~isempty(C_name)
                    evalin('caller', ['clear ', C_name]); % do 'clear C' in caller's workspace
                end
            end
            if nnz_B < nnz(C_inv_U)
                S = full(C_inv_U*(L\(P*(R\B)))); % [C*inv(U)]*[inv(L)*B]
            else
                S = full(C_inv_U/L)*(P*(R\B));   % [[C*inv(U)]*inv(L)]*B
            end
        end
        t2 = clock; stat.timing.solve = etime(t2,t1);
        if opts.verbal; fprintf('elapsed time: %7.3f secs\n', stat.timing.solve); end
    end
elseif strcmpi(opts.method, 'factorize_and_solve')
%% Compute S=C*inv(A)*B or X=inv(A)*B by factorizing A and solving for X column by column
    % Factorize A = L*U where L and U are upper and lower triangular, with permutations
    if strcmpi(opts.solver, 'MUMPS')
        [id, stat] = MUMPS_analyze_and_factorize(A, opts, opts.is_symmetric_A);
    else
        [L, U, P, Q, R, stat] = MATLAB_factorize(A, opts);
        if opts.clear_memory
            clear A
            if ~isempty(A_name)
                evalin('caller', ['clear ', A_name]); % do 'clear A' in caller's workspace
            end
        end
    end
    stat.timing.build = 0;  % the build time for A, B, C will be added in addition to this

    % Solve stage (forward and backward substitutions)
    if opts.verbal; fprintf('Solving...      '); end
    t1 = clock;
    if opts.return_X % Compute X=inv(A)*B; we call X as S here since S is what mesti_matrix_solver() returns
        if strcmpi(opts.solver, 'MUMPS')
            id.JOB = 3;  % what to do: solve
            id.RHS = B;  % no need to loop since we keep everything
            id.ICNTL(20) = 1; % tell MUMPS that the RHS is sparse
            id = zmumps(id,A);  % perform the solve
            if id.INFOG(1) < 0; error(MUMPS_error_message(id.INFOG)); end % check for errors
            S = id.SOL; % X = id.XOL
            % Destroy the MUMPS instance and deallocate memory
            id.JOB = -2;  % what to do: terminate the instance
            [~] = zmumps(id);
        else
            % Forward and backward substitutions + undo scaling and ordering
            % X = Q*U\(L\(P*(R\B)))
            % Do it in two steps so we can clear L to reduce peak memory usage
            inv_L_B = L\(P*(R\B)); % inv(L)*B
            if opts.clear_memory
                clear L P R B
                if ~isempty(B_name)
                    evalin('caller', ['clear ', B_name]); % do 'clear B' in caller's workspace
                end
            end
            S = Q*full(U\inv_L_B);
        end
    else % Compute S=C*inv(A)*B
        M_in = size(B, 2);
        M_out = size(C, 1);
        S = zeros(M_out, M_in);
        % Storing the whole X=inv(A)*B wastes memory, so we solve for opts.nrhs columns of X each time and only keep its projection onto C.
        if strcmpi(opts.solver, 'MUMPS')
            if opts.iterative_refinement
                stat.itr_ref_nsteps = zeros(M_in,1);
                stat.itr_ref_omega_1 = zeros(M_in,1);
                stat.itr_ref_omega_2 = zeros(M_in,1);
            end
            for k = 1:opts.nrhs:M_in
                in_list = k:min([k+opts.nrhs-1, M_in]);
                id.JOB = 3;  % what to do: solve
                id.RHS = B(:,in_list);
                id.ICNTL(20) = 1; % tell MUMPS that the RHS is sparse
                id = zmumps(id,A);  % perform the solve
                if id.INFOG(1) < 0; error(MUMPS_error_message(id.INFOG)); end % check for errors
                S(:,in_list) = C*id.SOL; % X = id.XOL
                if opts.iterative_refinement  % we must have opts.nrhs = 1 in this case
                    stat.itr_ref_nsteps(k) = id.INFOG(15); % number of steps of iterative refinement
                    stat.itr_ref_omega_1(k) = id.RINFOG(7); % scaled residual 1; see MUMPS user guide section 3.3.2
                    stat.itr_ref_omega_2(k) = id.RINFOG(8); % scaled residual 2; see MUMPS user guide section 3.3.2
                end
            end
            % Destroy the MUMPS instance and deallocate memory
            id.JOB = -2;  % what to do: terminate the instance
            [~] = zmumps(id);
        else
            CQ = C*Q;
            if opts.clear_memory
                clear C
                if ~isempty(C_name)
                    evalin('caller', ['clear ', C_name]); % do 'clear C' in caller's workspace
                end
            end
            for k = 1:opts.nrhs:M_in
                in_list = k:min([k+opts.nrhs-1, M_in]);
                % Forward and backward substitutions + undo scaling and ordering
                S(:,in_list) = CQ*full(U\(L\(P*(R\B(:,in_list)))));
            end
        end
    end
    if issparse(S); S = full(S); end
    t2 = clock; stat.timing.solve = etime(t2,t1);
    if opts.verbal; fprintf('elapsed time: %7.3f secs\n', stat.timing.solve); end
else
    error('opts.method = ''%s'' is not a supported option.', opts.method);
end

if opts.use_given_ordering; opts = rmfield(opts, 'ordering'); end % We don't return the user-specified ordering again since it can be large
stat.opts = opts; % Return the parameters used for user's reference
stat.timing.init = timing_init; % Initialization time
t2 = clock; stat.timing.total = etime(t2,t0); % Total computing time

end


%% Call MATLAB's lu() to factorize matrix A
function [L, U, P, Q, R, stat] = MATLAB_factorize(A, opts)

if opts.verbal; fprintf('Factorizing...  '); end
t1 = clock;

if opts.verbal_solver
    spparms('spumoni',2)
else
    spparms('spumoni',0)
end

% P*inv(R)*A*Q = L*U where R is diagonal, L and U are lower and upper triangular, and P and Q are premutation matrices
[L,U,P,Q,R] = lu(A);

t2 = clock; stat.timing.factorize = etime(t2,t1);
stat.timing.analyze = 0; % the analysis time is already counted in the factorization time
if opts.verbal; fprintf('elapsed time: %7.3f secs\n', stat.timing.factorize); end

end


%% Call MUMPS to analyze and factorize matrix A (if ind_schur is not given) or to compute its Schur complement (if ind_schur is given)
function [id, stat] = MUMPS_analyze_and_factorize(A, opts, is_symmetric, ind_schur)

%% Initialize MUMPS
N = size(A,1);
id = initmumps;  % get the default parameters
if is_symmetric
    id.SYM = 2;  % specify that matrix A is symmetric but not positive definite
else
    id.SYM = 0;  % specify that matrix A is not symmetric
end
id = zmumps(id);

if opts.verbal_solver
    % Output to standard output stream, which is labeled by 6 in fortran
    % Note that the output behavior depends on the compiler used to compile MUMPS:
    % - ifortran will let output go to the standard output
    % - other compilers like gfortran will sometimes write output to a file fort.6, sometimes give nothing
    id.ICNTL(3) = 6;
else
    id.ICNTL(3) = 0; % turn off output
end

% set the number of OpenMP threads, if given (only avaiable after MUMPS 5.2.0)
if isfield(opts, 'nthreads_OMP') && ~isempty(opts.nthreads_OMP)
    id.ICNTL(16) = opts.nthreads_OMP;
end

if nargin == 4
    % Specify where the Schur block is; id.VAR_SCHUR must be a row vector
    % We should allow ind_schur to be an empty vector (for which the Schur complement is an empty matrix), but the MATLAB interface of MUMPS crashes when id.VAR_SCHUR is empty, so we need to exclude such scenario here
    if ~isempty(ind_schur)
        if ~(isrow(ind_schur) && isnumeric(ind_schur) && isequal(round(ind_schur),ind_schur) && min(ind_schur)>0 && max(ind_schur)<=N)
            error('ind_schur must be a row vector of positive integers not exceeding size(A,1) = %d.', N);
        end
        id.VAR_SCHUR = ind_schur;
    end

    % Discard factors, since all we need is the Schur complement
    id.ICNTL(31) = 1;
elseif opts.iterative_refinement
    id.ICNTL(10) = 1000; % Enable iterative refinement and set maximum number of iterations; usually 1-2 iterations is sufficient

    % Lower the stopping criterion (omega_1 + omega_2 < id.CNTL(2)) for iterative refinement to machine precision.
    % Note that iterative refinement will also stop when omega_1 + omega_2 does not decrease by at least a factor of 5.
    %fprintf('Changing stopping criterion of iterative refinement from id.CNTL(2) = %g to %g\n', id.CNTL(2), 1e-16);
    id.CNTL(2) = 1e-16;
end

%% Analysis stage
if opts.verbal; fprintf('Analyzing...    '); end
t1 = clock;
id.JOB = 1;  % what to do: analysis
if opts.use_given_ordering
    % Use a user-specified ordering, if given
    % We don't check the validity of opts.ordering other than its size because it can be slow to check a long vector
    if numel(opts.ordering) ~= N
        error('numel(opts.ordering) = %d does not equal matrix size = %d.', numel(opts.ordering), N);
    end
    id.ICNTL(7) = 1; % use the ordering in id.PERM_IN
    id.PERM_IN = opts.ordering;  % the ordering (a permutation vector)
else
    if opts.use_METIS
        % Use the METIS package to compute ordering.
        % This typically gives a more sparse factorization, so the memory usage is lower and the factorization and solve stages will be faster. But the analyze stage will be much slower.
        id.ICNTL(7) = 5;
    else
        % use AMD to computer ordering (default)
        id.ICNTL(7) = 0;
    end
end
id = zmumps(id,A);  % run the analysis
if id.INFOG(1) < 0; error(MUMPS_error_message(id.INFOG)); end % check for errors

% Store statistics and ordering info
stat.ordering_method = id.INFOG(7); % the ordering method that was actually used
if opts.store_ordering
    % Store the ordering (a permutation vector) that was computed
    % line 84 of the MATLAB interface zmumps.m actually stores the inverse ordering rather than the ordering, so we need to undo the inversion here
    stat.ordering = zeros(1,N);
    stat.ordering(id.SYM_PERM) = 1:N;
end

t2 = clock; stat.timing.analyze = etime(t2,t1);
if opts.verbal; fprintf('elapsed time: %7.3f secs\nFactorizing...  ', stat.timing.analyze); end

%% Factorization stage
t1 = clock;
id.JOB = 2;  % what to do: factorize
id = zmumps(id,A);  % run the factorization
if id.INFOG(1) < 0; error(MUMPS_error_message(id.INFOG)); end % check for errors

if nargin == 4
    if isempty(ind_schur)
        id.SCHUR = zeros(0,0);
    else
        % What the MEX function zmumpsmex() returns is not schur but its tranpose, probably because C is row major while MATLAB is column major.
        % When A is not symmetric, line 77 of the MATLAB interface zmumps.m attempts to undo the transpose by returning schur', which would have worked if ' were to be transpose. But ' is conjugate transpose. So we need to conjugate it
        % When A is symmetric, MUMPS only returns the lower triangular part and the diagonal of the Schur complement (see MUMPS userguide)
        % line 79 of the MATLAB interface zmumps.m attempts to undo the transpose and to complete the other half by returning triu(schur)+tril(schur',-1), which would have worked if ' were to be transpose. But ' is conjugate transpose. So the lower triangular part (excluding the diagonal) has the wrong sign in its imaginary part. Now we need to fix that.
        if is_symmetric
            id.SCHUR = triu(id.SCHUR) + conj(tril(id.SCHUR,-1));
        else
            id.SCHUR = conj(id.SCHUR);
        end
    end
end

t2 = clock; stat.timing.factorize = etime(t2,t1);
if opts.verbal; fprintf('elapsed time: %7.3f secs\n', stat.timing.factorize); end

end


%% Interpret some of the error messages from MUMPS
function msg = MUMPS_error_message(INFOG)

fprintf('\n');
for nn = 1:length(INFOG)
    fprintf('INFOG(%d) = %d\n', nn, INFOG(nn));
end

% Interpret some of the error values; look at MUMPS user guide for complete listing
switch INFOG(1)
    case -1; err_msg = sprintf('An error occurred on processor %d', INFOG(2));
    case -2; err_msg = sprintf('NNZ (or NZ) = %d is out of range', INFOG(2));
    case -3; err_msg = 'MUMPS was called with an invalid value for JOB';
    case -4; err_msg = sprintf('Error in user-provided permutation array PERM_IN at position %d', INFOG(2));
    case -5; err_msg = sprintf('Not enough memory for real workspace allocation during analysis; INFOG(2) = %d', INFOG(2));
    case -6; err_msg = sprintf('Matrix is singular in structure; structural rank %d', INFOG(2));
    case -7; err_msg = sprintf('Not enough memory for integer workspace allocation during analysis; INFOG(2) = %d', INFOG(2));
    case -8; err_msg = 'Integer workarray IS too small for factorization; should increase ICNTL(14) and call again';
    case -9; err_msg = 'Real/complex workarray S too small for factorization; should increase ICNTL(14) and call again';
    case -10; err_msg = 'Matrix is numerically singular';
    case -13; err_msg = sprintf('Not enough memory for real/complex workspace allocation during factorization; INFOG(2) = %d; estimated memory usage = %d MB; actual memory allocation = %d MB', INFOG(2), INFOG(17), INFOG(19));
    case -14; err_msg = 'Integer workarray IS too small for solution; should increase ICNTL(14) and call again';
    case -15; err_msg = 'Integer workarray IS too small for iterative refinement and/or error analysis; should increase ICNTL(14) and call again';
    case -16; err_msg = sprintf('N = %d is out of range', INFOG(2));
    case -17; err_msg = 'Internal send buffer too small; should increase ICNTL(14) and call again';
    case -20; err_msg = 'Internal reception buffer too small; should increase ICNTL(14) and call again';
    case -44; err_msg = sprintf('The solve stage cannot be performed because the factors or part of the factors are not available; ICNTL(31) = %d', INFOG(2));
    otherwise; err_msg = 'See MUMPS user guide';
end
msg = sprintf('MUMPS failed with INFOG(1)=%d, INFOG(2)=%d: %s.', INFOG(1), INFOG(2), err_msg);

end
