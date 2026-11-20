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
def lbl(name,text,**p): return C("Label",name,5,dict(Text=text,Width=FILL,**p))
def btn(name,text,**p): return C("Button",name,6,dict(Text=text,**p))
def ha(name,ch,**p): return C("HorizontalArrangement",name,3,dict(Width=FILL,AlignVertical="2",**p),ch)
def va(name,ch,**p): return C("VerticalArrangement",name,3,dict(Width=FILL,**p),ch)
comps=[
 ha("HAConexion",[
   C("ListPicker","LPConectar",9,dict(Text="Conectar Bluetooth")),
   btn("BtnDesconectar","Desconectar"),
   C("CheckBox","ChkVoz",2,dict(Text="Voz",Checked="True")),
 ]),
 lbl("LblEstado","Desconectado",TextColor="&HFFCC0000"),
 lbl("LblModo","MODO: -",FontSize="22",FontBold="True",TextAlignment="1"),
 va("VAReposo",[lbl("LblAyuda","Mueve los switches de la tarjeta:\nSW1 SW0 = 01  Lectura\nSW1 SW0 = 10  Escritura\nSW1 SW0 = 11  Practica (SW2 = pista)",FontSize="18",TextAlignment="1")]),
 va("VALectura",[
   ha("HAPalabra",[C("TextBox","TxtPalabra",6,dict(Hint="Palabra (max 16)",Width=FILL)),btn("BtnEnviar","Enviar")]),
   lbl("LblLetra","-",FontSize="120",FontBold="True",TextAlignment="1"),
   lbl("LblInfoR","Escribe una palabra. Avanza con KEY1 (NEXT).",TextAlignment="1"),
 ],Visible="False"),
 va("VAEscritura",[
   lbl("LblTexto","",FontSize="30"),
   lbl("LblUlt","Escribe en el teclado Braille. KEY1 = espacio"),
   ha("HABotonesW",[btn("BtnLeer","Leer en voz alta"),btn("BtnBorrar","Borrar")]),
 ],Visible="False"),
 va("VAPractica",[
   ha("HALetras",[C("Label","LblN",5,dict(Text="Letras por sesion:")),
                  C("TextBox","TxtN",6,dict(Text="10",NumbersOnly="True",Width="60")),
                  btn("BtnAplicarN","Aplicar"),
                  C("Label","LblN0",5,dict(Text=" (0 = sin limite)"))]),
   lbl("LblInfoP","La FPGA elige la letra. KEY1 = saltar. SW2 = pista",TextAlignment="1"),
   lbl("LblObjetivo","-",FontSize="120",FontBold="True",TextAlignment="1"),
   lbl("LblStats","Aciertos: 0   Errores: 0   Precision: 0 %",FontSize="16",FontBold="True",TextAlignment="1"),
   lbl("LblGraf","Precision acumulada (arriba = 100 %, abajo = 0 %)",FontSize="12",TextAlignment="1"),
   C("Canvas","Canvas1",10,dict(Width=FILL,Height="200",BackgroundColor="&HFFF4F4F4",LineWidth="4",PaintColor="&HFF2A6FDB")),
 ],Visible="False"),
 lbl("LblLog","",FontSize="12",TextColor="&HFF666666"),
 C("BluetoothClient","BluetoothClient1",5,dict(DelimiterByte="10",CharacterEncoding="ISO-8859-1")),
 C("Clock","Clock1",3,dict(TimerInterval="100",TimerEnabled="False",TimerAlwaysFires="True")),
 C("TextToSpeech","TextToSpeech1",5,dict(Language="es")),
]
form={"$Name":"Screen1","$Type":"Form","$Version":"27","AppName":PROJ,"Title":"Braille FPGA",
      "Scrollable":"True","Sizing":"Responsive","Uuid":"0","$Components":comps}
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
X=0; Y=[0]
def put(b): blocks.append(b)
put(gdecl("intentos",num(0),0,0))
put(gdecl("nLetras",num(10),0,40))
put(gdecl("palabraW",txt(""),0,80))
put(gdecl("px",num(-1),250,0))
put(gdecl("py",num(0),250,40))

# Conexion
put(event("LPConectar","BeforePicking",[pset("LPConectar","Elements",pget("BluetoothClient1","AddressesAndNames"))],0,140))
put(event("LPConectar","AfterPicking",[
  ifs([(call("BluetoothClient1","Connect",pget("LPConectar","Selection")),
        [pset("LblEstado","Text",txt("Conectado")),
         pset("LblEstado","TextColor",color("green","#00ff00")),
         pset("Clock1","TimerEnabled",boolean(True)),
         enviar(txt("Q"))])],
      [pset("LblEstado","Text",txt("No se pudo conectar"))])],0,220))
