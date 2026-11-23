"""Nachrechnung zur Tempo-Spec (docs/superpowers/specs/2026-11-23-tempo-modus-design.md, Abschnitt 4).

Schaetzt je Aufnahme nachtraeglich eine Position aus der Beschleunigung und
misst, wie gleichmaessig der Hub von Wiederholung zu Wiederholung ist.
Bezug fuer das Guetetor der Live-Schaetzung (Abschnitt 6.4). Grob und
nicht-kausal: kennt den ganzen Satz.

Aufruf: uv run --no-project --with numpy python tools/sensorik-sim/tempo_nachrechnung.py data/sensoraufnahmen

Auswahl: Aufnahmen mit befestigungsart stapel/kurzhantel/langhantel und
repsWahr >= 5 aus korrekturen.json, ohne Luecken, mindestens 300 Messwerte.
Schwerkraftrichtung = Mittel der Beschleunigung ueber die ganze Aufnahme
(bei drehender Hantel also nur genaehert). Aktiver Teil = laengster
Abschnitt, in dem die gleitende Effektivbeschleunigung ueber 30 % ihres
Hoechstwerts liegt.
"""
import json,glob,os,sys
import numpy as np
root=sys.argv[1]
def load(d):
    rows=[l for l in open(os.path.join(d,'messwerte.csv')) if l[0] not in '#t' and l.strip()]
    return np.array([[float(x) for x in r.split(',')] for r in rows])
def movavg(x,n):
    n=max(3,int(n)|1); k=np.ones(n)/n
    return np.convolve(np.pad(x,(n//2,n//2),mode='edge'),k,mode='valid')
def period(x,fs):
    x=x-x.mean(); ac=np.correlate(x,x,'full')[len(x)-1:]; ac/=ac[0]
    lo,hi=int(0.8*fs),min(int(8*fs),len(ac)-1)
    if hi<=lo: return None
    return (lo+np.argmax(ac[lo:hi]))/fs
def peaks(x,mind):
    idx=[]
    for i in range(1,len(x)-1):
        if x[i]>x[i-1] and x[i]>=x[i+1]:
            if idx and i-idx[-1]<mind:
                if x[i]>x[idx[-1]]: idx[-1]=i
            else: idx.append(i)
    return idx
def strokes(p,fs,T):
    hi=peaks(p,0.6*T*fs); lo=peaks(-p,0.6*T*fs)
    ev=sorted([(i,1) for i in hi]+[(i,-1) for i in lo])
    s=np.array([abs(p[a[0]]-p[b[0]]) for a,b in zip(ev,ev[1:]) if a[1]!=b[1]])
    if len(s)==0: return s,0
    s=s[s>0.4*np.median(s)]
    return s,int(round(len(s)/2))
res={'stapel':[],'kurzhantel':[],'langhantel':[]}
KORR=json.load(open(os.path.join(root,'korrekturen.json')))['aufnahmen']
for d in sorted(glob.glob(os.path.join(root,'*/'))):
    k=KORR.get(os.path.basename(d.rstrip('/')))
    if not k: continue
    art=k.get('befestigungsart'); rw=k.get('repsWahr')
    if art not in res or not rw or rw<5: continue
    a=json.load(open(os.path.join(d,'aufnahme.json')))
    if a['statistik'].get('luecken'): continue
    m=load(d); n=len(m)
    if n<300: continue
    fs=n/(m[-1,0]-m[0,0]); acc=m[:,1:4]
    g=acc.mean(0); g/=np.linalg.norm(g)
    av=(acc@g-np.linalg.norm(acc.mean(0)))*9.81
    T=period(av,fs)
    if not T: continue
    # nicht-kausal: zweimal integrieren, je gleitenden Mittelwert ueber 1 Periode abziehen
    v=np.cumsum(av)/fs; v-=movavg(v,T*fs)
    p=np.cumsum(v)/fs; p-=movavg(p,T*fs)
    # kausal: leckende Integration, Zeitkonstante = 1 Periode
    al=np.exp(-1/(T*fs)); vc=np.zeros(n); pc=np.zeros(n)
    for i in range(1,n):
        vc[i]=al*(vc[i-1]+av[i]/fs); pc[i]=al*(pc[i-1]+vc[i]/fs)
    pc-=movavg(pc,T*fs)  # nur zum Vergleich der Form
    env=np.sqrt(movavg(av**2,T*fs)); on=env>0.3*env.max()
    best=(0,0); i=0
    while i<n:
        if on[i]:
            j=i
            while j<n and on[j]: j+=1
            if j-i>best[1]-best[0]: best=(i,j)
            i=j
        else: i+=1
    W=slice(*best)
    s,nh=strokes(p[W],fs,T); sc,nhc=strokes(pc[W],fs,T)
    mid=W
    cor=np.corrcoef(p[mid],pc[mid])[0,1]
    # Winkel: Achse mit groesstem Hub
    w=np.rad2deg(np.unwrap(np.deg2rad(m[:,7:9]),axis=0)); ax=np.argmax(np.ptp(w,axis=0)); wa=w[:,ax]-movavg(w[:,ax],T*fs*3)
    sw,nw=strokes(movavg(wa,5)[W],fs,T)
    res[art].append((os.path.basename(d.rstrip('/')),rw,T,np.median(s)*100 if len(s) else 0,np.std(s)/np.mean(s) if len(s) else 9,nh,np.median(sc)*100 if len(sc) else 0,cor,np.median(sw) if len(sw) else 0,np.std(sw)/np.mean(sw) if len(sw) else 9,nw))
for art,r in res.items():
    print('\n==',art,len(r))
    print('aufnahme            wahr  T[s] hub[cm] cv  gipfel | kausal hub[cm] korr | winkelhub[deg] cv gipfel')
    for x in r: print(f'{x[0]:20s}{x[1]:4d} {x[2]:5.1f} {x[3]:6.1f} {x[4]:4.2f} {x[5]:4d}   | {x[6]:6.1f} {x[7]:5.2f}      | {x[8]:6.1f} {x[9]:4.2f} {x[10]:4d}')
    if r:
        A=np.array([x[1:] for x in r],float)
        print('MEDIAN: hub %.1f cm, cv %.2f, |gipfel-wahr| median %.1f, kausal korr %.2f, winkelhub %.1f deg cv %.2f, |winkelgipfel-wahr| %.1f'%(np.median(A[:,2]),np.median(A[:,3]),np.median(abs(A[:,4]-A[:,0])),np.median(A[:,6]),np.median(A[:,7]),np.median(A[:,8]),np.median(abs(A[:,9]-A[:,0]))))
