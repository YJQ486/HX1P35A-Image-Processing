"""Render documentation flowcharts without browser font/layout dependencies.

Requires Pillow. Run: python scripts/render_doc_diagrams.py [--font FONT_FILE]
The PNGs are rendered at 2x resolution. Every label is measured before drawing;
the renderer rejects text outside its node and verifies nonempty glyphs.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import argparse
import json
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/diagrams'
# Node: id, center x/y, label. Edges may specify intermediate routing points.
CHARTS = {
 'video_overview': dict(title='从摄像头到显示器', size=(760,880), nodes=[
  ('A',400,100,'摄像头采集'),('B',400,205,'接收原始像素'),
  ('C',400,310,'还原彩色画面'),('D',400,415,'调整颜色\n选择显示效果'),
  ('E',400,520,'暂存整帧画面'),('F',400,625,'叠加框线、文字\n和 Logo'),
  ('G',400,730,'HDMI 显示器'),('H',125,310,'自动曝光控制')],
  edges=[('A','B'),('B','C'),('C','D'),('D','E'),('E','F'),('F','G'),
         ('C','H',[], '统计明暗'),('H','A',[(125,100)],'调节曝光和增益')]),
 'system_design': dict(title='视频处理与控制分工',size=(900,1160),nodes=[
  ('A',460,100,'摄像头原始数据'),('B',460,205,'还原 RGB 彩色像素'),
  ('C',460,310,'白平衡 A / B / C'),('D',460,415,'四种显示模式'),
  ('E',460,520,'DDR 整帧缓存'),('F',460,625,'检测框和文字'),
  ('G',460,730,'运行信息面板'),('H',460,835,'安路 Logo'),
  ('I',460,940,'HDMI 输出'),('J',130,205,'自动曝光控制'),
  ('K',770,310,'红色区域检测')], edges=[
  ('A','B'),('B','C'),('C','D'),('D','E'),('E','F'),('F','G'),('G','H'),('H','I'),
  ('B','J',[],'统计明暗'),('J','A',[(130,100)],'请求调参'),
  ('C','K',[],'彩色取样'),('K','F',[(770,625)],'传递坐标')]),
 'reading_path':dict(title='推荐阅读顺序',size=(900,700),nodes=[
  ('A',450,100,'首页\n项目能做什么'),('B',450,210,'系统设计\n画面经过哪些环节'),
  ('C',450,320,'验证报告\n哪些结论有依据'),('D',450,430,'选择下一步'),
  ('E',150,580,'准备演示\n板级测试记录'),('F',450,580,'运行代码\n构建与依赖说明'),
  ('G',750,580,'研究问题\n检测或亮度专项报告')],edges=[
  ('A','B'),('B','C'),('C','D'),('D','E',[(450,505),(150,505)]),
  ('D','F'),('D','G',[(450,505),(750,505)])]),
 'validation_steps':dict(title='各类检查回答不同问题',size=(560,620),nodes=[
  ('A',280,100,'模块仿真\n给定输入是否算对'),('B',280,235,'工具构建\n是否满足已设电路要求'),
  ('C',280,370,'实物测试\n真实环境下是否正常'),('D',280,505,'持续运行\n与独立启动验收')],edges=[('A','B'),('B','C'),('C','D')]),
 'contest_steps':dict(title='后续演示与提交顺序',size=(560,840),nodes=[
  ('A',280,100,'确定最终候选\n核对文件指纹'),('B',280,230,'演示摄像头\n和四种模式'),
  ('C',280,360,'检查 Logo、按键\n和红色框选'),('D',280,490,'记录连续运行\n与复位'),
  ('E',280,620,'完成固化\n脱离电脑启动'),('F',280,750,'整理正式提交材料')],edges=[('A','B'),('B','C'),('C','D'),('D','E'),('E','F')]),
 'build_steps':dict(title='完整构建与验证过程',size=(560,840),nodes=[
  ('A',280,100,'核对版本与依赖'),('B',280,230,'综合\n代码转换成电路'),
  ('C',280,360,'布局布线\n安排位置和连线'),('D',280,490,'核查时序\n与跨时钟传递'),
  ('E',280,620,'生成 bit 配置文件'),('F',280,750,'核对文件\n进行实物测试')],edges=[('A','B'),('B','C'),('C','D'),('D','E'),('E','F')]),
 'early_frame_marker':dict(title='早期帧首错位的原因',size=(560,730),nodes=[
  ('A',280,100,'帧首通知先到'),('B',280,230,'此时数据无效'),('C',280,360,'首批像素随后到达'),
  ('D',280,490,'通知与像素\n没有同时有效'),('E',280,620,'模式请求\n没有被正确采样')],edges=[('A','B'),('B','C'),('C','D'),('D','E')]),
 'exposure_evidence':dict(title='曝光与增益的证据层次',size=(560,730),nodes=[
  ('A',280,100,'FPGA 计算\n期望曝光和增益'),('B',280,230,'通过总线发出请求'),
  ('C',280,360,'记录事务是否完成'),('D',280,490,'读取传感器寄存器'),
  ('E',280,620,'观察图像\n何时真正变化')],edges=[('A','B'),('B','C'),('C','D'),('D','E')]),
 'logo_overlay':dict(title='透明 Logo 怎样叠加',size=(740,900),nodes=[
  ('A',370,100,'从 DDR 读出画面'),('B',370,220,'叠加左上运行信息'),
  ('C',370,340,'读取右上 Logo 像素'),('D',370,460,'该点是否透明'),
  ('E',180,620,'保留底图'),('F',560,620,'显示 Logo 颜色'),('G',370,790,'HDMI 输出')],edges=[
  ('A','B'),('B','C'),('C','D'),('D','E',[(370,540),(180,540)],'透明'),
  ('D','F',[(370,540),(560,540)],'不透明'),('E','G',[(180,710),(370,710)]),
  ('F','G',[(560,710),(370,710)])]),
 'red_original':dict(title='原红框为什么会扩大',size=(760,850),nodes=[
  ('A',440,100,'白平衡后的彩色数据'),('B',440,230,'判断像素是否足够红'),
  ('C',440,360,'累计全画面的命中点'),('D',440,490,'按全部红点的\n最外侧位置画框'),
  ('E',130,360,'远处同色小块'),('F',440,640,'可能跨过大片背景')],edges=[
  ('A','B'),('B','C'),('C','D'),('D','F'),('E','C',[],'也参与统计')]),
 'red_stability':dict(title='修复后的红色区域筛选',size=(560,1100),nodes=[
  ('A',280,100,'白平衡后的彩色画面'),('B',280,230,'按原阈值\n判断红色像素'),
  ('C',280,360,'分成 32×32 像素小块\n分别计数'),('D',280,490,'筛出红点较密集的小块'),
  ('E',280,620,'连接相邻块行中\n符合条件的区域'),('F',280,750,'选择累计支持量\n最大的区域链'),
  ('G',280,880,'连续帧确认\n处理短暂缺失'),('H',280,1010,'传到显示端画黄框')],edges=[
  ('A','B'),('B','C'),('C','D'),('D','E'),('E','F'),('F','G'),('G','H')]),
}

def render(name, spec, font_path, scale):
    w,h=spec['size']
    image=Image.new('RGB',(w*scale,h*scale),'white')
    draw=ImageDraw.Draw(image)
    font=ImageFont.truetype(str(font_path),20*scale)
    small=ImageFont.truetype(str(font_path),16*scale)
    title=ImageFont.truetype(str(font_path),24*scale)
    # Widths follow text measurements, not browser fallback font metrics.
    rects={}
    checks=[]
    def label(x,y,text,f,fill='#20324d',pad=0):
        x,y=x*scale,y*scale
        box=draw.multiline_textbbox((0,0),text,font=f,spacing=7*scale,align='center')
        tw,th=box[2]-box[0],box[3]-box[1]
        pos=(x-tw/2-box[0],y-th/2-box[1])
        bounds=draw.multiline_textbbox(pos,text,font=f,spacing=7*scale,align='center')
        assert all(math.isfinite(v) for v in bounds)
        assert bounds[0]>=0 and bounds[1]>=0 and bounds[2]<=w*scale and bounds[3]<=h*scale,(name,text,'canvas')
        if pad:
            draw.rounded_rectangle((bounds[0]-pad,bounds[1]-pad,bounds[2]+pad,bounds[3]+pad),radius=4*scale,fill='white')
        draw.multiline_text(pos,text,font=f,spacing=7*scale,align='center',fill=fill)
        checks.append(dict(text=text,bounds=[round(v/scale,2) for v in bounds]))
        return bounds
    for ident,x,y,text in spec['nodes']:
        lines=text.splitlines()
        tw=max(draw.textlength(line,font=font)/scale for line in lines)
        nw=max(210,tw+36)
        nh=76 if len(lines)>1 else 62
        rects[ident]=(x-nw/2,y-nh/2,x+nw/2,y+nh/2)
    def endpoint(ident,toward):
        l,t,r,b=rects[ident]; cx=(l+r)/2;cy=(t+b)/2
        dx,dy=toward[0]-cx,toward[1]-cy
        ratio=min((r-l)/2/abs(dx) if dx else float('inf'),(b-t)/2/abs(dy) if dy else float('inf'))
        return (cx+dx*ratio,cy+dy*ratio)
    centers={i:(x,y) for i,x,y,_ in spec['nodes']}
    for edge in spec['edges']:
        a,b=edge[:2]; via=edge[2] if len(edge)>2 else []; note=edge[3] if len(edge)>3 else None
        points=[endpoint(a,via[0] if via else centers[b]),*via,endpoint(b,via[-1] if via else centers[a])]
        pts=[(x*scale,y*scale) for x,y in points]
        draw.line(pts,fill='#6d819e',width=2*scale,joint='curve')
        x,y=pts[-1];px,py=pts[-2];angle=math.atan2(y-py,x-px)
        back=11*scale;wing=5*scale
        draw.polygon([(x,y),(x-back*math.cos(angle)+wing*math.sin(angle),y-back*math.sin(angle)-wing*math.cos(angle)),(x-back*math.cos(angle)-wing*math.sin(angle),y-back*math.sin(angle)+wing*math.cos(angle))],fill='#6d819e')
        if note:
            # Place notes on a long segment, outside all node rectangles.
            index=max(range(len(points)-1),key=lambda j:math.dist(points[j],points[j+1]))
            p,q=points[index:index+2]
            nx,ny=(p[0]+q[0])/2,(p[1]+q[1])/2
            if abs(p[1]-q[1])<1:ny-=18
            else:nx+=54
            label(nx,ny,note,small,fill='#53657e',pad=3*scale)
    label(w/2,35,spec['title'],title)
    for ident,x,y,text in spec['nodes']:
        rect=rects[ident]
        assert rect[0]>=12 and rect[2]<=w-12 and rect[1]>=60 and rect[3]<=h-12,(name,ident,rect)
        draw.rounded_rectangle(tuple(v*scale for v in rect),radius=12*scale,fill='#eff5ff',outline='#94afd2',width=2*scale)
        bounds=label(x,y,text,font)
        # At least 12 pixels horizontally and 10 vertically around the glyphs.
        assert bounds[0]>= (rect[0]+12)*scale and bounds[2]<=(rect[2]-12)*scale,(name,ident,'width')
        assert bounds[1]>= (rect[1]+10)*scale and bounds[3]<=(rect[3]-10)*scale,(name,ident,'height')
    node_texts={text for _,_,_,text in spec['nodes']}
    for check in checks:
        if check['text'] in node_texts:
            continue
        l,t,r,b=check['bounds']
        for ident,(nl,nt,nr,nb) in rects.items():
            assert r<=nl or l>=nr or b<=nt or t>=nb,(name,check['text'],'overlaps',ident)
    OUT.mkdir(exist_ok=True)
    image.save(OUT/(name+'.png'),optimize=True)
    return {'name':name,'size':image.size,'labels':checks,'nodes':len(rects)}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font',type=Path,default=Path('C:/Windows/Fonts/msyh.ttc'))
    parser.add_argument('--scale',type=int,default=2)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    if not args.font.is_file():parser.error('Pass --font with a CJK font file')
    if args.scale<1:parser.error('--scale must be positive')
    results=[render(name,spec,args.font,args.scale) for name,spec in CHARTS.items()]
    if args.report:
        args.report.write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'diagrams':len(results),'nodes':sum(x['nodes'] for x in results),'text_bounds':'pass'},ensure_ascii=False))

if __name__=='__main__':main()