put(event("BtnDesconectar","Click",[
  pset("Clock1","TimerEnabled",boolean(False)),
  call("BluetoothClient1","Disconnect"),
  pset("LblEstado","Text",txt("Desconectado")),
  pset("LblEstado","TextColor",color("red","#ff0000"))],0,380))
put(proc("enviar",["txt"],[
  ifs([(pget("BluetoothClient1","IsConnected"),
        [call("BluetoothClient1","SendText",join(L("txt"),txt("\\n")))])])],0,480))
# Recepcion
put(event("Clock1","Timer",[
  whileb(land(pget("BluetoothClient1","IsConnected"),
              mcmp("GT",pget("BluetoothClient1","BytesAvailableToReceive"),num(0))),
         [pcall("procesar",["raw"],[call("BluetoothClient1","ReceiveText",num(-1))])])],0,560))
# Procesar
def T(ch): return eq(L("t"),txt(ch))
procesar_body=[local([("linea",trim(L("raw")))],[
  ifs([(mcmp("GT",tlen(L("linea")),num(0)),[
    local([("t",seg(L("linea"),1,1)),
           ("c",choose(mcmp("GTE",tlen(L("linea")),num(2)),seg(L("linea"),2,1),txt(" ")))],[
      ifs([
        (T("M"),[pcall("mostrarModo",["m"],[L("c")])]),
        (T("D"),[pset("LblLetra","Text",upc(L("c"))),
                 pset("LblInfoR","Text",txt("Avanza con KEY1 (NEXT) en la tarjeta.")),
                 hablar(L("c"))]),
        (T("E"),[pset("LblLetra","Text",txt("-")),
                 pset("LblInfoR","Text",txt("Fin de la palabra. Escribe otra."))]),
        (T("K"),[pcall("letraEscrita",["c"],[L("c")])]),
        (T("T"),[pset("LblObjetivo","Text",upc(L("c"))),
                 pset("LblObjetivo","TextColor",color("black","#000000")),
                 pset("LblInfoP","Text",join(txt("Letra "),add(L("global intentos"),num(1)),txt(" de "),L("global nLetras"))),
                 hablar(join(txt("Letra "),L("c")))]),
        (lor(T("O"),T("X")),[pcall("resultado",["linea"],[L("linea")])]),
        (T("F"),[pcall("finSesion",["linea"],[L("linea")])]),
        (T("L"),[gset("global nLetras",hex2dec(seg(L("linea"),2,2))),
                 pset("LblLog","Text",join(txt("Letras por sesion: "),L("global nLetras")))]),
        (T("!"),[pset("LblLog","Text",join(txt("Error: "),L("linea")))]),
      ],[pset("LblLog","Text",L("linea"))])
    ])
  ])])
])]
put(proc("procesar",["raw"],procesar_body,500,0))
# Modo
def M(ch): return eq(L("m"),txt(ch))
put(proc("mostrarModo",["m"],[
  pset("VAReposo","Visible",M("I")),
  pset("VALectura","Visible",M("R")),
  pset("VAEscritura","Visible",M("W")),
  pset("VAPractica","Visible",M("P")),
  ifs([(M("R"),[pset("LblModo","Text",txt("MODO: LECTURA")),pset("LblLetra","Text",txt("-"))]),
       (M("W"),[pset("LblModo","Text",txt("MODO: ESCRITURA"))]),
       (M("P"),[pset("LblModo","Text",txt("MODO: PRACTICA")),
                gset("global intentos",num(0)),
                pcall("grafReset",[],[]),
                pset("LblObjetivo","Text",txt("-")),
                pset("LblStats","Text",txt("Aciertos: 0   Errores: 0   Precision: 0 %")),
                gset("global nLetras",pget("TxtN","Text")),
                enviar(join(txt("L"),pget("TxtN","Text")))])],
      [pset("LblModo","Text",txt("MODO: REPOSO"))]),
  hablar(pget("LblModo","Text"))],500,900))
# Escritura
def CC(ch): return eq(L("c"),txt(ch))
put(proc("letraEscrita",["c"],[
  ifs([(CC("?"),[pset("LblUlt","Text",txt("Patron no reconocido"))]),
       (CC(" "),[hablar(L("global palabraW")),
                 gset("global palabraW",txt("")),
                 pset("LblTexto","Text",join(pget("LblTexto","Text"),txt(" "))),
                 pset("LblUlt","Text",txt("Espacio"))])],
      [pset("LblTexto","Text",join(pget("LblTexto","Text"),L("c"))),
       gset("global palabraW",join(L("global palabraW"),L("c"))),
       pset("LblUlt","Text",join(txt("Ultima letra: "),upc(L("c")))),
       hablar(L("c"))])],500,1300))
