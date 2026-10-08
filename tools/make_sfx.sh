#!/usr/bin/env bash
# Builds the sound effects in assets/sfx (see the Sfx autoload).
#
#   tools/make_sfx.sh [KENNEY_DIR]
#
# Synthesised with ffmpeg: the ambience loops (rain, wind, waves, stream, crickets), birds,
# thunder, splashes, the hop "boing", sparkles, munching, rustling, the landscaping rumble
# and the vowel blips characters babble in. With KENNEY_DIR (Kenney's CC0 audio packs
# unpacked into interface-sounds/, impact-sounds/, rpg-audio/ and music-jingles/, from
# kenney.nl), also copies in the footsteps, impacts, UI clicks and jingles under the
# names the game uses. Every one-shot is evened out to the same peak level.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=assets/sfx
mkdir -p "$OUT"
KENNEY="${1:-}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
RATE=44100

# Scales a sound so its peak sits at $3 dBFS, writing mono Ogg Vorbis.
level() {
	local in="$1" out="$2" peak="$3"
	local max
	max=$(ffmpeg -hide_banner -i "$in" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-*[0-9.]*\) dB/\1/p')
	local gain
	gain=$(python3 -c "print(f'{($peak) - ($max):.2f}')")
	ffmpeg -v error -y -i "$in" -af "volume=${gain}dB" -ac 1 -ar $RATE -c:a libvorbis -q:a 4 "$out"
}

# A synthesised one-shot from an aevalsrc expression of t, lasting $3 seconds.
tone() {
	local name="$1" expr="$2" dur="$3" peak="${4:--4}"
	ffmpeg -v error -y -f lavfi -i "aevalsrc='$expr':s=$RATE:d=$dur" "$TMP/$name.wav"
	level "$TMP/$name.wav" "$OUT/$name.ogg" "$peak"
}

# A synthesised sound from a filter graph ($2 makes [out]), lasting $3 seconds.
graph() {
	local name="$1" fg="$2" dur="$3" peak="${4:--4}"
	ffmpeg -v error -y -filter_complex "$fg" -map "[out]" -t "$dur" -ar $RATE "$TMP/$name.wav"
	level "$TMP/$name.wav" "$OUT/$name.ogg" "$peak"
}

# --- Ambience loops (seamless: every wobble repeats a whole number of times) ----------

# Rain: a soft hiss with drops pattering through it.
graph rain_loop "anoisesrc=c=pink:r=$RATE:a=0.6:d=13,highpass=f=500,lowpass=f=4500,atrim=start=1[hiss];
	anoisesrc=c=velvet:r=$RATE:a=0.9:d=13:density=0.004,highpass=f=1800,lowpass=f=7000,atrim=start=1[drops];
	[hiss][drops]amix=inputs=2:weights=1 0.5,asetpts=N/SR/TB[out]" 12 -9
# Wind: low rushing that swells and dies away every eight seconds.
graph wind_loop "anoisesrc=c=brown:r=$RATE:a=0.9:d=17,lowpass=f=600,highpass=f=60,atrim=start=1,asetpts=N/SR/TB,
	volume=eval=frame:volume='0.3+0.7*pow(0.5+0.5*sin(2*PI*t/8),2)'[out]" 16 -10
# Waves on the shore: a swell and a hiss as each one breaks, every six seconds.
graph waves_loop "anoisesrc=c=pink:r=$RATE:a=0.7:d=19,lowpass=f=1400,atrim=start=1,asetpts=N/SR/TB,
	volume=eval=frame:volume='0.12+0.88*pow(0.5+0.5*sin(2*PI*t/6-PI/2),3)'[swell];
	anoisesrc=c=white:r=$RATE:a=0.3:d=19,highpass=f=2500,lowpass=f=7000,atrim=start=1,asetpts=N/SR/TB,
	volume=eval=frame:volume='pow(0.5+0.5*sin(2*PI*t/6-PI/2-0.6),6)'[foam];
	[swell][foam]amix=inputs=2:weights=1 0.6[out]" 18 -10
# A stream babbling over stones.
graph stream_loop "anoisesrc=c=pink:r=$RATE:a=0.6:d=9,bandpass=f=1800:w=1400,atrim=start=1,asetpts=N/SR/TB,
	volume=eval=frame:volume='0.55+0.25*sin(2*PI*t*3)*sin(2*PI*t*1.25)+0.2*sin(2*PI*t*7)'[out]" 8 -12
# Crickets at night: two trilling in turn.
tone crickets_loop "0.25*sin(2*PI*4600*t)*(0.5+0.5*sin(2*PI*42*t))*gt(sin(2*PI*1.25*t),0.2)+0.18*sin(2*PI*5200*t)*(0.5+0.5*sin(2*PI*50*t))*gt(sin(2*PI*0.875*t+1),0.4)" 8 -14

