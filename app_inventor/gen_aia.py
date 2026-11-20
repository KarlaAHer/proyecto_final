import json, zipfile, sys, itertools
from xml.sax.saxutils import escape
OUT=sys.argv[1]
PROJ="BrailleFPGA"; USER="ai_braille"
uid=itertools.count(100000)
def C(typ,name,ver,props=None,children=None):
    d={"$Name":name,"$Type":typ,"$Version":str(ver),"Uuid":str(next(uid))}
    if props: d.update({k:str(v) for k,v in props.items()})
    if children: d["$Components"]=children
    return d
FILL="-2"
PRI="&HFF1E3A5F"; ACC="&HFFF47B20"; WHITE="&HFFFFFFFF"; GRAY="&HFF6B7280"; BG="&HFFF1F3F7"
def lbl(name,text,**p):
    d=dict(Text=text,Width=FILL); d.update(p); return C("Label",name,5,d)
def btn(name,text,**p): return C("Button",name,6,dict(Text=text,**p))
def ha(name,ch,**p):
    d=dict(Width=FILL,AlignVertical="2"); d.update(p); return C("HorizontalArrangement",name,3,d,ch)
def va(name,ch,**p):
    d=dict(Width=FILL); d.update(p); return C("VerticalArrangement",name,3,d,ch)
