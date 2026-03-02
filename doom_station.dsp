import("stdfaust.lib");

declare name "DOOM STATION v4.0";
declare author "ALH477 & Community Code Review";
declare license "MIT";
declare version "4.0.2";
declare description "Industrial/Argent Metal — Schroeder Reverb, Bandlimited Sat, Multiband Parallel, True M/S";

// ============================================================
//  UI LAYOUT
// ============================================================
master_ui(x) = vgroup("DOOM STATION [style:tgroup]", x);
era_ui(x)    = master_ui(vgroup("[0] Era", x));
drive_ui(x)  = master_ui(vgroup("[1] Drive & Grit", x));
mod_ui(x)    = master_ui(vgroup("[2] Modulation", x));
dyn_ui(x)    = master_ui(vgroup("[3] Dynamics", x));
space_ui(x)  = master_ui(vgroup("[4] Space", x));
tone_ui(x)   = master_ui(vgroup("[5] Master Tone", x));

// ---- Controls ----
gameStyle   = era_ui(nentry("[0] Era [style:menu{'2016/Eternal':0;'Dark Ages':1}]",
                0, 0, 1, 1)) : si.smoo;

drive       = drive_ui(vslider("[0] Master Drive [style:knob]", 0.6, 0, 1, 0.01)) : si.smoo;
noiseAmt    = drive_ui(vslider("[1] Noise Floor",  0.05, 0, 0.2, 0.01))            : si.smoo;
msWidth     = drive_ui(vslider("[2] Mid/Side Sat Balance", 0.5, 0, 1, 0.01))       : si.smoo;

phRate      = mod_ui(vslider("[0] Phaser Rate [unit:Hz]",  0.42, 0.05, 4, 0.001)) : si.smoo;
phDepth     = mod_ui(vslider("[1] Phaser Depth",           0.75, 0, 1, 0.01))      : si.smoo;
phFeedback  = mod_ui(vslider("[2] Phaser Feedback",        0.4,  0, 0.9, 0.01))    : si.smoo;
chorusAmt   = mod_ui(vslider("[3] Chorus Depth",           0.3,  0, 1, 0.01))      : si.smoo;

gateThresh  = dyn_ui(vslider("[0] Gate [unit:dB]",         -60, -99, -20, 1))
                : ba.db2linear : si.smoo;
thresh      = dyn_ui(vslider("[1] Comp Threshold [unit:dB]",-26, -50, -6, 0.5))    : si.smoo;
ratio       = dyn_ui(vslider("[2] Comp Ratio",              9,   2, 20, 0.1))       : si.smoo;
compAtk     = dyn_ui(vslider("[3] Comp Attack [unit:ms]",   8,   1, 100, 0.5))
                : *(0.001) : si.smoo;
compRel     = dyn_ui(vslider("[4] Comp Release [unit:ms]",  85,  10, 500, 1))
                : *(0.001) : si.smoo;

fdnMix      = space_ui(vslider("[0] FDN Reverb Mix",  0.35, 0, 0.95, 0.01)) : si.smoo;
fdnDecay    = space_ui(vslider("[1] Reverb Decay",    0.6,  0.1, 0.98, 0.01)) : si.smoo;
fdnDamp     = space_ui(vslider("[2] Reverb Damping",  3500, 500, 12000, 10))   : si.smoo;
haasWidth   = space_ui(vslider("[3] Stereo Width",    0.6,  0, 1, 0.01))      : si.smoo;

tilt        = tone_ui(vslider("[0] Tilt EQ [style:knob]", 0, -8, 8, 0.1))     : si.smoo;
loShelf     = tone_ui(vslider("[1] Lo Shelf [unit:dB]",   2, -12, 12, 0.1))    : si.smoo;
hiShelf     = tone_ui(vslider("[2] Hi Shelf [unit:dB]",   1, -12, 12, 0.1))    : si.smoo;
masterVol   = tone_ui(vslider("[3] Master Out [unit:dB]", -3, -30, 6, 0.1))
                : ba.db2linear : si.smoo;

