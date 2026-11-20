function f = amp_lib()
%AMP_LIB  Skeleton for the ECE 164 two-stage folded-cascode hand calcs.
%
%   f = amp_lib();    % one struct of function handles
%
% CONVENTIONS (the whole skeleton is these four rules)
%   1. p is a struct holding EVERYTHING: specs, knobs, results.
%   2. Equations (f.eq.*) are pure: numbers in, number out. They never see p.
%   3. Steps are  p = step(p): read some fields, write some fields.
%      They run in order, and a later step overwrites an earlier one.
%   4. This library is the IDEAL macro-model, but with C1 added in (capacitance 
%      on stage 1 output, affects wp2/Gm2). Refinements
%      ("tweaks") are just extra steps you write in your run script and
%      insert in the chain right AFTER the step whose output they replace
%      and BEFORE the steps that consume it.
%
% TO EXTEND
%   new equation : add one line in equations()
%   new step     : write  function p = my_step(p)  (here, or in your script)
%                  and put it in the chain passed to f.run
%   new knob     : add a line in defaults(), or just set p.my_knob in your script
%   new report row / log column : add a name to the list in report / log call
%
% NAME MAP: Gm1 = input pair M3a/b, Gm2 = M9, Ro2 = ro8||ro9, Ro1 = folded
% cascode output resistance, Cc/Rc = compensation.
% Units: SI (F, S, ohm, rad/s, A, V, W); angles in degrees; names starting
% UGF/ are in Hz.
% Pole/zero frequencies (wp2, wc, ...) are stored as positive magnitudes in rad/s;
% the LHP minus sign is implied and never carried in p.

f.eq         = equations();
f.defaults   = @defaults;
f.gm_design  = @gm_design;
f.currents   = @currents;
f.gain_budget= @gain_budget;
f.analyze    = @analyze;
f.run        = @run_steps;
f.sweep      = @sweep;
f.compare    = @compare;
f.report     = @report;
f.log        = @log_iteration;
end


%% ============================ EQUATIONS ==================================
% One per handle; vectorized (.* ./) so vectors work. Pair each relation
% with its inverse so either direction is one call away.
function E = equations()
% crossover:  wc = Gm1/Cc
E.ugf_to_wc      = @(ugf) 2*pi*ugf;
E.wc_to_ugf      = @(wc) wc/(2*pi);
E.Gm1_from_wc    = @(Cc,wc) Cc.*wc;
E.wc_from_Gm1    = @(Gm1,Cc) Gm1./Cc;
% second pole / phase margin (ideal):  wp2 = Gm2/CL,  PM = 90 - atan(wc/wp2)
E.wp2_from_pm    = @(wc,PM) wc.*tand(PM);
E.pm_from_wp2    = @(wc,wp2) 90 - atand(wc./wp2);
E.wp2_from_Gm2 = @(Gm2,CL,Cc,C1) Gm2.*Cc ./ (C1.*CL + Cc.*(C1+CL));
E.Gm2_from_wp2 = @(wp2,CL,Cc,C1) wp2.*(C1.*CL + Cc.*(C1+CL)) ./ Cc;
% nulling resistor
E.Rc_from_Gm2    = @(Gm2) 1./Gm2;
% gain:  A0 = Gm1*Ro1*Gm2*Ro2
E.roprod_from_A0 = @(A0_dB,Gm1,Gm2) 10.^(A0_dB/20)./(Gm1.*Gm2);
E.A0dB_from_ro   = @(Gm1,Ro1,Gm2,Ro2) 20*log10(Gm1.*Ro1.*Gm2.*Ro2);
% square law helpers
E.id_from_gm     = @(gm,Vov) gm.*Vov/2;
E.gm_from_id     = @(Id,Vov) 2*Id./Vov;
E.ro_from_id     = @(Id,lambda) 1./(lambda.*Id);


% stage-1 supply current, PMOS input pair + PMOS fold sources:
%   I_tail + 2*I45 = 2*Id3*(1+r). 
E.stage1_current = @(Id3,r) 2*Id3.*(1+r);
E.Id45_min = @(Id3) 2*Id3;
end


%% ============================== DEFAULTS =================================
function p = defaults()
% specs (Table 1)
p.UGF_spec = 70e6;   p.A0_spec = 70;    p.GM_spec = 5;
p.PM_spec  = 65;     p.Pwr_spec = 2.5e-3;
p.CL = 5e-12;        p.VDD = 1.8;