# Practica: resultado
put(proc("resultado",["linea"],[
  local([("h",hex2dec(seg(L("linea"),3,2))),("e",hex2dec(seg(L("linea"),5,2)))],[
    gset("global intentos",add(L("h"),L("e"))),
    local([("acc",rnd(div(mul(num(100),L("h")),mmax(num(1),add(L("h"),L("e"))))))],[
      ifs([(eq(seg(L("linea"),1,1),txt("O")),
            [pset("LblObjetivo","TextColor",color("green","#00ff00")),
             pset("LblInfoP","Text",txt("Correcto!")),
             hablar(txt("Correcto"))])],
          [pset("LblObjetivo","TextColor",color("red","#ff0000")),
           pset("LblInfoP","Text",join(txt("Incorrecto: escribiste "),upc(seg(L("linea"),2,1)))),
           hablar(txt("Incorrecto"))]),
      pset("LblStats","Text",join(txt("Aciertos: "),L("h"),txt("   Errores: "),L("e"),txt("   Precision: "),L("acc"),txt(" %"))),
      pcall("grafPunto",["n","acc"],[L("global intentos"),L("acc")]),
    ])
  ])],1100,0))
# Practica: fin
put(proc("finSesion",["linea"],[
  local([("h",hex2dec(seg(L("linea"),2,2))),("e",hex2dec(seg(L("linea"),4,2)))],[
    local([("acc",rnd(div(mul(num(100),L("h")),mmax(num(1),add(L("h"),L("e"))))))],[
      pset("LblObjetivo","Text",txt("OK")),
      pset("LblObjetivo","TextColor",color("blue","#0000ff")),
      pset("LblInfoP","Text",txt("Sesion terminada. KEY1 (NEXT) = otra sesion")),
      pset("LblStats","Text",join(txt("FINAL - Aciertos: "),L("h"),txt("   Errores: "),L("e"),txt("   Precision: "),L("acc"),txt(" %"))),
      hablar(join(txt("Practica terminada. Precision "),L("acc"),txt(" por ciento"))),
    ])
  ])],1100,600))
# Grafica en Canvas (sin librerias externas)
put(proc("grafReset",[],[
  call("Canvas1","Clear"),
  gset("global px",num(-1)),
  gset("global py",num(0))],1700,0))
put(proc("grafPunto",["n","acc"],[
  local([("x",div(mul(L("n"),pget("Canvas1","Width")),
                  choose(eq(L("global nLetras"),num(0)),num(30),add(L("global nLetras"),num(1))))),
         ("y",add(pget("Canvas1","Height"),
                  mul(num(-1),div(mul(L("acc"),pget("Canvas1","Height")),num(100)))))],[
    ifs([(mcmp("GTE",L("global px"),num(0)),
          [call("Canvas1","DrawLine",L("global px"),L("global py"),L("x"),L("y"))])]),
    call("Canvas1","DrawLine",add(L("x"),num(-6)),L("y"),add(L("x"),num(6)),L("y")),
    call("Canvas1","DrawLine",L("x"),add(L("y"),num(-6)),L("x"),add(L("y"),num(6))),
    gset("global px",L("x")),
    gset("global py",L("y"))])],1700,200))
# Voz
put(proc("hablar",["txt"],[
  ifs([(land(pget("ChkVoz","Checked"),mcmp("GT",tlen(L("txt")),num(0))),
        [call("TextToSpeech1","Speak",L("txt"))])])],1100,1000))
# Botones
put(event("BtnEnviar","Click",[
  ifs([(mcmp("GT",tlen(pget("TxtPalabra","Text")),num(16)),
        [pset("LblLog","Text",txt("Maximo 16 caracteres"))])],
      [hablar(pget("TxtPalabra","Text")),
       enviar(join(txt("R"),pget("TxtPalabra","Text")))])],1100,1200))
put(event("BtnAplicarN","Click",[
  gset("global nLetras",pget("TxtN","Text")),
  enviar(join(txt("L"),pget("TxtN","Text")))],1100,1400))
put(event("BtnLeer","Click",[hablar(pget("LblTexto","Text"))],1100,1550))
put(event("BtnBorrar","Click",[
  pset("LblTexto","Text",txt("")),
  gset("global palabraW",txt(""))],1100,1650))

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