// ============================================================
//  ERA BLEND
// ============================================================
eraPhMod  = 1.0 + gameStyle * 0.4;
eraRevMod = 1.0 + gameStyle * 0.25;

// ============================================================
//  UTILITY
// ============================================================
softClip(amt) = _ * (1 + amt) : ma.tanh;

tubeSat(amt) = _ <: (_ * (1+amt)) , ((_ * (1+amt)) : (_ <: _ - (_*_*_)/3))
               :> *(0.5) : ma.tanh;

// ============================================================
//  NOISE GATE
// ============================================================
doomGate = _ <: _, (an.amp_follower(0.005) > gateThresh : si.smoo) : *;

// ============================================================
//  BAND-LIMITED SATURATION
// ============================================================
bandlimitedSat(drv) =
    _ : *(1 + drv*12)
      : fi.lowpass(3, ma.SR * 0.4)
      : ma.tanh
      : fi.lowpass(3, ma.SR * 0.4)
      : /(1.1 + drv*2.5);

// ============================================================
//  MULTIBAND PARALLEL SATURATION
// ============================================================
xFreq1 = 120.0;
xFreq2 = 800.0;
xFreq3 = 4000.0;

lr4lp(f)     = fi.lowpass(2,f)  : fi.lowpass(2,f);
lr4hp(f)     = fi.highpass(2,f) : fi.highpass(2,f);
lr4bp(f1,f2) = lr4hp(f1) : lr4lp(f2);

bandSub  = lr4lp(xFreq1);
bandLo   = lr4bp(xFreq1, xFreq2);
bandHi   = lr4bp(xFreq2, xFreq3);
bandPres = lr4hp(xFreq3);

mbSat(drv) = (_ <:
    (bandSub  : tubeSat(drv*0.4)),
    (bandLo   : bandlimitedSat(drv*1.0)),
    (bandHi   : bandlimitedSat(drv*1.3) : *(1.15)),
    (bandPres : softClip(drv*0.6))
) :> *(0.25);

// ============================================================
//  STEREO PHASER
// ============================================================
apCoef(fc) =
    (tan(ma.PI * max(20.0, min(fc, ma.SR * 0.49)) / ma.SR) - 1.0) /
    (tan(ma.PI * max(20.0, min(fc, ma.SR * 0.49)) / ma.SR) + 1.0);

ap1(a) = _ <: *(a), mem :> + ~ *(0.0-a);

modAPchain(depth, lfoSig) =
    ap1(apCoef(300  + depth * 800  * lfoSig)) :
    ap1(apCoef(500  + depth * 700  * lfoSig)) :
    ap1(apCoef(700  + depth * 900  * lfoSig)) :
    ap1(apCoef(900  + depth * 600  * lfoSig)) :
    ap1(apCoef(1100 + depth * 500  * lfoSig)) :
    ap1(apCoef(1400 + depth * 400  * lfoSig));

phaserChannel(fbk, depth, lfoSig) =
    _ <: *(1 - depth*0.5),
         (_ : + ~ (modAPchain(depth * eraPhMod, lfoSig) : *(fbk)) : *(depth*0.5))
    :> _;

doomPhaserStereo(l, r) =
    (l : phaserChannel(phFeedback, phDepth, lfoL)),
    (r : phaserChannel(phFeedback, phDepth, lfoR))
with {
    lfoL = os.osc(phRate);
    lfoR = os.osc(phRate) * cos(ma.PI/2) + os.osc(phRate*1.001) * sin(ma.PI/2);
};

// ============================================================
//  CHORUS
// ============================================================
chorusDelay = int(25 * 0.001 * ma.SR);
chorusMod   = int(chorusAmt * 0.010 * ma.SR);

chorusL = _ <: _, de.fdelay(4096, chorusDelay + int(chorusMod * os.osc(0.31))) :> *(0.5);
chorusR = _ <: _, de.fdelay(4096, chorusDelay + int(chorusMod * os.osc(0.37))) :> *(0.5);

