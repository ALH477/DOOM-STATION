# DOOM STATION
**v5.4.0**  
**Industrial / Argent Metal — Faust DSP Audio Effect**  
**MIT License**

---

## ⚠ SAFETY NOTICE ⚠
No demons were harmed during the development of this effect. They were band-limited, saturated, compressed, gated, convolved through an 8×8 Hadamard matrix, and output at −0.1 dBFS. Audiologically speaking, this is worse.

## Overview
DOOM STATION is a high-fidelity Faust DSP effect unit designed for industrial, metal, and cinematic sound design. It models the aggressive, spatially dense character of music produced for id Software's DOOM franchise — but functions as a fully general-purpose effect chain applicable to any source material demanding weight, width, and controlled destruction.

**Signal path summary:**  
Mono input → input gain → hysteresis noise gate → multiband parallel saturation → RMS compression → DC block → stereo phaser → chorus → M/S saturation → FDN reverb → tilt EQ → M/S widening → lookahead limiting → master volume → dry/wet mix → stereo output.

## Acknowledgements
This effect exists because some people made art that permanently rewired the reward circuits of an entire generation of listeners. DOOM STATION is dedicated to:

- **id Software** — for building the engine, the world, and the reason any of us wanted to make loud sounds in the first place. The Argent Tower doesn't process itself.
- **Mick Gordon** — for demonstrating that a synthesizer, a guitar, and an unhealthy obsession with sub-bass could together constitute a theological experience. The multiband saturation architecture in this effect is a direct spiritual descendant of his work.
- **Finishing Move Inc.** — for *The Dark Ages* OST and proving that the brutality was not a fluke. Industrial music with that level of compositional rigor deserves tools that can keep up.

Technical foundations by ALH477, community code review, Grok, and Claude.

## Signal Chain Architecture

1. **Input Stage**  
   Mono input with ±24 dB gain trim (`inputGain`). Signal is smoothed via `si.smoo` to prevent zipper noise on parameter changes.

2. **Noise Gate**  
   Hysteresis gate with independent open/close thresholds and a hold timer. Implemented as a two-state feedback machine using Faust's `~ (_, _)` topology — no illegal `rec{}` blocks. The hold counter prevents chattering on sustained transients.  
   - Open threshold: configurable from −99 to −20 dBFS  
   - Close threshold: independent, typically set below open threshold  
   - Hold time: 0–500 ms, sample-accurate countdown

3. **Multiband Parallel Saturation**  
   Four-band Linkwitz-Riley (LR4) crossover network feeding parallel saturation processors. Each band has its own DC block before the saturator to prevent DC offset accumulation.

   | Parameter   | Range          | Default              | Description                                      |
   |-------------|----------------|----------------------|--------------------------------------------------|
   | bandSub     | < 120 Hz       | tubeSat ×0.4         | Tube-style saturation, preserves low-end body    |
   | bandLo      | 120–800 Hz     | bandlimitedSat ×1.0  | Midrange grit with aliasing suppression          |
   | bandHi      | 800–4k Hz      | bandlimitedSat ×1.3  | Upper-mid aggression, +1.15 gain trim            |
   | bandPres    | > 4k Hz        | softClip ×0.6        | Air-band soft saturation, avoids harshness       |

   *Band-limited saturation* applies a 3rd-order lowpass at 0.4× Nyquist before and after `ma.tanh` to suppress harmonic aliasing — a common problem with naive waveshapers at high drive settings.

4. **RMS Compressor**  
   Feed-forward RMS compressor with a 50 ms RMS detection window. Gain reduction is computed in dB domain and smoothed with an asymmetric dual-pole envelope (fast attack, slow release). Makeup gain applied post-envelope.  
   - Threshold: −50 to −6 dBFS  
   - Ratio: 2:1 to 20:1  
   - Attack: 1–100 ms  
   - Release: 10–500 ms  
   - Makeup gain: ±24 dB

5. **Stereo Phaser**  
   Six-stage allpass phaser per channel with configurable center frequency, depth, and feedback. LFO phases are offset by 90° between L and R for stereo movement. Era mode scales the LFO modulation depth.

6. **Chorus**  
   Simple comb-based chorus using fractional delay lines (`de.fdelay`). Left and right channels use different LFO rates (0.31 Hz / 0.37 Hz) to avoid mono collapse.

