using Plots
using FFTW
using Printf
using FFMPEG

# VIVIMUSE [TEMPERAMENT.EXE]
# C4 stays fixed. G4 changes from a pure fifth to equal temperament.

gr()

# Yes, I could have demostrated this on a piano.
# But Who said I wanted to make it easy?  //;>     [302, count!]

const SR = 44100
const FPS = 24
const W, H = 1600, 900
const C4 = 261.6255653005986

const PURE_RATIO = 3 / 2           # Pythagoras walked so this fifth could be pure. The consequences, hovewer, are not. //;> 

const ET_RATIO = 2.0^(7 / 12)      # Twelve semitones. One Octave = 2:1. Zero universality accepted compromises. //;>

const PURE_G4 = C4 * PURE_RATIO
const ET_G4 = C4 * ET_RATIO
const PURE_SECONDS = 6.5
const GAP_SECONDS = 4.5
const ET_SECONDS = 6.5
const COMPARE_SECONDS = 10.0
const OUT_MP4 = "vivimuse_[temper.exe].mp4"
const OUT_WAV = "vivimuse_[temper.exe].wav"
const FRAME_DIR = "vivimuse_[temper.exe]_frames"
const BG = "#05070B"
const WHITE = "#FFFFFF"
const MUTED = "#AAB4C5"
const GRID = "#293141"
const VIOLET = "#8a36f6"          #"#8535E8" ? still a questio //;>
const GOLD = "#FFD166"
const MANIACFONT = "/Users/Desktop/vivimuse/Julia/MonomaniacOne-Regular"

cents(a, b) = 1200 * log2(a / b)
smoothstep01(x) = (clamp(x, 0.0, 1.0)^2) * (3 - 2 * clamp(x, 0.0, 1.0))

function tone(freq, duration; amp=0.20)
 # The Muse has entered the waveform era. //;>

    n = round(Int, duration * SR)
    t = (0:n-1) ./ SR
    fade_out = 1.0
    duration = length(t) / SR

    fade = clamp.((duration .- t) ./ fade_out, 0.0, 1.0)

    env = (1 .- exp.(-t ./ 0.025)) .* exp.(-t ./ 8.0) .* fade

    wave = sin.(2π .* freq .* t) .+
           0.42 .* sin.(2π .* 2 .* freq .* t) .+
           0.20 .* sin.(2π .* 3 .* freq .* t) .+
           0.09 .* sin.(2π .* 4 .* freq .* t)
    return amp .* env .* wave
end

function interval(fifth, duration)
    n = round(Int, duration * SR)
    x = tone(C4, duration) .+ tone(fifth, duration)
    nf = min(round(Int, 0.04 * SR), n)
    x[end-nf+1:end] .*= range(1.0, 0.0; length=nf)
    return x
end

silence(duration) = zeros(Float64, round(Int, duration * SR))    
# Finally, a frequency everyone can agree on. 
# x(t) = 0 , t ∈ [0, T]  //;>

function le(io, x::UInt16)
    write(io, UInt8(x & 0x00ff), UInt8((x >> 8) & 0x00ff))
end
function le(io, x::UInt32)
    write(io, UInt8(x & 0x000000ff), UInt8((x >> 8) & 0x000000ff),
          UInt8((x >> 16) & 0x000000ff), UInt8((x >> 24) & 0x000000ff))
end
le(io, x::Int16) = le(io, reinterpret(UInt16, x))

function write_wav(path, x)
    peak = maximum(abs, x)
    y = peak > 0 ? x .* (0.88 / peak) : x
    pcm = round.(Int16, clamp.(y .* 32767, -32768, 32767))
    bytes = UInt32(2 * length(pcm))
    open(path, "w") do io
        write(io, codeunits("RIFF")); le(io, UInt32(36) + bytes)
        write(io, codeunits("WAVEfmt ")); le(io, UInt32(16))
        le(io, UInt16(1)); le(io, UInt16(1))
        le(io, UInt32(SR)); le(io, UInt32(SR * 2))
        le(io, UInt16(2)); le(io, UInt16(16))
        write(io, codeunits("data")); le(io, bytes)
        for v in pcm
            le(io, v)
        end
    end
