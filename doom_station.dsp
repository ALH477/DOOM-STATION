import("stdfaust.lib");
declare name "DOOM STATION v5.4";
declare author "ALH477 & Community Code Review & Grok & Claude & Gemini";
declare license "MIT";
declare version "5.4.0";
declare description "Industrial/Argent Metal — FDN Reverb, Bandlimited Sat, Multiband Parallel, True M/S, Production Fixes";
// ============================================================
// UI LAYOUT
// ============================================================
master_ui(x) = vgroup("DOOM STATION [style:tgroup]", x);
era_ui(x) = master_ui(vgroup("[0] Era", x));
drive_ui(x) = master_ui(vgroup("[1] Drive & Grit", x));
mod_ui(x) = master_ui(vgroup("[2] Modulation", x));
dyn_ui(x) = master_ui(vgroup("[3] Dynamics", x));
space_ui(x) = master_ui(vgroup("[4] Space", x));
tone_ui(x) = master_ui(vgroup("[5] Master Tone", x));
// ---- Controls ----
gameStyle = era_ui(nentry("[0] Era [style:menu{'2016/Eternal':0;'Dark Ages':1}]",
                0, 0, 1, 1)) : si.smoo;
inputGain = drive_ui(vslider("[0] Input Gain [unit:dB]", 0, -24, 24, 0.1)) : ba.db2linear : si.smoo;
drive = drive_ui(vslider("[1] Master Drive [style:knob]", 0.6, 0, 1, 0.01)) : si.smoo;
noiseAmt = drive_ui(vslider("[2] Noise Floor", 0.05, 0, 0.2, 0.01)) : si.smoo;
msWidth = drive_ui(vslider("[3] Mid/Side Sat Balance", 0.5, 0, 1, 0.01)) : si.smoo;
phRate = mod_ui(vslider("[0] Phaser Rate [unit:Hz]", 0.42, 0.05, 4, 0.001)) : si.smoo;
phDepth = mod_ui(vslider("[1] Phaser Depth", 0.75, 0, 1, 0.01)) : si.smoo;
phFeedback = mod_ui(vslider("[2] Phaser Feedback", 0.4, 0, 0.9, 0.01)) : si.smoo;
phCenter = mod_ui(vslider("[3] Phaser Center [unit:Hz]", 800, 100, 5000, 10)) : si.smoo;
chorusAmt = mod_ui(vslider("[4] Chorus Depth", 0.3, 0, 1, 0.01)) : si.smoo;
gateThresh = dyn_ui(vslider("[0] Gate Open [unit:dB]", -60, -99, -20, 1)) : si.smoo;
gateClose = dyn_ui(vslider("[1] Gate Close [unit:dB]", -66, -99, -20, 1)) : si.smoo;
gateHold = dyn_ui(vslider("[2] Gate Hold [unit:ms]", 50, 0, 500, 1)) : *(0.001) : si.smoo;
thresh = dyn_ui(vslider("[3] Comp Threshold [unit:dB]",-26, -50, -6, 0.5)) : si.smoo;
ratio = dyn_ui(vslider("[4] Comp Ratio", 9, 2, 20, 0.1)) : si.smoo;
compAtk = dyn_ui(vslider("[5] Comp Attack [unit:ms]", 8, 1, 100, 0.5)) : *(0.001) : si.smoo;
compRel = dyn_ui(vslider("[6] Comp Release [unit:ms]", 85, 10, 500, 1)) : *(0.001) : si.smoo;
compMakeup = dyn_ui(vslider("[7] Comp Makeup [unit:dB]", 0, -24, 24, 0.1)) : ba.db2linear : si.smoo;
fdnMix = space_ui(vslider("[0] Reverb Mix", 0.35, 0, 1, 0.01)) : si.smoo;
fdnDecay = space_ui(vslider("[1] Reverb Decay", 0.6, 0.1, 0.98, 0.01)) : si.smoo;
fdnDamp = space_ui(vslider("[2] Reverb Damping", 3500, 500, 12000, 10)) : si.smoo;
stereoWidth = space_ui(vslider("[3] Stereo Width", 1.0, 0, 2, 0.01)) : si.smoo;
tilt = tone_ui(vslider("[0] Tilt EQ [style:knob]", 0, -8, 8, 0.1)) : si.smoo;
loShelf = tone_ui(vslider("[1] Lo Shelf [unit:dB]", 2, -12, 12, 0.1)) : si.smoo;
hiShelf = tone_ui(vslider("[2] Hi Shelf [unit:dB]", 1, -12, 12, 0.1)) : si.smoo;
masterMix = tone_ui(vslider("[3] Mix", 1.0, 0, 1, 0.01)) : si.smoo;
masterVol = tone_ui(vslider("[4] Master Out [unit:dB]", -3, -30, 6, 0.1)) : ba.db2linear : si.smoo;
// ============================================================
// ERA BLEND (Deeper Morphing)
// — Fixed: ba.linear_interp does not exist in stdfaust;
//   replaced with equivalent inline arithmetic.
// ============================================================
eraPhMod    = 1.0 + gameStyle * 0.4;
eraRevMod   = 1.0 + gameStyle * 0.25;
eraSatMod   = 1.0 + gameStyle * 0.3;   // Eternal: tight, Dark: more harmonic
eraDampMod  = 1.0 - gameStyle * 0.3;   // Eternal: bright, Dark: darker
eraWidthMod = 1.0 - gameStyle * 0.2;   // Eternal: wide,  Dark: narrower
eraEqTilt   = gameStyle * -2.0;        // Eternal: neutral, Dark: darker tilt
// ============================================================
// UTILITY
// ============================================================
softClip(amt) = _ * (1 + amt) : ma.tanh;
tubeSat(amt) = _ <: (_ * (1+amt)) , ((_ * (1+amt)) : (_ <: _ - (_*_*_)/3)) :> *(0.5) : ma.tanh;
// ============================================================
// DC BLOCKING
// ============================================================
dcBlock = fi.highpass(1, 20);
// ============================================================
// NOISE GATE WITH HYSTERESIS AND HOLD
// — Fixed: removed illegal rec{} block and bare ' prime-on-identifier syntax.
//   Rewritten with proper ~ (_, _) two-state feedback topology.
//   stateUpdate :: (gate_prev, hold_prev, env_db) -> (gate_next, hold_next)
//   ~ (_, _) feeds the two outputs back to the first two inputs each tick.
//   : (_, !) drops hold_next from the output, leaving only the gate CV.
// ============================================================
doomGate = _ <: _, (abs : an.amp_follower(0.005) : ba.linear2db : gateStateMachine : si.smoo) : *
with {
    gateStateMachine = stateUpdate ~ (_, _) : (_, !)
    with {
        stateUpdate(gate_p, hold_p, env) = gate_n, hold_n
        with {
            thr    = ba.if(gate_p > 0.5, gateClose, gateThresh);
            above  = env > thr;
            hold_n = ba.if(above,
                           float(ba.sec2samp(gateHold)),
                           max(0.0, hold_p - 1.0));
            gate_n = ba.if(above | (hold_p > 0.0), 1.0, 0.0);
        };
    };
};
// ============================================================
// BAND-LIMITED SATURATION
// ============================================================
bandlimitedSat(drv) =
    _ : *(1 + drv*12)
      : fi.lowpass(3, ma.SR * 0.4)
      : ma.tanh
      : fi.lowpass(3, ma.SR * 0.4)
      : /(1.1 + drv*2.5);
