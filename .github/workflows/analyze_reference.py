from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageStat
import cv2
import librosa
import torch
from transformers import BlipProcessor, BlipForConditionalGeneration
from sklearn.cluster import MiniBatchKMeans

ROOT = Path('video-analysis')
VIDEO = 'video_2026-09-13_13-35-33.mp4'
TIMES = [0.0, 2.5, 5.0, 7.5, 10.0, 12.5, 14.0]

COLOR_NAMES = {
    'black': np.array([20,20,20]), 'charcoal': np.array([55,60,60]),
    'slate gray': np.array([95,105,110]), 'mist gray': np.array([175,180,180]),
    'white': np.array([235,235,230]), 'deep ocean blue': np.array([25,65,85]),
    'steel blue': np.array([75,105,125]), 'sky blue': np.array([125,170,195]),
    'deep forest green': np.array([30,65,45]), 'moss green': np.array([75,95,55]),
    'olive green': np.array([115,115,60]), 'grass green': np.array([80,125,55]),
    'earth brown': np.array([105,75,50]), 'stone beige': np.array([155,140,115]),
    'warm gold': np.array([190,145,70]), 'rust': np.array([145,70,40]),
}

def nearest_color(rgb):
    return min(COLOR_NAMES, key=lambda n: np.linalg.norm(rgb - COLOR_NAMES[n]))

# Semantic frame captions and objective color/tonal analysis.
device = 'cuda' if torch.cuda.is_available() else 'cpu'
processor = BlipProcessor.from_pretrained('Salesforce/blip-image-captioning-base')
model = BlipForConditionalGeneration.from_pretrained('Salesforce/blip-image-captioning-base').to(device)
lines = ['REFERENCE VIDEO VISUAL REPORT', 'Sample times: ' + ', '.join(map(str, TIMES)), '']
for i, t in enumerate(TIMES):
    path = ROOT / 'frames' / f'frame-{i}.jpg'
    im = Image.open(path).convert('RGB')
    with torch.no_grad():
        inputs = processor(images=im, return_tensors='pt').to(device)
        out = model.generate(**inputs, max_new_tokens=55, num_beams=5, repetition_penalty=1.2)
    caption = processor.decode(out[0], skip_special_tokens=True)
    arr = np.asarray(im.resize((96, 96))).reshape(-1, 3)
    km = MiniBatchKMeans(n_clusters=4, random_state=3, n_init=5).fit(arr)
    counts = np.bincount(km.labels_)
    order = np.argsort(counts)[::-1]
    colors = []
    for idx in order:
        rgb = km.cluster_centers_[idx]
        pct = counts[idx] / counts.sum() * 100
        colors.append(f'{nearest_color(rgb)} {pct:.0f}% rgb({rgb[0]:.0f},{rgb[1]:.0f},{rgb[2]:.0f})')
    hsv = cv2.cvtColor(np.asarray(im), cv2.COLOR_RGB2HSV)
    brightness = np.asarray(im).mean()
    saturation = hsv[...,1].mean() / 255
    lines += [f'[{t:04.1f}s] caption: {caption}', f'  brightness_0_255={brightness:.1f}; mean_saturation_0_1={saturation:.3f}', '  dominant_colors: ' + '; '.join(colors), '']
(ROOT / 'visual-report.txt').write_text('\n'.join(lines))

# Estimate global image motion between consecutive half-second samples.
cap = cv2.VideoCapture(VIDEO)
duration = cap.get(cv2.CAP_PROP_FRAME_COUNT) / max(cap.get(cv2.CAP_PROP_FPS), 1)
sample_times = np.arange(0.0, max(duration - 0.5, 0.5), 0.5)
frames = []
for t in sample_times:
    cap.set(cv2.CAP_PROP_POS_MSEC, float(t * 1000))
    ok, frame = cap.read()
    if ok:
        gray = cv2.cvtColor(cv2.resize(frame, (180, 400)), cv2.COLOR_BGR2GRAY)
        frames.append((float(t), gray))