sp_n=itertools.count(1)
def sp(h="12"): return C("Label",f"Esp{next(sp_n)}",5,dict(Text="",Height=h,Width=FILL))
def hsp(): return C("Label",f"Esp{next(sp_n)}",5,dict(Text="",Width="8"))
def card(name,ch): return va(name,ch,BackgroundColor=WHITE,Width="-1092",AlignHorizontal="3")
def title(name,text): return lbl(name,text,FontSize="24",FontBold="True",TextColor=PRI,TextAlignment="1")
def tab(name,text): return btn(name,text,Width="-1025",Height=FILL,BackgroundColor=WHITE,TextColor=GRAY,FontBold="True",FontSize="13",Shape="0")
def pbtn(name,text,color=PRI,**p): return btn(name,text,BackgroundColor=color,TextColor=WHITE,FontBold="True",Shape="1",**p)
comps=[
 ha("HAHeader",[lbl("LblTitulo","  Braille FPGA",FontSize="20",FontBold="True",TextColor=WHITE),
                C("Label","LblConex",5,dict(Text="● Desconectado  ",TextColor="&HFFFF8A80",FontBold="True"))],
    BackgroundColor=PRI,Height="56"),
 ha("HATabs",[tab("BtnTabInicio","Inicio"),tab("BtnTabLectura","Lectura"),
              tab("BtnTabEscritura","Escritura"),tab("BtnTabPractica","Práctica")],
    BackgroundColor=WHITE,Height="48"),
 C("Label","LblLinea",5,dict(Text="",Height="3",Width=FILL,BackgroundColor=ACC)),
 # ---------- INICIO ----------
 va("VAInicio",[
   sp("24"),
   lbl("LblHomeTitulo","Sistema Bidireccional\nTexto ↔ Braille",FontSize="26",FontBold="True",TextColor=PRI,TextAlignment="1"),
   lbl("LblHomeSub","FPGA DE10-Lite  ·  Sistemas Embebidos  ·  UDLAP",TextColor=GRAY,TextAlignment="1"),
   sp("20"),
   card("VACardCon",[
     sp("8"),
     lbl("LblConTit","Conexión Bluetooth",FontBold="True",FontSize="16",TextColor=PRI,TextAlignment="1"),
     sp("6"),
     C("ListPicker","LPConectar",9,dict(Text="Conectar al HC-05",BackgroundColor=PRI,TextColor=WHITE,FontBold="True",Shape="1",Width="-1080",Title="Elige el HC-05")),
     sp("6"),
     btn("BtnDesconectar","Desconectar",Width="-1080",Shape="1",BackgroundColor="&HFFE5E7EB",TextColor=PRI),
     C("CheckBox","ChkVoz",2,dict(Text="Voz activada",Checked="True")),
     sp("8")]),
   sp("16"),
   card("VACardModos",[
     sp("8"),
     lbl("LblModosTit","Los modos se eligen en la tarjeta",FontBold="True",FontSize="16",TextColor=PRI,TextAlignment="1"),
     lbl("LblModosTxt","SW1 SW0 = 01  →  Lectura\nSW1 SW0 = 10  →  Escritura\nSW1 SW0 = 11  →  Práctica  (SW2 = pista)\nSW1 SW0 = 00  →  Inicio",FontSize="15",TextAlignment="1"),
     sp("8"),
     lbl("LblModoActual","Modo de la tarjeta: —",FontBold="True",TextColor=ACC,TextAlignment="1"),
     sp("8")]),
 ],AlignHorizontal="3"),
 # ---------- LECTURA ----------
 va("VALectura",[
   sp("16"), title("LblTitR","Lectura"),
   lbl("LblSubR","Escribe una palabra; la celda la muestra letra por letra",TextColor=GRAY,TextAlignment="1"),
   sp("12"),
   card("VACardPal",[sp("8"),
     ha("HAPalabra",[C("TextBox","TxtPalabra",6,dict(Hint="Palabra (máx. 16)",Width=FILL,FontSize="16")),
                     pbtn("BtnEnviar","Enviar",ACC)],Width="-1090"),
     sp("8")]),
   sp("12"),
   card("VACardLetra",[lbl("LblLetra","—",FontSize="120",FontBold="True",TextColor=PRI,TextAlignment="1"),
                       lbl("LblInfoR","Avanza con KEY1 (NEXT) en la tarjeta",TextColor=GRAY,TextAlignment="1"),sp("10")]),
 ],AlignHorizontal="3",Visible="False"),
 # ---------- ESCRITURA ----------
 va("VAEscritura",[
   sp("16"), title("LblTitW","Escritura"),
   lbl("LblSubW","Forma la letra en el teclado Braille. KEY1 = espacio",TextColor=GRAY,TextAlignment="1"),
   sp("12"),
   card("VACardTexto",[sp("8"),
     lbl("LblTexto","",FontSize="30",TextColor=PRI,Height="160",Width="-1090"),
     lbl("LblUlt","",TextColor=ACC,FontBold="True",TextAlignment="1"),sp("8")]),
   sp("12"),
   ha("HABotonesW",[pbtn("BtnLeer","Leer en voz alta",PRI,Width="-1045"),
                    hsp(),
                    pbtn("BtnBorrar","Borrar",GRAY,Width="-1045")],Width="-1092"),
 ],AlignHorizontal="3",Visible="False"),
 # ---------- PRACTICA ----------
 va("VAPractica",[
   sp("16"), title("LblTitP","Práctica"),
   lbl("LblSubP","La FPGA elige la letra y te califica. KEY1 = saltar · SW2 = pista",TextColor=GRAY,TextAlignment="1"),
   sp("10"),
   card("VACardN",[sp("6"),
     ha("HALetras",[C("Label","LblN",5,dict(Text="Letras por sesión: ",FontBold="True",TextColor=PRI)),
                    C("TextBox","TxtN",6,dict(Text="10",NumbersOnly="True",Width="60")),
                    pbtn("BtnAplicarN","Aplicar",ACC),
                    C("Label","LblN0",5,dict(Text="  0 = sin límite",TextColor=GRAY))],Width="-1090"),
     sp("6")]),
   sp("10"),
   card("VACardObj",[lbl("LblInfoP","Esperando letra…",TextColor=GRAY,TextAlignment="1"),
                     lbl("LblObjetivo","—",FontSize="110",FontBold="True",TextColor=PRI,TextAlignment="1"),sp("6")]),
   sp("10"),
   ha("HAStats",[
     va("VAHits",[lbl("LblHits","0",FontSize="28",FontBold="True",TextColor="&HFF16A34A",TextAlignment="1"),
                  lbl("LblHitsT","Aciertos",TextColor=GRAY,TextAlignment="1")],BackgroundColor=WHITE,Width="-1032"),
     hsp(),
     va("VAMiss",[lbl("LblMiss","0",FontSize="28",FontBold="True",TextColor="&HFFDC2626",TextAlignment="1"),
                  lbl("LblMissT","Errores",TextColor=GRAY,TextAlignment="1")],BackgroundColor=WHITE,Width="-1032"),
     hsp(),
     va("VAAcc",[lbl("LblAcc","0 %",FontSize="28",FontBold="True",TextColor=PRI,TextAlignment="1"),
                 lbl("LblAccT","Precisión",TextColor=GRAY,TextAlignment="1")],BackgroundColor=WHITE,Width="-1032"),
   ],Width="-1092"),
   sp("10"),
   card("VACardGraf",[lbl("LblGraf","Precisión acumulada  (arriba 100 % · abajo 0 %)",FontSize="12",TextColor=GRAY,TextAlignment="1"),
     C("Canvas","Canvas1",10,dict(Width="-1095",Height="180",BackgroundColor="&HFFF8FAFC",LineWidth="4",PaintColor="&HFFF47B20")),sp("6")]),
 ],AlignHorizontal="3",Visible="False"),
 sp("10"),
 lbl("LblLog","",FontSize="12",TextColor=GRAY,TextAlignment="1"),
 C("BluetoothClient","BluetoothClient1",5,dict(CharacterEncoding="ISO-8859-1")),
 C("Clock","Clock1",3,dict(TimerInterval="100",TimerEnabled="False",TimerAlwaysFires="True")),
 C("TextToSpeech","TextToSpeech1",5,dict(Language="es")),
]
form={"$Name":"Screen1","$Type":"Form","$Version":"27","AppName":PROJ,"Title":"Braille FPGA",
      "TitleVisible":"False","BackgroundColor":BG,"Scrollable":"True","Sizing":"Responsive",
      "AlignHorizontal":"3","Uuid":"0","$Components":comps}
