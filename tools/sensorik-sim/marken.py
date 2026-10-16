"""Echte Sätze mit Marken (satzbeginn/satzende) laden und die Takt-Auswertung gegen sie messen."""
import csv,glob,json,re
from lib import *
def laden_marken(prefix='2026-10-16-13'):
    out=[]
    for d in sorted(glob.glob(R+prefix+'*')):
        a=json.load(open(d+'/aufnahme.json')); soll=(a.get('label') or {}).get('reps')
        if not soll: continue
        rows=[];marke={}
        for l in open(d+'/messwerte.csv'):
            if l.startswith('# marke'):
                _,_,n,t=l.split(); marke[n]=float(t)
            elif l[0] in 't#': continue
            else: rows.append(list(map(float,l.split(','))))
        out.append({'id':d[-7:],'fam':fam(a['kontext']['exerciseName']),'soll':soll,'acc':[(r[1],r[2],r[3]) for r in rows],
                    't':[r[0] for r in rows],'marke':marke})
    return out
def fenster(k,T,thr=0.6):
    h=huelle(k,T); pk=max(h); i0=h.index(pk); a=i0;b=i0
    while a>0 and h[a-1]>=thr*pk: a-=1
    while b<len(h)-1 and h[b+1]>=thr*pk: b+=1
    return a*DT,b*DT,pk,h
if __name__=='__main__':
    for s in laden_marken():
        k=kanaele(s['acc'])['pca']; T,q=takt(k)
        a,b,pk,h=fenster(k,T)
        m=s['marke']; ms=m.get('satzbeginn'); me=m.get('satzende')
        print(s['id'],s['fam'],'soll',s['soll'],'T %.2f q %.2f'%(T,q),'huelle %.1f-%.1f (%.1fs => %.1f Reps)'%(a,b,b-a,(b-a)/T),'marke',ms,me,
              'mark-dauer %.1fs => %.1f Reps'%((me-ms),(me-ms)/T) if ms and me else '', 'dt-beg %.1f dt-end %.1f'%(a-ms,b-me) if ms and me else '')
