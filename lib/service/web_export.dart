import 'dart:convert';

import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_models.dart';

String standaloneFileName(EditablePack pack) {
  final raw = pack.manifest.gameName.trim().isNotEmpty
      ? pack.manifest.gameName.trim()
      : pack.name.trim();
  var base = raw
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (base.isEmpty) base = 'game';
  return '$base.html';
}

String buildStandaloneHtml(EditablePack pack) {
  final files = pack.toFiles();
  final media = <String, String>{};
  for (final entry in pack.importedMedia.entries) {
    final mime = _mimeFor(entry.key);
    if (mime == null) continue;
    media[entry.key] = 'data:$mime;base64,${base64Encode(entry.value)}';
  }
  final labels = <String, String>{
    'tap': t('web.labels.tap'),
    'end': t('web.labels.end'),
    'restart': t('web.labels.restart'),
    'submit': t('web.labels.submit'),
    'answerHint': t('web.labels.answerHint'),
    'aiOffline': t('web.labels.aiOffline'),
    'wrong': t('web.labels.wrong'),
    'conditionFail': t('web.labels.conditionFail'),
    'chooseFiles': t('web.labels.chooseFiles'),
    'needFiles': t('web.labels.needFiles'),
    'unsupportedType': t('submit.result.unsupportedType'),
    'close': t('web.labels.close'),
  };
  final rawTitle = pack.manifest.gameName.trim().isNotEmpty
      ? pack.manifest.gameName.trim()
      : pack.name.trim();
  final title = rawTitle.isEmpty ? 'Game' : rawTitle;
  final payload = _escapeScript(
    jsonEncode(<String, dynamic>{
      'title': title,
      'files': files,
      'media': media,
      'labels': labels,
    }),
  );
  return _template
      .replaceAll('__TITLE__', _htmlText(title))
      .replaceAll('__LANG__', _htmlAttr(I18n.instance.lang))
      .replaceAll('__PACK_JSON__', payload);
}

String? _mimeFor(String path) {
  final p = path.toLowerCase();
  final dot = p.lastIndexOf('.');
  final ext = dot < 0 ? '' : p.substring(dot + 1);
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    case 'mp3':
      return 'audio/mpeg';
    case 'wav':
      return 'audio/wav';
    case 'ogg':
      return 'audio/ogg';
    case 'm4a':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'flac':
      return 'audio/flac';
    case 'mp4':
      return 'video/mp4';
    case 'webm':
      return 'video/webm';
    case 'mov':
      return 'video/quicktime';
    case 'ogv':
      return 'video/ogg';
  }
  return null;
}

String _escapeScript(String json) => json
    .replaceAll('<', r'\u003c')
    .replaceAll('\u2028', r'\u2028')
    .replaceAll('\u2029', r'\u2029');

