%% Initial Calcs (equations given in slides)
clear; clc;

%% --- Target Specs ---
% These don't change

UGF_spec = 70e6;      % Unity Gain Frequency, Hz (at minimum)
A0_spec = 70;         % DC gain, dB (at minimum)
AM_spec = 5;          % Gain margin, dB (at minimum)
PM_spec  = 65;        % Phase margin, degrees (at minimum)
Pwr_spec = 2.5e-3;    % Power dissipation, W (at maximum - try to minimize!)

% --- Constants --- 
CL = 5e-12;           % F 
VDD = 1.8;            % V


%% --- Knobs ---
% Workspace--where we alter values/change margins/etc

Cc = 1e-12;                   % TO START: prof said usually 100 fF to 10 pF, choose 1pF
UGF_target = UGF_spec * 1.15;   % TO START: trying a 15% margin
    % Freedom (increasing target) here gives margin for GM of stage 1 (variable Gm1, currently understood to be gm3)
    
PM_target = [PM_spec PM_spec+3 PM_spec+6 PM_spec+9];    % checking different values 
    % Freedom (increasing target) here gives margin for GM of stage 2 (variable Gm2, currently understood to be gm9)

Vov = 0.15;                   % TO START: pick min, may increase later

%% --- Governing Equations ---

wc  = 2*pi*UGF_target;          
Gm1 = Cc * wc;                  

wp2 = wc ./ tand(90 - PM_target);   
Gm2 = wp2 * CL;                 


Rc  = 1 ./ Gm2;                  % This is the nulling resistor, moving zero to +infinity   

%% --- Results ---

% Finding Ro1*Ro2 based off of the Gm values calculated in the Equations
% section
A0_notdB = 10^(A0_spec/20);     % NO MARGIN on this yet
RoProduct   = A0_notdB ./ (Gm1*Gm2);   % Ro1*Ro2, from A0 = Gm1Ro1Gm2Ro2

%% --- Extra (sanity) checks ---

Id1_est = Gm1 * Vov / 2;     
Id2_est = Gm2 * Vov / 2;

%% --- Print results ---
fprintf('BASED ON KNOBS Cc, UGF, PM (various): \n')
fprintf('Gm1 = %.4e S\n', Gm1);
fprintf('PM_target   Gm2 (mS)   Rc (ohm)   Id2_est (uA)   Ro1*Ro2 (Mohm^2)\n');
for k = 1:numel(PM_target)
    fprintf('%8.0f   %8.3f   %8.0f   %10.0f   %14.0f\n', ...
        PM_target(k), Gm2(k)*1e3, Rc(k), Id2_est(k)*1e6, RoProduct(k)/1e6);
end
% fprintf('Gm2 = %.4e S\n', Gm2);
% fprintf('fp2 = %.4e Hz\n', wp2/(2*pi));
% fprintf('Rc  = %.0f ohm\n', Rc);
% fprintf('Ro1*Ro2 needed = %.3g ohm^2\n', RoProduct);
fprintf('Id1 est = %.0f uA, budget = %.0f uA total\n', Id1_est*1e6, Pwr_spec/VDD*1e6);
% fprintf('Id2 est = %.0f uA, budget = %.0f uA total\n', Id2_est*1e6, Pwr_spec/VDD*1e6);