7. **True M/S Saturation**  
   Encodes the stereo signal to Mid/Side, applies independent band-limited saturation to M and S channels with the `msWidth` control weighting saturation intensity between them, then decodes back to L/R. This produces asymmetric harmonic distortion between the center image and the stereo field.

8. **8×8 Hadamard FDN Reverb**  
   A Feedback Delay Network with eight delay lines and an 8×8 Hadamard mixing matrix. The Hadamard transform provides maximum energy diffusion across the feedback paths with no energy loss (it is an orthogonal matrix).  
   Delay line lengths (at 44.1 kHz): 1427, 1621, 1861, 2053, 2293, 2539, 2797, 3061 samples — prime-adjacent values chosen for minimal comb filtering.  
   The Hadamard matrix is implemented as three stages of butterfly operations (Walsh-Hadamard decomposition) using named-argument pattern matching, avoiding Faust's `ro.hadamard` primitive which generates malformed route expressions in current compiler versions.  
   L/R taps are taken from channels 0 and 4 of the 8-bus — these are maximally decorrelated positions in a Hadamard matrix, ensuring a wide, diffuse stereo image with no phase cancellation.

9. **Master EQ**  
   Tilt EQ (symmetric shelf pair around 1 kHz) plus independent lo-shelf (80 Hz) and hi-shelf (8 kHz). Era mode adds an additional tilt offset (0 dB in 2016/Eternal, −2 dB in Dark Ages) for stylistically appropriate spectral balance.

10. **M/S Stereo Widener**  
    Second M/S encode/decode stage. The Side channel is scaled by `stereoWidth` × eraWidthMod before decoding. Width > 1.0 expands the stereo field; Width < 1.0 narrows it toward mono. Safer than Haas-effect widening, which causes mono incompatibility.

11. **Lookahead Limiter**  
    2 ms lookahead delay with an amplitude follower-based gain control. Output is hard-clipped to ±0.98 via `ma.tanh` then min/max. Prevents intersample peaks from exceeding 0 dBFS.

## Era Mode
The Era selector morphs multiple processing parameters simultaneously between two stylistic presets:

| Parameter          | 2016 / Eternal          | Dark Ages                  |
|--------------------|-------------------------|----------------------------|
| Saturation         | Tight (×1.0)            | More harmonic (×1.3)       |
| Reverb Mix         | Baseline                | +25% send level            |
| Reverb Damping     | Bright                  | Darker (×0.7 cutoff)       |
| Phaser Depth       | Standard                | +40% LFO modulation        |
| Stereo Width       | Wide (×1.0)             | Narrower (×0.8)            |
| EQ Tilt            | Neutral (0 dB)          | −2 dB dark tilt            |

## Parameter Reference

### Drive & Grit
| Parameter          | Range             | Default | Description                                      |
|--------------------|-------------------|---------|--------------------------------------------------|
| Input Gain         | −24 to +24 dB     | 0 dB    | Pre-processing input trim                        |
| Master Drive       | 0.0 – 1.0         | 0.6     | Global saturation intensity across all bands     |
| Noise Floor        | 0.0 – 0.2         | 0.05    | Analog-style noise injection amplitude           |
| Mid/Side Sat Bal   | 0.0 – 1.0         | 0.5     | Saturation balance between M and S channels      |

### Modulation
| Parameter       | Range          | Default   | Description                              |
|-----------------|----------------|-----------|------------------------------------------|
| Phaser Rate     | 0.05 – 4 Hz    | 0.42 Hz   | LFO speed for allpass modulation         |
| Phaser Depth    | 0.0 – 1.0      | 0.75      | Allpass modulation depth                 |
| Phaser Feedback | 0.0 – 0.9      | 0.4       | Phaser feedback gain (resonance)         |
| Phaser Center   | 100 – 5000 Hz  | 800 Hz    | Center frequency of allpass chain        |
| Chorus Depth    | 0.0 – 1.0      | 0.3       | Chorus modulation depth (delay variation)|

### Dynamics
| Parameter       | Range            | Default | Description                          |
|-----------------|------------------|---------|--------------------------------------|
| Gate Open       | −99 to −20 dB    | −60 dB  | Gate open threshold                  |
| Gate Close      | −99 to −20 dB    | −66 dB  | Gate close threshold (hysteresis)    |
| Gate Hold       | 0 – 500 ms       | 50 ms   | Hold time before gate closes         |
| Comp Threshold  | −50 to −6 dB     | −26 dB  | RMS compressor threshold             |
| Comp Ratio      | 2:1 – 20:1       | 9:1     | Compression ratio above threshold    |
| Comp Attack     | 1 – 100 ms       | 8 ms    | Gain reduction attack time           |
| Comp Release    | 10 – 500 ms      | 85 ms   | Gain reduction release time          |
| Comp Makeup     | −24 to +24 dB    | 0 dB    | Post-compression makeup gain         |