% knobs
p.Cc         = 1e-12;
p.UGF_target = p.UGF_spec*1.15;
p.PM_target  = p.PM_spec + 5;
p.Vov        = 0.15;
p.C1 = 100e-15;      % parasitic at Vout1 (mostly Cgs9); set 0 for the ideal model

% rough assumptions (replace as you learn more)
p.lambda     = 0.1;
p.id45_id3_ratio = 2.25;
end


%% =============================== STEPS ===================================
% Each step lists what it reads and writes, so you know where to insert tweaks.

function p = gm_design(p)
% reads: UGF_target, Cc, PM_target, CL      writes: wc, Gm1, wp2_req, Gm2, Rc
E = equations();
p.wc      = E.ugf_to_wc(p.UGF_target);
p.Gm1     = E.Gm1_from_wc(p.Cc, p.wc);
p.wp2_req = E.wp2_from_pm(p.wc, p.PM_target);
p.Gm2     = E.Gm2_from_wp2(p.wp2_req, p.CL, p.Cc, p.C1);
p.Rc      = E.Rc_from_Gm2(p.Gm2);
end


function p = currents(p)
% reads: Gm1, Gm2, Vov, I45:I3 ratio, VDD     writes: Id3, Id45, Istage1, Istage2, Icore, Pcore
% (signal path only; bias network not included)
E = equations();
p.Id3   = E.id_from_gm(p.Gm1, p.Vov);              % We know Gm1 = gm3
p.Id45 = p.id45_id3_ratio * p.Id3;
if p.Id45 <= E.Id45_min(p.Id3)
    warning('currents: I45 (%.0f uA) must exceed I_tail (%.0f uA).', ...
        p.Id45*1e6, E.Id45_min(p.Id3)*1e6);
end
p.Istage1   = E.stage1_current(p.Id3, p.id45_id3_ratio);   % stage 1 total
p.Istage2   = E.id_from_gm(p.Gm2, p.Vov);
p.Icore = p.Istage1 + p.Istage2;
p.Pcore = p.VDD*p.Icore;
end

function p = gain_budget(p)
% reads: A0_spec, Gm1, Gm2, Vov, lambda     writes: RoProduct, Ro2_est, Ro1_req
E = equations();
p.RoProduct = E.roprod_from_A0(p.A0_spec, p.Gm1, p.Gm2);
p.Ro2_est   = 0.5*E.ro_from_id(E.id_from_gm(p.Gm2, p.Vov), p.lambda);  % Gm2 = 2ID/Vov, find ID, then ro=1/(lambda*ID), then Ro2 = ro8 || ro9 so do Ro2 = ro/2
p.Ro1_req   = p.RoProduct/p.Ro2_est;
end

function p = analyze(p)
% reads: Gm1, Gm2, Cc, CL (and Ro1, Ro2 if set)   writes: wc_act, UGF_act, wp2_act, PM_act, A0_act
E = equations();
assert(isfield(p,'Gm1') && isfield(p,'Gm2'), ...
    'analyze needs p.Gm1 and p.Gm2 (run gm_design or set them by hand).');
p.wc_act  = E.wc_from_Gm1(p.Gm1, p.Cc);
p.UGF_act = E.wc_to_ugf(p.wc_act);
p.wp2_act = E.wp2_from_Gm2(p.Gm2, p.CL, p.Cc, p.C1);
p.PM_act  = E.pm_from_wp2(p.wc_act, p.wp2_act);
if isfield(p,'Ro1') && isfield(p,'Ro2')
    p.A0_act = E.A0dB_from_ro(p.Gm1, p.Ro1, p.Gm2, p.Ro2);
end
end


%% ============================== TOOLS ====================================

function p = run_steps(p, steps)
%RUN_STEPS  p = f.run(p, {f.gm_design, f.currents, f.gain_budget, f.analyze});
%   Default chain is the four steps above in that order.
if nargin < 2 || isempty(steps)
    steps = {@gm_design, @currents, @gain_budget, @analyze};
end
for k = 1:numel(steps), p = steps{k}(p); end
end

