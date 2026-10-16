from sim import *
import pickle,sys
S=laden(); sch=schablonen(S)
KOMBI=[(a,z,kw) for a in ('pca','ay','grav') for z,kws in (('huelle',[dict(thr=0.6,bias=0.5)]),('gipfel',[dict(amin=0.3,amax=1.3),dict(amin=0.3,amax=1.8)])) for kw in kws]
def alle(acc):
    kan=kanaele(acc); out=[]
    for a,z,kw in KOMBI:
        k=kan[a]; T,q=takt(k)
        out.append(None if not T else (zaehle_huelle(k,T,**kw) if z=='huelle' else zaehle_gipfel(k,T,**kw)))
    return out
rng=random.Random(7)
N=int(sys.argv[1]) if len(sys.argv)>1 else 24
SIM={}   # (fam, blockQuelle) -> Liste (soll, [ergebnisse je Kombi])
for f in sch:
    for blk in 'AB':
        pool=[x for x in sch[f] if x['block']==blk]
        if len(pool)<2: continue
        rows=[]
        for _ in range(N):
            n=rng.randint(4,12); acc,_m=erzeuge(pool,n,rng,block=blk)
            rows.append((n,alle(acc)))
        SIM[(f,blk)]=rows
REAL={}
for s in S:
    REAL.setdefault((s['fam'],s['block']),[]).append((s['soll'],alle(s['acc'])))
pickle.dump((KOMBI,SIM,REAL),open('/tmp/sensorik-sim-ev2.pkl','wb'))
def stat(rows,i):
    ex=sum(r[1][i]==r[0] for r in rows); p=sum(r[1][i] is not None and abs(r[1][i]-r[0])<=1 for r in rows); return ex,p,len(rows)
print('Spalten: sim(Vorlagen A) | echt B ;  sim(Vorlagen B) | echt A     [exakt/+-1 von n]')
for f in ('curl','raise','triceps','press'):
    print(f)
    for i,(a,z,kw) in enumerate(KOMBI):
        c=[]
        for sk,rk in ((('A'),'B'),('B','A')):
            s1=stat(SIM[(f,sk)],i) if (f,sk) in SIM else None; r1=stat(REAL[(f,rk)],i) if (f,rk) in REAL else None
            c.append(f'sim{sk} {s1[0]}/{s1[1]} von {s1[2]} | echt{rk} {r1[0]}/{r1[1]} von {r1[2]}' if s1 and r1 else '-')
        print(f'  {a:5} {z:6} {str(kw):34}',' ;; '.join(c))