### Space
| Parameter       | Range         | Default | Description                              |
|-----------------|---------------|---------|------------------------------------------|
| Reverb Mix      | 0.0 – 1.0     | 0.35    | Wet/dry balance for FDN reverb send      |
| Reverb Decay    | 0.1 – 0.98    | 0.6     | Feedback coefficient (controls RT60)     |
| Reverb Damping  | 500 – 12000 Hz| 3500 Hz | Lowpass cutoff on each feedback path     |
| Stereo Width    | 0.0 – 2.0     | 1.0     | M/S Side channel scale factor            |

### Master Tone
| Parameter   | Range          | Default | Description                          |
|-------------|----------------|---------|--------------------------------------|
| Tilt EQ     | −8 to +8 dB    | 0 dB    | Symmetric tilt shelf around 1 kHz    |
| Lo Shelf    | −12 to +12 dB  | +2 dB   | Low shelf at 80 Hz                   |
| Hi Shelf    | −12 to +12 dB  | +1 dB   | High shelf at 8 kHz                  |
| Mix         | 0.0 – 1.0      | 1.0     | Global dry/wet blend                 |
| Master Out  | −30 to +6 dB   | −3 dB   | Output level after limiter           |

## Usage

### Compilation
Compile with the Faust compiler targeting your preferred backend:

```bash
# JACK / Linux
faust2jack doom_station_v5_4.dsp

# CLAP plugin
faust2clap doom_station_v5_4.dsp

# VST3 plugin
faust2vst3 doom_station_v5_4.dsp

# Web Audio
faust2wam doom_station_v5_4.dsp

# Max/MSP external
faust2max doom_station_v5_4.dsp
```

### Signal Routing
DOOM STATION expects a **mono input** and produces a **stereo output**. Route accordingly in your DAW or host environment:

- Guitar / bass: insert on a mono channel, route stereo to mix bus
- Drums / stems: sum to mono pre-insert or use the dry/wet Mix control to blend
- Synths: works on stereo sources; left channel is used as the mono core input

### Suggested Starting Points

| Use Case            | Suggested Settings                                      |
|---------------------|---------------------------------------------------------|
| Heavy Guitar        | Era: Eternal, Drive: 0.7, Comp Ratio: 12:1, Reverb Mix: 0.25, Width: 1.2 |
| Cinematic Drums     | Era: Dark Ages, Drive: 0.5, Gate Hold: 80ms, Comp Atk: 4ms, Reverb Decay: 0.75 |
| Bass Processing     | Drive: 0.4, bandSub sat dominant, Width: 0.8, no chorus, Reverb Mix: 0.15 |
| Ambient Texture     | Drive: 0.3, Reverb Decay: 0.95, Damping: 8000Hz, Width: 1.8, Mix: 0.6 |
| Full Mix Bus        | Drive: 0.2, Comp Ratio: 4:1, Makeup: −1dB, Limiter active, Mix: 0.4 |

## Technical Notes & Known Compiler Workarounds
Several Faust stdlib functions were found absent or broken in current compiler distributions. The following substitutions were made:

- `ba.linear_interp` — does not exist in stdfaust. Replaced with equivalent inline arithmetic.
- `an.smooth_ud` — does not exist in stdfaust. Replaced with dual `fi.pole` smoothing blended 50/50.
- `ro.hadamard(n)` — generates a malformed `route()` expression. Replaced with explicit Walsh-Hadamard butterfly decomposition.
- `rec{}` block syntax — does not exist in Faust. Noise gate rewritten using `~ (_, _)` topology.
- `ba.selector(k,n)` — replaced with named-argument `pick0and4` function for the 8-bus.

## License
**MIT License.** Use it, modify it, destroy things with it.

This software is provided as-is. Anthropic, id Software, Mick Gordon, and Finishing Move Inc. are referenced for inspirational credit only and are not affiliated with or responsible for this project. Any demons encountered during use should be considered within specification.

**RIP & TEAR // UNTIL IT IS DONE**