scm='#|\n$JSON\n'+json.dumps({"authURL":["ai2.appinventor.mit.edu"],"YaVersion":"208","Source":"Form","Properties":form},ensure_ascii=False)+'\n|#'

# ---------------- blocks ----------------
TYPES={}
def walk(cs):
    for c in cs:
        TYPES[c["$Name"]]=c["$Type"]; walk(c.get("$Components",[]))
walk(comps)
def v(name,blk): return f'<value name="{name}">{blk}</value>'
def st(name,stmts): return f'<statement name="{name}">{chain(stmts)}</statement>' if stmts else ''
def chain(stmts):
    if not stmts: return ''
    s=stmts[0]; rest=chain(stmts[1:])
    return s[:-len('</block>')]+(f'<next>{rest}</next>' if rest else '')+'</block>'
def txt(t): return f'<block type="text"><field name="TEXT">{escape(t)}</field></block>'
def num(n): return f'<block type="math_number"><field name="NUM">{n}</field></block>'
def boolean(b): return f'<block type="logic_boolean"><field name="BOOL">{"TRUE" if b else "FALSE"}</field></block>'
def color(c,h): return f'<block type="color_{c}"><field name="COLOR">{h}</field></block>'
def get(var): return f'<block type="lexical_variable_get"><field name="VAR">{var}</field></block>'
def gset(var,val): return f'<block type="lexical_variable_set"><field name="VAR">{var}</field>{v("VALUE",val)}</block>'
def join(*a): return f'<block type="text_join"><mutation items="{len(a)}"></mutation>'+''.join(v(f"ADD{i}",x) for i,x in enumerate(a))+'</block>'
def seg(t,s,l): return f'<block type="text_segment">{v("TEXT",t)}{v("START",num(s))}{v("LENGTH",num(l))}</block>'
def tlen(t): return f'<block type="text_length">{v("VALUE",t)}</block>'
def trim(t): return f'<block type="text_trim">{v("TEXT",t)}</block>'
def upc(t): return f'<block type="text_changeCase"><field name="OP">UPCASE</field>{v("TEXT",t)}</block>'
def eq(a,b): return f'<block type="logic_compare"><field name="OP">EQ</field>{v("A",a)}{v("B",b)}</block>'
def mcmp(op,a,b): return f'<block type="math_compare"><field name="OP">{op}</field>{v("A",a)}{v("B",b)}</block>'
def lor(a,b): return f'<block type="logic_operation"><mutation items="2"></mutation><field name="OP">OR</field>{v("A",a)}{v("B",b)}</block>'
def land(a,b): return f'<block type="logic_operation"><mutation items="2"></mutation><field name="OP">AND</field>{v("A",a)}{v("B",b)}</block>'
def add(a,b): return f'<block type="math_add"><mutation items="2"></mutation>{v("NUM0",a)}{v("NUM1",b)}</block>'
def mul(a,b): return f'<block type="math_multiply"><mutation items="2"></mutation>{v("NUM0",a)}{v("NUM1",b)}</block>'
def div(a,b): return f'<block type="math_division">{v("A",a)}{v("B",b)}</block>'
def rnd(a): return f'<block type="math_round"><field name="OP">ROUND</field>{v("NUM",a)}</block>'
def mmax(a,b): return f'<block type="math_on_list"><mutation items="2"></mutation><field name="OP">MAX</field>{v("NUM0",a)}{v("NUM1",b)}</block>'
def hex2dec(a): return f'<block type="math_convert_number"><field name="OP">HEX_TO_DEC</field>{v("NUM",a)}</block>'
def choose(t,a,b): return f'<block type="controls_choose">{v("TEST",t)}{v("THENRETURN",a)}{v("ELSERETURN",b)}</block>'
def mut(comp): return f'is_generic="false" instance_name="{comp}"'
def pset(comp,prop,val): return (f'<block type="component_set_get"><mutation component_type="{TYPES[comp]}" set_or_get="set" property_name="{prop}" {mut(comp)}></mutation>'
                                 f'<field name="COMPONENT_SELECTOR">{comp}</field><field name="PROP">{prop}</field>{v("VALUE",val)}</block>')
