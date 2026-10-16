"""Rennen der Zaehler: alle Kandidaten gegen dieselben Saetze, Signal wie in Swift (Tiefpass 3 Hz).

python3 rennen.py            -> Entwicklungsmenge (35 Saetze vom 16.10., data/sensoraufnahmen)
python3 rennen.py --blind    -> frische Saetze (data/sensoraufnahmen-blind), erst nach Festlegung
"""
import glob, json, math, sys
import numpy as np
from lib import R, fam

DT = 0.02
ALPHA = DT / (1 / (2 * math.pi * 3.0) + DT)  # wie Satztakt.tiefpassHz = 3


# ---------- Laden ----------

def laden(ordner=R, prefix='2026-10-16-'):
    out = []
    for d in sorted(glob.glob(ordner + prefix + '*')):
        a = json.load(open(d + '/aufnahme.json')); soll = (a.get('label') or {}).get('reps')
        if not soll: continue
        rows, marke = [], {}
        for l in open(d + '/messwerte.csv'):
            if l.startswith('# marke'):
                _, _, n, t = l.split(); marke[n] = float(t)
            elif l[0] in 't#': continue
            else: rows.append(list(map(float, l.split(','))))
        r = np.array(rows)
        out.append({'id': d.rstrip('/')[-7:], 'fam': fam(a['kontext']['exerciseName']), 'soll': soll,
                    'acc': r[:, 1:4], 'gyro': r[:, 4:7], 'winkel': r[:, 7:10], 't': r[:, 0], 'marke': marke})
    return out


# ---------- Signal wie Swift ----------

def tiefpass(x, a=ALPHA):
    y = np.empty_like(x); s = x[0]
    for i, v in enumerate(x): s += a * (v - s); y[i] = s
    return y

