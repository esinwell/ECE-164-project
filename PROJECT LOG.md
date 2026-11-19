```
I figure we can use this as a running document where we write what we have done so that we can see how the calculations evolve (so that writing the report later will be easier). 

We should put every entry under a heading with a date, and include whatever modifications we have made to our calculations/models (or at least include the git commit # so we can reference the changes).
```

# 11/18 - Eloise
* We were given equations in Lecture 10, slide 43, that matched the equations I had worked on deriving before. ( #TODO - ADD that initial document.) I am using these equations to govern initial calculations:
$$A_{dc}=A_{v1}\cdot A_{v2}=G_{m1}\cdot R_{o1}\cdot G_{m2}\cdot R_{o2}\\
\omega_{p1}\approx -\frac{1}{C_cG_{m2}R_{o2}R_{o1}}\\
\omega_{p2}=-\frac{G_{m2}}{C_2}\\
\omega_c=\omega_{p1}\cdot A_{dc}=\frac{G_{m1}}{C_c}\\
PM=90\deg-\arctan(\frac{\omega_c}{\omega_{p2}})$$
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
	* $G_m2=C_L\cdot \omega_{p2} = C_L\cdot \frac{\omega_c}{\tan( 90 - \text{PM\_target})}$ 
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
		* #TODO-NEXT Think about other poles in circuit & where they might be to get a better idea of PM budget? :(
			* In my circuit approximations, I approximated away C_1 (sum of parasitic caps to GND on vout1) and C_2 (same for vout2, pales compared to CL)
			* Other parasitics