cap.release()
mlines = ['GLOBAL FRAME-TO-FRAME MOTION REPORT', 'Positive dx means scene features moved right; positive dy means scene features moved down. Camera motion is generally opposite.', '']
for (t1, a), (t2, b) in zip(frames, frames[1:]):
    orb = cv2.ORB_create(nfeatures=700)
    k1, d1 = orb.detectAndCompute(a, None)
    k2, d2 = orb.detectAndCompute(b, None)
    if d1 is None or d2 is None or len(k1) < 8 or len(k2) < 8:
        mlines.append(f'{t1:.1f}-{t2:.1f}s insufficient_features')
        continue
    matches = cv2.BFMatcher(cv2.NORM_HAMMING).knnMatch(d1, d2, k=2)
    good = [m for m,n in matches if m.distance < 0.72*n.distance]
    if len(good) < 8:
        mlines.append(f'{t1:.1f}-{t2:.1f}s weak_match_count={len(good)} possible_cut_or_low_texture')
        continue
    p1 = np.float32([k1[m.queryIdx].pt for m in good])
    p2 = np.float32([k2[m.trainIdx].pt for m in good])
    M, mask = cv2.estimateAffinePartial2D(p1, p2, method=cv2.RANSAC, ransacReprojThreshold=3.0)
    if M is None:
        mlines.append(f'{t1:.1f}-{t2:.1f}s affine_failed possible_cut')
        continue
    dx, dy = M[0,2], M[1,2]
    scale = math.sqrt(M[0,0]**2 + M[0,1]**2)
    rot = math.degrees(math.atan2(M[1,0], M[0,0]))
    inliers = int(mask.sum()) if mask is not None else 0
    mlines.append(f'{t1:.1f}-{t2:.1f}s scene_dx={dx:+.2f}px scene_dy={dy:+.2f}px scale={scale:.5f} rotation={rot:+.3f}deg inliers={inliers}/{len(good)}')
(ROOT / 'motion-report.txt').write_text('\n'.join(mlines))

# Audio structure, energy, rhythm, spectral character, and approximate key.
y, sr = librosa.load(str(ROOT / 'audio.wav'), sr=None, mono=True)
dur = librosa.get_duration(y=y, sr=sr)
onset_env = librosa.onset.onset_strength(y=y, sr=sr)
tempo, beats = librosa.beat.beat_track(onset_envelope=onset_env, sr=sr)
tempo = float(np.asarray(tempo).reshape(-1)[0])
beat_times = librosa.frames_to_time(beats, sr=sr)
onsets = librosa.onset.onset_detect(y=y, sr=sr, units='time', backtrack=False)
rms = librosa.feature.rms(y=y)[0]
rms_times = librosa.times_like(rms, sr=sr)
centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr, roll_percent=0.85)[0]
zcr = librosa.feature.zero_crossing_rate(y)[0]
chroma = librosa.feature.chroma_cqt(y=y, sr=sr).mean(axis=1)
major = np.array([6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88])
minor = np.array([6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17])
notes = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
scores=[]
for k in range(12):
    scores.append((np.corrcoef(chroma, np.roll(major,k))[0,1], f'{notes[k]} major'))
    scores.append((np.corrcoef(chroma, np.roll(minor,k))[0,1], f'{notes[k]} minor'))
key_score, key_name = max(scores)
max_rms = max(float(rms.max()), 1e-9)
curve=[]
for start in np.arange(0, dur, 0.5):
    sel = rms[(rms_times >= start) & (rms_times < start+0.5)]
    val = float(sel.mean()) if len(sel) else 0.0
    db = 20*math.log10(max(val,1e-9))
    curve.append(f'{start:04.1f}-{min(start+0.5,dur):04.1f}s rms={val:.5f} dbfs={db:.1f} relative={val/max_rms:.3f}')
peak_idx = np.argsort(rms)[-8:][::-1]
peaks = sorted((float(rms_times[i]), float(rms[i]/max_rms)) for i in peak_idx)
alines = [
    'REFERENCE VIDEO AUDIO REPORT', f'duration_seconds={dur:.3f}', f'sample_rate={sr}',
    f'estimated_tempo_bpm={tempo:.2f}', f'beat_times_seconds={np.round(beat_times,3).tolist()}',
    f'onset_times_seconds={np.round(onsets,3).tolist()}', f'approximate_key={key_name} correlation={key_score:.3f}',
    f'mean_spectral_centroid_hz={centroid.mean():.1f}', f'mean_85pct_rolloff_hz={rolloff.mean():.1f}',
    f'mean_zero_crossing_rate={zcr.mean():.4f}', 'strongest_rms_peaks_time_relative=' + str([(round(t,3),round(v,3)) for t,v in peaks]),
    '', 'HALF-SECOND ENERGY CURVE', *curve,
]
(ROOT / 'audio-report.txt').write_text('\n'.join(alines))