// ============================================================
// MULTIBAND PARALLEL SATURATION WITH PER-BAND DC BLOCK
// ============================================================
xFreq1 = 120.0;
xFreq2 = 800.0;
xFreq3 = 4000.0;
lr4lp(f)     = fi.lowpass(2,f)  : fi.lowpass(2,f);
lr4hp(f)     = fi.highpass(2,f) : fi.highpass(2,f);
lr4bp(f1,f2) = lr4hp(f1) : lr4lp(f2);
bandSub  = lr4lp(xFreq1)         : dcBlock : tubeSat(drive*0.4  * eraSatMod);
bandLo   = lr4bp(xFreq1, xFreq2) : dcBlock : bandlimitedSat(drive*1.0  * eraSatMod);
bandHi   = lr4bp(xFreq2, xFreq3) : dcBlock : bandlimitedSat(drive*1.3  * eraSatMod) : *(1.15);
bandPres = lr4hp(xFreq3)         : dcBlock : softClip(drive*0.6 * eraSatMod);
mbSat(drv) = (_ <:
    bandSub,
    bandLo,
    bandHi,
    bandPres
) :> *(0.25);
// ============================================================
// STEREO PHASER WITH CENTER FREQ
// ============================================================
apCoef(fc) =
    (tan(ma.PI * max(20.0, min(fc, ma.SR * 0.49)) / ma.SR) - 1.0) /
    (tan(ma.PI * max(20.0, min(fc, ma.SR * 0.49)) / ma.SR) + 1.0);
