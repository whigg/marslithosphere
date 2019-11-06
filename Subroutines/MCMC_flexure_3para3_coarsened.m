function out = MCMC_flexure_3para3_coarsened(gamma,Te_range,rhot_range,f_range,Te_isd,rhot_isd,f_isd,Te_ini,rhot_ini,f_ini,N,burnin,DEGS,FADM,FCOR,FADM_sd,FCOR_sd,degs,HH,Mij,Lwin)

ifplot = 0;

format long
CurrPath = pwd;
addpath([CurrPath '/Subroutines'],'-end');

%disp 'Apply MCMC method to constraining flexural parameters, Te, rhot, and f'  


if ifplot
figure;
subplot1(2,1)
end

%% Fit all the three curves

%disp 'Fit free-air admittance and free-air correlation'

% Bayesian parameter estimation
acc=0; % number of accepted step after burnin steps

dim=3; % total # of parameters: Te, rhot, f
prop_Var=[Te_isd rhot_isd f_isd]; % pre-assumed Gaussian variance

% Initialize Markov chain
X = zeros(dim,N); 
X(:,1) = [Te_ini;rhot_ini;f_ini]; % initial values

%disp('Initial setup for parameter steps - SD(Te), SD(rhot), SD(f), SD(rhoc),SD(alpha)')
%disp(num2str(prop_Var))

% Adaptive variance
sp=2.38^2/dim; % constant 
epsilon=0.1; % 0-0.1 Matrix diagnal
V = zeros(dim,dim,N); % covariance matrix
V(:,:,1) = diag(prop_Var); % initial
R = chol(V(:,:,1)); % decompose ... Lower/upper matrix
k0 = 50; % after k0 steps, covariance matrix is updated; k0 can be varied if needed
%R = diag(prop_Var);

% Calculate synethic curves 
Te = X(1,1)*1e3;
rhot = X(2,1);        
f = X(3,1);
rhob = 600;
rhoc = rhot;
alpha = 0;