def gleitend(x, w):
    n = len(x); c = np.concatenate([[0], np.cumsum(x)]); i = np.arange(n)
    a = np.maximum(0, i - w // 2); b = np.minimum(n, i + w // 2 + 1)
    return (c[b] - c[a]) / (b - a)

def hauptachse(X):
    X = X - X.mean(0); w, v = np.linalg.eigh(X.T @ X / len(X))
    return X @ v[:, -1]

def kappen(x, f=1.5):
    sek = int(1 / DT)
    rms = np.sort([math.sqrt((x[i:i + sek] ** 2).mean()) for i in range(0, len(x) - sek + 1, sek)])
    obere = rms[len(rms) // 2:]; c = f * obere[len(obere) // 2]
    return np.clip(x, -c, c) if c > 0 else x

def signal(s, quelle='acc', kapp=1.5):
    X = s[quelle].copy()
    if quelle == 'winkel': X = np.degrees(np.unwrap(np.radians(X), axis=0))
    H = np.stack([tiefpass(X[:, k]) for k in range(3)], 1)
    H = H - np.stack([gleitend(H[:, k], int(3.0 / DT)) for k in range(3)], 1)
    x = hauptachse(H)
    return kappen(x, kapp) if kapp else x


# ---------- Takt ----------

def takt(x, lo=1.2, hi=3.0, rel=0.85):
    x = x - x.mean(); n = len(x); var = (x * x).mean()
    if var < 1e-12: return None, 0
    a, b = int(lo / 2 / DT), min(int(hi / DT), n // 2)
    c = {l: (x[:n - l] * x[l:]).sum() / (n - l) for l in range(a, b + 1)}
    pk = [l for l in range(a + 1, b) if c[l] > c[l - 1] and c[l] >= c[l + 1] and c[l] > 0]
    if not pk: return None, 0
    mx = max(c[l] for l in pk); cand = [l for l in pk if l * DT >= lo and c[l] >= rel * mx]
    return (cand[0] * DT, c[cand[0]] / var) if cand else (None, 0)


# ---------- Kette (Swift kurzhantel/takt2) und Varianten ----------

def gleich(a, b):
    a = a - a.mean(); b = b - b.mean(); n = (a * a).sum() + (b * b).sum()
    return 2 * (a * b).sum() / n if n > 0 else 0.0

def resample(w, L):
    return np.interp(np.linspace(0, len(w) - 1, L), np.arange(len(w)), w)

def kette(x, T, schwelle=0.9, rand=None, vorlage=False, flex=0.0, lo=0.75, hi=1.3, enden=(1, -1)):
    """Laengste Kette sich gleichender Abschnitte. rand: niedrigere Schwelle fuer je ein Glied an den Enden.
    vorlage: Glieder am Ende zusaetzlich gegen den Median der Kette pruefen. flex: Abschnittslaenge +-flex."""
    L = int(round(T / DT)); n = len(x)
    if L < 2 or n <= L: return []
    laengen = [L] if not flex else sorted({int(round(L * (1 + f))) for f in np.linspace(-flex, flex, 5)})

    def schritt(start, Lc, richtung):
        ref = x[start:start + Lc]; best = (-2, None, None)
        for d in range(int(lo * Lc), int(hi * Lc) + 1):
            s = start + richtung * d
            for L2 in laengen:
                if s < 0 or s + L2 > n: continue
                w = x[s:s + L2]
                g = gleich(resample(ref, L), resample(w, L))
                if g > best[0]: best = (g, s, L2)
        return best

    beste = []
    for saat in range(0, n - L, max(1, L // 4)):
        glieder = [(saat, L)]
        for richtung in (1, -1):
            cur, Lc = saat, L
            while True:
                g, s, L2 = schritt(cur, Lc, richtung)
                if s is None or g < schwelle: break
                if richtung == 1: glieder.append((s, L2))
                else: glieder.insert(0, (s, L2))
                cur, Lc = s, L2
        if len(glieder) > len(beste): beste = glieder
    if beste and rand is not None:
        # je Ende ein weiteres Glied mit niedrigerer Schwelle
        ref = np.median([resample(x[s:s + l], L) for s, l in beste], 0) if vorlage else None
        for richtung in enden:
            s0, l0 = beste[-1] if richtung == 1 else beste[0]
            g, s, L2 = schritt(s0, l0, richtung)
            if s is not None and ref is not None: g = gleich(ref, resample(x[s:s + L2], L))
            if s is not None and g >= rand:
                if richtung == 1: beste.append((s, L2))
                else: beste.insert(0, (s, L2))
    return beste


# ---------- Phase ----------

def analytisch(x):
    n = len(x); X = np.fft.fft(x); h = np.zeros(n); h[0] = 1
    if n % 2 == 0: h[n // 2] = 1; h[1:n // 2] = 2
    else: h[1:(n + 1) // 2] = 2
    return np.fft.ifft(X * h)

def bandpass(x, f0, breite=0.5):
    """Gauss-Bandpass im Frequenzbereich um f0 (relative Breite)."""
    n = len(x); f = np.fft.fftfreq(n, DT); X = np.fft.fft(x - x.mean())
    g = np.exp(-0.5 * ((np.abs(f) - f0) / (breite * f0)) ** 2)
    return np.real(np.fft.ifft(X * g))

def phase(x, T, breite=0.5, anteil=0.35, glatt=1.0):
    """Wiederholungen = Phasendrehung / 2pi im aktiven Bereich (Amplitude ueber anteil x Median der oberen Haelfte)."""
    y = bandpass(x, 1 / T, breite); z = analytisch(y)
    amp = gleitend(np.abs(z), max(1, int(glatt * T / DT)))
    ref = np.median(np.sort(amp)[len(amp) // 2:])
    aktiv = amp >= anteil * ref
    # laengster zusammenhaengender aktiver Bereich
    best = (0, 0, 0); i = 0
    while i < len(aktiv):
        if aktiv[i]:
            j = i
            while j < len(aktiv) and aktiv[j]: j += 1
            if j - i > best[0]: best = (j - i, i, j)
            i = j
        else: i += 1
    _, a, b = best
    if b - a < 2: return 0, (a, b)
    ph = np.unwrap(np.angle(z[a:b]))
    return abs(ph[-1] - ph[0]) / (2 * math.pi), (a, b)


# ---------- Motiv (Matrix-Profil, brute force) ----------

def motiv(x, T, schwelle=0.8):
    """Bestes Motiv der Laenge T, dann nicht ueberlappende Vorkommen mit Gleichheit >= schwelle zaehlen."""
    L = int(round(T / DT)); n = len(x) - L
    if n < 2: return 0
    W = np.lib.stride_tricks.sliding_window_view(x, L)[:n]
    W = W - W.mean(1, keepdims=True); e = (W * W).sum(1)
    G = 2 * (W @ W.T) / (e[:, None] + e[None, :] + 1e-12)
    for i in range(n): G[i, max(0, i - L // 2):i + L // 2 + 1] = -2
    profil = G.max(1); kern = int(np.argmax(profil * (e > np.median(e))))
    g = 2 * (W @ W[kern]) / (e + e[kern] + 1e-12)
    # nicht ueberlappend gierig nach Guete
    frei = np.ones(len(x), bool); zahl = 0
    for i in np.argsort(-g):
        if g[i] < schwelle: break
        if frei[i:i + L - L // 4].all(): frei[i:i + L - L // 4] = False; zahl += 1
    return zahl


# ---------- Gipfel (Schmitt-Trigger) ----------

def gipfel(x, T, hyst=0.4):
    """Nulldurchgaenge mit Hysterese auf dem Bandpass-Signal, nur aus dem aktiven Bereich der Phase."""
    y = bandpass(x, 1 / T, 0.5)
    _, (a, b) = phase(x, T)
    y = y[a:b]; ref = np.median(np.abs(y)) * hyst
    zustand, zahl = 0, 0
    for v in y:
        if zustand <= 0 and v > ref: zustand = 1; zahl += 1
        elif zustand >= 0 and v < -ref: zustand = -1
    return zahl


# ---------- Kandidaten ----------

def basis_huelle(x, T, thr=0.6, bias=0.5):
    from lib import huelle
    h = np.array(huelle(list(x), T)); pk = h.max(); i0 = int(h.argmax()); a = b = i0
    while a > 0 and h[a - 1] >= thr * pk: a -= 1
    while b < len(h) - 1 and h[b + 1] >= thr * pk: b += 1
    return int((b - a) * DT / T + 0.5 + bias)

KANDIDATEN = {
    'takt1':      lambda x, T: basis_huelle(x, T),
    'kette':      lambda x, T: len(kette(x, T)),
    'kette+rand': lambda x, T: len(kette(x, T, rand=0.7)),
    'kette+vorl': lambda x, T: len(kette(x, T, rand=0.7, vorlage=True)),
    'kette+flex': lambda x, T: len(kette(x, T, flex=0.15)),
    'phase':      lambda x, T: round(phase(x, T)[0]),
    'motiv':      lambda x, T: motiv(x, T),
    'gipfel':     lambda x, T: gipfel(x, T),
}


def rechnen(saetze, namen, quelle='acc'):
    erg = {}
    for s in saetze:
        x = signal(s, quelle); T, _ = takt(x)
        erg[s['id']] = {k: (KANDIDATEN[k](x, T) if T else -1) for k in namen}
    return erg

def bericht(saetze, erg, namen):
    print('%-12s %6s %5s %6s %6s' % ('', 'exakt', '+-1', 'zuviel', 'zuwenig'))
    for k in namen:
        d = [erg[s['id']][k] - s['soll'] for s in saetze]
        print('%-12s %3d/%-2d %5d %6d %6d' % (k, sum(v == 0 for v in d), len(d), sum(abs(v) <= 1 for v in d),
                                             sum(v > 0 for v in d), sum(v < 0 for v in d)))

def paare(saetze, erg, namen):
    """Zwei Zaehler einig -> zeigen, sonst nachfragen. Still falsch = einig, aber falsch."""
    print('\npaar                     gezeigt richtig  still-falsch  nachfrage')
    zeilen = []
    for i, a in enumerate(namen):
        for b in namen[i + 1:]:
            ok = falsch = frage = 0
            for s in saetze:
                u, v = erg[s['id']][a], erg[s['id']][b]
                if u == v: ok += u == s['soll']; falsch += u != s['soll']
                else: frage += 1
            zeilen.append((falsch, frage, a, b, ok))
    for falsch, frage, a, b, ok in sorted(zeilen)[:12]:
        print('%-24s %8d %13d %10d' % (a + ' & ' + b, ok, falsch, frage))


if __name__ == '__main__':
    blind = '--blind' in sys.argv
    namen = [a for a in sys.argv[1:] if not a.startswith('--')] or list(KANDIDATEN)
    ordner = R.replace('sensoraufnahmen/', 'sensoraufnahmen-blind/') if blind else R
    S = laden(ordner)
    erg = rechnen(S, namen)
    bericht(S, erg, namen)
    paare(S, erg, namen)
    if '--detail' in sys.argv:
        for s in S: print(s['id'], s['fam'], 'soll', s['soll'], ' '.join('%s=%s' % (k, erg[s['id']][k]) for k in namen))
