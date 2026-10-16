"""Rand ueber die Gleichheit der Wiederholungen: Kette aufeinanderfolgender Takt-Abschnitte, die sich gleichen.

Signal und Takt wie Satztakt (gekappt 1,5, Takt hoechstens 3 s). Von jedem Startpunkt aus waechst eine Kette
vorwaerts und rueckwaerts: der naechste Abschnitt (Laenge T) beginnt dort, wo er dem aktuellen am besten
gleicht (Abstand 0,75..1,3 T, normierte Korrelation). Die Kette bricht ab, wenn die beste Korrelation unter
`schwelle` faellt. Gezaehlt wird die laengste Kette (Anzahl Abschnitte) plus `plus`.
"""
import numpy as np
from rand import *

def ncorr(a,b):
    """Gleichheit nach Form und Groesse: 2<a,b>/(|a|^2+|b|^2). Wie die normierte Korrelation bei gleicher
    Energie, faellt aber, wenn ein Abschnitt viel schwaecher ist (Ausklingen nach dem Ablegen)."""
    a=a-a.mean(); b=b-b.mean(); n=(a*a).sum()+(b*b).sum()
    return float(2*(a*b).sum()/n) if n>0 else 0.0

def schritt(x,start,L,richtung,lo,hi):
    """Bester naechster Abschnitt nach (richtung=+1) bzw. vor (-1) x[start:start+L]."""
    ref=x[start:start+L]; best=(-2,None)
    for d in range(int(lo*L),int(hi*L)+1):
        s=start+richtung*d
        if s<0 or s+L>len(x): continue
        r=ncorr(ref,x[s:s+L])
        if r>best[0]: best=(r,s)
    return best

def kette(x,T,schwelle=0.6,lo=0.75,hi=1.3,saat=0.25):
    """Laengste Kette sich gleichender Abschnitte -> (Anzahl Abschnitte, Startindizes, Korrelationen)."""
    L=int(round(T/DT)); best=(0,[],[])
    for s0 in range(0,len(x)-L,max(1,int(saat*L))):
        starts=[s0]; rs=[]
        for richtung in (1,-1):
            cur=s0
            while True:
                r,s=schritt(x,cur,L,richtung,lo,hi)
                if s is None or r<schwelle: break
                if richtung==1: starts.append(s); rs.append(r)
                else: starts.insert(0,s); rs.insert(0,r)
                cur=s
        if len(starts)>best[0]: best=(len(starts),starts,rs)
    return best

def zaehle_kette(k,schwelle=0.6,plus=0,**kw):
    k=np.array(kappen(k,1.5)); T,q=takt(list(k),hi=3.0)
    if not T: return None,None,None
    n,starts,rs=kette(k,T,schwelle,**kw)
    return n+plus,starts,T

if __name__=='__main__':
    import sys,os
    schwellen=[float(v) for v in sys.argv[1:]] or [0.5,0.6,0.7,0.8]
    S=alle_saetze()
    cache={s['id']:kanaele(s['acc'])['pca'] for s in S}
    base={s['id']:zaehle(cache[s['id']],1.5)[0] for s in S}
    for th in schwellen:
        print('schwelle',th)
        teile=[('abstimm',lambda s:not s['neu'])]
        if os.environ.get('PRUEF'): teile.append(('pruef',lambda s:s['neu']))
        for teil,ist in teile:
            q=[s for s in S if ist(s)]
            res=[(s,zaehle_kette(cache[s['id']],th)) for s in q]
            for s,(n,starts,T) in res:
                m=s['marke']; t0=s['t'][0] if s.get('t') else 0
                info=''
                if starts:
                    a=starts[0]*DT; b=(starts[-1]*DT+T)
                    info='kette %.1f-%.1f'%(a,b)
                    if 'satzbeginn' in m: info+=' marke %.1f-%s'%(m['satzbeginn']-t0,'%.1f'%(m['satzende']-t0) if 'satzende' in m else '?')
                print('   %s %-7s soll %2d kette %2s basis %2s  T %.2f  %s'%(s['id'],s['fam'],s['soll'],n,base[s['id']],T or 0,info))
            for plus in (0,1):
                ex=sum(n is not None and n+plus==s['soll'] for s,(n,_,_) in res)
                pm=sum(n is not None and abs(n+plus-s['soll'])<=1 for s,(n,_,_) in res)
                print('  %-8s plus %d: exakt %d/%d  +-1 %d   (basis exakt %d)'%(teil,plus,ex,len(q),pm,sum(base[s['id']]==s['soll'] for s in q)))
