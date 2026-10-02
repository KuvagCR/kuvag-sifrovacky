async function saveStationDetail(stationId){
  if(!state.sessionToken)return false;
  const finishedAt=new Date().toISOString();
  try{
    const r=await fetch(SUPABASE_URL+"/rest/v1/rpc/save_station_detail",{method:"POST",headers:{"apikey":SUPABASE_KEY,"Content-Type":"application/json"},body:JSON.stringify({p_session_token:state.sessionToken,p_station_id:stationId,p_hints_used:state.stationHints,p_wrong_attempts:state.stationWrong,p_started_at:state.stationStartedAt,p_finished_at:finishedAt,p_answer_history:state.stationAnswerHistory||[],p_hints_history:state.stationHintsHistory||[]})});
    if(!r.ok){console.error("Detail stanoviště:",r.status,await r.text());return false}return true;
  }catch(e){console.error("Detail stanoviště:",e);return false}
}
function safeGameText(v){return escHtml(v||"").replace(/\n/g,"<br>")}
station=function(){
  app.className="card";state.hintIndex=0;state.stationHints=0;state.stationWrong=0;state.stationStartedAt=new Date().toISOString();state.stationAnswerHistory=[];state.stationHintsHistory=[];
  let s=stations[state.i],image=s.image||HERO;
  app.innerHTML='<div class="eyebrow">Stanoviště '+(state.i+1)+' / '+stations.length+'</div><div class="progress"><i style="width:'+((state.i+1)/stations.length*100)+'%"></i></div><h2>'+safeGameText(s.title)+'</h2><img class="station-photo" src="'+escHtml(image)+'" alt="Fotografie stanoviště">'+(s.type==="cipher"?'<div class="cipher"><div class="cipher-title">ŠIFROVACÍ TABULKA</div><div class="cipher-grid">'+Array.from({length:26},(_,i)=>'<span><b>'+String.fromCharCode(65+i)+'</b><small>'+(i+1)+'</small></span>').join("")+'</div></div>':s.type==="field"?'<div class="field-badge">⌖ ÚKOL V TERÉNU</div>':'')+(s.story?'<div class="letter small-letter">'+safeGameText(s.story)+'</div>':'')+'<div class="task">'+safeGameText(s.task)+'</div><input id="answer" placeholder="Tvoje odpověď…" autocomplete="off"><button id="check">ZKONTROLOVAT →</button><button id="hint" class="secondary">💡 NÁPOVĚDA</button><div id="hintbox"></div><div id="msg" class="msg"></div>';
  let img=document.querySelector(".station-photo");if(img)img.onerror=()=>{img.onerror=null;img.src=HERO};
  document.querySelector("#check").onclick=check;document.querySelector("#answer").onkeydown=e=>{if(e.key==="Enter")check()};document.querySelector("#hint").onclick=hint;let mapBtn=document.querySelector("#cityMapButton");if(mapBtn){mapBtn.hidden=false;mapBtn.style.display="inline-block"};
};
hint=function(){
  let s=stations[state.i],box=document.querySelector("#hintbox");if(state.hintIndex>=s.hints.length){box.innerHTML='<div class="hint">Další nápověda už není.</div>';return}
  const hintNumber=state.hintIndex+1,hintText=s.hints[state.hintIndex];state.hints++;state.stationHints++;state.score=Math.max(0,state.score-(state.hintIndex?20:10));state.stationHintsHistory.push({hint:hintNumber,text:hintText,used_at:new Date().toISOString()});state.hintIndex++;box.innerHTML='<div class="hint">💡 '+safeGameText(hintText)+'</div>';
};
check=async function(){
  let input=document.querySelector("#answer"),val=input.value,s=stations[state.i],msg=document.querySelector("#msg"),btn=document.querySelector("#check");if(!val.trim()||btn.disabled)return;
  btn.disabled=true;btn.textContent="KONTROLUJI…";let result=await checkStationAnswer(s.id,val);if(!result.ok){btn.disabled=false;btn.textContent="ZKONTROLOVAT →";msg.className="msg bad";msg.textContent="Odpověď se nepodařilo ověřit. Zkontroluj připojení a zkus to znovu.";return}
  state.stationAnswerHistory.push({answer:val.trim(),correct:!!result.correct,answered_at:new Date().toISOString()});
  if(result.correct){msg.className="msg ok";msg.textContent="✓ Správně! Získáváš přístup k další stopě.";let saved=await saveStationDetail(s.id);if(!saved){btn.disabled=false;btn.textContent="ZKONTROLOVAT →";msg.className="msg bad";msg.textContent="Odpověď je správně, ale výsledek se nepodařilo uložit. Zkontroluj připojení a stiskni ZKONTROLOVAT znovu.";state.stationAnswerHistory.pop();return}setTimeout(()=>reveal(),750)}
  else{state.wrong++;state.stationWrong++;state.score=Math.max(0,state.score-5);btn.disabled=false;btn.textContent="ZKONTROLOVAT →";msg.className="msg bad";msg.textContent="To není správný klíč. Zkus to znovu.";input.select()}
};
