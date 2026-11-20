(function(root){
 const completedPhases=new Set([
  "reveal",
  "reveal-history",
  "reveal-riddle",
  "reveal-cemetery-history",
  "reveal-cemetery-next",
  "standard-route-reveal-0",
  "chapel-route",
  "chapel-route-solved",
  "chapel-stone-history",
  "knarovka-route",
  "post-route",
  "post-route-solved",
  "roses-route",
  "square-route"
 ]);

 function resolveSavedGameView(saved,nextIndex,completedIndexes,stationCount){
  const savedIndex=Number(saved&&saved.i);
  const phase=typeof (saved&&saved.phase)==="string"?saved.phase:"station";
  const completed=completedIndexes instanceof Set?completedIndexes:new Set(completedIndexes||[]);
  if(phase==="finished"&&nextIndex>=stationCount)return{phase,index:savedIndex,completed:true};
  if(phase==="finish-pending"&&nextIndex>=stationCount)return{phase,index:savedIndex,completed:true};
  if(phase==="station"){
   if(savedIndex===nextIndex)return{phase,index:savedIndex,completed:false};
   if(completed.has(savedIndex))return{phase,index:savedIndex,completed:true};
   return{phase:"station",index:nextIndex,completed:false};
  }
  if((phase==="fountain-memory"||phase==="fountain-mary-reveal")&&savedIndex===nextIndex&&!completed.has(savedIndex)){
   return{phase,index:savedIndex,completed:false};
  }
  const standardRoute=/^standard-route-[0-2]$/.test(phase);
  if((completedPhases.has(phase)||standardRoute)&&completed.has(savedIndex)&&savedIndex<nextIndex){
   return{phase,index:savedIndex,completed:true};
  }
  return{phase:"station",index:nextIndex,completed:false};
 }

 root.KuvagGameProgress={resolveSavedGameView};
 if(typeof module==="object"&&module.exports)module.exports=root.KuvagGameProgress;
})(typeof globalThis!=="undefined"?globalThis:this);