function T = sweep(p, field, vals, steps, outs)
%SWEEP  Vary one field, run a chain, tabulate numeric outputs.
%   T = f.sweep(p, 'PM_target', 65:3:74, [], {'PM_target','Gm2','Istage2','Pcore'})
assert(isfield(p, field), 'sweep: p has no field "%s".', field);
R = zeros(numel(vals), numel(outs));
for k = 1:numel(vals)
    q = p; q.(field) = vals(k);
    q = run_steps(q, steps);
    for j = 1:numel(outs), R(k,j) = q.(outs{j}); end
end
T = array2table(R, 'VariableNames', outs);
end

function T = compare(cases, fields, labels)
%COMPARE  Side-by-side of any fields across any number of p structs.
%   T = f.compare({p0, p1}, {'Gm2','PM_act'}, {'before','after'})
%   labels must be valid MATLAB names (letters, digits, underscore).
n = numel(cases);
if nargin < 3, labels = arrayfun(@(k) sprintf('case%d',k), 1:n, 'UniformOutput', false); end
R = nan(numel(fields), n);
for j = 1:n
    for i = 1:numel(fields)
        if isfield(cases{j}, fields{i}), R(i,j) = cases{j}.(fields{i}); end
    end
end
T = array2table(R, 'RowNames', fields, 'VariableNames', labels);
end

function report(p)
%REPORT  Prints whichever of these fields exist. Add a row to show more.
%        {field, label, multiply-by, unit}
rows = {
 'UGF_target','UGF target',       1e-6,        'MHz'
 'PM_target', 'PM target',        1,           'deg'
 'Cc',        'Cc',               1e12,        'pF'
 'Gm1',       'Gm1 (M3a/b)',      1e6,         'uS'
 'Gm2',       'Gm2 (M9)',         1e3,         'mS'
 'Rc',        'Rc',               1,           'ohm'
 'RoProduct', 'Ro1*Ro2 needed',   1e-6,        'kohm^2'
 'Ro2_est',   'Ro2 est',          1e-3,        'kohm'
 'Ro1_req',   'Ro1 required',     1e-3,        'kohm'
 'Id3',       'Id3, input device', 1e6,         'uA'
 'Id45',      'I45 (M4/M5)',      1e6,         'uA'
 'Istage1',       'I, stage 1',      1e6,         'uA'
 'Istage2',       'I, stage 2',      1e6,         'uA'
 'Icore',     'Icore (no bias)',  1e6,         'uA'
 'Pcore',     'Pcore (no bias)',  1e3,         'mW'
 'UGF_act',   'UGF achieved',     1e-6,        'MHz'
 'wp2_act',   'fp2 achieved',     1e-6/(2*pi), 'MHz'
 'PM_act',    'PM achieved',      1,           'deg'
 'A0_act',    'A0 achieved',      1,           'dB'
};
for k = 1:size(rows,1)
    if isfield(p, rows{k,1})
        fprintf('%-18s %10.4g %s\n', rows{k,2}, p.(rows{k,1})*rows{k,3}, rows{k,4});
    end
end
end

function log_iteration(p, note, fields, file)
%LOG_ITERATION  Append chosen fields + a note to a CSV (design-flow evidence).
%   f.log(p, 'baseline')                         % default fields
%   f.log(p, 'raised Cc', {'Cc','Gm1','Gm2'})    % your own fields
%   Keep the same field list for a given file (header is written once).
if nargin < 3 || isempty(fields)
    fields = {'Cc','UGF_target','PM_target','Vov','Gm1','Gm2','Icore','Pcore','PM_act'};
end
if nargin < 4, file = 'iteration_log.csv'; end
isnew = ~(exist(file,'file') == 2);
fid = fopen(file, 'a');
if isnew, fprintf(fid, 'time,%s,note\n', strjoin(fields, ',')); end
vals = nan(1, numel(fields));
for i = 1:numel(fields)
    if isfield(p, fields{i}), vals(i) = p.(fields{i}); end
end
%fprintf(fid, '%s,%s,%s\n', datestr(now,'yyyy-mm-dd HH:MM'), ...
fprintf(fid, '%s,%s,%s\n', string(datetime('now'), 'yyyy-MM-dd HH:mm'), ...
    strjoin(arrayfun(@(v) sprintf('%g',v), vals, 'UniformOutput', false), ','), ...
    strrep(note, ',', ';'));
fclose(fid);
end