doomChorus(l, r) = (l : chorusL) , (r : chorusR);

// ============================================================
//  RMS COMPRESSOR
// ============================================================
doomComp =
    _ <: _,
         ((_ <: *)
          : si.smooth(ba.tau2pole(compAtk)) : sqrt
          : ba.linear2db
          : -(thresh)
          : *(1 - 1/ratio)
          : max(0)
          : (0 - _)
          : ba.db2linear
          : si.smooth(ba.tau2pole(compRel)))
    : *;

// ============================================================
//  SCHROEDER-MOORER REVERB
// ============================================================
d0 = 1481; d1 = 1867; d2 = 2243; d3 = 2791;
d4 = 3307; d5 = 3761; d6 = 4243; d7 = 4691;

lineDecay(len) = fdnDecay ^ (len / 4691.0);

schroederComb(len, decay) =
    + ~ (de.delay(8192, len) : fi.lowpass(1, fdnDamp) : *(decay));

schroederAP(len) = fi.allpass_comb(len, len, 0.7);

fdnReverbStereo(l, r) =
    (l : schroederComb(d0, lineDecay(d0))
       : schroederComb(d1, lineDecay(d1))
       : schroederComb(d2, lineDecay(d2))
       : schroederComb(d3, lineDecay(d3))
       : schroederAP(347) : schroederAP(113))
    ,
    (r : schroederComb(d4, lineDecay(d4))
       : schroederComb(d5, lineDecay(d5))
       : schroederComb(d6, lineDecay(d6))
       : schroederComb(d7, lineDecay(d7))
       : schroederAP(353) : schroederAP(127));

reverbWet(l, r) =
    (fdnReverbStereo(l, r) : (*(min(0.95, fdnMix * eraRevMod)),
                               *(min(0.95, fdnMix * eraRevMod)))),
    (l * (1 - fdnMix), r * (1 - fdnMix))
    :> (_, _);

// ============================================================
//  DC BLOCKING
// ============================================================
dcBlock = fi.highpass(1, 20);

// ============================================================
//  MASTER TONE STACK
// ============================================================
masterEQ =
    fi.highshelf(1, 1000, tilt)    :
    fi.lowshelf(1, 1000, (0-tilt)) :
    fi.lowshelf(2, 80, loShelf)    :
    fi.highshelf(2, 8000, hiShelf);

// ============================================================
//  TRUE M/S SATURATION
// ============================================================
msEncode(l, r) = (l + r) * 0.5 , (l - r) * 0.5;
msDecode(m, s) = m + s , m - s;

msSaturate(l, r) =
    msEncode(l, r) :
    ((bandlimitedSat(drive * (1 - msWidth*0.3))) ,
     (bandlimitedSat(drive * msWidth))) :
    msDecode;

// ============================================================
//  SAFETY LIMITER
// ============================================================
brickWall = softClip(0.15) : min(0.98) : max(-0.98);

// ============================================================
//  NOISE INJECTION
// ============================================================
addNoise = _ + (no.noise * noiseAmt * 0.25);

// ============================================================
//  HAAS STEREO WIDENER
// ============================================================
haasDelay = int(18.0 * 0.001 * ma.SR);

// Takes a mono signal, returns stereo pair (l, r)
haasWiden = _ <: _, (de.delay(4096, haasDelay) : *(haasWidth));

// ============================================================
//  MAIN SIGNAL FLOW
// ============================================================
monoCore =
    doomGate :
    addNoise :
    mbSat(drive) :
    doomComp :
    dcBlock;

// stereoCore takes (l, r) — fed by haasWiden which splits mono to stereo
stereoCore =
    doomPhaserStereo :
    doomChorus :
    msSaturate :
    reverbWet :
    ((masterEQ) , (masterEQ)) :
    ((brickWall) , (brickWall)) :
    ((*(masterVol)) , (*(masterVol)));

process = monoCore : haasWiden : stereoCore;