end

function spectrum(x; start_sec=0.45, seconds=1.5, nfft=131072)
    i = round(Int, start_sec * SR) + 1
    n = round(Int, seconds * SR)
    segment = x[i:i+n-1]
    window = 0.5 .- 0.5 .* cos.(2π .* (0:length(segment)-1) ./ (length(segment)-1))
    z = zeros(Float64, nfft)
    z[1:length(segment)] .= segment .* window
    a = abs.(rfft(z))
    f = (0:length(a)-1) .* (SR / nfft)
    db = 20 .* log10.(a ./ (maximum(a) + eps()) .+ 1e-7)
    return f, db
end

function harmonic_labels!(p2, blend, comparison)
    # C4: always the same values in all phases.
    annotate!(p2, 274, -8, text(@sprintf("C4 = %.3f Hz", C4), 12, WHITE, :left))
    annotate!(p2, 540, -44, text(@sprintf("C4 x 2 = %.3f Hz", 2*C4), 12, WHITE, :left))
    annotate!(p2, 807, -2, text(@sprintf("C4 x 3 = %.3f Hz", 3*C4), 12, WHITE, :left))
    annotate!(p2, 1025, -65, text(@sprintf("C4 x 4 = %.3f Hz", 4*C4), 12, WHITE, :right))

    if comparison
     # Phase 3: show both temperaments
        annotate!(p2, 412, -17, text(@sprintf("Pure G4"), 12, VIOLET, :left))
        annotate!(p2, 412, -31, text(@sprintf("ET G4"), 12, GOLD, :left))
        annotate!(p2, 807, -26, text(@sprintf("Pure G4 x 2 = %.3f Hz", 2*PURE_G4), 12, VIOLET, :left))
        annotate!(p2, 807, -38, text(@sprintf("ET G4 x 2 = %.3f Hz", 2*ET_G4), 12, GOLD, :left))
        annotate!(p2, 1182, -2, text(@sprintf("Pure G4 x 3 = %.3f Hz", 3*PURE_G4), 12, VIOLET, :right))
        annotate!(p2, 1182, -9, text(@sprintf("ET G4 x 3 = %.3f Hz", 3*ET_G4), 12, GOLD, :right))
    else
        g4 = (1 - blend) * PURE_G4 + blend * ET_G4
        col = blend < 0.5 ? VIOLET : GOLD
        annotate!(p2, 407, -23, text(@sprintf("G4 = %.3f Hz", g4), 12, col, :left))
        annotate!(p2, 807, -29, text(@sprintf("G4 x 2 = %.3f Hz", 2*g4), 12, col, :left))
        annotate!(p2, 1182, -9, text(@sprintf("G4 x 3 = %.3f Hz", 3*g4), 12, col, :right))
    end
end