# --- Birds (one-shots, played now and then by day) --------------------------------------

tone bird_1 "0.5*sin(2*PI*(2800*t+9000*t*t))*exp(-pow((t-0.06)/0.035,2))+0.5*sin(2*PI*(2800*(t-0.25)+9000*(t-0.25)*(t-0.25)))*exp(-pow((t-0.31)/0.035,2))" 0.5 -8
tone bird_2 "0.5*sin(2*PI*(4200*t-2600*t*t))*(0.55+0.45*sin(2*PI*30*t))*exp(-pow((t-0.32)/0.2,2))" 0.7 -9
tone bird_3 "0.5*sin(2*PI*(2100*t-240*cos(2*PI*t)))*exp(-pow((t-0.3)/0.17,2))" 0.65 -8
tone bird_4 "0.45*(sin(2*PI*3000*t)*exp(-pow((t-0.05)/0.025,2))+sin(2*PI*3500*t)*exp(-pow((t-0.15)/0.025,2))+sin(2*PI*(4200*t+3000*t*t))*exp(-pow((t-0.27)/0.035,2)))" 0.4 -8

# --- Weather ---------------------------------------------------------------------------

graph thunder_1 "anoisesrc=c=white:r=$RATE:a=0.8:d=5,highpass=f=1200,volume=eval=frame:volume='exp(-t/0.07)'[crack];
	anoisesrc=c=brown:r=$RATE:a=1:d=5,lowpass=f=180,volume=eval=frame:volume='(1-exp(-t/0.08))*exp(-t/1.5)*(0.7+0.3*sin(2*PI*1.7*t)*sin(2*PI*0.6*t))'[rumble];
	[crack][rumble]amix=inputs=2:weights=0.5 1[out]" 5 -3
graph thunder_2 "anoisesrc=c=brown:r=$RATE:a=1:d=5,lowpass=f=140,volume=eval=frame:volume='(1-exp(-t/0.4))*exp(-t/1.8)*(0.6+0.4*sin(2*PI*1.1*t)*sin(2*PI*0.45*t))'[out]" 5 -5

# --- Water -----------------------------------------------------------------------------

graph splash "anoisesrc=c=white:r=$RATE:a=0.8:d=0.6,highpass=f=700,lowpass=f=5000,volume=eval=frame:volume='exp(-t/0.1)'[s];
	aevalsrc='0.8*sin(2*PI*(900*t-2500*t*t))*exp(-t/0.05)':s=$RATE:d=0.6[p];[s][p]amix=inputs=2[out]" 0.6 -4
tone plop "0.8*sin(2*PI*(700*t-2800*t*t))*exp(-t/0.04)" 0.18 -6

# --- Little things ---------------------------------------------------------------------

tone boing "0.6*sin(2*PI*(260*t+900*t*t))*exp(-t/0.12)*(1+0.3*sin(2*PI*18*t))" 0.32 -8
tone sparkle "0.3*(sin(2*PI*1047*t)*exp(-t/0.25)+sin(2*PI*1319*max(t-0.06,0))*gt(t,0.06)*exp(-(t-0.06)/0.25)+sin(2*PI*1568*max(t-0.12,0))*gt(t,0.12)*exp(-(t-0.12)/0.25)+sin(2*PI*2093*max(t-0.18,0))*gt(t,0.18)*exp(-(t-0.18)/0.3))" 0.8 -7
graph munch "anoisesrc=c=white:r=$RATE:a=0.8:d=0.6,bandpass=f=2600:w=2600,volume=eval=frame:volume='exp(-pow((t-0.04)/0.025,2))+exp(-pow((t-0.22)/0.025,2))+0.8*exp(-pow((t-0.4)/0.025,2))'[out]" 0.55 -7
graph rustle "anoisesrc=c=pink:r=$RATE:a=0.8:d=0.7,highpass=f=1800,lowpass=f=8000,volume=eval=frame:volume='(1-exp(-t/0.03))*exp(-t/0.25)*(0.6+0.4*sin(2*PI*23*t)*sin(2*PI*9*t))'[out]" 0.7 -7
# A soft whoosh of air (swinging a net, casting a line): noise swelling and fading, its
# pitch sliding down as it goes.
graph whoosh_1 "anoisesrc=c=pink:r=$RATE:a=0.8:d=0.45,bandpass=f=1100:w=1400,volume=eval=frame:volume='pow(sin(PI*min(t/0.4,1)),2)'[out]" 0.4 -9
graph whoosh_2 "anoisesrc=c=pink:r=$RATE:a=0.8:d=0.4,bandpass=f=800:w=1000,volume=eval=frame:volume='pow(sin(PI*min(t/0.32,1)),3)'[out]" 0.32 -9
graph rumble "anoisesrc=c=brown:r=$RATE:a=1:d=0.9,lowpass=f=260,volume=eval=frame:volume='(1-exp(-t/0.03))*exp(-t/0.35)'[out]" 0.9 -4