def pget(comp,prop): return (f'<block type="component_set_get"><mutation component_type="{TYPES[comp]}" set_or_get="get" property_name="{prop}" {mut(comp)}></mutation>'
                             f'<field name="COMPONENT_SELECTOR">{comp}</field><field name="PROP">{prop}</field></block>')
def call(comp,meth,*args): return (f'<block type="component_method"><mutation component_type="{TYPES[comp]}" method_name="{meth}" {mut(comp)}></mutation>'
                                   f'<field name="COMPONENT_SELECTOR">{comp}</field>'+''.join(v(f"ARG{i}",a) for i,a in enumerate(args))+'</block>')
def event(comp,ev,stmts,x,y): return (f'<block type="component_event" x="{x}" y="{y}"><mutation component_type="{TYPES[comp] if comp!="Screen1" else "Form"}" {mut(comp)} event_name="{ev}"></mutation>'
                                      f'<field name="COMPONENT_SELECTOR">{comp}</field>{st("DO",stmts)}</block>')
def ifs(conds,elsest=None):
    n=len(conds)
    m=f'<mutation elseif="{n-1}" else="{1 if elsest else 0}"></mutation>' if (n>1 or elsest) else ''
    body=''.join(v(f"IF{i}",c)+st(f"DO{i}",s) for i,(c,s) in enumerate(conds))
    return f'<block type="controls_if">{m}{body}{st("ELSE",elsest) if elsest else ""}</block>'
def whileb(t,stmts): return f'<block type="controls_while">{v("TEST",t)}{st("STATEMENT",stmts)}</block>'
def local(names_vals,stmts):
    m='<mutation>'+''.join(f'<localname name="{n}"></localname>' for n,_ in names_vals)+'</mutation>'
    f=''.join(f'<field name="VAR{i}">{n}</field>' for i,(n,_) in enumerate(names_vals))
    d=''.join(v(f"DECL{i}",val) for i,(_,val) in enumerate(names_vals))
    return f'<block type="local_declaration_statement">{m}{f}{d}{st("STACK",stmts)}</block>'
def proc(name,args,stmts,x,y):
    m='<mutation>'+''.join(f'<arg name="{a}"></arg>' for a in args)+'</mutation>'
    f=''.join(f'<field name="VAR{i}">{a}</field>' for i,a in enumerate(args))
    return f'<block type="procedures_defnoreturn" x="{x}" y="{y}">{m}<field name="NAME">{name}</field>{f}{st("STACK",stmts)}</block>'
def pcall(name,args,vals):
    m=f'<mutation name="{name}">'+''.join(f'<arg name="{a}"></arg>' for a in args)+'</mutation>'
    return f'<block type="procedures_callnoreturn">{m}<field name="PROCNAME">{name}</field>'+''.join(v(f"ARG{i}",x) for i,x in enumerate(vals))+'</block>'
def gdecl(name,val,x,y): return f'<block type="global_declaration" x="{x}" y="{y}"><field name="NAME">{name}</field>{v("VALUE",val)}</block>'

hablar=lambda t: pcall("hablar",["txt"],[t])
enviar=lambda t: pcall("enviar",["txt"],[t])
L=lambda n: get(n)
blocks=[]
def put(b): blocks.append(b)
NL=txt("\\n")
def startsat(t,p): return f'<block type="text_starts_at">{v("TEXT",t)}{v("PIECE",p)}</block>'
def sub(a,b): return f'<block type="math_subtract">{v("A",a)}{v("B",b)}</block>'
put(gdecl("intentos",num(0),0,0))
put(gdecl("nLetras",num(10),0,40))
put(gdecl("palabraW",txt(""),0,80))
put(gdecl("buf",txt(""),0,120))
put(gdecl("px",num(-1),250,0))
put(gdecl("py",num(0),250,40))