function make_frame(t, f_p, db_p, f_e, db_e, status, detail, pure_alpha, et_alpha)
    pure_on = clamp(pure_alpha, 0.0, 1.0)
    et_on = clamp(et_alpha, 0.0, 1.0)
    comparison = pure_on > 0.99 && et_on > 0.99
    blend = et_on

    p1 = plot(
        xlims=(390.58, 393.9), ylims=(0, 1),
        background_color=BG, foreground_color=WHITE,
        grid=false, legend=false, framestyle=:none,
        size=(W, 260), left_margin=35Plots.px, right_margin=35Plots.px,
        top_margin=8Plots.px, bottom_margin=8Plots.px,
        title="UPPER NOTE: G4", titlefont=font(17, WHITE),
        titlelocation=:left
    )

    plot!(p1, [391.10, 393.9], [0.72, 0.72], color=GRID, linewidth=1, label=false)
    plot!(p1, [391.40, 393.9], [0.28, 0.28], color=GRID, linewidth=1, label=false)
    plot!(p1, [ET_G4, ET_G4], [0.06, 0.78], color=GOLD, linewidth=3,
          alpha=0.22 + 0.78 * et_on, label=false)
    plot!(p1, [PURE_G4, PURE_G4], [0.06, 0.78], color=VIOLET, linewidth=3,
          alpha=0.22 + 0.78 * pure_on, label=false)
    scatter!(p1, [ET_G4], [0.28], color=GOLD, markersize=7,
             alpha=0.22 + 0.78 * et_on, label=false)
    scatter!(p1, [PURE_G4], [0.72], color=VIOLET, markersize=7,
             alpha=0.22 + 0.78 * pure_on, label=false)
    annotate!(p1, 390.58, 0.28,
        text(@sprintf("EQUAL-TEMPERED G4  %.3f Hz", ET_G4), 14, GOLD, :left))
    annotate!(p1, 390.58, 0.72,
        text(@sprintf("PURE G4  %.3f Hz", PURE_G4), 15, VIOLET, :left))
    annotate!(p1, 393.75, 0.82,
        text(@sprintf("Δ %.3f Hz  |  %.3f cents", PURE_G4-ET_G4,
                      cents(PURE_RATIO, ET_RATIO)), 14, WHITE, :right))
    plot!(p1, xlabel="Frequency (Hz)", xguidefont=font(12, MUTED),
          tickfont=font(12, MUTED), xticks=390.5:0.5:393.5,
          foreground_color=WHITE)

    p2 = plot(
        xlims=(200, 1200), ylims=(-85, 5),
        background_color=BG, foreground_color=WHITE,
        grid=true, gridcolor=GRID, gridalpha=0.7,
        legend=(0.82, 1.20), legendfont=font(12, WHITE),
        legend_background_color=BG, legend_foreground_color=GRID,
        framestyle=:box, size=(W, 570),
        left_margin=105Plots.px, right_margin=55Plots.px,
        top_margin=35Plots.px, bottom_margin=65Plots.px,
        title="HARMONIC SPECTRUM · C4 - G4", titlefont=font(19, WHITE),
        xlabel="Frequency (Hz)", ylabel="Relative level (dB)",
        guidefont=font(16, MUTED), tickfont=font(14, MUTED)
    )

    ip = findall((f_p .>= 200) .& (f_p .<= 1200))
    ie = findall((f_e .>= 200) .& (f_e .<= 1200))
    # Preserve the original measured FFT spectra and crossfade them.
    plot!(p2, f_p[ip], db_p[ip], color=VIOLET, linewidth=2.2,
          alpha=0.12 + 0.88 * pure_on, label="1 — Pure fifth 3:2")
    plot!(p2, f_e[ie], db_e[ie], color=GOLD, linewidth=2.2,
          linestyle=:dash, alpha=0.12 + 0.88 * et_on,
          label="2 — Equal temperament")
    vline!(p2, [C4], color=WHITE, alpha=0.65,
           linewidth=1, linestyle=:dot, label=false)
    vline!(p2, [ET_G4], color=GOLD, alpha=0.15 + 0.70*et_on,
           linewidth=1.2, linestyle=:dot, label=false)
    vline!(p2, [PURE_G4], color=VIOLET, alpha=0.15 + 0.70*pure_on,
           linewidth=1.2, linestyle=:dot, label=false)
    harmonic_labels!(p2, blend, comparison)

    header = plot(
        xlims=(0, 1), ylims=(0, 1),
        background_color=BG, foreground_color=WHITE,
        grid=false, legend=false, framestyle=:none,
        size=(W, 130), left_margin=0Plots.px, right_margin=0Plots.px,
        top_margin=0Plots.px, bottom_margin=0Plots.px
    )

    annotate!(header, 0.01, 0.82,
        text("VIVIMUSE  [TEMPERAMENT.EXE]", 24, WHITE, :left ; family = MANIACFONT))
    annotate!(header, 0.99, 0.79,
        text(status, 24, WHITE, :right ; family = MANIACFONT))
    annotate!(header, 0.5, 0.05,
        text(detail, 19, WHITE, :center))

    full = plot(header, p1, p2,
        layout=grid(3, 1, heights=[0.13, 0.23, 0.64]),
        size=(W, H), background_color=BG,
        left_margin=45Plots.px, right_margin=35Plots.px,
        top_margin=12Plots.px, bottom_margin=30Plots.px)
    return full
