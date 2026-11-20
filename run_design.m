%% RUN_DESIGN  Your workspace. Run one section at a time (Ctrl+Enter).
% Needs amp_lib.m in the same folder. Tweak functions live at the BOTTOM
% of this file (local functions in scripts need MATLAB R2016b or newer).
clear; clc; format short g
f = amp_lib();

%% 1. KNOBS
p = f.defaults();
p.Cc         = 1e-12;
p.UGF_target = 80.5e6;     % Hz
p.PM_target  = 70;         % deg

%% 2. CORE RUN (mostly-ideal macro-model): design direction, then check it back
base = {f.gm_design, f.currents, f.gain_budget, f.analyze};   % the default chain
p0 = f.run(p, base);
f.report(p0);

%% 3. EXAMPLE TWEAK A: see how C1 choices affect result
% Input circuit parameters (that we found earlier), output the impact on performance (specs)
% Add one step *after* analyze that overrides wp2_act/PM_act.
% fprintf("\nStep 3:\n")
% p_ideal = p;  p_ideal.C1 = 0;
% T = f.compare({f.run(p_ideal), f.run(p)}, {'Gm2','Istage2','Pcore','PM_act'}, {'ideal','withC1'})
% T = f.sweep(p, 'C1', [0 65e-15 100e-15 150e-15], [], {'C1','Gm2','Istage2','PM_act'})


%% 5. SWEEP (works on any chain, including ones with your tweaks)
% T = f.sweep(p, 'PM_target', [65 68 70 71 74], base, ...
%     {'PM_target','Gm2','Rc'})
% 
% %% 6. CALL ONE EQUATION DIRECTLY
% f.eq.wp2_from_pm(2*pi*80.5e6, 70) / (2*pi) * 1e-6        % MHz
% f.eq.pm_from_wp2(2*pi*80.5e6, 2*pi*300e6)                % deg
% 
% %% 7. HAND-OVERRIDE A VALUE AND RE-ANALYZE (e.g. rounded-up Gm2)
% r = p0;  r.Gm2 = 7.5e-3;
% r = f.analyze(r);
% f.report(r);

%% 8. LOG AN ITERATION
% Only uncomment if you mean to add to the log
%f.log(p0, 'adding current and power calcs: C1 = 100fF, I45/I3 = 2.25 (placeholder, must >2)')


%% ========================= TWEAKS (yours; keep at bottom) ================
% A tweak is just  p = tweak(p).  Read fields, overwrite fields, return p.

% function p = tweak_C1_analysis(p)
% % Replaces the ideal p2 with one that includes C1 (parasitic at Vout1).
% % reads: Gm2, Cc, CL, C1, wc_act    writes: wp2_act, PM_act
% p.wp2_act = p.Gm2*p.Cc / (p.C1*p.CL + p.Cc*(p.C1 + p.CL));
% p.PM_act  = 90 - atand(p.wc_act / p.wp2_act);
% end
% 
% function p = tweak_C1_design(p)
% % Gm2 needed to land wp2_req when C1 is present.
% % reads: wp2_req, Cc, CL, C1        writes: Gm2, Rc
% p.Gm2 = p.wp2_req * (p.C1*p.CL + p.Cc*(p.C1 + p.CL)) / p.Cc;
% p.Rc  = 1/p.Gm2;
% end