ap1(a) = _ <: *(a), mem :> + ~ *(0.0-a);
modAPchain(depth, lfoSig, center) =
    ap1(apCoef(center * 0.375 + depth * center * 1.0   * lfoSig)) :
    ap1(apCoef(center * 0.625 + depth * center * 0.875 * lfoSig)) :
    ap1(apCoef(center * 0.875 + depth * center * 1.125 * lfoSig)) :
    ap1(apCoef(center * 1.125 + depth * center * 0.75  * lfoSig)) :
    ap1(apCoef(center * 1.375 + depth * center * 0.625 * lfoSig)) :
    ap1(apCoef(center * 1.75  + depth * center * 0.5   * lfoSig));
phaserChannel(fbk, depth, lfoSig, center) =
    _ <: *(1 - depth*0.5),
         (_ : + ~ (modAPchain(depth * eraPhMod, lfoSig, center) : *(fbk)) : *(depth*0.5))
    :> _;
doomPhaserStereo(l, r) =
    (l : phaserChannel(phFeedback, phDepth, lfoL, phCenter)),
    (r : phaserChannel(phFeedback, phDepth, lfoR, phCenter))
with {
    lfoL = os.osc(phRate);
    lfoR = os.osc(phRate) * cos(ma.PI/2) + os.osc(phRate*1.001) * sin(ma.PI/2);
};
// ============================================================
// CHORUS
// ============================================================
chorusDelay = int(25 * 0.001 * ma.SR);
chorusMod   = int(chorusAmt * 0.010 * ma.SR);
chorusL = _ <: _, de.fdelay(4096, chorusDelay + int(chorusMod * os.osc(0.31))) :> *(0.5);
chorusR = _ <: _, de.fdelay(4096, chorusDelay + int(chorusMod * os.osc(0.37))) :> *(0.5);
doomChorus(l, r) = (l : chorusL) , (r : chorusR);
// ============================================================
// RMS COMPRESSOR WITH ASYMMETRIC ENVELOPE
// — Fixed: an.smooth_ud does not exist in stdfaust.
//   Replaced with dual fi.pole smoothing blended 50/50.
//   Attack pole tightens transients; release pole sustains gain reduction tail.
// ============================================================
doomComp =
    _ <: _,
         (rmsDetect : raw_gr : compEnv : ba.db2linear : *(compMakeup))
    : *
with {
    rmsWindow = 0.050;
    rmsDetect = _ <: * : an.rms_envelope_rect(rmsWindow) : ba.linear2db;
    raw_gr    = -(thresh) : max(0) : *(1.0 - 1.0/max(1.0001, ratio)) : *(0.0-1.0);
    compEnv   = _ <: fi.pole(ba.tau2pole(compAtk)), fi.pole(ba.tau2pole(compRel)) :> *(0.5);
};
// ============================================================
// 8x8 HADAMARD FDN REVERB
// — Fixed: fdnDelays as a named par() block is not referenceable
//   as a symbol. Replaced with a scalar function and direct literals.
// ============================================================

// Delay lengths as a scalar selector function — returns a single int
fdnLen(i) = ba.take(i+1, (1427, 1621, 1861, 2053, 2293, 2539, 2797, 3061)) * (ma.SR/44100.0);

// Decay attenuation per delay line
fdnAtten(i) = fdnDecay ^ (fdnLen(i) / fdnLen(7));

