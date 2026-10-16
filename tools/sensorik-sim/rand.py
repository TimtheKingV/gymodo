"""Rand (Satzanfang/-ende) getrennt vom Takt: Ausreisser der Beschleunigung kappen, bevor Takt und Huellkurve laufen."""
import math
from marken import *
def kappen(k,faktor):
    """Kappt bei faktor x Median der Sekunden-Effektivwerte der aktiven Sekunden (obere Haelfte)."""
    n=len(k); sek=int(1/DT)
    rms=sorted(math.sqrt(sum(v*v for v in k[i:i+sek])/sek) for i in range(0,n-sek+1,sek))
    obere=rms[len(rms)//2:]; ref=obere[len(obere)//2]
    c=faktor*ref
    return [max(-c,min(c,v)) for v in k]
def zaehle(k,faktor=None,thr=0.6,bias=0.5,T=None):
    if faktor: k=kappen(k,faktor)
    if T is None:
        T,q=takt(k)
        if not T: return None,None,None
    a,b,pk,h=fenster(k,T,thr)
    return int((b-a)/T+0.5+bias),(a,b),T
def alle_saetze():
    S=laden_marken('2026-10-16-')
    for s in S: s['neu']=s['id']>='1300'
    return S
if __name__=='__main__':
    import sys
    S=alle_saetze()
    cache={s['id']:kanaele(s['acc'])['pca'] for s in S}
    for f in (None,1.2,1.5,2.0,3.0):
        print('kappen',f)
        for fam_ in ('curl','raise','triceps','press'):
            r=[(s['id'],s['soll'],zaehle(cache[s['id']],f)[0],s['neu']) for s in S if s['fam']==fam_]
            for neu in (False,True):
                q=[x for x in r if x[3]==neu]
                if q: print('  %-8s %s exakt %d/%d  +-1 %d  | %s'%(fam_,'neu' if neu else 'alt',sum(x[2]==x[1] for x in q),len(q),sum(x[2] is not None and abs(x[2]-x[1])<=1 for x in q),' '.join('%s:%s/%s'%(x[0][-7:],x[2],x[1]) for x in q)))
