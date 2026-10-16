import json,csv,glob,math,random
R='/Users/timbuttner/Documents/gymtavo/fitness-app/data/sensoraufnahmen/'
FAM={'Bizepscurl':'curl','Hammercurl':'curl','Seitheben':'raise','Trizepsstrecken':'triceps','Schulterdrücken':'press'}
def fam(name):
    for k,v in FAM.items():
        if k in name: return v
def lp(x,a):
    y=[];s=x[0]
    for v in x: s+=a*(v-s); y.append(s)
    return y
def box(x,w):
    n=len(x);c=[0]
    for v in x:c.append(c[-1]+v)
    return [(c[min(n,i+w//2+1)]-c[max(0,i-w//2)])/(min(n,i+w//2+1)-max(0,i-w//2)) for i in range(n)]
def pca1(cols):
    n=len(cols[0]); m=[sum(c)/n for c in cols]
    X=[[c[i]-m[k] for k,c in enumerate(cols)] for i in range(n)]
    C=[[sum(r[i]*r[j] for r in X)/n for j in range(3)] for i in range(3)]
    v=[1,1,1]
    for _ in range(60):
        w=[sum(C[i][j]*v[j] for j in range(3)) for i in range(3)]
        nn=math.sqrt(sum(a*a for a in w)) or 1; v=[a/nn for a in w]
    return [sum(r[k]*v[k] for k in range(3)) for r in X]
DT=0.02
def kanaele(acc,alpha=0.15,hp=3.0):
    """acc: Liste (ax,ay,az) bei 50 Hz -> dict Kanal -> hochpassgefiltertes Signal"""
    n=len(acc); w=int(hp/DT)
    tief=[lp([a[i] for a in acc],alpha) for i in range(3)]
    hoch=[[a-c for a,c in zip(x,box(x,w))] for x in tief]
    m=[sum(x[n//4:3*n//4])/max(1,(3*n//4-n//4)) for x in tief]; gn=math.sqrt(sum(v*v for v in m)) or 1; g=[v/gn for v in m]
    return {'pca':pca1(hoch),'ay':hoch[1],'grav':[sum(hoch[k][i]*g[k] for k in range(3)) for i in range(n)]}
def acorr(x,lag):
    n=len(x); return sum(x[i]*x[i+lag] for i in range(n-lag))/(n-lag)
def takt(s,lo=1.2,hi=4.0,rel=0.85):
    n=len(s); m=sum(s)/n; x=[v-m for v in s]; var=sum(v*v for v in x)/n
    if var<1e-9: return None,0
    a,b=int(lo/2/DT),min(int(hi/DT),n//2)
    c={l:acorr(x,l) for l in range(a,b+1)}
    pk=[l for l in range(a+1,b) if c[l]>c[l-1] and c[l]>=c[l+1] and c[l]>0]
    if not pk: return None,0
    mx=max(c[l] for l in pk); cand=[l for l in pk if l*DT>=lo and c[l]>=rel*mx]
    return (cand[0]*DT,c[cand[0]]/var) if cand else (None,0)
def huelle(s,T):
    w=2*math.pi/T; L=int(1.5*T/DT); co=[math.cos(w*i*DT) for i in range(len(s))]; si=[math.sin(w*i*DT) for i in range(len(s))]
    out=[]
    for i in range(len(s)):
        re=im=0
        for k in range(max(0,i-L),min(len(s),i+L+1)):
            h=0.5*(1+math.cos(math.pi*(k-i)/L)); re+=h*s[k]*co[k]; im+=h*s[k]*si[k]
        out.append(math.hypot(re,im)/L)
    return out
def zaehle_huelle(s,T,thr=0.6,bias=0.5):
    h=huelle(s,T); pk=max(h); i0=h.index(pk); a=i0
    while a>0 and h[a-1]>=thr*pk: a-=1
    b=i0
    while b<len(h)-1 and h[b+1]>=thr*pk: b+=1
    return int((b-a)*DT/T+0.5+bias)
def zaehle_gipfel(s,T,amin=0.3,amax=1.3,lo=0.7,hi=1.35,mind=0.6):
    r=int(mind*T/DT)
    pk=[i for i in range(len(s)) if s[i]>0 and s[i]==max(s[max(0,i-r):i+r+1])]
    if len(pk)<2: return len(pk)
    amp=sorted(s[i] for i in pk); med=amp[len(amp)//2]
    pk=[i for i in pk if amin*med<=s[i]<=amax*med]
    best=[];cur=[]
    for i in pk:
        if cur and lo*T<=(i-cur[-1])*DT<=hi*T: cur.append(i)
        else:
            if len(cur)>len(best): best=cur
            cur=[i]
    if len(cur)>len(best): best=cur
    return len(best)
def verfahren(acc,achse,zaehler,**kw):
    k=kanaele(acc)[achse]; T,q=takt(k)
    if not T: return None
    return zaehle_huelle(k,T,**kw) if zaehler=='huelle' else zaehle_gipfel(k,T,**kw)
def laden():
    sets=[]
    for d in sorted(glob.glob(R+'2026-10-16-*')):
        a=json.load(open(d+'/aufnahme.json')); soll=(a.get('label') or {}).get('reps')
        if not soll: continue
        rows=[list(map(float,r)) for r in list(csv.reader(open(d+'/messwerte.csv')))[1:] if r and not r[0].startswith('#')]
        sets.append({'id':d[-7:],'name':a['kontext']['exerciseName'],'fam':fam(a['kontext']['exerciseName']),'soll':soll,
                     'acc':[(r[1],r[2],r[3]) for r in rows],'block':'A' if d[-7:]<'1100' else 'B'})
    return sets