hadamardMix8 = _,_,_,_,_,_,_,_ : s1 : s2 : s3 : par(i, 8, *(1.0/sqrt(8.0)))
with {
    s1(a,b,c,d,e,f,g,h) = a+b, a-b, c+d, c-d, e+f, e-f, g+h, g-h;
    s2(a,b,c,d,e,f,g,h) = a+c, b+d, a-c, b-d, e+g, f+h, e-g, f-h;
    s3(a,b,c,d,e,f,g,h) = a+e, b+f, c+g, d+h, a-e, b-f, c-g, d-h;
};

delays = par(i, 8, de.delay(8192, int(fdnLen(i))));
attens = par(i, 8, fi.lowpass(1, fdnDamp * eraDampMod) : *(fdnAtten(i)));

// Extract channels 0 and 4 from an 8-bus using explicit discard
pick0and4(a,b,c,d,e,f,g,h) = a, e;

fdnReverb =
    (_ <: par(i, 8, _)) :
    par(i, 8, +) ~ (delays : attens : hadamardMix8) :
    pick0and4;

fdnReverbStereo(l, r) = (l + r) * 0.5 : fdnReverb;

reverbWet(l, r) =
    (fdnReverbStereo(l, r) : (*(min(1.0, fdnMix * eraRevMod)), *(min(1.0, fdnMix * eraRevMod)))),
    (l * (1 - fdnMix), r * (1 - fdnMix))
    :> (_, _);
// ============================================================
// MASTER TONE STACK WITH ERA TILT
// ============================================================
masterEQ =
    fi.highshelf(1, 1000, tilt + eraEqTilt) :
    fi.lowshelf(1, 1000, (0 - tilt - eraEqTilt)) :
    fi.lowshelf(2, 80, loShelf) :
    fi.highshelf(2, 8000, hiShelf);
// ============================================================
// TRUE M/S SATURATION
// ============================================================
msEncode(l, r) = (l + r) * 0.5 , (l - r) * 0.5;
msDecode(m, s) = m + s , m - s;
msSaturate(l, r) =
    msEncode(l, r) :
    (bandlimitedSat(drive * (1 - msWidth*0.3) * eraSatMod),
     bandlimitedSat(drive * msWidth * eraSatMod)) :
    msDecode;
// ============================================================
// LOOKAHEAD LIMITER
// ============================================================
lookaheadMs    = 2.0;
lookaheadDelay = int(lookaheadMs * 0.001 * ma.SR);
brickWallLimiter = _ <: de.delay(8192, lookaheadDelay), (abs : an.amp_follower_ud(0.001, 0.1) : ba.linear2db : (-0.1 - _) : min(0) : ba.db2linear) : * : ma.tanh : min(0.98) : max(-0.98);
// ============================================================
// NOISE INJECTION
// ============================================================
addNoise = _ + (no.noise * noiseAmt * 0.25);
// ============================================================
// M/S STEREO WIDENER (Safer than Haas)
// ============================================================
msWidener(l, r) = msEncode(l, r) : (_, *(stereoWidth * eraWidthMod)) : msDecode;
// ============================================================
// MAIN SIGNAL FLOW
// ============================================================
monoCore =
    *(inputGain) :
    doomGate :
    addNoise :
    mbSat(drive) :
    doomComp :
    dcBlock;

phaserStage  = _ , _ : doomPhaserStereo;
chorusStage  = _ , _ : doomChorus;
msSatStage   = _ , _ : msSaturate;
reverbStage  = _ , _ : reverbWet;
eqStage      = masterEQ , masterEQ;
widenerStage = _ , _ : msWidener;
limiterStage = brickWallLimiter , brickWallLimiter;
volStage     = *(masterVol) , *(masterVol);

stereoCore =
    phaserStage :
    chorusStage :
    msSatStage :
    reverbStage :
    eqStage :
    widenerStage :
    limiterStage :
    volStage;

dryWetMix(dryL, dryR, wetL, wetR) =
    dryL * (1 - masterMix) + wetL * masterMix,
    dryR * (1 - masterMix) + wetR * masterMix;

process =
    _ <:
        (_ <: _, _),
        (_ : monoCore : (_ <: _, _) : stereoCore)
    : dryWetMix;
