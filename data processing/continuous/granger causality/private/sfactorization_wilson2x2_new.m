function [H, Z, S, psi] = sfactorization_wilson2x2_new(S, freq, Niterations, tol, cmbindx, checkflag, stabilityfix)
    % This is a version based on Fieldtrip function sfactorization_wilson2x2
    % [init] is set 'rand' here

    % S: complex double
    % I: double
    % Sarr: complex double
    N = numel(freq);
    selfreq = 1:numel(freq);
    m = size(cmbindx, 1);
    Ntim = size(S, 4);

    % check whether the last frequency bin is strictly real-valued.
    % if that's the case, then it is assumed to be the Nyquist frequency
    % and the two-sided spectral density will have an even number of
    % frequency bins. if not, in order to preserve hermitian symmetry,
    % the number of frequency bins needs to be odd.
    Send = S(:, :, end, end); % complex double

    if all(imag(Send(:)) < abs(trace(Send) ./ size(Send, 1) * 1e-9))
        hasnyq = true;
        N2 = 2 * (N - 1);
    else
        hasnyq = false;
        N2 = 2 * (N - 1) + 1;
    end

    % preallocate memory for the identity matrix
    I = repmat(eye(2), [1 1 m Ntim N2]); % Defining 2 x 2 identity matrix % double

    % preallocate memory for the 2-sided spectral density
    Sarr = zeros(2, 2, m, N2, Ntim) + 1i .* zeros(2, 2, m, N2, Ntim); % complex

    % --- Step 1: Form 2-sided spectral densities for ifft routine in matlab
    % tic
    % A = zeros(m*4, 2);
    % for rowind = 1:m
    %     [a,b,~,~] = ndgrid(cmbindx(rowind,:));
    %     A((rowind-1)*4+[1:4], :) = unique([a(:) b(:)], 'rows', 'stable');
    % end
    % sz = size(S);
    % S1 = reshape(S, sz(1)*sz(2), sz(3));
    % Sarr(:,:,:,1:N) = reshape(S1(sub2ind(sz, A(:,1), A(:,2)), :), 2, 2, m, sz(3));
    % toc

    % tic
    for c = 1:m
        Sarr(:, :, c, 1:N, :) = S(cmbindx(c, :), cmbindx(c, :), :, :);
    end

    % toc
    Sarr = permute(Sarr, [1 2 3 5 4]);

    if hasnyq
        N1 = N;
    else
        N1 = N + 1; % the highest frequency needs to be represented twice, for symmetry purposes
    end

    Sarr(:, :, :, :, N1:N2) = flip(Sarr(:, :, :, :, 2:N), 5);
    Sarr(2, 1, :, :, N1:N2) = pagectranspose(Sarr(2, 1, :, :, N1:N2));
    Sarr(1, 2, :, :, N1:N2) = pagectranspose(Sarr(1, 2, :, :, N1:N2));
    % Sarr              = permute(Sarr, [1 2 4 3]);
    Sarr(:, :, :, :, 1) = Sarr(:, :, :, :, 1) .* 2; % weight the DC-bin

    % the input cross-spectral density is assumed to be weighted with a
    % factor of 2 in all non-DC and Nyquist bins, therefore weight the
    % Nyquist bin with a factor of 2 to get a correct two-sided representation
    if hasnyq
        Sarr(:, :, :, :, N) = Sarr(:, :, :, :, N) .* 2;
    end

    % --- Step 2: Compute covariance matrices
    gam = real(reshape(ifft(reshape(Sarr, [4 * m * Ntim N2]), [], 2), [2 2 m Ntim N2])); %double

    % --- Step 3: Initialize for iterations
    gam0 = gam(:, :, :, 1, 1);

    h = complex(zeros(size(gam0)));

    % case init is set 'rand'
    for k = 1:m
        tmp = rand(2, 2); %arbitrary initial condition
        tmp = triu(tmp);
        h(:, :, k) = tmp; % double
    end

    psi = repmat(h, [1 1 1 Ntim N2]); % double

    % --- Step 4: Iterations to get spectral factors
    for iter = 1:Niterations
        invpsi = inv2x2(psi);
        %     % --
        %     function J =Jacobian1(t)
        %     global l1 l2 l3;
        %     j1 = [-(l1+l2.*cos(t(2,:))+l3.*cos(t(2,:)+t(3,:))).*sin(t(1,:));
        %         -(l2.*sin(t(2,:))+l3.*sin(t(2,:)+t(3,:))).*cos(t(1,:));
        %         -l3.*sin(t(2,:)+t(3,:)).*cos(t(1,:));
        %         (l1+l2.*cos(t(2,:))+l3.*cos(t(2,:)+t(3,:))).*cos(t(1,:));
        %         -(l2.*sin(t(2,:))+l3.*sin(t(2,:)+t(3,:))).*sin(t(1,:));
        %         -l3.*sin(t(2,:)+t(3,:)).*sin(t(1,:));
        %         zeros(1,size(t,2));
        %         l2.*cos(t(2,:))+l3.*cos(t(2,:)+t(3,:));
        %         l3.*cos(t(2,:)+t(3,:))];
        %     J = permute(reshape(j1,3,3,[]),[2 1 3]);
        %     end
        %     J=Jacobian1(M1);
        %     vx=(B(1)-A(1))/2.5;
        %     vy=0;
        %     vz=0;
        %     V=[vx;vy;vz];
        %     Td=cell2mat(arrayfun(@(jj)J(:,:,jj)\V,1:size(J,3),'un',0));
        %     % --
        g = sandwich2x2(invpsi, Sarr) + I; % complex double
        gp = PlusOperator2x2(g, m, N, stabilityfix); %gp constitutes positive and half of zero lags % complex double

        psi_old = psi;
        psi = mtimes2x2(psi, gp);

        if checkflag
            psierr = abs(psi - psi_old) ./ abs(psi);
            psierrf = mean(psierr(:));

            if (psierrf < tol)
                fprintf('reaching convergence at iteration %d\n', iter);
                break;
            end % checking convergence

        end

    end

    %i --- Step 5: Get covariance matrix from spectral factors
    % gamtmp = reshape(real(ifft(transpose(reshape(psi, [4*m*Ntim N2]))))', [2 2 m Ntim N2]); % double
    gamtmp = reshape(real(ifft(ctranspose(reshape(psi, [4 * m * Ntim N2]))))', [2 2 m Ntim N2]); % double

    % --- Step 6: Get noise covariance & transfer function
    A0 = gamtmp(:, :, :, :, 1); % double
    A0inv = inv2x2(A0); % double

    % Z = zeros(2,2,m);
    % for k = 1:m
    %     %Z     = A0*A0.'*fs; %Noise covariance matrix
    %     Z(:,:,k) = A0(:,:,k)*A0(:,:,k).'; %Noise covariance matrix not multiplied by sampling frequency
    %     %FIXME check this; at least not multiplying it removes the need to correct later on
    %     %this also makes it more equivalent to the noisecov estimated by biosig's mvar-function
    % end

    Z = pagemtimes(A0, pagetranspose(A0)); % double
    % Z = pagemtimes(A0, pagectranspose(A0));

    H = mtimes2x2(psi, A0inv(:, :, :, :, ones(1, size(psi, 5)))); %complex
    S = mtimes2x2(psi, ctranspose2x2(psi)); % complex

    siz = [size(H)];
    H = reshape(H, [4 * siz(3) siz(4) siz(5)]);

    siz = [size(S)];
    S = reshape(S, [4 * siz(3) siz(4) siz(5)]);

    siz = [size(Z) 1];
    Z = reshape(Z, [4 * siz(3) siz(4) siz(5)]);

    siz = [size(psi)];
    psi = reshape(psi, [4 * siz(3) siz(4) siz(5)]);

    % return only the frequency bins that were in the input
    H = H(:, :, selfreq);
    S = S(:, :, selfreq);
    psi = psi(:, :, selfreq);

    H = permute(H, [1 3 2]); % complex
    S = permute(S, [1 3 2]); % complex
    psi = permute(psi, [1 3 2]); % complex

    %---------------------------------------------------------------------
    function gp = PlusOperator2x2(g, ncmb, nfreq, stabilityfix)

        % This function is for [ ]+operation:
        % to take the positive lags & half of the zero lag and reconstitute
        % M. Dhamala, UF, August 2006
        %     g = permute(g, [1 2 3 5 4]);
        sz = size(g);
        %         g   = transpose(reshape(g, numel(g)/sz(5), sz(5))); % complex
        g = ctranspose(reshape(g, numel(g) / sz(5), sz(5))); % complex
        gam = ifft(g); % complex

        % taking only the positive lags and half of the zero lag
        gamp = gam; % complex
        beta0 = 0.5 * gam(1, :); % complex

        %for k = 1:ncmb
        %  gamp(1,(k-1)*4+1:k*4) = reshape(triu(reshape(beta0(1,(k-1)*4+1:k*4),[2 2])),[1 4]);
        %end
        beta0(2:4:4 * ncmb * sz(4)) = 0;
        gamp(1, :) = beta0;
        gamp(nfreq + 1:end, :) = 0;

        % smooth with a window, only for the long latency boundary: this is a
        % stabilityfix proposed by Martin Vinck
        if stabilityfix
            w = tukeywin(nfreq * 2, 0.5);
            gamp(1:nfreq, :) = gamp(1:nfreq, :) .* repmat(w(nfreq + 1:end), [1 size(gamp, 2)]);
        else
            % nothing to be done here
        end

        % reconstituting
        gp = fft(gamp); % complex
        % gp = reshape(transpose(gp), sz);
        gp = reshape(ctranspose(gp), sz);

    end

end