String _htmlText(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

String _htmlAttr(String s) => _htmlText(s);

const String _template = r'''<!DOCTYPE html>
<html lang="__LANG__">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="color-scheme" content="dark">
<title>__TITLE__</title>
<style>
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html,body{margin:0;height:100%;background:#0C0C0E;color:#fff;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif;overflow:hidden}
#app{position:fixed;inset:0;overflow:hidden;cursor:pointer}
#bg{position:absolute;inset:0;background-color:#101418;background-position:center;background-size:cover;background-repeat:no-repeat}
#sprites{position:absolute;inset:0;pointer-events:none}
.sprite{position:absolute;left:50%;top:25.65%;height:62%;background-repeat:no-repeat;background-position:center bottom;background-size:contain;transform:translateX(calc(-50% + var(--sx) * 50%))}
#linemedia{position:absolute;inset:0;pointer-events:none}
#lineimg{position:absolute;left:0;right:0;top:6%;bottom:22%;display:flex;align-items:center;justify-content:center;pointer-events:none}
#lineimg img{max-width:min(84vw,820px);max-height:100%;object-fit:contain;border-radius:12px;pointer-events:auto;cursor:zoom-in;box-shadow:0 14px 44px rgba(0,0,0,.55)}
#corners{position:absolute;right:12px;top:12px;display:flex;flex-direction:column;gap:8px;align-items:flex-end;pointer-events:none}
.corner{max-width:min(46vw,320px);border-radius:12px;background:rgba(0,0,0,.55);pointer-events:auto;overflow:hidden}
.corner audio{display:block;width:min(46vw,320px)}
.corner video{display:block;width:min(46vw,320px);max-height:38vh;border-radius:12px}
#dialogue{position:absolute;left:50%;transform:translateX(-50%);bottom:calc(16px + env(safe-area-inset-bottom,0px));width:min(760px,calc(100% - 32px));min-height:96px;display:none;flex-direction:column;padding:14px 18px 18px;background:rgba(0,0,0,.6);border:1px solid rgba(255,255,255,.24);border-radius:16px;backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);pointer-events:none}
#dialogue.show{display:flex}
#speaker{display:none;align-self:flex-start;max-width:100%;background:#FF385C;border-radius:8px;padding:3px 9px;margin-bottom:8px;font-size:clamp(11px,2.6vw,12px);font-weight:600;line-height:1.45;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#speaker.show{display:block}
#text{font-size:clamp(15px,1.15vw + 9px,19px);line-height:1.62;white-space:pre-wrap;word-break:break-word;overflow-wrap:anywhere}
#taphint{position:absolute;right:14px;bottom:6px;font-size:11px;color:rgba(255,255,255,.34);user-select:none}
#overlay{position:absolute;inset:0;display:none;align-items:center;justify-content:center;padding:24px;background:rgba(0,0,0,.62);overflow:auto}
#overlay.open{display:flex}
#overlay[data-mode="end"]{background:rgba(0,0,0,.72)}
.panel{width:min(520px,100%);display:flex;flex-direction:column;gap:10px}
.choice{display:block;width:100%;text-align:left;font:inherit;color:#fff;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.12);border-radius:12px;padding:14px 16px;font-size:clamp(14px,3.4vw,15px);line-height:1.5;cursor:pointer;transition:background .15s ease}
.choice:hover:not(:disabled){background:rgba(255,255,255,.16)}
.choice:disabled{background:rgba(255,255,255,.04);color:rgba(255,255,255,.38);border-color:transparent;cursor:default}
.choice .cond{display:block;margin-top:4px;font-size:11px;color:rgba(255,255,255,.54)}
.choice:disabled .cond{color:rgba(255,255,255,.24)}
.check{width:min(440px,100%);display:flex;flex-direction:column;gap:12px;padding:20px;background:#151518;border:1px solid rgba(255,255,255,.14);border-radius:16px}
.check h2{margin:0;font-size:16px;font-weight:600;line-height:1.5}
.check p{margin:0;font-size:13px;line-height:1.6;color:rgba(255,255,255,.72)}
.field{width:100%;padding:10px 12px;font:inherit;font-size:14px;color:#fff;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.16);border-radius:10px;outline:none}
.field:focus{border-color:#FF385C}
.field::placeholder{color:rgba(255,255,255,.4)}
.err{min-height:0;font-size:12px;line-height:1.5;color:#FF6B84}
.row{display:flex;gap:10px;justify-content:flex-end;flex-wrap:wrap}
.btn{font:inherit;font-size:14px;padding:10px 16px;border:0;border-radius:10px;background:#FF385C;color:#fff;cursor:pointer}
.btn:hover{filter:brightness(1.08)}
.btn.ghost{background:transparent;border:1px solid rgba(255,255,255,.2);color:rgba(255,255,255,.8)}
.filebox{position:relative;display:block;padding:14px;text-align:center;font-size:13px;color:rgba(255,255,255,.8);background:rgba(255,255,255,.04);border:1px dashed rgba(255,255,255,.28);border-radius:10px;cursor:pointer}
.filebox:hover{border-color:rgba(255,255,255,.45)}
.hiddenfile{position:absolute;left:0;top:0;width:1px;height:1px;opacity:0;overflow:hidden}
.endpanel{display:flex;flex-direction:column;align-items:center;gap:16px;text-align:center;padding:8px}
.endicon{width:56px;height:56px;border-radius:50%;border:2px solid rgba(255,255,255,.4);display:flex;align-items:center;justify-content:center;font-size:22px;color:#FF385C}
.endtitle{font-size:clamp(16px,4vw,20px);letter-spacing:.04em}
#lightbox{position:fixed;inset:0;z-index:50;display:none;align-items:center;justify-content:center;padding:16px;background:rgba(0,0,0,.9);cursor:zoom-out}
#lightbox.open{display:flex}
#lightbox img{max-width:100%;max-height:100%;object-fit:contain;border-radius:12px}
@media (max-width:520px){#dialogue{min-height:0;padding:12px 14px 16px}}
</style>
</head>
<body>
<div id="app">
<div id="bg"></div>
<div id="sprites"></div>
<div id="linemedia"></div>
<div id="dialogue">
<div id="speaker"></div>
<div id="text"></div>
<div id="taphint"></div>
</div>
<div id="overlay"></div>
<div id="lightbox"><img alt=""></div>
</div>
<script type="application/json" id="pack">__PACK_JSON__</script>
<script>
(function(){
'use strict';
var DATA=JSON.parse(document.getElementById('pack').textContent);
var FILES=DATA.files||{};
var MEDIA=DATA.media||{};
var LABELS=DATA.labels||{};
var STAGES=[];
var CHECKS={};
var ITEMS={};
var COND_RE=/^\s*([^\s<>=!]+)\s*(>=|<=|==|!=|>|<|=)?\s*(-?\d+)?\s*$/;

function el(tag,cls,text){var n=document.createElement(tag);if(cls)n.className=cls;if(text!=null)n.textContent=text;return n;}
function txt(v){return v==null?'':String(v);}
function fileBase(rel){var parts=txt(rel).split('/');return parts[parts.length-1].replace(/\.json$/i,'');}
function leadingNumber(name){var m=/^(\d+)/.exec(txt(name));return m?parseInt(m[1],10):0;}

Object.keys(FILES).forEach(function(rel){
  var lower=rel.toLowerCase();
  var obj;
  try{obj=JSON.parse(FILES[rel]);}catch(e){return;}
  if(!obj||typeof obj!=='object')return;
  if(lower.indexOf('stage/')===0){
    STAGES.push({
      id:txt(obj.id).trim(),
      fileName:rel.split('/').pop(),
      lines:Array.isArray(obj.lines)?obj.lines:[],
      checkpoints:Array.isArray(obj.checkpoint)?obj.checkpoint:[],
      background:txt(obj.background),
      bgm:txt(obj.bgm)
    });
  }else if(lower.indexOf('check/')===0){
    CHECKS[fileBase(rel)]=obj;
  }else if(lower.indexOf('item/')===0){
    var base=fileBase(rel);
    var id=txt(obj.id).trim()||base;
    ITEMS[id]={id:id,name:txt(obj.name)||base,asset:txt(obj.asset),initial:Number(obj.initial)||0};
  }
});
STAGES.sort(function(a,b){var na=leadingNumber(a.fileName),nb=leadingNumber(b.fileName);if(na!==nb)return na-nb;if(a.fileName<b.fileName)return -1;if(a.fileName>b.fileName)return 1;return 0;});

var app=document.getElementById('app');
var bgEl=document.getElementById('bg');
var spritesEl=document.getElementById('sprites');
var lineMediaEl=document.getElementById('linemedia');
var dialogueEl=document.getElementById('dialogue');
var speakerEl=document.getElementById('speaker');
var textEl=document.getElementById('text');
var tapEl=document.getElementById('taphint');
var overlayEl=document.getElementById('overlay');
var lightboxEl=document.getElementById('lightbox');
var lightboxImg=lightboxEl.querySelector('img');

var bgmEl=document.createElement('audio');
bgmEl.loop=true;
bgmEl.preload='auto';
document.body.appendChild(bgmEl);

var stageIndex=0;
var lineIndex=0;
var ended=false;
var values={};
var overlayMode=null;
var currentBgm='';
var lightboxOpen=false;

function tryPlay(){var p=bgmEl.play();if(p&&p.catch)p.catch(function(){});}
function setBgm(src){
  if(!src||!MEDIA[src]){
    if(currentBgm){currentBgm='';bgmEl.pause();bgmEl.removeAttribute('src');bgmEl.load();}
    return;
  }
  if(currentBgm===src){if(bgmEl.paused)tryPlay();return;}
  currentBgm=src;
  bgmEl.src=MEDIA[src];
  tryPlay();
}
function setBg(src){
  bgEl.style.backgroundImage=src&&MEDIA[src]?'url("'+MEDIA[src]+'")':'none';
}
function setSprites(list){
  spritesEl.textContent='';
  if(!Array.isArray(list))return;
  for(var i=0;i<list.length;i++){
    var s=list[i]||{};
    var asset=txt(s.asset);
    if(!asset||!MEDIA[asset])continue;
    var d=el('div','sprite');
    var pos=txt(s.position);
    d.style.setProperty('--sx',pos==='left'?'-0.55':pos==='right'?'0.55':'0');
    d.style.backgroundImage='url("'+MEDIA[asset]+'")';
    spritesEl.appendChild(d);
  }
}
function openLightbox(src){lightboxImg.src=src;lightboxEl.classList.add('open');lightboxOpen=true;}
function closeLightbox(){lightboxOpen=false;lightboxEl.classList.remove('open');lightboxImg.removeAttribute('src');}
lightboxEl.addEventListener('click',function(ev){ev.stopPropagation();closeLightbox();});

function setLineMedia(line){
  lineMediaEl.textContent='';
  if(!line)return;
  var img=txt(line.image);
  var aud=txt(line.audio);
  var vid=txt(line.video);
  if(img&&MEDIA[img]){
    var wrap=el('div');
    wrap.id='lineimg';
    var im=el('img');
    im.alt='';
    im.src=MEDIA[img];
    im.addEventListener('click',function(ev){ev.stopPropagation();openLightbox(MEDIA[img]);});
    wrap.appendChild(im);
    lineMediaEl.appendChild(wrap);
  }
  var cornerBox=null;
  if(aud&&MEDIA[aud]){
    cornerBox=cornerBox||el('div');
    cornerBox.id='corners';
    var box=el('div','corner');
    var au=el('audio');
    au.controls=true;
    au.src=MEDIA[aud];
    box.appendChild(au);
    cornerBox.appendChild(box);
  }
  if(vid&&MEDIA[vid]){
    cornerBox=cornerBox||el('div');
    cornerBox.id='corners';
    var box2=el('div','corner');
    var vd=el('video');
    vd.controls=true;
    vd.playsInline=true;
    vd.src=MEDIA[vid];
    box2.appendChild(vd);
    cornerBox.appendChild(box2);
  }
  if(cornerBox)lineMediaEl.appendChild(cornerBox);
}

function setDialogue(line){
  if(!line){
    dialogueEl.classList.remove('show');
    return;
  }
  dialogueEl.classList.add('show');
  var sp=txt(line.speaker).trim();
  if(sp){speakerEl.textContent=sp;speakerEl.classList.add('show');}
  else{speakerEl.textContent='';speakerEl.classList.remove('show');}
  textEl.textContent=txt(line.text);
  tapEl.textContent=LABELS.tap||'';
}

function sceneAt(idx){
  var stage=STAGES[stageIndex];
  var bg=stage?stage.background:'';
  var sprites=[];
  var lines=stage?stage.lines:[];
  var last=Math.max(0,Math.min(idx,lines.length-1));
  for(var i=0;i<lines.length&&i<=last;i++){
    var l=lines[i]||{};
    if(txt(l.background))bg=txt(l.background);
    if(Array.isArray(l.sprites))sprites=l.sprites;
  }
  return {bg:bg,sprites:sprites,bgm:stage?stage.bgm:''};
}

function matches(condition){
  var text=txt(condition).trim();
  if(!text)return true;
  var parts=text.split('&&');
  for(var i=0;i<parts.length;i++){
    var m=COND_RE.exec(parts[i]);
    if(!m)return false;
    var op=m[2]||'>=';
    if(op==='=')op='==';
    var item=m[1]||'';
    var want=m[3]===undefined?1:parseInt(m[3],10);
    var have=Object.prototype.hasOwnProperty.call(values,item)?values[item]:0;
    var ok=false;
    if(op==='>=')ok=have>=want;
    else if(op==='<=')ok=have<=want;
    else if(op==='==')ok=have===want;
    else if(op==='!=')ok=have!==want;
    else if(op==='>')ok=have>want;
    else if(op==='<')ok=have<want;
    if(!ok)return false;
  }
  return true;
}

function applyGrant(cp){
  var g=cp.grant||{};
  Object.keys(g).forEach(function(k){
    var n=Number(g[k]);
    if(!isFinite(n))n=0;
    var base=Object.prototype.hasOwnProperty.call(values,k)?values[k]:0;
    values[k]=base+Math.trunc(n);
  });
}
function findStage(id){
  if(!id)return -1;
  for(var i=0;i<STAGES.length;i++){
    var key=STAGES[i].id||fileBase(STAGES[i].fileName);
    if(key===id)return i;
  }
  return -1;
}
function clearOverlay(){
  overlayMode=null;
  overlayEl.textContent='';
  overlayEl.classList.remove('open');
  overlayEl.removeAttribute('data-mode');
}
function showChoices(stage){
  overlayMode='choices';
  overlayEl.textContent='';
  overlayEl.removeAttribute('data-mode');
  var panel=el('div','panel');
  var cps=stage.checkpoints||[];
  for(var i=0;i<cps.length;i++){
    (function(cp,idx){
      cp=cp||{};
      var met=matches(cp.condition);
      var btn=el('button','choice');
      btn.type='button';
      var label=txt(cp.text).trim()||String(idx+1);
      btn.appendChild(el('span',null,label));
      var cond=txt(cp.condition).trim();
      if(cond)btn.appendChild(el('span','cond',cond));
      if(met){
        btn.addEventListener('click',function(ev){ev.stopPropagation();onChoice(cp);});
      }else{
        btn.disabled=true;
      }
      panel.appendChild(btn);
    })(cps[i],i);
  }
  overlayEl.appendChild(panel);
  overlayEl.classList.add('open');
}
function onChoice(cp){
  if(txt(cp.check).trim()){openCheckPanel(cp);return;}
  applyGrant(cp);
  jump(cp.next);
}
function finishCheck(cp){clearOverlay();applyGrant(cp);jump(cp.next);}
function openCheckPanel(cp){
  var id=txt(cp.check).trim();
  var check=CHECKS[id];
  if(!check){finishCheck(cp);return;}
  var type=txt(check.type);
  var params=check.params||check||{};
  overlayMode='check';
  overlayEl.textContent='';
  overlayEl.removeAttribute('data-mode');
  var panel=el('div','check');
  var title=txt(cp.text).trim();
  if(title)panel.appendChild(el('h2',null,title));
  var err=el('div','err');
  function closeRow(){
    var row=el('div','row');
    var back=el('button','btn ghost',LABELS.close||'');
    back.type='button';
    back.addEventListener('click',function(ev){ev.stopPropagation();showChoices(STAGES[stageIndex]);});
    row.appendChild(back);
    panel.appendChild(row);
    return row;
  }
  if(type==='text_answer'){
    var aiOn=!!String(params.ai_criteria||'').trim()||((params.ai_points||[]).length>0);
    var needText=params.need_text!==false;
    var input=el('input','field');
    input.type='text';
    input.autocomplete='off';
    input.placeholder=LABELS.answerHint||'';
    panel.appendChild(input);
    if(aiOn)panel.appendChild(el('p',null,LABELS.aiOffline||''));
    panel.appendChild(err);
    var row1=closeRow();
    var submit1=el('button','btn',LABELS.submit||'');
    submit1.type='button';
    submit1.addEventListener('click',function(ev){
      ev.stopPropagation();
      if(aiOn){
        if(!needText||input.value.trim()){finishCheck(cp);}
        else{err.textContent=LABELS.wrong||'';input.focus();}
        return;
      }
      var expected=txt(params.answer).trim();
      if(expected&&input.value.trim()===expected){finishCheck(cp);}
      else{err.textContent=LABELS.wrong||'';input.focus();}
    });
    input.addEventListener('keydown',function(ev){if(ev.key==='Enter'){ev.preventDefault();submit1.click();}});
    row1.appendChild(submit1);
  }else if(type==='photo_submit'||type==='media_submit'){
    var required=1;
    var needRaw=(params.submit_need!=null)?params.submit_need:params.requireCount;
    if(needRaw!=null){
      var rn=Number(needRaw);
      if(!isNaN(rn))required=Math.trunc(rn);
    }
    var fileBox=el('label','filebox',LABELS.chooseFiles||'');
    var fileInput=el('input','hiddenfile');
    fileInput.type='file';
    fileInput.multiple=true;
    fileInput.accept=type==='photo_submit'?'image/*':'image/*,video/*,audio/*';
    fileBox.appendChild(fileInput);
    panel.appendChild(fileBox);
    panel.appendChild(err);
    var row2=closeRow();
    var submit2=el('button','btn',LABELS.submit||'');
    submit2.type='button';
    submit2.addEventListener('click',function(ev){
      ev.stopPropagation();
      var have=fileInput.files?fileInput.files.length:0;
      if(have>=required){finishCheck(cp);}
      else{err.textContent=txt(LABELS.needFiles).replace('{need}',String(required)).replace('{have}',String(have));}
    });
    row2.appendChild(submit2);
  }else if(type==='condition'){
    if(matches(txt(params.condition))){
      panel.appendChild(err);
      var row3=closeRow();
      var submit3=el('button','btn',LABELS.submit||'');
      submit3.type='button';
      submit3.addEventListener('click',function(ev){ev.stopPropagation();finishCheck(cp);});
      row3.appendChild(submit3);
    }else{
      var fail=txt(params.fail_text).trim()||txt(LABELS.conditionFail);
      panel.appendChild(el('p',null,fail));
      closeRow();
    }
  }else if(String(params.ai_criteria||'').trim()||((params.ai_points||[]).length>0)){
    panel.appendChild(el('p',null,LABELS.aiOffline||''));
    var row4=closeRow();
    var submit4=el('button','btn',LABELS.submit||'');
    submit4.type='button';
    submit4.addEventListener('click',function(ev){ev.stopPropagation();finishCheck(cp);});
    row4.appendChild(submit4);
  }else{
    panel.appendChild(el('p',null,(LABELS.unsupportedType||'').replace('{type}',type)));
    closeRow();
  }
  overlayEl.appendChild(panel);
  overlayEl.classList.add('open');
}
function showEnd(){
  overlayMode='end';
  overlayEl.textContent='';
  overlayEl.setAttribute('data-mode','end');
  var panel=el('div','endpanel');
  panel.appendChild(el('div','endicon','\u2713'));
  panel.appendChild(el('div','endtitle',LABELS.end||''));
  var btn=el('button','btn',LABELS.restart||'');
  btn.type='button';
  btn.addEventListener('click',function(ev){ev.stopPropagation();reset();});
  panel.appendChild(btn);
  overlayEl.appendChild(panel);
  overlayEl.classList.add('open');
}
function render(){
  var stage=STAGES[stageIndex]||null;
  var lines=stage?stage.lines:[];
  var atChoices=!!stage&&!ended&&lineIndex>=lines.length;
  var line=!ended&&!atChoices&&lineIndex>=0&&lineIndex<lines.length?lines[lineIndex]:null;
  var scene=sceneAt(lineIndex);
  setBg(scene.bg);
  setSprites(scene.sprites);
  setBgm(scene.bgm);
  setLineMedia(line);
  setDialogue(line);
  if(ended){showEnd();return;}
  if(atChoices){showChoices(stage);return;}
  clearOverlay();
}
function advance(){
  var stage=STAGES[stageIndex];
  if(!stage||ended)return;
  if(lineIndex<stage.lines.length-1){lineIndex++;render();return;}
  if(!stage.checkpoints.length){ended=true;render();return;}
  lineIndex=stage.lines.length;
  render();
}
function jump(next){
  var nid=txt(next).trim();
  if(!nid){ended=true;render();return;}
  var idx=findStage(nid);
  if(idx<0){ended=true;render();return;}
  stageIndex=idx;
  lineIndex=0;
  ended=false;
  render();
}
function initValues(){
  values={};
  Object.keys(ITEMS).forEach(function(k){values[k]=ITEMS[k].initial;});
}
function reset(){
  initValues();
  stageIndex=0;
  lineIndex=0;
  ended=false;
  closeLightbox();
  clearOverlay();
  render();
}

app.addEventListener('click',function(ev){
  if(lightboxOpen)return;
  if(overlayMode)return;
  var target=ev.target;
  if(target&&target.closest&&target.closest('audio,video,button,input,label,select,textarea,a'))return;
  advance();
});
document.addEventListener('click',function(){
  if(currentBgm&&bgmEl.paused)tryPlay();
},true);

if(!STAGES.length)ended=true;
initValues();
render();
})();
</script>
</body>
</html>
''';
