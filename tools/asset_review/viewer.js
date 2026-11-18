import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
const el=id=>document.getElementById(id);
const dialog=el('model3d');
let renderer,scene,camera,controls,environment,currentObject,mixer,currentAction,clips=[],model,token=0,frameHandle=0,lastFrame=0,returnFocus;
const clockLabels={idle:'待机',run:'移动',float:'漂浮',attack:'攻击',attack_1:'普通攻击一',attack_2:'普通攻击二',dodge:'闪避',hit:'受击',death:'死亡',bite:'撕咬',charge:'冲锋',howl:'咆哮',cast:'施法',open:'开启',spike:'地刺循环',press:'下压',activate:'拉动'};
const bounds=new THREE.Box3(), center=new THREE.Vector3();
let extent=1;
function freeObject(object) {
 const geometries=new Set(),materials=new Set(),textures=new Set();
 object.traverse(node=>{if(node.geometry)geometries.add(node.geometry); for(const m of Array.isArray(node.material)?node.material:node.material?[node.material]:[]){materials.add(m);for(const value of Object.values(m))if(value?.isTexture && value!==environment)textures.add(value);}});
 geometries.forEach(x=>x.dispose());materials.forEach(x=>x.dispose());textures.forEach(x=>{x.source?.data?.close?.();x.dispose();});
}
function initialize() {
 if(renderer)return;
 renderer=new THREE.WebGLRenderer({antialias:true,alpha:false});
 renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.outputColorSpace=THREE.SRGBColorSpace;
 renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.15;
 renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
 el('model3d-canvas').append(renderer.domElement);renderer.domElement.setAttribute('aria-label','模型三维预览，可拖动旋转');
 scene=new THREE.Scene();scene.background=new THREE.Color('#152029');
 const pmrem=new THREE.PMREMGenerator(renderer);const room=new RoomEnvironment();environment=pmrem.fromScene(room,.04).texture;room.dispose();pmrem.dispose();scene.environment=environment;
 camera=new THREE.PerspectiveCamera(38,1,.01,1000);
 controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.dampingFactor=.08;controls.maxPolarAngle=Math.PI*.93;
 scene.add(new THREE.HemisphereLight(0xb9d4ee,0x30261e,1.8));
 for(const [pos,color,power] of [[[4,7,5],0xe1ebff,3.4],[[-5,4,-3],0x87adc9,2.0],[[3,2,-4],0xf0ba84,1.0]]){
  const light=new THREE.DirectionalLight(color,power);light.position.set(...pos);scene.add(light);
 }
 new ResizeObserver(resize).observe(el('model3d-canvas'));
}
function resize(){if(!renderer)return;const node=el('model3d-canvas');const width=node.clientWidth,height=node.clientHeight;if(!width||!height)return;renderer.setSize(width,height,false);camera.aspect=width/height;camera.updateProjectionMatrix();if(currentObject)frameView();}
function frameView(view='angle') {
 if(!currentObject)return;
 const size=bounds.getSize(new THREE.Vector3());
 const vertical=size.y/(2*Math.tan(THREE.MathUtils.degToRad(camera.fov/2)));
 const horizontal=Math.max(size.x,size.z)/(2*Math.tan(THREE.MathUtils.degToRad(camera.fov/2))*camera.aspect);
 const distance=Math.max(vertical,horizontal,extent*.6)*1.4;
 const direction=view==='front'?new THREE.Vector3(0,.08,1):view==='side'?new THREE.Vector3(1,.08,0):view==='back'?new THREE.Vector3(0,.08,-1):new THREE.Vector3(.8,.45,1.3).normalize();
 camera.position.copy(center).addScaledVector(direction,distance);camera.near=Math.max(.001,extent/1000);camera.far=extent*200;camera.updateProjectionMatrix();
 controls.target.copy(center);controls.minDistance=extent*.12;controls.maxDistance=extent*8;controls.update();controls.saveState();
}
function animate(now){frameHandle=requestAnimationFrame(animate);const delta=lastFrame?Math.min(.05,(now-lastFrame)/1000):0;lastFrame=now;controls?.update(delta);if(mixer)mixer.update(delta);if(currentAction&&!el('model3d-time').matches(':active')){const duration=currentAction.getClip().duration;el('model3d-time').value=duration?String(currentAction.time/duration*1000):'0';}if(renderer)renderer.render(scene,camera);}
function chooseAnimation(name){
 if(!mixer)return;mixer.stopAllAction();currentAction=null;
 if(name){const clip=clips.find(x=>x.name===name);if(clip){currentAction=mixer.clipAction(clip);currentAction.reset().play();currentAction.paused=false;el('model3d-play').textContent='暂停动画';el('model3d-play').setAttribute('aria-pressed','true');mixer.update(0);}}
 el('model3d-time').disabled=!currentAction;el('model3d-play').disabled=!currentAction;
}
function syncReview(){const entry=window.assetReview.get(model.id);el('model3d-review').value=window.assetReview.status(model);el('model3d-note').value=entry.note||'';el('model3d-saved').textContent='';}
async function showModel(next){
 const request=++token;model=next;el('model3d-title').textContent=next.name;el('model3d-description').textContent=next.description;el('model3d-version').textContent='模型版本 '+next.sha256.slice(0,10);
 el('model3d-preview').src='../../'+next.preview+'?v='+next.sha256;el('model3d-preview').alt=next.name+'渲染预览';
 el('model3d-status').textContent='正在载入三维模型…';dialog.dataset.state='loading';
 syncReview();
 if(currentObject){mixer?.stopAllAction();mixer?.uncacheRoot(currentObject);scene.remove(currentObject);freeObject(currentObject);currentObject=null;}
 mixer=null;currentAction=null;clips=[];el('model3d-time').value='0';el('model3d-play').textContent='播放动画';el('model3d-play').setAttribute('aria-pressed','false');el('model3d-animation').replaceChildren(new Option('静态模型',''));el('model3d-animation').disabled=true;
 el('model3d-play').disabled=true;el('model3d-time').disabled=true;el('model3d-wireframe').checked=false;
 if(location.protocol==='file:'){el('model3d-status').textContent='双击文件夹中的「启动模型审核.command」开启旋转与动画预览。这里仍可查看图片并填写意见。';dialog.dataset.state='file';return;}
 try{
  initialize();resize();
  const gltf=await new GLTFLoader().loadAsync('../../'+next.glb+'?v='+next.sha256);
  if(request!==token){freeObject(gltf.scene);return;}
  currentObject=gltf.scene;scene.add(currentObject);currentObject.updateMatrixWorld(true);
  currentObject.traverse(node=>{if(node.isMesh){node.castShadow=true;node.receiveShadow=true;}});
  bounds.setFromObject(currentObject);bounds.getCenter(center);extent=Math.max(...bounds.getSize(new THREE.Vector3()).toArray(),.2);
  frameView();clips=gltf.animations;mixer=clips.length?new THREE.AnimationMixer(currentObject):null;
  el('model3d-animation').replaceChildren(new Option('静态姿态',''),...clips.map(x=>new Option(clockLabels[x.name]||x.name,x.name)));
  el('model3d-animation').disabled=!clips.length;
  const initial=clips.find(x=>x.name==='idle')||clips[0];if(initial){el('model3d-animation').value=initial.name;chooseAnimation(initial.name);}
  el('model3d-status').textContent=clips.length?`已载入 · ${clips.length} 个动画可切换`:'已载入 · 拖动旋转，滚轮缩放';dialog.dataset.state='ready';
  if(!frameHandle){lastFrame=0;frameHandle=requestAnimationFrame(animate);}
 }catch(error){if(request!==token)return;el('model3d-status').textContent='三维预览未能载入。可继续查看渲染图并填写意见。';dialog.dataset.state='error';console.error('Model review load failed',error);}
}
window.openModel3D=async next=>{returnFocus=document.activeElement;if(!dialog.open)dialog.showModal();await showModel(next);};
dialog.addEventListener('close',()=>{++token;cancelAnimationFrame(frameHandle);frameHandle=0;lastFrame=0;if(currentObject){mixer?.stopAllAction();mixer?.uncacheRoot(currentObject);scene.remove(currentObject);freeObject(currentObject);currentObject=null;}mixer=null;currentAction=null;returnFocus?.focus();});
el('model3d-animation').addEventListener('change',event=>chooseAnimation(event.target.value));
el('model3d-play').addEventListener('click',()=>{if(!currentAction)return;currentAction.paused=!currentAction.paused;el('model3d-play').textContent=currentAction.paused?'播放动画':'暂停动画';el('model3d-play').setAttribute('aria-pressed',String(!currentAction.paused));});
el('model3d-time').addEventListener('input',event=>{if(currentAction){currentAction.time=Number(event.target.value)/1000*currentAction.getClip().duration;mixer.update(0);}});
el('model3d-wireframe').addEventListener('change',event=>{currentObject?.traverse(node=>{if(node.material)for(const mat of Array.isArray(node.material)?node.material:[node.material])mat.wireframe=event.target.checked;});});
for(const name of ['front','side','back','angle'])el('model3d-'+name).addEventListener('click',()=>frameView(name));
const save=()=>{if(!model)return;const success=window.assetReview.save(model,{status:el('model3d-review').value,note:el('model3d-note').value});el('model3d-saved').textContent=success?'已保存到当前浏览器':'本地保存失败，请导出审核';};
el('model3d-review').addEventListener('change',save);el('model3d-note').addEventListener('input',save);
for(const [id,step] of [['model3d-prev',-1],['model3d-next',1]])el(id).addEventListener('click',()=>{const list=window.assetReview.filtered();if(!list.length)return;const index=list.findIndex(x=>x.id===model.id);showModel(list[(index+step+list.length)%list.length]);});
