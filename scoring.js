(function(root){
 function stageHintPenalty(counts){
  return[0,1,2].reduce((sum,index)=>{
   let count=Math.max(0,Number(counts&&counts[index])||0);
   return sum+(count>0?10:0)+(count>1?20:0);
  },0);
 }
 function stationProgressPenalty(progress){
  let hints=Math.max(0,Number(progress.hints)||0),hintPenalty;
  if(Number(progress.stationOrder)===2){
   let stages=Array.isArray(progress.stageHints)?progress.stageHints:[0,0,0];
   let staged=stages.reduce((sum,count)=>sum+Math.max(0,Number(count)||0),0);
   let legacy=Math.max(0,hints-staged);
   hintPenalty=stageHintPenalty(stages)+(legacy===0?0:legacy===1?10:30);
  }else{
   hintPenalty=hints===0?0:hints===1?10:30;
  }
  return hintPenalty+Math.max(0,Number(progress.wrong)||0)*5+(progress.navigationUsed?30:0);
 }
 root.KuvagGameScoring={stageHintPenalty,stationProgressPenalty};
 if(typeof module==="object"&&module.exports)module.exports=root.KuvagGameScoring;
})(typeof globalThis!=="undefined"?globalThis:this);