# ---------- Conexion ----------
put(event("LPConectar","BeforePicking",[pset("LPConectar","Elements",pget("BluetoothClient1","AddressesAndNames"))],0,180))
put(event("LPConectar","AfterPicking",[
  ifs([(call("BluetoothClient1","Connect",pget("LPConectar","Selection")),
        [pset("LblConex","Text",txt("● Conectado  ")),
         pset("LblConex","TextColor",color("green","#86efac")),
         gset("global buf",txt("")),
         pset("Clock1","TimerEnabled",boolean(True)),
         pset("LblLog","Text",txt("Conectado. Consultando el modo de la tarjeta…")),
         enviar(txt("Q"))])],
      [pset("LblLog","Text",txt("No se pudo conectar. ¿El HC-05 está encendido y emparejado?"))])],0,260))
put(event("BtnDesconectar","Click",[
  pset("Clock1","TimerEnabled",boolean(False)),
  call("BluetoothClient1","Disconnect"),
  pset("LblConex","Text",txt("● Desconectado  ")),
  pset("LblConex","TextColor",color("pink","#ff8a80"))],0,460))
# enviar: texto + byte 10 ('\n') como numero, sin depender de escapes
put(proc("enviar",["txt"],[
  ifs([(pget("BluetoothClient1","IsConnected"),
        [call("BluetoothClient1","SendText",L("txt")),
         call("BluetoothClient1","Send1ByteNumber",num(10))])],
      [pset("LblLog","Text",txt("No conectado"))])],0,560))
# Recepcion: junta lo que llega y separa por lineas
put(event("Clock1","Timer",[
  ifs([(land(pget("BluetoothClient1","IsConnected"),
             mcmp("GT",pget("BluetoothClient1","BytesAvailableToReceive"),num(0))),
        [gset("global buf",join(L("global buf"),
              call("BluetoothClient1","ReceiveText",pget("BluetoothClient1","BytesAvailableToReceive"))))])]),
  whileb(mcmp("GT",startsat(L("global buf"),NL),num(0)),[
    local([("p",startsat(L("global buf"),NL))],[
      pcall("procesar",["raw"],[seg(L("global buf"),1,None) if False else
            f'<block type="text_segment">{v("TEXT",L("global buf"))}{v("START",num(1))}{v("LENGTH",sub(L("p"),num(1)))}</block>']),
      gset("global buf",f'<block type="text_segment">{v("TEXT",L("global buf"))}{v("START",add(L("p"),num(1)))}{v("LENGTH",sub(tlen(L("global buf")),L("p")))}</block>')])])],0,680))

# ---------- Procesar mensajes ----------
def T(ch): return eq(L("t"),txt(ch))
put(proc("procesar",["raw"],[local([("linea",trim(L("raw")))],[
  ifs([(mcmp("GT",tlen(L("linea")),num(0)),[
    local([("t",seg(L("linea"),1,1)),
           ("c",choose(mcmp("GTE",tlen(L("linea")),num(2)),seg(L("linea"),2,1),txt(" ")))],[
      ifs([
        (T("M"),[pcall("mostrarModo",["m"],[L("c")])]),
        (T("D"),[pset("LblLetra","Text",upc(L("c"))),
                 pset("LblInfoR","Text",txt("Avanza con KEY1 (NEXT) en la tarjeta")),
                 hablar(L("c"))]),
        (T("E"),[pset("LblLetra","Text",txt("—")),
                 pset("LblInfoR","Text",txt("Fin de la palabra. Escribe otra."))]),
        (T("K"),[pcall("letraEscrita",["c"],[L("c")])]),
        (T("T"),[pset("LblObjetivo","Text",upc(L("c"))),
                 pset("LblObjetivo","TextColor",color("dark_gray","#1e3a5f")),
                 pset("LblInfoP","Text",join(txt("Letra "),add(L("global intentos"),num(1)),txt(" de "),L("global nLetras"),txt(" · escríbela"))),
                 hablar(join(txt("Letra "),L("c")))]),
        (lor(T("O"),T("X")),[pcall("resultado",["linea"],[L("linea")])]),
        (T("F"),[pcall("finSesion",["linea"],[L("linea")])]),
        (T("L"),[gset("global nLetras",hex2dec(seg(L("linea"),2,2))),
                 pset("LblLog","Text",join(txt("Letras por sesión: "),L("global nLetras")))]),
        (T("!"),[pset("LblLog","Text",join(txt("Aviso de la FPGA: "),L("linea")))]),
      ],[pset("LblLog","Text",L("linea"))])
    ])
  ])])])],500,0))

