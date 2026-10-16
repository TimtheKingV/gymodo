import pickle,sys
KOMBI,SIM,REAL=pickle.load(open(sys.argv[1] if len(sys.argv)>1 else '/tmp/sensorik-sim-ev2.pkl','rb'))
def rate(rows,i):
    n=len(rows); ex=sum(r[1][i]==r[0] for r in rows)/n; p=sum(r[1][i] is not None and abs(r[1][i]-r[0])<=1 for r in rows)/n; return ex,p
sim=[r for v in SIM.values() for r in v]; real=[r for v in REAL.values() for r in v]
print('Methode                                    sim exakt/+-1   echt exakt/+-1')
xs=[];ys=[]
for i,(a,z,kw) in enumerate(KOMBI):
    s=rate(sim,i); r=rate(real,i); xs.append(s[1]); ys.append(r[1])
    print(f'{a:5} {z:6} {str(kw):32} {s[0]*100:4.0f}% /{s[1]*100:4.0f}%     {r[0]*100:4.0f}% /{r[1]*100:4.0f}%')
import statistics
mx,my=statistics.mean(xs),statistics.mean(ys)
c=sum((x-mx)*(y-my) for x,y in zip(xs,ys))/(sum((x-mx)**2 for x in xs)**.5*sum((y-my)**2 for y in ys)**.5)
print('Korrelation sim/echt (+-1):',round(c,2))