end

function main()

    pure = interval(PURE_G4, PURE_SECONDS)   

     # A dip in the Castalian Spring.
     # Then we may discuss the fifth.  //;>

    et = interval(ET_G4, ET_SECONDS)
    compare = interval(PURE_G4, COMPARE_SECONDS) .+
              interval(ET_G4, COMPARE_SECONDS)
    audio = vcat(pure, silence(GAP_SECONDS), et,
                 silence(GAP_SECONDS), compare)
    write_wav(OUT_WAV, audio)
    fp, dp = spectrum(pure)
    fe, de = spectrum(et)
    mkpath(FRAME_DIR)
    total_seconds = PURE_SECONDS + GAP_SECONDS + ET_SECONDS + GAP_SECONDS + COMPARE_SECONDS
    nframes = round(Int, total_seconds * FPS)

    for frame in 1:nframes
        t = (frame - 1) / FPS
        first_gap_start = PURE_SECONDS
        first_gap_end = first_gap_start + GAP_SECONDS
        second_gap_start = first_gap_end + ET_SECONDS
        second_gap_end = second_gap_start + GAP_SECONDS

        if t < first_gap_start
            status = "PHASE 1 / PURE FIFTH — C4 + G4 (3:2)"
            detail = @sprintf("C4 = %.2f Hz   •   Pure G4 = %.2f Hz", C4, PURE_G4)
            pure_alpha, et_alpha = 1.0, 0.0
        elseif t < first_gap_end
            status = "TRANSITION / SILENCE"
            detail = "VISUAL RETUNING: PURE FIFTH → EQUAL TEMPERAMENT"
            u = smoothstep01((t - first_gap_start) / GAP_SECONDS)
            pure_alpha, et_alpha = 1.0 - u, u
        elseif t < second_gap_start
            status = "PHASE 2 / EQUAL TEMPERAMENT — C4 + G4"
            detail = "fₙ = f_ref × 2^(n/12)"
            pure_alpha, et_alpha = 0.0, 1.0
        elseif t < second_gap_end
            status = "TRANSITION / SILENCE"
            detail = "PHASE 2 → PHASE 3 / COMPARISON"
            u = smoothstep01((t - second_gap_start) / GAP_SECONDS)
            pure_alpha, et_alpha = u, 1.0
        else
            status = "PHASE 3 / COMPARISON 1 vs 2"
            detail = @sprintf("C4 × 3 ≈ PURE G4 × 2 = %.3f Hz   •   ET G4 × 2 = %.3f Hz   •   Δ %.3f Hz",
                C4 * 3, ET_G4 * 2, (C4 * 3) - (ET_G4 * 2))
            pure_alpha, et_alpha = 1.0, 1.0
        end
        p = make_frame(t, fp, dp, fe, de, status, detail, pure_alpha, et_alpha)
        savefig(p, joinpath(FRAME_DIR, @sprintf("frame_%05d.png", frame)))
        if frame == 1 || frame % FPS == 0
            println("Rendering frame $frame / $nframes")
        end
    end

    pattern = joinpath(FRAME_DIR, "frame_%05d.png")
    FFMPEG.ffmpeg_exe(`-y -framerate $FPS -i $pattern -i $OUT_WAV -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest -movflags +faststart $OUT_MP4`)
    println("\nCreated video WITH audio: ", abspath(OUT_MP4))
    println("Created audio file:      ", abspath(OUT_WAV))
    println(@sprintf("C4 = %.3f Hz | Pure G4 = %.3f Hz | Equal-tempered G4 = %.3f Hz",
                     C4, PURE_G4, ET_G4))

end

main()

# VIVIMUSE SYSTEM STATUS : [302,!]
# RENDER: COMPLETE
# FFT: PERFORMED
# PERFECT FIFTH: VERIFIED
# TEMPERAMENT: UNRESOLVED
# PIANIST: HAS LEFT TO PRACTICE ON A WHITE STEINWAY. 
//;>