# ---------- Pestanas ----------
TABS=[("I","VAInicio","BtnTabInicio"),("R","VALectura","BtnTabLectura"),
      ("W","VAEscritura","BtnTabEscritura"),("P","VAPractica","BtnTabPractica")]
def Tm(ch): return eq(L("t"),txt(ch))
tabst=[]
for ch,vaN,bt in TABS:
    tabst+= [pset(vaN,"Visible",Tm(ch)),
             pset(bt,"BackgroundColor",choose(Tm(ch),color("orange","#f47b20"),color("white","#ffffff"))),
             pset(bt,"TextColor",choose(Tm(ch),color("white","#ffffff"),color("gray","#6b7280")))]
put(proc("mostrarTab",["t"],tabst,500,1000))
for ch,vaN,bt in TABS:
    put(event(bt,"Click",[pcall("mostrarTab",["t"],[txt(ch)])],1700,800+TABS.index((ch,vaN,bt))*80))

def M(ch): return eq(L("m"),txt(ch))
put(proc("mostrarModo",["m"],[
  pcall("mostrarTab",["t"],[choose(lor(lor(M("R"),M("W")),M("P")),L("m"),txt("I"))]),
  ifs([(M("R"),[pset("LblModoActual","Text",txt("Modo de la tarjeta: LECTURA")),pset("LblLetra","Text",txt("—"))]),
       (M("W"),[pset("LblModoActual","Text",txt("Modo de la tarjeta: ESCRITURA"))]),
       (M("P"),[pset("LblModoActual","Text",txt("Modo de la tarjeta: PRÁCTICA")),
                gset("global intentos",num(0)),
                pcall("grafReset",[],[]),
                pset("LblObjetivo","Text",txt("—")),
                pset("LblHits","Text",num(0)),
                pset("LblMiss","Text",num(0)),
                pset("LblAcc","Text",txt("0 %")),
                gset("global nLetras",pget("TxtN","Text")),
                enviar(join(txt("L"),pget("TxtN","Text")))])],
      [pset("LblModoActual","Text",txt("Modo de la tarjeta: INICIO (reposo)"))]),
  hablar(pget("LblModoActual","Text"))],500,1400))

# ---------- Escritura ----------
def CC(ch): return eq(L("c"),txt(ch))
put(proc("letraEscrita",["c"],[
  ifs([(CC("?"),[pset("LblUlt","Text",txt("Patrón no reconocido"))]),
       (CC(" "),[hablar(L("global palabraW")),
                 gset("global palabraW",txt("")),
                 pset("LblTexto","Text",join(pget("LblTexto","Text"),txt(" "))),
                 pset("LblUlt","Text",txt("Espacio"))])],
      [pset("LblTexto","Text",join(pget("LblTexto","Text"),L("c"))),
       gset("global palabraW",join(L("global palabraW"),L("c"))),
       pset("LblUlt","Text",join(txt("Última letra: "),upc(L("c")))),
       hablar(L("c"))])],500,1800))

# ---------- Practica ----------
def stats(h,e,acc): return [pset("LblHits","Text",h),pset("LblMiss","Text",e),pset("LblAcc","Text",join(acc,txt(" %")))]
ACCX=lambda: rnd(div(mul(num(100),L("h")),mmax(num(1),add(L("h"),L("e")))))
put(proc("resultado",["linea"],[
  local([("h",hex2dec(seg(L("linea"),3,2))),("e",hex2dec(seg(L("linea"),5,2)))],[
    gset("global intentos",add(L("h"),L("e"))),
    local([("acc",ACCX())],[
      ifs([(eq(seg(L("linea"),1,1),txt("O")),
            [pset("LblObjetivo","TextColor",color("green","#16a34a")),
             pset("LblInfoP","Text",txt("¡Correcto!")),
             hablar(txt("Correcto"))])],
          [pset("LblObjetivo","TextColor",color("red","#dc2626")),
           pset("LblInfoP","Text",join(txt("Incorrecto · escribiste "),upc(seg(L("linea"),2,1)))),
           hablar(txt("Incorrecto"))]),
      *stats(L("h"),L("e"),L("acc")),
      pcall("grafPunto",["n","acc"],[L("global intentos"),L("acc")]),
    ])
  ])],1100,0))
