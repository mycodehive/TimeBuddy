'use strict';
const fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib'),n=256,pixels=Buffer.alloc((n*4+1)*n);
function crc(b){let c=0xffffffff;for(const v of b){c^=v;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;}
function chunk(type,data){const t=Buffer.from(type),out=Buffer.alloc(data.length+12);out.writeUInt32BE(data.length,0);t.copy(out,4);data.copy(out,8);out.writeUInt32BE(crc(Buffer.concat([t,data])),8+data.length);return out;}
for(let y=0;y<n;y++)for(let x=0;x<n;x++){let p=[0,0,0,0];const e=(cx,cy,rx,ry)=>((x-cx)/rx)**2+((y-cy)/ry)**2<=1;
 if(e(128,218,86,15))p=[183,209,190,110];
 if(e(58,64,32,35)||e(198,64,32,35))p=[222,155,93,255];
 if(e(58,65,18,20)||e(198,65,18,20))p=[255,215,168,255];
 if(e(128,126,99,87))p=[238,175,105,255];
 if(e(128,140,82,67))p=[250,195,132,255];
 if(e(128,154,51,38))p=[255,226,183,255];
 if(e(91,116,8,12)||e(165,116,8,12))p=[65,53,44,255];
 if(e(89,113,2,3)||e(163,113,2,3))p=[255,255,255,255];
 if(e(71,141,13,7)||e(185,141,13,7))p=[245,143,130,255];
 if(e(128,146,9,6))p=[83,60,44,255];
 if(y>=156&&y<=172&&Math.abs(((x-128)/20)**2+((y-154)/14)**2-1)<0.24)p=[83,60,44,255];
 if(e(128,204,30,23))p=[70,145,116,255];
 if(e(128,204,22,17))p=[245,253,242,255];
 if((Math.abs(x-128)<2&&y>193&&y<205)||(Math.abs(y-204)<2&&x>=128&&x<140))p=[70,145,116,255];
 const i=y*(n*4+1)+1+x*4;for(let j=0;j<4;j++)pixels[i+j]=p[j];
}
const h=Buffer.alloc(13);h.writeUInt32BE(n);h.writeUInt32BE(n,4);h[8]=8;h[9]=6;
const png=Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',h),chunk('IDAT',zlib.deflateSync(pixels)),chunk('IEND',Buffer.alloc(0))]);
const ico=Buffer.alloc(22);ico.writeUInt16LE(1,2);ico.writeUInt16LE(1,4);ico.writeUInt16LE(1,10);ico.writeUInt16LE(32,12);ico.writeUInt32LE(png.length,14);ico.writeUInt32LE(22,18);
for(const dir of ['src/assets','build'])fs.mkdirSync(path.join(__dirname,'..',dir),{recursive:true});
fs.writeFileSync(path.join(__dirname,'../src/assets/buddy.png'),png);fs.writeFileSync(path.join(__dirname,'../build/icon.ico'),Buffer.concat([ico,png]));
