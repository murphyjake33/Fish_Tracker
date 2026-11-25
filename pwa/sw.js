const V="tl-v2",CDN="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js",SHELL=["./","index.html","config.js","manifest.webmanifest","icons/icon-192.png"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(V).then(async c=>{await c.addAll(SHELL);try{await c.put(CDN,await fetch(CDN,{mode:"no-cors"}));}catch(x){}}));self.skipWaiting();});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==V).map(x=>caches.delete(x)))));self.clients.claim();});
self.addEventListener("fetch",e=>{
  const u=e.request.url;if(e.request.method!=="GET")return;
  if(u===CDN){e.respondWith(caches.match(CDN).then(m=>m||fetch(e.request)));return;}
  if(new URL(u).origin!==location.origin)return;
  e.respondWith(fetch(e.request).then(r=>{const c=r.clone();caches.open(V).then(x=>x.put(e.request,c));return r;}).catch(()=>caches.match(e.request)));
});
