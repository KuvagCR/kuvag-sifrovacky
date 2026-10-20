// Klikací detail jednotlivého průchodu hráče ve výsledcích.
(function(){
  let bindTimer=null;
  function jsonArray(v){if(Array.isArray(v))return v;if(!v)return[];try{return JSON.parse(v)||[]}catch(e){return[]}}
  function sec(a,b){if(!a||!b)return null;return Math.max(0,Math.round((new Date(b)-new Date(a))/1000))}
  function fmtSec(s){if(s===null)return "—";return s<60?s+" s":Math.floor(s/60)+" min "+s%60+" s"}
  function playerTypeText(s){let t=typeLabel(s.player_type);return s.is_test_run?t+" • testovací průchod":t+" • ostrý průchod"}
  async function sessionsForCurrentFilter(){
    let gid=$("#gameSelect").value;if(!gid)return[];
    let type=$("#typeSelect").value,runType=$("#runTypeSelect")?.value||"live";
    let filter=(type==="all"?"":"&player_type=eq."+encodeURIComponent(type))+(runType==="test"?"&is_test_run=eq.true":runType==="live"?"&is_test_run=eq.false":"");
    return req("/rest/v1/game_sessions?select=id,player_name,player_type,is_test_run,started_at,finished_at,hints_used,wrong_attempts,total_points,is_finished&game_id=eq."+encodeURIComponent(gid)+filter+"&is_finished=eq.true&total_points=gt.300&order=started_at.desc");
  }
  async function bindPlayerRows(){
    let rows=[...document.querySelectorAll("#rows tr")];if(!rows.length)return;
    try{let sessions=await sessionsForCurrentFilter();rows.forEach((tr,i)=>{let s=sessions[i],cell=tr.cells[0];if(!s||!cell)return;cell.classList.add("playerDetailLink");cell.title="Zobrazit detail průchodu";cell.onclick=()=>openPlayerDetail(s.id);});}catch(e){console.error("Detail hráče – navázání:",e)}
  }
  async function openPlayerDetail(sessionId){
    let modal=document.querySelector("#playerDetailModal");if(!modal){modal=document.createElement("div");modal.id="playerDetailModal";modal.className="detailOverlay";document.body.appendChild(modal)}
    modal.innerHTML='<div class="detailPanel"><button class="detailClose" type="button">×</button><div class="tag">DETAIL PRŮCHODU</div><h1>Načítám…</h1></div>';modal.hidden=false;modal.querySelector(".detailClose").onclick=()=>modal.hidden=true;modal.onclick=e=>{if(e.target===modal)modal.hidden=true};
    try{
      let sessions=await req("/rest/v1/game_sessions?select=id,game_id,player_name,player_type,is_test_run,started_at,finished_at,hints_used,wrong_attempts,total_points,is_finished&id=eq."+encodeURIComponent(sessionId));let s=sessions[0];if(!s)throw new Error("Průchod nenalezen");
      let progress=await req("/rest/v1/station_progress?select=station_id,started_at,finished_at,answer_history,hints_history,hints_used,wrong_attempts&session_id=eq."+encodeURIComponent(sessionId)+"&order=started_at.asc");
      let stations=await req("/rest/v1/stations?select=id,station_order,title,correct_answer&game_id=eq."+encodeURIComponent(s.game_id)+"&order=station_order.asc");let byId=new Map(stations.map(x=>[String(x.id),x]));
      let cards=progress.map((p,i)=>{let st=byId.get(String(p.station_id))||{},answers=jsonArray(p.answer_history),hints=jsonArray(p.hints_history),time=fmtSec(sec(p.started_at,p.finished_at));let answerHtml=answers.length?answers.map(a=>'<div class="answerAttempt '+(a.correct?'answerOk':'answerBad')+'"><span>'+(a.correct?'✓':'×')+'</span><strong>'+esc(a.answer||"")+'</strong><small>'+(a.correct?'správně':'špatně')+'</small></div>').join(""):'<div class="detailEmpty">U tohoto staršího průchodu nejsou odpovědi uložené.</div>';let hintHtml=hints.length?hints.map(h=>'<div class="hintUsed"><strong>Nápověda '+esc(h.hint||"")+'</strong><span>'+esc(h.text||"")+'</span></div>').join(""):'<div class="detailEmpty">Bez nápovědy</div>';return '<article class="detailStation"><div class="detailStationHead"><div><span class="detailNo">'+esc(st.station_order||i+1)+'</span><h2>'+esc(st.title||"Stanoviště")+'</h2></div><strong class="detailTime">'+time+'</strong></div><div class="detailGrid"><div><h3>Odpovědi</h3>'+answerHtml+(st.correct_answer?'<div class="correctAnswer">Správná odpověď: <strong>'+esc(st.correct_answer)+'</strong></div>':'')+'</div><div><h3>Nápovědy</h3>'+hintHtml+'</div></div><div class="detailMini"><span>Chybné pokusy: <b>'+Number(p.wrong_attempts||0)+'</b></span><span>Použité nápovědy: <b>'+Number(p.hints_used||0)+'</b></span></div></article>'}).join("");
      modal.querySelector(".detailPanel").innerHTML='<button class="detailClose" type="button">×</button><div class="tag">DETAIL PRŮCHODU</div><h1>'+esc(s.player_name)+'</h1><p class="detailPlayerType">'+esc(playerTypeText(s))+'</p><div class="detailSummary"><span><b>'+duration(s.started_at,s.finished_at)+'</b> celkový čas</span><span><b>'+Number(s.total_points||0)+'</b> bodů</span><span><b>'+Number(s.hints_used||0)+'</b> nápověd</span><span><b>'+Number(s.wrong_attempts||0)+'</b> chyb</span></div>'+cards+(cards?'':'<div class="detailEmpty big">K tomuto průchodu nejsou uložené detaily stanovišť.</div>');modal.querySelector(".detailClose").onclick=()=>modal.hidden=true;
    }catch(e){console.error(e);modal.querySelector(".detailPanel").innerHTML='<button class="detailClose" type="button">×</button><div class="tag">DETAIL PRŮCHODU</div><h1>Detail se nepodařilo načíst</h1><p>'+esc(e.message||String(e))+'</p>';modal.querySelector(".detailClose").onclick=()=>modal.hidden=true}
  }
  const rows=document.querySelector("#rows");if(rows)new MutationObserver(()=>{clearTimeout(bindTimer);bindTimer=setTimeout(bindPlayerRows,50)}).observe(rows,{childList:true});setTimeout(bindPlayerRows,500);
})();