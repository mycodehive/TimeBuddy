'use strict';
const {contextBridge,ipcRenderer}=require('electron');
const invoke=(name,...args)=>ipcRenderer.invoke(name,...args);
contextBridge.exposeInMainWorld('buddy',{state:()=>invoke('state'),locales:()=>invoke('locales'),language:l=>invoke('language',l),setup:(p,c)=>invoke('setup',p,c),auth:p=>invoke('auth',p),unlock:p=>invoke('unlock',p),parentGet:()=>invoke('parent-get'),save:v=>invoke('parent-save',v),action:(a,n)=>invoke('action',a,n),dismiss:()=>invoke('dismiss'),onState:fn=>{ipcRenderer.on('state',(_,v)=>fn(v));},onParentOpen:fn=>{ipcRenderer.on('parent-open',()=>fn());}});