put(proc("finSesion",["linea"],[
  local([("h",hex2dec(seg(L("linea"),2,2))),("e",hex2dec(seg(L("linea"),4,2)))],[
    local([("acc",ACCX())],[
      pset("LblObjetivo","Text",txt("✓")),
      pset("LblObjetivo","TextColor",color("orange","#f47b20")),
      pset("LblInfoP","Text",txt("Sesión terminada · KEY1 (NEXT) = otra sesión")),
      *stats(L("h"),L("e"),L("acc")),
      hablar(join(txt("Práctica terminada. "),L("h"),txt(" aciertos, "),L("e"),txt(" errores. Precisión "),L("acc"),txt(" por ciento"))),
    ])
  ])],1100,500))
put(proc("grafReset",[],[
  call("Canvas1","Clear"),
  gset("global px",num(-1)),
  gset("global py",num(0))],1100,900))
put(proc("grafPunto",["n","acc"],[
  local([("x",div(mul(L("n"),pget("Canvas1","Width")),
                  choose(eq(L("global nLetras"),num(0)),num(30),add(L("global nLetras"),num(1))))),
         ("y",sub(pget("Canvas1","Height"),div(mul(L("acc"),pget("Canvas1","Height")),num(100))))],[
    ifs([(mcmp("GTE",L("global px"),num(0)),
          [call("Canvas1","DrawLine",L("global px"),L("global py"),L("x"),L("y"))])]),
    call("Canvas1","DrawLine",sub(L("x"),num(6)),L("y"),add(L("x"),num(6)),L("y")),
    call("Canvas1","DrawLine",L("x"),sub(L("y"),num(6)),L("x"),add(L("y"),num(6))),
    gset("global px",L("x")),
    gset("global py",L("y"))])],1100,1050))

# ---------- Voz y botones ----------
put(proc("hablar",["txt"],[
  ifs([(land(pget("ChkVoz","Checked"),mcmp("GT",tlen(L("txt")),num(0))),
        [call("TextToSpeech1","Speak",L("txt"))])])],1700,0))
put(event("BtnEnviar","Click",[
  ifs([(mcmp("GT",tlen(pget("TxtPalabra","Text")),num(16)),
        [pset("LblLog","Text",txt("Máximo 16 caracteres"))])],
      [hablar(pget("TxtPalabra","Text")),
       enviar(join(txt("R"),pget("TxtPalabra","Text")))])],1700,150))
put(event("BtnAplicarN","Click",[
  gset("global nLetras",pget("TxtN","Text")),
  enviar(join(txt("L"),pget("TxtN","Text")))],1700,350))
put(event("BtnLeer","Click",[hablar(pget("LblTexto","Text"))],1700,480))
put(event("BtnBorrar","Click",[
  pset("LblTexto","Text",txt("")),
  pset("LblUlt","Text",txt("")),
  gset("global palabraW",txt(""))],1700,560))

bky='<xml xmlns="http://www.w3.org/1999/xhtml">'+''.join(blocks)+'<yacodeblocks ya-version="208" language-version="33"></yacodeblocks></xml>'
props=f"""main=appinventor.{USER}.{PROJ}.Screen1
name={PROJ}
assets=../assets
source=../src
build=../build
versioncode=1
versionname=1.0
useslocation=False
aname={PROJ}
sizing=Responsive
showlistsasjson=True
actionbar=True
theme=AppTheme.Light.DarkActionBar
color.primary=&FF3F51B5
color.primary.dark=&FF303F9F
color.accent=&FFFF4081
"""
import xml.dom.minidom
xml.dom.minidom.parseString(bky)          # valida XML
json.loads(scm.split('$JSON\n')[1].rsplit('\n|#',1)[0])  # valida JSON
with zipfile.ZipFile(OUT,'w',zipfile.ZIP_DEFLATED) as z:
    z.writestr("youngandroidproject/project.properties",props)
    z.writestr(f"src/appinventor/{USER}/{PROJ}/Screen1.scm",scm)
    z.writestr(f"src/appinventor/{USER}/{PROJ}/Screen1.bky",bky)
print("ok", len(blocks), "top-level blocks")
