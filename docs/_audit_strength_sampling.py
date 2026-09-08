"""架构审计辅助脚本 — 用于 architecture-audit-response.md 第 C-2 节。

把 lib/core/engine/element_strength.dart 的 compute() 在 Python 中重实现，
对四柱在六十甲子上均匀采样，估计 support>=80 / <=20（变格倾向）的触发频率。

注意：
- 藏干表为通行版本，可能与 bazi_core 的 BaziTable.getCangGan 有细微出入。
- 均匀采样不等于真实生日分布（月支与季节相关、四柱受历法约束），
  所以结果是量级估计而非精确频率。
- 本脚本不参与构建，仅作为审计结论的可复现依据保留。
"""
import random, itertools
GAN="甲乙丙丁戊己庚辛壬癸"
ZHI="子丑寅卯辰巳午未申酉戌亥"
GW={'甲':'木','乙':'木','丙':'火','丁':'火','戊':'土','己':'土','庚':'金','辛':'金','壬':'水','癸':'水'}
CANG={'子':['癸'],'丑':['己','癸','辛'],'寅':['甲','丙','戊'],'卯':['乙'],'辰':['戊','乙','癸'],
'巳':['丙','庚','戊'],'午':['丁','己'],'未':['己','丁','乙'],'申':['庚','壬','戊'],'酉':['辛'],
'戌':['戊','辛','丁'],'亥':['壬','甲']}
ZW={z:GW[CANG[z][0]] for z in ZHI}
GEN={'木':'火','火':'土','土':'金','金':'水','水':'木'}
CTL={'木':'土','土':'水','水':'火','火':'金','金':'木'}
def mult(e,m):
    if e==m: return 1.4
    if GEN[m]==e: return 1.2
    if GEN[e]==m: return 1.0
    if CTL[e]==m: return 0.8
    return 0.6
def prop(n): return [1.0] if n==1 else ([0.7,0.3] if n==2 else [0.6,0.3,0.1])
def support(pillars):  # [(gan,zhi)] year month day time
    m=ZW[pillars[1][1]]
    s={w:0.0 for w in '木火土金水'}
    for g,_ in pillars:
        w=GW[g]; s[w]+=1.0*mult(w,m)
    for (g,z),pw in zip(pillars,[1.0,1.8,1.0,1.0]):
        cg=CANG[z]; pr=prop(len(cg))
        for c,p in zip(cg,pr):
            w=GW[c]; s[w]+=pw*p*mult(w,m)
    tot=sum(s.values())
    de=GW[pillars[2][0]]
    re_=[k for k,v in GEN.items() if v==de][0]
    return (s[de]+s[re_])/tot*100
# sexagenary cycle
JZ=[(GAN[i%10],ZHI[i%12]) for i in range(60)]
random.seed(0)
N=300000
hi=lo=0; vals=[]
for _ in range(N):
    p=[random.choice(JZ) for _ in range(4)]
    v=support(p); vals.append(v)
    if v>=80: hi+=1
    if v<=20: lo+=1
vals.sort()
print(f"n={N}  support>=80: {hi} ({hi/N*100:.3f}%)   support<=20: {lo} ({lo/N*100:.3f}%)")
print(f"min={vals[0]:.1f} p1={vals[N//100]:.1f} p50={vals[N//2]:.1f} p99={vals[99*N//100]:.1f} max={vals[-1]:.1f}")
b={'身强(>=55)':sum(1 for v in vals if v>=55),'中和':sum(1 for v in vals if 42<v<55),'身弱(<=42)':sum(1 for v in vals if v<=42)}
print({k:f"{v/N*100:.1f}%" for k,v in b.items()})
