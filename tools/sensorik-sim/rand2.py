"""Verfahren 'rand': Rand aus der Aktivitaet, Takt nur im Randfenster. Abstimmen an alten Saetzen, pruefen an neuen."""
import math,itertools,sys
from rand import *
def aktivitaet(k,fenster_s=1.0):
    w=int(fenster_s/DT); q=[v*v for v in k]; n=len(k); c=[0]
    for v in q: c.append(c[-1]+v)
    return [math.sqrt((c[min(n,i+w//2+1)]-c[max(0,i-w//2)])/(min(n,i+w//2+1)-max(0,i-w//2))) for i in range(n)]
def rand_fenster(k,kapp=1.5,thr=0.5,fenster_s=1.0):
    kc=kappen(k,kapp); act=aktivitaet(kc,fenster_s)
    ref=sorted(act)[int(0.75*len(act))]; lim=thr*ref
    best=(0,0,0);i=0;n=len(act)
    while i<n:
        if act[i]>=lim:
            j=i
            while j<n and act[j]>=lim: j+=1
            if j-i>best[1]-best[0]: best=(i,j,0)
            i=j
        else: i+=1
    return best[0]*DT,best[1]*DT,kc
def zaehle_rand(k,kapp=1.5,thr=0.5,fenster_s=1.0,rand=0.0,bias=0.5):
    a,b,kc=rand_fenster(k,kapp,thr,fenster_s)
    seg=kc[int(a/DT):int(b/DT)]
    if len(seg)<int(4/DT): return None,(a,b),None
    T,q=takt(seg)
    if not T: return None,(a,b),None
    return int((b-a-rand)/T+0.5+bias),(a,b),T
if __name__=='__main__':
    S=alle_saetze(); K={s['id']:kanaele(s['acc'])['pca'] for s in S}
    alt=[s for s in S if not s['neu']]; neu=[s for s in S if s['neu']]
    def score(L,**kw):
        ex=pm=0
        for s in L:
            n=zaehle_rand(K[s['id']],**kw)[0]
            ex+=n==s['soll']; pm+=n is not None and abs(n-s['soll'])<=1
        return ex,pm,len(L)
    res=[]
    for kapp,thr,fs,rand,bias in itertools.product((1.5,2.0),(0.4,0.5,0.6,0.7),(0.5,1.0,2.0),(0,0.5,1.0,1.5,2.0),(0.0,0.5)):
        kw=dict(kapp=kapp,thr=thr,fenster_s=fs,rand=rand,bias=bias)
        res.append((score(alt,**kw),kw))
    res.sort(key=lambda r:(-r[0][0],-r[0][1]))
    for r,kw in res[:8]: print('alt',r,kw,'-> neu',score(neu,**kw))