% calculate localized admcor
[fadm,fcor,~,~] = localized_synthetic_admcor2(Te,f*rhot/rhob,alpha,rhot,rhoc,degs',HH,Mij);
fadm = fadm*1e3;
fcor = real(fcor);
deg_localmodel = Lwin+5:90-Lwin;
s = find(deg_localmodel>=min(DEGS)&deg_localmodel<=max(DEGS));

% Calculate prior 
currPrior = unifpdf(X(1,1),Te_range(1),Te_range(2))*unifpdf(X(2,1),rhot_range(1),rhot_range(2))*unifpdf(X(3,1),f_range(1),f_range(2)); % continuous uniform pdf

% Calculate likelihood
%currLikely = prod(normpdf(FADM,fadm,sqrt(Sigma2e)))*prod(normpdf(FCOR,fcor,sqrt(Sigma2e1)))*prod(normpdf(BCOR,bcor,sqrt(Sigma2e1))); % multi-variate Gaussian;log current likelihood
LcurrLikely = log(prod(normpdf(FADM,fadm(s)',FADM_sd)))+log(prod(normpdf(FCOR,fcor(s)',FCOR_sd))); % multi-variate Gaussian;log current likelihood
LcurrLikely = 1/gamma*LcurrLikely;

% Initialize the results
fadm_best = FADM*0;
fcor_best = fadm_best;
fadm_sd = fadm_best;
fcor_sd = fadm_best;

% Construct Markov chain    
for k=2:N

    Yprop=X(:,k-1) + (randn(1,dim)*R)'; % random walking
        
    % calculate the synthetic curves 
    Te = Yprop(1)*1e3;
    rhot = Yprop(2);        
    f = Yprop(3);
    rhoc = rhot;
    alpha = 0;
    
    [fadm,fcor,~,~] = localized_synthetic_admcor2(Te,f*rhot/rhob,alpha,rhot,rhoc,degs',HH,Mij);
    fadm = fadm*1e3;
    fcor = real(fcor);
    
    % Update prior and likelihood
    propPrior = unifpdf(Yprop(1),Te_range(1),Te_range(2))*unifpdf(Yprop(2),rhot_range(1),rhot_range(2))*unifpdf(Yprop(3),f_range(1),f_range(2)); % continuous uniform pdf
    LpropLikely = log(prod(normpdf(FADM,fadm(s)',FADM_sd)))+log(prod(normpdf(FCOR,fcor(s)',FCOR_sd)));% multi-variate Gaussian of Yi^{k}
    LpropLikely = 1/gamma*LpropLikely;
    
    % Calculate acceptance probability
    %if (currPrior==0||currLikely==0)
    if (currPrior==0||LcurrLikely==-Inf) % require rhot>rhoc
        X(:,k) = X(:,k-1);
    else
        %a = min(1,propLikely/currLikely*propPrior/currPrior);
        a = min(1,exp(LpropLikely)/exp(LcurrLikely)*propPrior/currPrior);
        %disp(a)
        if (rand()<=a)
            X(:,k) = Yprop;
            %currLikely = propLikely;
            LcurrLikely = LpropLikely;
            currPrior = propPrior;
            fadm_curr = fadm(s)';
            fcor_curr = fcor(s)';
            
    if ifplot
    subplot1(1);
    cla
    errorbar(DEGS,FADM,FADM_sd,'k');hold on;
%    plot(DEGS,FADM,'k');hold on;    
    plot(DEGS,fadm_curr,'r')
    ylabel('Free-air adm. (mGal/km)')
    set(gca,'Ytick',-100:50:260,'ylim',[0 200],'Xtick',0:20:120,'xlim',[min(DEGS) max(DEGS)],'YMinorTick','on','XMinorTick','on')

    subplot1(2);
    cla
    errorbar(DEGS,FCOR,FCOR_sd,'k');hold on;
%    plot(DEGS,FCOR,'k');hold on;
    plot(DEGS,fcor_curr,'r')
    ylabel('Free-air cor.')
    set(gca,'Ytick',-0.5:0.5:1,'Ylim',[-1 1],'Xtick',0:20:120,'xlim',[min(DEGS) max(DEGS)],'YMinorTick','on','XMinorTick','on')
    pause(0.01)      
    end
    
        else
            X(:,k) = X(:,k-1);
        end
    end
    
    if(k>=burnin)
        fadm_best = fadm_best+fadm_curr;
        fcor_best = fcor_best+fcor_curr;
        fadm_sd = fadm_sd+fadm_curr.^2;
        fcor_sd = fcor_sd+fcor_curr.^2;
        acc = acc+1;
    end
    
    if k==burnin
        fadm_min = fadm_curr';
        fadm_max = fadm_curr';
        fcor_min = fcor_curr';
        fcor_max = fcor_curr';
    end
    if k>burnin
        fadm_min = min(fadm_min,fadm_curr');
        fadm_max = max(fadm_max,fadm_curr');
        fcor_min = min(fcor_min,fcor_curr');
        fcor_max = max(fcor_max,fcor_curr');
    end
    
    % Update the adaptive variance matrix
    if mod(k,k0)==1
        V(:,:,k)=sp*cov(X(:,1:k-1)')+epsilon*eye(dim,dim);
        R=chol(V(:,:,k));
    else
        V(:,:,k)=V(:,:,k-1);
    end
    
    disp(['k=' num2str(k) ',accepted steps=' num2str(acc) ',Te=' num2str(X(1,k)) ' km, rhot=' num2str(X(2,k)) ' kg/m^3, f=' num2str(X(3,k)) ]);
    
    %if mod(k,100)==0
    %    save tmp.mat
    %end
    
end

fadm_best = fadm_best/acc;
fcor_best = fcor_best/acc;
fadm_sd = sqrt(fadm_sd/acc-fadm_best.^2);
fcor_sd = sqrt(fcor_sd/acc-fcor_best.^2);

Tebest = mean(X(1,burnin:N));
Tesd = std(X(1,burnin:N));
rhotbest = mean(X(2,burnin:N));
rhotsd = std(X(2,burnin:N));
fbest = mean(X(3,burnin:N));
fsd = std(X(3,burnin:N));

save(['Cap3_VB_3para_' num2str(min(DEGS)) num2str(max(DEGS)) '_' num2str(gamma) '.mat']);

out = 1;
end