# --- Voices: a vowel blip each, pitched per character when they talk --------------------

voice() {
	local v="$1" f1="$2" f2="$3"
	graph "voice_$v" "aevalsrc='(2*(t*220-floor(t*220+0.5)))*min(1,t/0.006)*exp(-t/0.045)':s=$RATE:d=0.11,asplit=3[a][b][c];
		[a]bandpass=f=$f1:w=160[x];[b]bandpass=f=$f2:w=260[y];[c]lowpass=f=500[z];
		[x][y][z]amix=inputs=3:weights=1 0.7 0.35[out]" 0.11 -6
}
voice a 800 1250
voice e 450 2000
voice i 330 2300
voice o 480 850
voice u 340 750

# --- From Kenney's packs (CC0) --------------------------------------------------------

if [ -n "$KENNEY" ]; then
	copy() { # copy NAME SOURCE... : each source becomes NAME_1, NAME_2...
		local name="$1"
		shift
		local n=1
		for src in "$@"; do
			level "$KENNEY/$src" "$OUT/${name}_$n.ogg" "${PEAK:--6}"
			n=$((n + 1))
		done
	}
	I=interface-sounds/Audio
	X=impact-sounds/Audio
	R=rpg-audio/Audio
	J="music-jingles/Audio"
	PEAK=-12 copy step_grass $X/footstep_grass_00{0,1,2,3,4}.ogg
	PEAK=-12 copy step_stone $X/footstep_concrete_00{0,1,2,3,4}.ogg
	PEAK=-12 copy step_wood $X/footstep_wood_00{0,1,2,3,4}.ogg
	PEAK=-12 copy step_snow $X/footstep_snow_00{0,1,2,3,4}.ogg
	PEAK=-14 copy step_carpet $X/footstep_carpet_00{0,1,2,3,4}.ogg
	copy chop $R/chop.ogg $X/impactWood_medium_00{0,1,2}.ogg
	copy mine $X/impactMining_00{0,1,2,3}.ogg
	copy dig $X/impactSoft_heavy_00{0,1,2}.ogg
	PEAK=-8 copy thud $X/impactSoft_medium_00{0,1,2}.ogg
	PEAK=-8 copy place $X/impactWood_light_00{0,1,2}.ogg
	PEAK=-8 copy clonk $X/impactGeneric_light_00{0,1}.ogg
	PEAK=-8 copy hammer $X/impactPlank_medium_00{0,1,2}.ogg
	copy door_open $R/doorOpen_{1,2}.ogg
	copy door_close $R/doorClose_{1,2}.ogg
	copy coins $R/handleCoins.ogg $R/handleCoins2.ogg
	PEAK=-8 copy page $R/bookFlip{1,2,3}.ogg
	PEAK=-8 copy cloth $R/cloth{1,2,3,4}.ogg
	PEAK=-10 copy creak $R/creak{1,2,3}.ogg
	PEAK=-8 copy pop $I/pluck_00{1,2}.ogg
	PEAK=-14 copy ui_move $I/tick_00{1,2,4}.ogg
	PEAK=-12 copy ui_select $I/select_00{1,2}.ogg
	PEAK=-12 copy ui_back $I/back_00{1,2}.ogg
	PEAK=-10 copy ui_open $I/maximize_00{1,2}.ogg
	PEAK=-10 copy ui_close $I/minimize_00{1,2}.ogg
	PEAK=-12 copy ui_error $I/error_00{6,8}.ogg
	PEAK=-12 copy ui_toggle $I/toggle_00{1,2}.ogg
	PEAK=-10 copy twinkle $I/glass_00{1,2,3}.ogg
	PEAK=-8 copy jingle_catch "$J/Steel jingles/jingles_STEEL10.ogg"
	PEAK=-8 copy jingle_lost "$J/Pizzicato jingles/jingles_PIZZI11.ogg"
	PEAK=-8 copy jingle_reward "$J/Steel jingles/jingles_STEEL15.ogg"
	PEAK=-8 copy jingle_build "$J/Steel jingles/jingles_STEEL02.ogg"
	PEAK=-8 copy jingle_learn "$J/Pizzicato jingles/jingles_PIZZI02.ogg"
	PEAK=-8 copy jingle_ding "$J/Steel jingles/jingles_STEEL16.ogg"
	PEAK=-8 copy jingle_craft "$J/Pizzicato jingles/jingles_PIZZI10.ogg"
fi
ls "$OUT" | wc -l
