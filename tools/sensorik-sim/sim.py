from lib import *
import random,statistics
def schablonen(S):
    """Aus echten Saetzen: Fenster um jeden Gipfel (Wiederholungen), Aufheben, Ablegen, Rauschen.
    Nur Saetze, deren Zaehlung (pca/huelle) mit der Eingabe uebereinstimmt, gelten als sauber."""
    out={}
    for s in S:
        acc=s['acc']; kan=kanaele(acc); gewaehlt=None
        for ach in ('pca','grav','ay'):
            k=kan[ach]; T,q=takt(k)
            if not T: continue
            if zaehle_huelle(k,T)==s['soll'] or zaehle_gipfel(k,T)==s['soll']: gewaehlt=(ach,k,T); break
        if not gewaehlt: continue
        ach,k,T=gewaehlt; n=len(k); r=int(0.6*T/DT)
        pk=[i for i in range(n) if k[i]>0 and k[i]==max(k[max(0,i-r):i+r+1])]
        best=[];cur=[]
        for i in pk:
            if cur and 0.7*T<=(i-cur[-1])*DT<=1.35*T: cur.append(i)
            else:
                if len(cur)>len(best): best=cur
                cur=[i]
        if len(cur)>len(best): best=cur
        h=int(T/DT/2)
        fenster=[acc[i-h:i+h] for i in best[1:-1] if i-h>=0 and i+h<=n]
        if len(fenster)<3: continue
        pick=acc[:max(10,best[0]-h)]; ablegen=acc[min(n-10,best[-1]+h):]
        ruhe=acc[-30:]; sd=max(0.005,statistics.pstdev([a[1] for a in ruhe]) if len(ruhe)>10 else 0.01)
        out.setdefault(s['fam'],[]).append({'id':s['id'],'T':T,'fenster':fenster,'aufheben':pick,'ablegen':ablegen,'sd':sd,'block':s['block']})
    return out
def resample(seg,f):
    """Zeit um Faktor f dehnen (f>1 langsamer)."""
    n=len(seg); m=max(2,int(round(n*f)))
    out=[]
    for j in range(m):
        x=j*(n-1)/(m-1); i=int(x); fr=x-i; i2=min(n-1,i+1)
        out.append(tuple(seg[i][c]*(1-fr)+seg[i2][c]*fr for c in range(3)))
    return out
def erzeuge(sch,n,rng,block=None,tempo=(0.8,1.3),amp=(0.8,1.25),rauschen=1.0):
    pool=[x for x in sch if block is None or x['block']==block] or sch
    quelle=rng.choice(pool)
    amp=(amp[0],amp[1]) if False else amp
    satzamp=rng.uniform(*amp)
    Tziel=rng.uniform(1.5,2.3)/DT     # Zieltakt in Messwerten: ein Tempo je Satz
    kern=[]
    for _ in range(n):
        w=rng.choice(quelle['fenster'])      # alle Wiederholungen eines Satzes aus demselben echten Satz
        a=satzamp*rng.uniform(0.8,1.2)
        w=resample(w,Tziel*rng.uniform(0.92,1.08)*(1.35 if rng.random()<0.04 else 1)/len(w))
        mean=[sum(x[c] for x in w)/len(w) for c in range(3)]
        # linearer Trend zwischen den Fensterraendern raus, damit Fenster sich aneinanderfuegen
        L=len(w); trend=[[ (w[-1][c]-w[0][c])*i/(L-1) for c in range(3)] for i in range(L)]
        kern.append([tuple(mean[c]+a*(w[i][c]-trend[i][c]-mean[c]) for c in range(3)) for i in range(L)])
    # Fenster nacheinander, Versatz zwischen Ende und Anfang ausgleichen
    ges=[]
    for w in kern:
        if ges:
            off=[ges[-1][c]-w[0][c] for c in range(3)]
            w=[tuple(x[c]+off[c] for c in range(3)) for x in w]
        ges+=w
    pick=resample(rng.choice(pool)['aufheben'],rng.uniform(0.9,1.2))
    abl=resample(rng.choice(pool)['ablegen'],rng.uniform(0.9,1.2))
    def anschluss(seg,ref,vorn):
        # Konstanten Versatz, damit das Segment an `ref` anschliesst
        if vorn: off=[ref[c]-seg[-1][c] for c in range(3)]
        else: off=[ref[c]-seg[0][c] for c in range(3)]
        return [tuple(x[c]+off[c] for c in range(3)) for x in seg]
    pick=anschluss(pick,ges[0],True); abl=anschluss(abl,ges[-1],False)
    acc=pick+ges+abl
    sd=quelle['sd']*rauschen
    acc=[tuple(x[c]+rng.gauss(0,sd) for c in range(3)) for x in acc]
    return acc,{'T':Tziel*DT,'kernStart':len(pick)*DT,'kernEnde':(len(pick)+len(ges))*DT}
if __name__=='__main__':
    S=laden(); sch=schablonen(S)
    print({f:[(x['id'],len(x['fenster']),round(x['T'],2),round(x['sd'],3)) for x in v] for f,v in sch.items()})
