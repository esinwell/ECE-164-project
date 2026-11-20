```
I figure we can use this as a running document where we write what we have done so that we can see how the calculations evolve (so that writing the report later will be easier). 

We should put every entry under a heading with a date, and include whatever modifications we have made to our calculations/models (or at least include the git commit # so we can reference the changes).
```

# 11/18 - Eloise
* We were given equations in Lecture 10, slide 43, that matched the equations I had worked on deriving before. ( #TODO - ADD that initial document.) I am using these equations to govern initial calculations:

$$
A_{dc}=A_{v1}\cdot A_{v2}=G_{m1}\cdot R_{o1}\cdot G_{m2}\cdot R_{o2}
$$

$$
\omega_{p1}\approx -\frac{1}{C_cG_{m2}R_{o2}R_{o1}}
$$

$$
\omega_{p2}=-\frac{G_{m2}}{C_2}
$$

$$
\omega_c=\omega_{p1}\cdot A_{dc}=\frac{G_{m1}}{C_c}
$$

$$
PM=90\deg-\arctan(\frac{\omega_c}{\omega_{p2}})
$$

* From these equations, I see the following knob possibilities:
	* C_c: as discussed in class, we know this is free
	* Gms
	* UGF w_c
	* Phase margin PM
* We know we can use C_c, and it will be helpful to use UGF and PM as these are target specs we need to meet (so, design around them). We can see that if these values are 'fixed,' the Gms actually depend on them, so these will not be independent knobs.

### Calculation 1 - Initial calculations
* Constants: $C_L=5pF$
* Independent/first-order knobs: $UGF, PM, C_c$
	* Build margins into UGF and PM. As the initial rough guess, I will use the following values for calculations:
		* `UGF_target = UGF_spec * 1.15` = 80.5MHz
			* $\rightarrow \omega_c = 2\cdot \pi \cdot$`UGF_target`
		* `PM_target = PM_spec + 10` = $75\degree$
	* For $C_c$, prof said in class that typical values are 100fF - 10pF. I will choose 1pF.
* Direct results of independent knobs thru above equations:
	* $G_{m1}=C_c\cdot \omega_c$
	* $G_{m2}=C_L\cdot \omega_{p2} = C_L\cdot \frac{\omega_c}{\tan( 90 - \text{PMtarget})}$ 
* Indirect results of independent knobs:
	* $R_c = \frac{1}{G_{m2}}$ for the nulling resistor (zero $\rightarrow +\infty$)
	* $R_{o1}\cdot R_{o2}$, if using the exact DC gain spec of 70dB (in unitless form below):
		* $R_{o1}\cdot R_{o2}=\frac{A_{v0}}{G_{m1}\cdot G_{m2}}$ 

Git commit: 03f91e7
Output:
```
BASED ON KNOBS Cc, UGF, PM:  
Gm1 = 5.0580e-04 S  
Gm2 = 9.4383e-03 S  
fp2 = 3.0043e+08 Hz  
Rc = 106 ohm  
Ro1*Ro2 needed = 6.62e+08 ohm^2  
Id2 est = 708 uA, budget = 1389 uA total
```
#### Analysis
* $G_{m2}/G_{m1} \approx 18.6$ which seems very asymmetrical, and we can see that current consumption of stage 2 is relatively huge. 
	* Try tightening margin on PM, as this is where Gm2 gets its freedom?
		* Think about other poles in circuit & where they might be to get a better idea of PM budget? :(
			* In my circuit approximations, I approximated away C_1 (sum of parasitic caps to GND on vout1) and C_2 (same for vout2, pales compared to CL)
			* Other parasitics

# 11/19 - Eloise
- Prof said that we should just finish 'frequency planning' and have *a* working design and only work on optimizing later. I do want to try refining GM2 a little bit but won't go too far.
	- I am going to factor back in one set of capacitances--the ones I called C_1. I feel safe saying C_2 gets dominated by C_L, but C_1 doesn't have another larger capacitor on that node so we should look back at it. 
		- C_1 will really just be C_gs of M9 (there are some other C_gds but in saturation we consider those almost 0)
		- Calcs
			- $\omega_{p1} \approx \frac{1}{C_cA_{v2}R_{o1}+C_1R_{o1}}$
				- $C_cA_{v2}R_{o2}$ from my calcs is like $10^{-12} \cdot 9.44\cdot 10^{-3} \cdot 6.62 \cdot 10^{8}$ 
				- Don't know what Ro2 alone is, but use $\approx \sqrt{6.62\cdot 10^8}$, and $C_1 \approx C_{gs9}$ which is going to be on the order of femtofarads, so that C1 x Ro1 term is going to be super negligible compared to the other one. *Disregard impact of C_1 on wp1*.
			- $\omega_{p2} \approx \frac{G_{m2}C_c}{C_LC_c\cdot C_1(C_L+C_C)}$. **Approximating C_1 = 100fF**, see that wp2 moves down to 268MHz from 300MHz. Subbing into PM equation with wc = 80.5MHz (the 15% margin), we see PM go from 75 -> ~73.3. 
				- There will be other poles, but this will probably be the most significant (relatively high resistance of Ro1) and it was not very much. From this I'm going to say to drop down the phase margin target from 75 to 70 (5 degree cushion with C1 explicitly accounted for)
	- Running again with **phase margin target = 70** and C1 factored into wp2 (affecting GM2) (and Ro2 estimated by Gm2=2ID/Vov and Ro2=1/lambdaID)
		- (See iteration_log.csv, 2026-11-19 19:09 'new baseline')
		- GM2/GM1 is better but still not great--looks like it's not worth it to keep refining now.
(Note: I've completely refactored the calculation script at this point and will be moving forward with this framework.)
```
UGF target 80.5 MHz  
PM target 70 deg  
Cc 1 pF  
gm1 (M3a/b) 505.8 uS  
gm2 (M9) 7.782 mS  
Rc 128.5 ohm  
Ro1*Ro2 needed 803.4 kohm^2  
Ro2 est 8.567 kohm  
Ro1 required 93.78 kohm  
UGF achieved 80.5 MHz  
fp2 achieved 221.2 MHz  
PM achieved 70 deg
```
### Onto currents
* Stage 1 current: when at its DC operating point (vid = 0), we will draw $I_{tail12}=2I_3$ through the M3s, and $2I_{45}$ through the folded cascode. Overall stage current is $I_{stage1}=2I_3+2I_{45}$. 
	* I3: get from $g_{m3}V_{ov}/2$, and we know gm3 is Gm1
	* I45: We also know that, when the differential input is fully steered (worst case: M3b carries entire $I_{tail12}$), $I_{7a}=I{45}=I_{7b}\rightarrow I_{6b}=I_{45}-2I_3$ and I6 can't be <=0 (things will go to triode etc). Probably should actually be somewhat higher than 0 to avoid getting near triode--choose $I_{45} = 2.25\cdot I_3$ **for now, can drop closer to 2 later**?
* Stage 2 current: same thru M8 and M9, get from $g_{m9}V_{ov}/2$ and we know gm9 is Gm2

Added these calculations to my script to get (nothing new from last time, just adding info)
(see iteration_log 2026-11-19 20:34)
``` 
Id3, input device 37.93 uA  
I45 (M4/M5) 85.35 uA  
I, stage 1 246.6 uA  
I, stage 2 583.7 uA  
Icore (no bias) 830.2 uA  
Pcore (no bias) 1.494 mW  
```
note that power consumption is ~59% of total budget 2.5mW. Not sure how good or bad that is--how much would biasing reasonably consume?
Tweaks to look at:
* We haven't considered gain much, just used bare minimum to constrain the overall Ro1 x Ro2. Ro2 is simpler: $\approx r_{o8}||r_{o9}$. We did Gm2, Vov -> Istage2, which is also I8 = I9 -> r_o8,9 = 1/(lambda * I8,9) so `Ro2_est` is half ro8,9 (with lambda approximated as 0.1). Because we know transconductance of that stage as well, the gain of stage 2 is pretty fixed (aside from needing to figure out real lambda). Gain of stage 1 has much more flexibility--we found the *minimum* Ro1 needed to meet the *minimum* gain spec, but this `Ro1 required` has no actual relationship to the real Ro1 we will see.
* C1 = 100fF is a guess
* 5 degree cushion on PM is a guess constraint
* 15% margin on UGF is a guess constraint (cutting this down will probably save power, as it is proportional to Gm1 ie proportional to current)
* I45/I3 = 2.25 is a guess constraint
* Lambda = 0.1 is a guess
* Vov = 150mV will probably need to be tweaked

Going to go to cadence now (finally) #TODO-NEXT